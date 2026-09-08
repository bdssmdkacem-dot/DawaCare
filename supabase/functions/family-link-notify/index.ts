import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const FCM = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  const auth = req.headers.get('Authorization');
  if (!auth) return json({ error: 'Unauthorized' }, 401);

  const userClient = createClient(URL, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: auth } },
  });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return json({ error: 'Unauthorized' }, 401);

  const body = await req.json();
  const requestId = body?.request_id as string | undefined;
  const eventType = body?.event_type as string | undefined;
  if (!requestId || !eventType) return json({ error: 'request_id and event_type are required' }, 400);
  if (!['REQUESTED', 'APPROVED', 'REJECTED'].includes(eventType)) return json({ error: 'invalid event_type' }, 400);
  if (!FCM) return json({ sent: 0, reason: 'FCM_NOT_CONFIGURED' });

  const admin = createClient(URL, SERVICE);
  const { data: request, error } = await admin
      .from('family_link_requests')
      .select('id,patient_id,caregiver_id,status')
      .eq('id', requestId)
      .single();
  if (error || !request) return json({ error: 'REQUEST_NOT_FOUND' }, 404);

  const senderId = eventType === 'REQUESTED' ? request.caregiver_id : request.patient_id;
  const recipientId = eventType === 'REQUESTED' ? request.patient_id : request.caregiver_id;
  if (user.id !== senderId) return json({ error: 'Forbidden' }, 403);
  if (eventType === 'APPROVED' && request.status !== 'APPROVED') return json({ error: 'REQUEST_NOT_APPROVED' }, 409);
  if (eventType === 'REJECTED' && request.status !== 'REJECTED') return json({ error: 'REQUEST_NOT_REJECTED' }, 409);

  const eventKey = `family-link:${eventType}:${requestId}`;
  const { data: existing } = await admin
      .from('push_notification_events')
      .select('sent_count')
      .eq('event_key', eventKey)
      .maybeSingle();
  if (existing?.sent_count > 0) return json({ sent: existing.sent_count, duplicate: true });

  const { data: sender } = await admin
      .from('profiles')
      .select('full_name,avatar_url')
      .eq('id', user.id)
      .maybeSingle();
  const { data: devices } = await admin
      .from('devices')
      .select('id,push_token')
      .eq('user_id', recipientId)
      .not('push_token', 'is', null);

  const account = JSON.parse(FCM);
  const accessToken = await getAccessToken(account);
  let sent = 0;
  for (const device of devices ?? []) {
    const title = eventType === 'APPROVED'
        ? 'تم قبول طلب المتابعة'
        : eventType === 'REJECTED'
            ? 'تم رفض طلب المتابعة'
            : 'طلب متابعة جديد';
    const bodyText = eventType === 'APPROVED'
        ? `${sender?.full_name || 'المريض'} قبل طلب متابعته.`
        : eventType === 'REJECTED'
            ? `${sender?.full_name || 'المريض'} رفض طلب المتابعة.`
            : `${sender?.full_name || 'أحد أفراد العائلة'} يريد متابعتك.`;
    const image = sender?.avatar_url || undefined;

    try {
      const response = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: {
            token: device.push_token,
            notification: { title, body: bodyText, ...(image ? { image } : {}) },
            data: {
              type: `FAMILY_LINK_${eventType}`,
              request_id: requestId,
              sender_name: sender?.full_name || '',
              sender_avatar_url: sender?.avatar_url || '',
            },
            android: {
              priority: 'high',
              notification: {
                channel_id: 'caregiver_alerts',
                sound: 'default',
                notification_priority: 'PRIORITY_HIGH',
                ...(image ? { image } : {}),
              },
            },
          },
        }),
      });
      if (response.ok) {
        sent++;
      } else if (response.status === 404 || response.status === 410) {
        try { await admin.from('devices').delete().eq('id', device.id); } catch (_) {}
      }
    } catch (_) {}
  }

  await admin.from('push_notification_events').upsert({
    event_key: eventKey,
    event_type: eventType,
    request_id: requestId,
    sender_id: user.id,
    recipient_id: recipientId,
    sent_at: sent > 0 ? new Date().toISOString() : null,
    sent_count: sent,
  }, { onConflict: 'event_key' });

  return json({ sent, devices: devices?.length ?? 0 });
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}

interface Account { project_id: string; client_email: string; private_key: string; }
let cached: { token: string; expiresAt: number } | null = null;

async function getAccessToken(a: Account): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.expiresAt - 60 > now) return cached.token;
  const enc = new TextEncoder();
  const b64 = (b: ArrayBuffer | Uint8Array) => {
    const x = b instanceof Uint8Array ? b : new Uint8Array(b);
    return btoa(Array.from(x).map(c => String.fromCharCode(c)).join(''))
      .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  };
  const header = b64(enc.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claims = b64(enc.encode(JSON.stringify({
    iss: a.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })));
  const unsigned = `${header}.${claims}`;
  const pem = a.private_key.replace(/-----BEGIN PRIVATE KEY-----/, '').replace(/-----END PRIVATE KEY-----/, '').replace(/\s/g, '');
  const der = Uint8Array.from(atob(pem), x => x.charCodeAt(0));
  const key = await crypto.subtle.importKey('pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, enc.encode(unsigned));
  const jwt = `${unsigned}.${b64(sig)}`;
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!response.ok) throw new Error(`OAuth token exchange failed: ${await response.text()}`);
  const jsonResponse = await response.json();
  cached = { token: jsonResponse.access_token, expiresAt: now + (jsonResponse.expires_in ?? 3600) };
  return cached.token;
}
