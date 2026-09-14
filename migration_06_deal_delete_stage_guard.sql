-- ============================================================
-- 마이그레이션 06: 딜 삭제를 초기 단계(발굴/접촉)로 제한
--                  (내용의 연속성 보존을 위해, 제안 단계 이상 진행된 딜은
--                   삭제할 수 없고 관리자만 예외적으로 삭제 가능)
-- Supabase 대시보드 > SQL Editor 에서 전체 실행하세요.
-- ============================================================

drop policy if exists "deals_delete" on deals;
create policy "deals_delete" on deals for delete to authenticated
  using (
    app_is_approved() and (
      app_role() = 'admin'
      or (app_role() = 'manager' and department = app_department() and stage_id in ('discovery','contact'))
      or (app_role() = 'rep' and department = app_department() and owner = app_name() and stage_id in ('discovery','contact'))
    )
  );
