-- ============================================
-- 조직 코드 시스템 + 프로필 자동 생성 (최종)
-- Supabase SQL Editor에서 실행하세요
-- 기존 SQL 3개 실행 후 이것을 추가 실행
-- ============================================

-- 1. 조직에 코드 컬럼 추가 (이미 있으면 무시됨)
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS org_code TEXT UNIQUE;

-- 2. 기존 조직에 코드 부여 (없으면)
UPDATE organizations SET org_code = upper(substr(md5(id::text), 1, 6))
WHERE org_code IS NULL;

-- 3. 트리거 함수 삭제 후 재생성
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- 4. 새 트리거: 회원가입 시 임시 프로필만 생성 (조직 없이)
-- 실제 조직 배정은 앱에서 처리
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_name TEXT;
  new_org_id UUID;
  org_code_val TEXT;
BEGIN
  user_name := split_part(NEW.email, '@', 1);
  
  -- 6자리 고유 코드 생성
  org_code_val := upper(substr(md5(gen_random_uuid()::text), 1, 6));
  
  -- 새 조직 생성
  INSERT INTO public.organizations (name, org_code)
  VALUES (user_name || '의 조직', org_code_val)
  RETURNING id INTO new_org_id;
  
  -- 프로필 생성 (기본 admin - 첫 가입이므로)
  INSERT INTO public.profiles (id, org_id, name, role, sites)
  VALUES (NEW.id, new_org_id, user_name, 'admin', ARRAY['all']);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- 5. 조직 코드로 참여하는 함수 (앱에서 RPC 호출)
CREATE OR REPLACE FUNCTION public.join_org_by_code(code TEXT, user_name TEXT)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target_org_id UUID;
  target_org_name TEXT;
  current_user_id UUID;
BEGIN
  current_user_id := auth.uid();
  IF current_user_id IS NULL THEN
    RETURN jsonb_build_object('error', '로그인 필요');
  END IF;
  
  -- 코드로 조직 찾기
  SELECT id, name INTO target_org_id, target_org_name
  FROM public.organizations
  WHERE org_code = upper(code);
  
  IF target_org_id IS NULL THEN
    RETURN jsonb_build_object('error', '잘못된 조직 코드');
  END IF;
  
  -- 기존 프로필의 빈 조직 삭제 (자동 생성된 것)
  DELETE FROM public.organizations
  WHERE id IN (SELECT org_id FROM public.profiles WHERE id = current_user_id)
  AND id != target_org_id
  AND NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE org_id = organizations.id AND id != current_user_id
  );
  
  -- 프로필 업데이트: 대상 조직으로 이동, manager로
  UPDATE public.profiles
  SET org_id = target_org_id,
      name = COALESCE(NULLIF(user_name, ''), name),
      role = 'manager',
      sites = '{}'
  WHERE id = current_user_id;
  
  RETURN jsonb_build_object('success', true, 'org_name', target_org_name);
END;
$$ LANGUAGE plpgsql;

-- 6. RLS 추가: organizations에서 org_code 읽기 허용
DROP POLICY IF EXISTS "org_select" ON organizations;
CREATE POLICY "org_select" ON organizations FOR SELECT
  TO authenticated USING (true);  -- 코드 검증을 위해 전체 조회 허용 (코드만 노출)
