-- Schedules the escalation-check Edge Function every 10 minutes.
--
-- The bearer token below is this project's *anon/publishable* key (safe to
-- read — it's the same value already public in the compiled app). It's only
-- there to pass the function's verify_jwt gate; the function itself talks to
-- the database using SUPABASE_SERVICE_ROLE_KEY, which Supabase injects
-- automatically into every Edge Function's environment.
--
-- If you rotate the anon key or redeploy to a new project, re-run this with
-- the new project ref/key (or `select cron.alter_job(...)`), otherwise the
-- cron job keeps calling the old URL/key and silently fails.
select cron.schedule(
  'dawacare-escalation-check',
  '*/10 * * * *',
  $$
  select net.http_post(
    url := 'https://lwdwlfhytdetziqfbgje.supabase.co/functions/v1/escalation-check',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx3ZHdsZmh5dGRldHppcWZiZ2plIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgwNDQ4NDAsImV4cCI6MjEwMzYyMDg0MH0.rOKnMi9sP3LSK5N-Ncjt_iHJ6ajM2F54JQVhwvdU9-g',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
