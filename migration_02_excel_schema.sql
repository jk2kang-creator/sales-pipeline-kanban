-- ============================================================
-- 마이그레이션 02: 엑셀('딜_파이프라인_관리양식_2026_v4_3.xlsx') 서식 반영
-- - deals 테이블에 엑셀 컬럼 추가
-- - activities(활동 이력) 테이블 신규 생성
-- - 연습용 예시 딜 7건 삭제 → 엑셀 실데이터 20건 + 활동이력 10건으로 교체
-- Supabase 대시보드 > SQL Editor 에서 전체 실행하세요.
-- ============================================================

-- ---------- 1. deals 테이블 확장 ----------
alter table deals
  add column if not exists deal_code          text unique,   -- 딜 ID (예: D-001)
  add column if not exists department         text,          -- 영업부서
  add column if not exists next_action_date   date,          -- 다음 액션일
  add column if not exists next_action_note   text,          -- 다음 액션 내용
  add column if not exists competitor         text,          -- 경쟁사
  add column if not exists competitive_edge   text,          -- 당사 경쟁우위
  add column if not exists confirmed_date     date,          -- 확정일 (수주·실주)
  add column if not exists memo               text,          -- 비고 / 메모
  add column if not exists updated_at         timestamptz not null default now(); -- 최종 업데이트일

alter table deals alter column deal_name drop not null; -- 엑셀 실데이터는 별도 딜명이 없음

-- ---------- 2. activities: 딜 활동 이력 ----------
create table if not exists activities (
  id            uuid primary key default gen_random_uuid(),
  deal_id       uuid not null references deals(id) on delete cascade,
  activity_date date not null,
  activity_type text not null,   -- 미팅/전화/이메일/제안발표/데모·PoC/현장방문/계약협의/기타
  content       text,            -- 활동 내용
  next_action   text,            -- 다음 액션
  memo          text,            -- 비고
  created_at    timestamptz not null default now()
);
create index if not exists idx_activities_deal_id on activities(deal_id);

alter table activities enable row level security;
drop policy if exists "activities_anon_all" on activities;
create policy "activities_anon_all"
  on activities
  for all
  to anon, authenticated
  using (true)
  with check (true);

-- ---------- 3. 기존 연습용 예시 딜 전체 삭제 (활동이력도 cascade 삭제됨) ----------
delete from deals;

-- ---------- 4. 엑셀 실데이터: 딜 20건 ----------
-- 금액은 엑셀의 '만원' 단위를 '원'으로 환산 (예: 85,000만원 -> 850,000,000원)
insert into deals
  (deal_code, company, department, owner, stage_id, amount, probability,
   expected_close_date, updated_at, next_action_date, next_action_note,
   competitor, competitive_edge, confirmed_date, memo)
