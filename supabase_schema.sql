-- ============================================================
-- 영업 파이프라인 Supabase 스키마 + 초기 데이터 + RLS (연습용)
-- ============================================================

create extension if not exists pgcrypto;

-- ---------- 1. stages: 파이프라인 단계 ----------
create table if not exists stages (
  id                  text primary key,      -- 단계 슬러그 (lead, review, proposal, negotiation, won, lost)
  name                text not null,          -- 화면에 표시할 단계 이름
  sort_order          int not null,           -- 칸반 보드에서의 정렬 순서
  default_probability numeric not null default 0 check (default_probability between 0 and 100)
);

-- ---------- 2. deals: 영업 기회(딜) ----------
create table if not exists deals (
  id                   uuid primary key default gen_random_uuid(),
  company              text not null,                              -- 고객사
  deal_name            text not null,                              -- 딜명
  amount               numeric not null check (amount >= 0),       -- 금액 (원)
  stage_id             text not null references stages(id),        -- 단계
  owner                text not null,                               -- 담당자
  expected_close_date  date,                                        -- 예상 마감일
  probability          numeric not null default 0 check (probability between 0 and 100), -- 수주 확률(%)
  created_at           timestamptz not null default now()           -- 생성일시
);

create index if not exists idx_deals_stage_id on deals(stage_id);

-- ---------- 3. RLS: 연습용 익명 전체 허용 ----------
alter table stages enable row level security;
alter table deals  enable row level security;

drop policy if exists "stages_anon_all" on stages;
create policy "stages_anon_all"
  on stages
  for all
  to anon, authenticated
  using (true)
  with check (true);

drop policy if exists "deals_anon_all" on deals;
create policy "deals_anon_all"
  on deals
  for all
  to anon, authenticated
  using (true)
  with check (true);

-- ---------- 4. 초기 데이터: 단계 ----------
insert into stages (id, name, sort_order, default_probability) values
  ('lead',        '리드', 1, 10),
  ('review',      '검토', 2, 30),
  ('proposal',    '제안', 3, 50),
  ('negotiation', '협상', 4, 70),
  ('won',         '수주', 5, 100),
  ('lost',        '실주', 6, 0)
on conflict (id) do update
  set name = excluded.name,
      sort_order = excluded.sort_order,
      default_probability = excluded.default_probability;

-- ---------- 5. 초기 데이터: 딜 (화면 예시 6건) ----------
insert into deals (company, deal_name, amount, stage_id, owner, expected_close_date, probability) values
  ('(주)한빛전자',   '클라우드 인프라 전환 프로젝트',   120000000, 'lead',        '김민수', '2026-10-15', 20),
  ('대성물산',        '사내 ERP 고도화',                  85000000, 'review',      '이서연', '2026-09-30', 40),
  ('태양테크',        '보안 솔루션 구축',                  64000000, 'proposal',    '박지훈', '2026-10-05', 55),
  ('미래산업',        '영업관리 시스템 라이선스 갱신',      32000000, 'negotiation', '김민수', '2026-09-20', 75),
  ('그린바이오',      '데이터 분석 플랫폼 구축',          150000000, 'won',         '최유진', '2026-08-25', 100),
  ('동해로지스틱스',  '물류관리 시스템 도입',              47000000, 'lost',        '이서연', '2026-08-10', 0);
