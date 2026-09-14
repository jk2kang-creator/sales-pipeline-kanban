-- ============================================================
-- 마이그레이션 05: 로그인 후 "내 정보 수정"(이메일·부서) 기능 지원
-- Supabase 대시보드 > SQL Editor 에서 전체 실행하세요.
-- ============================================================

-- 1) complete_profile: 이미 승인된 매니저/담당자가 부서를 변경하면
--    RLS가 부서 기준으로 데이터를 나눠주기 때문에, 자동으로 다시 "승인 대기"
--    상태로 되돌려 관리자가 재승인하도록 함 (관리자·조회전용은 부서가 접근 범위에
--    영향을 주지 않으므로 재승인 없이 즉시 반영).
create or replace function public.complete_profile(p_name text, p_department text)
returns void language plpgsql security definer set search_path = public as
$$
declare
  v_role text;
  v_dept text;
  v_approved boolean;
begin
  select role, department, is_approved into v_role, v_dept, v_approved
  from app_users where id = auth.uid();

  if v_role in ('manager','rep') and coalesce(v_approved,false) and p_department is distinct from v_dept then
    update app_users set name = p_name, department = p_department, is_approved = false where id = auth.uid();
  else
    update app_users set name = p_name, department = p_department where id = auth.uid();
  end if;
end;
$$;

-- 2) sync_own_email: 로그인 시 auth.users의 실제(인증된) 이메일을 app_users에
--    동기화. 클라이언트가 임의의 값을 넣을 수 없고 항상 auth.users의 실제 값만
--    복사하므로 안전함 (이메일 변경은 Supabase Auth의 인증 메일 절차를 거쳐야
--    실제로 반영됨).
create or replace function public.sync_own_email()
returns void language plpgsql security definer set search_path = public as
$$
begin
  update app_users set email = (select email from auth.users where id = auth.uid())
  where id = auth.uid();
end;
$$;
grant execute on function public.sync_own_email() to authenticated;
