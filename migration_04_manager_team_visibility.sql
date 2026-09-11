-- ============================================================
-- 마이그레이션 04: 매니저의 같은 부서 팀원 조회 허용
--                  (딜 등록 시 "담당자" 드롭다운에 실제 팀원 이름을 띄우기 위함)
-- Supabase 대시보드 > SQL Editor 에서 전체 실행하세요.
-- ============================================================

-- 기존 app_users_select 정책: 본인 행 또는 관리자만 조회 가능
-- -> 매니저가 본인 부서 팀원(매니저/담당자) 목록도 조회할 수 있도록 조건 추가
drop policy if exists "app_users_select" on app_users;
create policy "app_users_select" on app_users for select to authenticated
  using (
    id = auth.uid()
    or app_role() = 'admin'
    or (app_role() = 'manager' and department = app_department())
  );
