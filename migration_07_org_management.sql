-- ============================================================
-- 마이그레이션 07: 사업본부·부서를 관리자가 직접 생성/수정/삭제할 수 있도록
--                  DB 테이블로 전환 (기존 JS 하드코딩 목록을 대체)
-- Supabase 대시보드 > SQL Editor 에서 전체 실행하세요.
-- ============================================================

-- 1) 사업본부
create table if not exists business_units (
  name       text primary key,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
alter table business_units enable row level security;
drop policy if exists "business_units_read" on business_units;
create policy "business_units_read" on business_units for select to anon, authenticated using (true);
drop policy if exists "business_units_write" on business_units;
create policy "business_units_write" on business_units for all to authenticated
  using (app_role() = 'admin') with check (app_role() = 'admin');

-- 2) 부서 (사업본부에 종속, 사업본부명이 바뀌면 자동으로 같이 갱신됨)
create table if not exists departments (
  name          text primary key,
  business_unit text not null references business_units(name) on update cascade on delete restrict,
  sort_order    int not null default 0,
  created_at    timestamptz not null default now()
);
alter table departments enable row level security;
drop policy if exists "departments_read" on departments;
create policy "departments_read" on departments for select to anon, authenticated using (true);
drop policy if exists "departments_write" on departments;
create policy "departments_write" on departments for all to authenticated
  using (app_role() = 'admin') with check (app_role() = 'admin');

-- 3) 부서명 변경 시, 기존 딜·사용자에 저장된 부서 텍스트도 함께 갱신
--    (deals.department / app_users.department는 외래키가 아닌 텍스트 컬럼이라
--     departments.name을 바꾸는 것만으로는 과거 데이터가 자동 반영되지 않음)
create or replace function public.rename_department(p_old_name text, p_new_name text)
returns void language plpgsql security definer set search_path = public as
$$
begin
  if app_role() <> 'admin' then
    raise exception '관리자만 부서명을 변경할 수 있습니다.';
  end if;
  update departments set name = p_new_name where name = p_old_name;
  update deals set department = p_new_name where department = p_old_name;
  update app_users set department = p_new_name where department = p_old_name;
end;
$$;
grant execute on function public.rename_department(text, text) to authenticated;

-- 사업본부명 변경 (departments.business_unit은 on update cascade로 자동 갱신됨)
create or replace function public.rename_business_unit(p_old_name text, p_new_name text)
returns void language plpgsql security definer set search_path = public as
$$
begin
  if app_role() <> 'admin' then
    raise exception '관리자만 사업본부명을 변경할 수 있습니다.';
  end if;
  update business_units set name = p_new_name where name = p_old_name;
end;
$$;
grant execute on function public.rename_business_unit(text, text) to authenticated;

-- 4) 현재 운영 중인 8개 사업본부 / 16개 부서로 초기 데이터 구성
insert into business_units (name, sort_order) values
  ('BTS사업본부',1), ('DT사업본부',2), ('NBS사업본부',3), ('CDS사업본부',4),
  ('SDI사업본부',5), ('JFT사업본부',6), ('Account사업본부',7), ('Security사업본부',8)
on conflict (name) do nothing;

insert into departments (name, business_unit, sort_order) values
  ('SI사업부','BTS사업본부',1), ('매니지드사업부','BTS사업본부',2),
  ('NPS사업부','DT사업본부',1), ('NS사업부','DT사업본부',2), ('NCI사업부','DT사업본부',3), ('SIG사업부','DT사업본부',4),
  ('중부사업부','NBS사업본부',1), ('영남사업부','NBS사업본부',2),
  ('솔루션사업1부','CDS사업본부',1), ('솔루션사업2부','CDS사업본부',2),
  ('SDI사업부','SDI사업본부',1),
  ('OCI사업부','JFT사업본부',1), ('AI사업부','JFT사업본부',2), ('Infra사업부','JFT사업본부',3),
  ('Account사업부','Account사업본부',1),
  ('Security사업부','Security사업본부',1)
on conflict (name) do nothing;
