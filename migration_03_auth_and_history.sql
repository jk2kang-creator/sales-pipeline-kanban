-- ============================================================
-- 마이그레이션 03: 사용자 인증·권한(FR-AUTH) + 딜 변경이력(FR-DEAL-04)
--                  + 접속 이력(FR-AUTH-04)
-- Supabase 대시보드 > SQL Editor 에서 전체 실행하세요.
-- 실행 후 반드시 맨 아래 "최초 관리자 지정" 절차를 진행해야 합니다.
-- ============================================================

-- ---------- 1. app_users: 로그인 계정 프로필 (역할·부서) ----------
create table if not exists app_users (
  id           uuid primary key references auth.users(id) on delete cascade,
  email        text not null,
  name         text,
  department   text,                                   -- 영업1팀 등 (DEPARTMENTS 값과 일치)
  role         text not null default 'pending'          -- admin/manager/rep/viewer/pending
                 check (role in ('admin','manager','rep','viewer','pending')),
  is_approved  boolean not null default false,
  created_at   timestamptz not null default now()
);

-- 신규 가입 시 app_users 행 자동 생성 (관리자 승인 전까지 role='pending')
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.app_users (id, email) values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

-- 현재 로그인한 사용자의 role/department/name/승인여부를 안전하게 조회하는 함수
-- (security definer로 RLS 재귀 없이 app_users를 조회)
create or replace function public.app_role()
returns text language sql security definer set search_path = public stable as
$$ select coalesce((select role from app_users where id = auth.uid()), 'pending') $$;

create or replace function public.app_department()
returns text language sql security definer set search_path = public stable as
$$ select department from app_users where id = auth.uid() $$;

create or replace function public.app_name()
returns text language sql security definer set search_path = public stable as
$$ select name from app_users where id = auth.uid() $$;

create or replace function public.app_is_approved()
returns boolean language sql security definer set search_path = public stable as
$$ select coalesce((select is_approved from app_users where id = auth.uid()), false) $$;

-- 회원가입 직후 본인 이름·부서를 채우는 전용 함수 (role/is_approved는 손댈 수 없음)
create or replace function public.complete_profile(p_name text, p_department text)
returns void language plpgsql security definer set search_path = public as
$$
begin
  update app_users set name = p_name, department = p_department where id = auth.uid();
end;
$$;
grant execute on function public.complete_profile(text, text) to authenticated;

alter table app_users enable row level security;
drop policy if exists "app_users_select" on app_users;
create policy "app_users_select" on app_users for select to authenticated
  using (id = auth.uid() or app_role() = 'admin');
drop policy if exists "app_users_admin_write" on app_users;
create policy "app_users_admin_write" on app_users for update to authenticated
  using (app_role() = 'admin') with check (app_role() = 'admin');

-- ---------- 2. access_log: 로그인 접속 이력 (FR-AUTH-04) ----------
create table if not exists access_log (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references app_users(id) on delete set null,
  event_type text not null default 'login',
  created_at timestamptz not null default now()
);
alter table access_log enable row level security;
drop policy if exists "access_log_insert_own" on access_log;
create policy "access_log_insert_own" on access_log for insert to authenticated
  with check (user_id = auth.uid());
drop policy if exists "access_log_select" on access_log;
create policy "access_log_select" on access_log for select to authenticated
  using (app_role() = 'admin');

-- ---------- 3. deal_history: 딜 변경 이력 자동 기록 (FR-DEAL-04) ----------
create table if not exists deal_history (
  id            uuid primary key default gen_random_uuid(),
  deal_id       uuid not null references deals(id) on delete cascade,
  changed_by    uuid references app_users(id) on delete set null default auth.uid(),
  change_type   text not null default 'updated',   -- created/updated/stage_changed
  field_changed text,                               -- 한글 라벨 (예: 단계, 예상금액)
  old_value     text,
  new_value     text,
  changed_at    timestamptz not null default now()
);
create index if not exists idx_deal_history_deal_id on deal_history(deal_id);

