// DawaCare — escalation-check Edge Function
//
// Purpose: runs on a schedule (via pg_cron, see supabase/README.md) and
// catches doses that were never confirmed by the patient. This is the
// reliable, server-side half of the reminder system — it does not depend on
// the patient's phone being on, connected, or the app being open, which is
// why it lives here instead of only as a local notification on-device.
//
// For every PENDING/REMINDER_SENT/SNOOZED dose whose grace period has
// elapsed, it:
//   1. marks the dose MISSED
//   2. creates a caregiver_alerts row for every linked caregiver
//   3. sends a push notification via FCM HTTP v1 (if a service account is configured)
//
// Deploy with:
//   supabase functions deploy escalation-check --no-verify-jwt
// Schedule with pg_cron (see supabase/README.md for the exact SQL).
//
// Push notifications are OPTIONAL for this function to work — dose status
// and in-app caregiver_alerts rows are always written regardless. Push only
// activates once FCM_SERVICE_ACCOUNT_JSON is set (see supabase/README.md).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
// The full JSON key of a Firebase service account with the
// "Firebase Cloud Messaging API" role, set via:
//   supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat service-account.json)"
const FCM_SERVICE_ACCOUNT_JSON = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');

Deno.serve(async (_req) => {
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const now = new Date();

  const { data: overdueDoses, error } = await supabase
    .from('dose_instances')
    .select('id, patient_id, medication_id, scheduled_at, status, dose_amount')
    .in('status', ['PENDING', 'REMINDER_SENT', 'SNOOZED'])
    .lt('scheduled_at', now.toISOString());

  if (error) {
    console.error('Failed to fetch overdue doses', error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  if (!overdueDoses || overdueDoses.length === 0) {
    return new Response(JSON.stringify({ checked: 0, escalated: 0 }), { status: 200 });
  }

  const patientIds = [...new Set(overdueDoses.map((d) => d.patient_id))];

  const { data: policies } = await supabase
    .from('reminder_policies')
    .select('patient_id, grace_period_min, caregiver_escalation')
    .in('patient_id', patientIds);

  const policyByPatient = new Map((policies ?? []).map((p) => [p.patient_id, p]));

  let escalatedCount = 0;

  for (const dose of overdueDoses) {
    const policy = policyByPatient.get(dose.patient_id) ?? {
      grace_period_min: 60,
      caregiver_escalation: true,
    };

    const scheduledAt = new Date(dose.scheduled_at);
    const graceDeadline = new Date(scheduledAt.getTime() + policy.grace_period_min * 60_000);
    if (now < graceDeadline) continue; // still inside grace period

    const { error: updateError } = await supabase
      .from('dose_instances')
      .update({ status: 'MISSED', updated_at: now.toISOString() })
      .eq('id', dose.id)
      .in('status', ['PENDING', 'REMINDER_SENT', 'SNOOZED']);
    if (updateError) {
      console.error('Failed to mark dose missed', dose.id, updateError);
      continue;
    }

    await supabase.from('dose_events').insert({
      dose_id: dose.id,
      patient_id: dose.patient_id,
      action: 'MISSED',
      source: 'SYSTEM',
    });

    if (!policy.caregiver_escalation) continue;

    const { data: existingAlert } = await supabase
      .from('caregiver_alerts')
      .select('id')
      .eq('dose_id', dose.id)
      .limit(1);
    if (existingAlert && existingAlert.length > 0) continue;

    const { data: caregivers } = await supabase
      .from('caregiver_patient')
      .select('caregiver_id')
      .eq('patient_id', dose.patient_id);

    const { data: patientProfile } = await supabase
      .from('profiles')
      .select('full_name')
      .eq('id', dose.patient_id)
      .single();

    const patientName = patientProfile?.full_name || 'أحد أفراد العائلة';
    const message = `لم يتم تأكيد جرعة دواء ${patientName} في موعدها.`;

    for (const link of caregivers ?? []) {
      await supabase.from('caregiver_alerts').insert({
        caregiver_id: link.caregiver_id,
        patient_id: dose.patient_id,
        dose_id: dose.id,
        type: 'MISSED_DOSE',
        message,
      });

      if (FCM_SERVICE_ACCOUNT_JSON) {
        await sendPushToUser(supabase, link.caregiver_id, message).catch((err) =>
          console.error('FCM push failed for', link.caregiver_id, err),
        );
      }
    }

    escalatedCount += 1;
  }

  return new Response(
    JSON.stringify({ checked: overdueDoses.length, escalated: escalatedCount }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
});

// ---------------------------------------------------------------------------
// FCM HTTP v1 — the legacy `fcm.googleapis.com/fcm/send` server-key API was
// retired by Google, so this uses a service-account-signed OAuth2 token
// instead, built with the Web Crypto API (no external JWT library needed).
// ---------------------------------------------------------------------------

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

let cachedAccessToken: { token: string; expiresAt: number } | null = null;

async function getAccessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessToken.expiresAt - 60 > now) {
    return cachedAccessToken.token;
  }

  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };

  const encoder = new TextEncoder();
  const base64url = (bytes: ArrayBuffer | Uint8Array): string => {
    const bin = Array.from(bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes))
      .map((b) => String.fromCharCode(b))
      .join('');
    return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  };

  const unsigned =
    base64url(encoder.encode(JSON.stringify(header))) +
    '.' +
    base64url(encoder.encode(JSON.stringify(claims)));

  const pemBody = account.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const keyDer = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyDer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    encoder.encode(unsigned),
  );

  const jwt = `${unsigned}.${base64url(signature)}`;

  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!tokenResponse.ok) {
    throw new Error(`OAuth token exchange failed: ${await tokenResponse.text()}`);
  }

  const tokenJson = await tokenResponse.json();
  cachedAccessToken = {
    token: tokenJson.access_token,
    expiresAt: now + (tokenJson.expires_in ?? 3600),
  };
  return cachedAccessToken.token;
}

async function sendPushToUser(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  userId: string,
  message: string,
): Promise<void> {
  if (!FCM_SERVICE_ACCOUNT_JSON) return;
  const account: ServiceAccount = JSON.parse(FCM_SERVICE_ACCOUNT_JSON);
  const accessToken = await getAccessToken(account);

  const { data: devices } = await supabase
    .from('devices')
    .select('push_token')
    .eq('user_id', userId)
    .not('push_token', 'is', null);

  for (const device of devices ?? []) {
    await fetch(
      `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: device.push_token,
            notification: { title: 'دواء كير — تنبيه', body: message },
            android: { priority: 'high' },
          },
        }),
      },
    );
  }
}