values
  ('D-001','삼성전자','영업1팀','김철수','proposal',    850000000, 45,'2026-10-15','2026-08-19','2026-08-28','PoC 결과 보고회 (경영진 참석)',null,'클라우드 전환 비용 절감',null,'Q4 예산 집행 확정 예정'),
  ('D-002','LG화학','영업2팀','이영희','negotiation',  420000000, 70,'2026-09-30','2026-08-10','2026-08-20','수정 계약서 회신 독촉',null,'현지 기술지원 강점',null,'법무 검토 회신 지연 중'),
  ('D-003','현대자동차','영업1팀','박민준','won',       630000000,100,'2026-08-01','2026-07-31',null,null,null,null,'2026-07-31','계약 완료, 9월 착수 예정'),
  ('D-004','SK하이닉스','영업3팀','최지연','contact',   290000000, 25,'2026-12-01','2026-06-25','2026-09-10','CTO 면담 재요청',null,'보안 인증 보유',null,'6월 이후 접촉 끊김'),
  ('D-005','포스코','솔루션팀','정대호','discovery',    150000000, 10,'2027-01-31','2026-06-10',null,null,null,'업종 특화 솔루션',null,'DM 발송 후 회신 없음'),
  ('D-006','롯데케미칼','영업2팀','이영희','proposal',  380000000, 45,'2026-11-01','2026-08-05','2026-08-18','제안서 최종본 제출',null,'빠른 구축 일정',null,'의사결정권자 면담 필요'),
  ('D-007','KT','파트너팀','강수진','negotiation',      710000000, 70,'2026-09-30','2026-08-21','2026-09-08','가격 협상 4차 (파트너 동석)',null,'파트너 채널 협력',null,'마진 구조 조율 중'),
  ('D-008','GS에너지','영업3팀','최지연','lost',        520000000,  0,null,'2026-07-15',null,null,null,null,'2026-07-15','예산 삭감으로 발주 취소'),
  ('D-009','두산에너빌','영업1팀','김철수','discovery', 220000000, 10,'2027-02-01','2026-08-22','2026-09-02','니즈 조사 미팅',null,'플랜트 업종 경험',null,'신규 발굴 건'),
  ('D-010','한화시스템','솔루션팀','오준혁','proposal', 950000000, 45,'2026-10-31','2026-08-18','2026-08-27','보안 인증서 추가 제출',null,'보안성·국산화 요건 충족',null,'방산 요건 검토 중'),
  ('D-011','신세계','영업2팀','이영희','contact',       180000000, 25,'2026-12-15','2026-06-30',null,null,null,'리테일 레퍼런스 다수',null,'담당자 변경 후 재접촉 필요'),
  ('D-012','CJ제일제당','영업1팀','박민준','negotiation',470000000, 70,'2026-09-20','2026-08-12','2026-08-21','임원 보고 결과 확인',null,'식품업 특화 모듈',null,'임원 보고 후 결정 예정'),
  ('D-013','카카오','파트너팀','강수진','won',          330000000,100,'2026-08-14','2026-08-14',null,null,null,null,'2026-08-14','계약 완료'),
  ('D-014','네이버','솔루션팀','오준혁','hold',         610000000,  0,null,'2026-06-05',null,'4분기 재논의',null,null,null,'내부 방향성 결정 후 재개'),
  ('D-015','코오롱','영업3팀','최지연','discovery',     110000000, 10,'2027-03-01','2026-06-20','2026-09-15','리플렛 발송 후 재접촉',null,null,null,'6월 이후 진전 없음'),
  ('D-016','LS일렉트릭','영업1팀','김철수','proposal',  280000000, 45,'2026-11-30','2026-08-20','2026-09-04','제안 발표 (9/4 확정)',null,'국내 서비스망 강점',null,'의사결정자 참석 확인 완료'),
  ('D-017','현대건설','영업2팀','이영희','contact',     350000000, 25,'2027-01-15','2026-08-24','2026-09-07','RFI 응답서 제출',null,'건설 BIM 연동 경험',null,'입찰 공고 10월 예정'),
  ('D-018','SK이노베이션','영업3팀','최지연','discovery',440000000, 10,'2027-01-31','2026-07-28','2026-08-14','사업부 담당자 소개 요청',null,null,null,'그룹사 공략 전략 연계'),
  ('D-019','셀트리온','솔루션팀','오준혁','negotiation',880000000, 70,'2026-09-15','2026-08-23','2026-08-26','임원 최종 승인 결과 확인',null,'FDA 규정 대응 강점',null,'기술 검토 이견 없음'),
  ('D-020','기아','영업1팀','박민준','proposal',        560000000, 45,'2026-10-20','2026-08-01','2026-08-11','PoC 제안 발표 일정 확정',null,'모빌리티 특화 경험',null,'현대 레퍼런스 활용 가능');

-- ---------- 5. 엑셀 실데이터: 활동 이력 10건 ----------
insert into activities (deal_id, activity_date, activity_type, content, next_action, memo)
select d.id, v.activity_date::date, v.activity_type, v.content, v.next_action, v.memo
from (values
  ('D-019','2026-08-23','미팅','임원 최종 승인 전 기술 검토 미팅','임원 보고 결과 8/26 확인','기술 검토 이견 없음'),
  ('D-007','2026-08-21','계약협의','파트너사와 공동 가격 협상 3차','수정 견적서 9/8 제출','파트너 마진 구조 조율 중'),
  ('D-016','2026-08-20','미팅','제안 발표 일정 9/4 확정 및 청중 구성 파악','발표 자료 9/1까지 완성','의사결정자 참석 확인 완료'),
  ('D-001','2026-08-19','미팅','솔루션 PoC 결과 공유 미팅 진행. CTO 포함 5명 참석','경영진 보고회 8/28 진행','긍정적 반응, Q4 예산 확인 필요'),
  ('D-010','2026-08-18','제안발표','기술 제안서 PT 진행 (방산 요건 집중)','보안 인증서 추가 제출 8/27','2차 발표 요청 가능성'),
  ('D-013','2026-08-14','계약협의','최종 계약 체결 완료','킥오프 일정 협의','수주 확정'),
  ('D-012','2026-08-12','미팅','임원 보고 전 최종 Q&A 미팅','임원 보고 결과 8/21 확인','식품 업종 레퍼런스 강조'),
  ('D-002','2026-08-10','계약협의','계약 조건 3차 협의. 가격 5% 추가 할인 요청 접수','수정 계약서 회신 8/20','법무 검토 회신 대기 중'),
  ('D-020','2026-08-01','제안발표','PoC 제안 발표 준비 상황 점검 미팅','발표 일정 확정 8/11','현대 레퍼런스 최대 활용'),
  ('D-004','2026-06-25','전화','담당자 변경 후 첫 통화. 니즈 파악','CTO 면담 일정 조율','이후 회신 없음 · 재접촉 필요')
) as v(deal_code, activity_date, activity_type, content, next_action, memo)
join deals d on d.deal_code = v.deal_code;
