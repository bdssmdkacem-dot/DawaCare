import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const FCM_SERVICE_ACCOUNT_JSON = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return new Response('Unauthorized', { status: 401 });

  const userClient = createClient(SUPABASE_URL, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return new Response('Unauthorized', { status: 401 });

  const body = await req.json();
  const messageId = body?.voice_message_id as string | undefined;
  if (!messageId) return new Response('voice_message_id is required', { status: 400 });

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const { data: message, error } = await admin
    .from('voice_messages')
    .select('id, sender_id, patient_id')
    .eq('id', messageId)
    .single();
  if (error || !message || message.sender_id !== user.id) {
    return new Response('Forbidden', { status: 403 });
  }

  const { data: link } = await admin
    .from('caregiver_patient')
    .select('id')
    .eq('caregiver_id', user.id)
    .eq('patient_id', message.patient_id)
    .in('role', ['PRIMARY_CAREGIVER', 'CAREGIVER'])
    .maybeSingle();
  if (!link) return new Response('Forbidden', { status: 403 });

  if (!FCM_SERVICE_ACCOUNT_JSON) {
    return new Response(JSON.stringify({ sent: false, reason: 'FCM_NOT_CONFIGURED' }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const { data: sender } = await admin.from('profiles').select('full_name').eq('id', user.id).single();
  const senderName = sender?.full_name || 'متابعك';
  const { data: devices } = await admin
    .from('devices')
    .select('push_token')
    .eq('user_id', message.patient_id)
    .not('push_token', 'is', null);

  const account = JSON.parse(FCM_SERVICE_ACCOUNT_JSON);
  const accessToken = await getAccessToken(account);
  let sent = 0;

  for (const device of devices ?? []) {
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
      {
        method: 'POST',
        headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: {
            token: device.push_token,
            notification: {
              title: 'رسالة صوتية جديدة 🎙️',
              body: `${senderName} أرسل لك رسالة صوتية.`,
            },
            data: { type: 'VOICE_MESSAGE', voice_message_id: message.id },
            android: { priority: 'high', notification: { channel_id: 'caregiver_alerts' } },
          },
        }),
      },
    );
    if (response.ok) sent++;
  }

  return new Response(JSON.stringify({ sent }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
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
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!response.ok) throw new Error(`OAuth token exchange failed: ${await response.text()}`);
  const json = await response.json();
  cachedAccessToken = { token: json.access_token, expiresAt: now + (json.expires_in ?? 3600) };
  return cachedAccessToken.token;
}
