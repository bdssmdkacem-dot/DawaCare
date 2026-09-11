import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const FCM = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  const h = req.headers.get('Authorization');
  if (!h) return json({ error: 'Unauthorized' }, 401);

  const userClient = createClient(URL, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: h } },
  });
  const {
    data: { user },
  } = await userClient.auth.getUser();
  if (!user) return json({ error: 'Unauthorized' }, 401);

  const body = await req.json().catch(() => null);
  const messageId = body?.message_id as string | undefined;
  if (!messageId) return json({ error: 'MESSAGE_ID_REQUIRED' }, 400);

  const admin = createClient(URL, SERVICE);
  const { data: message, error: messageError } = await admin
    .from('messages')
    .select('id,patient_id,sender_id,recipient_id,message_type,body')
    .eq('id', messageId)
    .single();
  if (messageError || !message) return json({ error: 'MESSAGE_NOT_FOUND' }, 404);
  if (message.sender_id !== user.id) return json({ error: 'FORBIDDEN' }, 403);

  const { data: link } = await admin
    .from('caregiver_patient')
    .select('id')
    .eq('patient_id', message.patient_id)
    .or(`caregiver_id.eq.${message.sender_id},caregiver_id.eq.${message.recipient_id}`)
    .maybeSingle();
  if (!link) return json({ error: 'FORBIDDEN' }, 403);
  if (!FCM) return json({ error: 'FCM_NOT_CONFIGURED' }, 500);

  const eventKey = `message:${messageId}`;
  const { data: old } = await admin
    .from('push_notification_events')
    .select('sent_count')
    .eq('event_key', eventKey)
    .maybeSingle();
  if (old && old.sent_count > 0) {
    return json({ sent: old.sent_count, duplicate: true });
  }

  const { data: sender } = await admin
    .from('profiles')
    .select('full_name')
    .eq('id', message.sender_id)
    .single();
  const senderName = sender?.full_name || 'جهة اتصالك';
  const title =
    message.message_type === 'voice'
      ? 'رسالة صوتية جديدة 🎙️'
      : message.message_type === 'image'
        ? 'صورة جديدة 🖼️'
        : 'رسالة جديدة 💬';
  const text =
    message.message_type === 'text'
      ? message.body || 'لديك رسالة جديدة.'
      : message.message_type === 'voice'
        ? `${senderName} أرسل لك رسالة صوتية.`
        : `${senderName} أرسل لك صورة.`;

  const { data: devices, error: devicesError } = await admin
    .from('devices')
    .select('id,push_token')
    .eq('user_id', message.recipient_id)
    .not('push_token', 'is', null);
  if (devicesError) return json({ error: devicesError.message }, 500);

  const valid = (devices ?? []).filter(
    (d) => typeof d.push_token === 'string' && d.push_token.trim(),
  );
  if (!valid.length) return json({ sent: 0, reason: 'NO_PUSH_DEVICES' });

  const account = JSON.parse(FCM);
  const token = await getAccessToken(account);
  let sent = 0;

  for (const device of valid) {
    try {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token: device.push_token,
              notification: { title, body: text.slice(0, 180) },
              data: {
                type: 'CHAT_MESSAGE',
                message_id: message.id,
                patient_id: message.patient_id,
                message_type: message.message_type,
                sender_id: message.sender_id,
              },
              android: {
                priority: 'high',
                notification: {
                  channel_id: 'caregiver_alerts',
                  sound: 'default',
                  notification_priority: 'PRIORITY_HIGH',
                },
              },
            },
          }),
        },
      );
      if (response.ok) {
        sent++;
      } else if (response.status === 404 || response.status === 410) {
        await admin.from('devices').delete().eq('id', device.id);
      }
    } catch (e) {
      console.error('FCM', e);
    }
  }

  await admin.from('push_notification_events').upsert(
    {
      event_key: eventKey,
      event_type: 'CHAT_MESSAGE',
      sender_id: message.sender_id,
      recipient_id: message.recipient_id,
      sent_at: sent ? new Date().toISOString() : null,
      sent_count: sent,
    },
    { onConflict: 'event_key' },
  );

  return sent
    ? json({ sent, devices: valid.length })
    : json({ error: 'FCM_DELIVERY_FAILED', sent }, 502);
});

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

let cached: { token: string; expiresAt: number } | null = null;

async function getAccessToken(a: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.expiresAt - 60 > now) return cached.token;
  const enc = new TextEncoder();
  const b64 = (x: ArrayBuffer | Uint8Array) => {
    const u = x instanceof Uint8Array ? x : new Uint8Array(x);
    return btoa(Array.from(u).map((c) => String.fromCharCode(c)).join(''))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');
  };
  const head = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: a.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${b64(enc.encode(JSON.stringify(head)))}.${b64(enc.encode(JSON.stringify(claims)))}`;
  const pem = a.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    enc.encode(unsigned),
  );
  const jwt = `${unsigned}.${b64(sig)}`;
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!r.ok) throw new Error(`OAuth token exchange failed: ${await r.text()}`);
  const j = await r.json();
  cached = { token: j.access_token, expiresAt: now + (j.expires_in ?? 3600) };
  return cached.token;
}
