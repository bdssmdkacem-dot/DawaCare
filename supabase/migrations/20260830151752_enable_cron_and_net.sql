-- Enable extensions used by the scheduled escalation job.
create extension if not exists pg_cron;
create extension if not exists pg_net;
