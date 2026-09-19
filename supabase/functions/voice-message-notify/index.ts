import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const FCM_SERVICE_ACCOUNT_JSON = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'Unauthorized' }, 401);

  const userClient = createClient(SUPABASE_URL, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return json({ error: 'Unauthorized' }, 401);

  const body = await req.json().catch(() => null);
  const messageId = body?.voice_message_id as string | undefined;
  if (!messageId) return json({ error: 'voice_message_id is required' }, 400);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const { data: message, error } = await admin
    .from('voice_messages')
    .select('id, sender_id, patient_id')
    .eq('id', messageId)
    .single();
  if (error || !message) {
    console.error('voice-message-notify: message not found', messageId, error?.message);
    return json({ error: 'MESSAGE_NOT_FOUND' }, 404);
  }
  if (message.sender_id !== user.id) return json({ error: 'Forbidden' }, 403);

  const { data: link } = await admin
    .from('caregiver_patient')
    .select('id')
    .eq('caregiver_id', user.id)
    .eq('patient_id', message.patient_id)
    .in('role', ['PRIMARY_CAREGIVER', 'CAREGIVER'])
    .maybeSingle();
  if (!link) return json({ error: 'Forbidden' }, 403);

  // Fail loud instead of silently returning 200 with sent:0 — a caregiver
  // hitting this path in production means every voice message push is
  // silently dropped, which is exactly the bug this rewrite fixes.
  if (!FCM_SERVICE_ACCOUNT_JSON) {
    console.error('voice-message-notify: FCM_SERVICE_ACCOUNT_JSON secret is not configured on this project');
    return json({ sent: 0, reason: 'FCM_NOT_CONFIGURED' }, 500);
  }

  // Idempotency guard: the Flutter client retries this call up to 3 times
  // if it can't confirm success (e.g. a flaky network read of *our
  // response*, even though FCM already accepted the message). Without this
  // guard a retry would re-push and the patient gets duplicate pings for
  // one voice message.
  const eventKey = `voice-message:${messageId}`;
  const { data: existingEvent } = await admin
    .from('push_notification_events')
    .select('sent_count')
    .eq('event_key', eventKey)
    .maybeSingle();
  if (existingEvent && existingEvent.sent_count > 0) {
    return json({ sent: existingEvent.sent_count, duplicate: true });
  }

  const { data: sender } = await admin.from('profiles').select('full_name').eq('id', user.id).single();
  const { data: recipientProfile } = await admin.from('profiles').select('language').eq('id', message.patient_id).maybeSingle();
  const language = recipientProfile?.language === 'en' || recipientProfile?.language === 'fr' ? recipientProfile.language : 'ar';
  const senderName = sender?.full_name || (language === 'en' ? 'Your caregiver' : language === 'fr' ? 'Votre accompagnant' : 'متابعك');

  const { data: devices, error: devicesError } = await admin
    .from('devices')
    .select('id, push_token')
    .eq('user_id', message.patient_id)
    .not('push_token', 'is', null);
  if (devicesError) {
    console.error('voice-message-notify: failed to load devices', devicesError.message);
    return json({ error: devicesError.message }, 500);
  }
  const validDevices = (devices ?? []).filter((d) => typeof d.push_token === 'string' && d.push_token.trim().length > 0);
  if (validDevices.length === 0) {
    console.warn('voice-message-notify: patient has no registered push device', message.patient_id);
    return json({ sent: 0, devices: 0, reason: 'NO_PUSH_DEVICES' });
  }

  const account = JSON.parse(FCM_SERVICE_ACCOUNT_JSON);
  const accessToken = await getAccessToken(account);
  let sent = 0;
  let invalid = 0;
  const failures: Array<{ device_id: string; status: number; body: string }> = [];

  for (const device of validDevices) {
    try {
      const response = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: {
            token: device.push_token,
            notification: {
              title: language === 'en' ? 'New voice message 🎙️' : language === 'fr' ? 'Nouveau message vocal 🎙️' : 'رسالة صوتية جديدة 🎙️',
              body: language === 'en' ? `${senderName} sent you a voice message.` : language === 'fr' ? `${senderName} vous a envoyé un message vocal.` : `${senderName} أرسل لك رسالة صوتية.`,
            },
            data: { type: 'VOICE_MESSAGE', voice_message_id: message.id, sender_name: senderName },
            android: {
              priority: 'high',
              notification: {
                channel_id: 'caregiver_alerts_v2',
                sound: 'default',
                notification_priority: 'PRIORITY_HIGH',
              },
            },
          },
        }),
      });
      if (response.ok) {
        sent++;
      } else {
        const responseBody = await response.text();
        failures.push({ device_id: device.id, status: response.status, body: responseBody.slice(0, 500) });
        console.error('voice-message-notify: FCM send failed', device.id, response.status, responseBody.slice(0, 500));
        if (response.status === 404 || response.status === 410) {
          invalid++;
          const { error: deleteError } = await admin.from('devices').delete().eq('id', device.id);
          if (deleteError) console.error('voice-message-notify: failed to prune stale device', device.id, deleteError.message);
        }
      }
    } catch (err) {
      failures.push({ device_id: device.id, status: 0, body: String(err) });
      console.error('voice-message-notify: FCM send threw', device.id, err);
    }
  }

  const { error: eventError } = await admin.from('push_notification_events').upsert({
    event_key: eventKey,
    event_type: 'VOICE_MESSAGE',
    sender_id: user.id,
    recipient_id: message.patient_id,
    sent_at: sent > 0 ? new Date().toISOString() : null,
    sent_count: sent,
  }, { onConflict: 'event_key' });
  if (eventError) console.error('voice-message-notify: failed to record push event', eventError.message);

  if (sent === 0) {
    console.error('voice-message-notify: delivery failed for all devices', message.patient_id, JSON.stringify(failures));
    return json({ error: 'FCM_DELIVERY_FAILED', sent, devices: validDevices.length, invalid, failures }, 502);
  }
  return json({ sent, devices: validDevices.length, invalid, failed: failures.length });
});

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

let cachedAccessToken: { token: string; expiresAt: number } | null = null;

async function getAccessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessToken.expiresAt - 60 > now) return cachedAccessToken.token;

  const encoder = new TextEncoder();
  const base64url = (bytes: ArrayBuffer | Uint8Array): string => {
    const array = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
    const bin = Array.from(array).map((b) => String.fromCharCode(b)).join('');
    return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  };
  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${base64url(encoder.encode(JSON.stringify(header)))}.${base64url(encoder.encode(JSON.stringify(claims)))}`;
  const pemBody = account.private_key.replace(/-----BEGIN PRIVATE KEY-----/, '').replace(/-----END PRIVATE KEY-----/, '').replace(/\s/g, '');
  const keyDer = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey('pkcs8', keyDer, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', cryptoKey, encoder.encode(unsigned));
  const jwt = `${unsigned}.${base64url(signature)}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: jwt }),
  });
  if (!response.ok) throw new Error(`OAuth token exchange failed: ${await response.text()}`);
  const tokenJson = await response.json();
  cachedAccessToken = { token: tokenJson.access_token, expiresAt: now + (tokenJson.expires_in ?? 3600) };
  return cachedAccessToken.token;
}