alter table deal_history enable row level security;
drop policy if exists "deal_history_select" on deal_history;
create policy "deal_history_select" on deal_history for select to authenticated
  using (
    app_role() in ('admin','viewer')
    or exists (
      select 1 from deals d where d.id = deal_history.deal_id
        and (app_role() in ('manager','rep') and d.department = app_department())
    )
  );
drop policy if exists "deal_history_insert" on deal_history;
create policy "deal_history_insert" on deal_history for insert to authenticated
  with check (app_is_approved());

-- ---------- 4. stages: 읽기는 전체 허용, 쓰기는 차단 (앱에서 수정하지 않음) ----------
drop policy if exists "stages_anon_all" on stages;
drop policy if exists "stages_read" on stages;
create policy "stages_read" on stages for select to anon, authenticated using (true);

-- ---------- 5. deals: 역할·부서 기준 행 수준 접근 제어 (FR-AUTH-03) ----------
drop policy if exists "deals_anon_all" on deals;

drop policy if exists "deals_select" on deals;
create policy "deals_select" on deals for select to authenticated
  using (
    app_is_approved() and (
      app_role() in ('admin','viewer')
      or (app_role() in ('manager','rep') and department = app_department())
    )
  );

drop policy if exists "deals_insert" on deals;
create policy "deals_insert" on deals for insert to authenticated
  with check (
    app_is_approved() and (
      app_role() = 'admin'
      or (app_role() = 'manager' and department = app_department())
      or (app_role() = 'rep' and department = app_department() and owner = app_name())
    )
  );

drop policy if exists "deals_update" on deals;
create policy "deals_update" on deals for update to authenticated
  using (
    app_is_approved() and (
      app_role() = 'admin'
      or (app_role() = 'manager' and department = app_department())
      or (app_role() = 'rep' and department = app_department() and owner = app_name())
    )
  )
  with check (
    app_role() = 'admin'
    or (app_role() = 'manager' and department = app_department())
    or (app_role() = 'rep' and department = app_department() and owner = app_name())
  );

drop policy if exists "deals_delete" on deals;
create policy "deals_delete" on deals for delete to authenticated
  using (
    app_is_approved() and (
      app_role() = 'admin'
      or (app_role() = 'manager' and department = app_department())
      or (app_role() = 'rep' and department = app_department() and owner = app_name())
    )
  );

-- ---------- 6. activities: deals와 동일한 기준 (연결된 딜 기준) ----------
drop policy if exists "activities_anon_all" on activities;

drop policy if exists "activities_select" on activities;
create policy "activities_select" on activities for select to authenticated
  using (
    app_is_approved() and exists (
      select 1 from deals d where d.id = activities.deal_id and (
        app_role() in ('admin','viewer')
        or (app_role() in ('manager','rep') and d.department = app_department())
      )
    )
  );

drop policy if exists "activities_write" on activities;
create policy "activities_write" on activities for all to authenticated
  using (
    app_is_approved() and exists (
      select 1 from deals d where d.id = activities.deal_id and (
        app_role() = 'admin'
        or (app_role() = 'manager' and d.department = app_department())
        or (app_role() = 'rep' and d.department = app_department() and d.owner = app_name())
      )
    )
  )
  with check (
    exists (
      select 1 from deals d where d.id = activities.deal_id and (
        app_role() = 'admin'
        or (app_role() = 'manager' and d.department = app_department())
        or (app_role() = 'rep' and d.department = app_department() and d.owner = app_name())
      )
    )
  );

-- ============================================================
-- 최초 관리자 지정 (필수 · 마이그레이션 실행 후 1회)
-- ============================================================
-- 1) 배포된 앱에서 본인 이메일로 회원가입을 먼저 진행하세요 (승인 대기 상태로 생성됩니다).
-- 2) 아래 UPDATE문의 이메일을 본인 이메일로 바꾸고 SQL Editor에서 실행하세요.
--
-- update app_users
--   set role = 'admin', is_approved = true, name = '강형구', department = 'S&P사업본부'
--   where email = '본인이메일@etevers.com';
