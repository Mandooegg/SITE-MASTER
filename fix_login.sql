-- ============================================
-- SITE-MASTER 로그인 문제 통합 수정
-- Supabase SQL Editor에서 실행하세요
-- 
-- 이 파일 하나로 아래 문제를 모두 해결합니다:
-- 1. handle_new_user 트리거 미설치/오작동
-- 2. RLS 정책 충돌 (org_select 중복)
-- 3. 기존 프로필 없는 유저 복구
-- ============================================

-- ============================================
-- STEP 1: org_code 컬럼 확인/추가
-- ============================================
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS org_code TEXT UNIQUE;

-- 기존 조직에 코드 부여 (없으면)
UPDATE organizations SET org_code = upper(substr(md5(id::text), 1, 6))
WHERE org_code IS NULL;

-- ============================================
-- STEP 2: 트리거 함수 재생성 (핵심!)
-- ============================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_name TEXT;
  new_org_id UUID;
  org_code_val TEXT;
  retry_count INT := 0;
BEGIN
  user_name := split_part(NEW.email, '@', 1);
  
  -- 이미 프로필이 있으면 스킵 (중복 방지)
  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = NEW.id) THEN
    RETURN NEW;
  END IF;
  
  -- org_code 중복 방지를 위한 루프
  LOOP
    org_code_val := upper(substr(md5(gen_random_uuid()::text), 1, 6));
    BEGIN
      INSERT INTO public.organizations (name, org_code)
      VALUES (user_name || '의 조직', org_code_val)
      RETURNING id INTO new_org_id;
      EXIT; -- 성공하면 루프 탈출
    EXCEPTION WHEN unique_violation THEN
      retry_count := retry_count + 1;
      IF retry_count > 5 THEN
        RAISE EXCEPTION '조직 코드 생성 실패 (5회 재시도)';
      END IF;
    END;
  END LOOP;
  
  -- 프로필 생성 (기본 admin)
  INSERT INTO public.profiles (id, org_id, name, role, sites)
  VALUES (NEW.id, new_org_id, user_name, 'admin', ARRAY['all']);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- STEP 3: RLS 정책 정리 (충돌 해결)
-- ============================================

-- organizations 정책 통합 (기존 중복 제거 후 재생성)
DROP POLICY IF EXISTS "org_access" ON organizations;
DROP POLICY IF EXISTS "org_select" ON organizations;
DROP POLICY IF EXISTS "org_insert" ON organizations;
DROP POLICY IF EXISTS "org_update" ON organizations;

-- 인증된 사용자는 조직 생성 가능
CREATE POLICY "org_insert" ON organizations FOR INSERT
  TO authenticated WITH CHECK (true);

-- 모든 인증 사용자가 조직 조회 가능 (org_code 검증용)
CREATE POLICY "org_select" ON organizations FOR SELECT
  TO authenticated USING (true);

-- 자기 조직만 수정 가능
CREATE POLICY "org_update" ON organizations FOR UPDATE
  TO authenticated USING (
    id IN (SELECT org_id FROM profiles WHERE id = auth.uid())
  );

-- profiles 정책 정리
DROP POLICY IF EXISTS "own_profile" ON profiles;
DROP POLICY IF EXISTS "org_profiles" ON profiles;
DROP POLICY IF EXISTS "profile_insert" ON profiles;
DROP POLICY IF EXISTS "profile_select" ON profiles;
DROP POLICY IF EXISTS "profile_update" ON profiles;

-- 자기 프로필 생성 가능
CREATE POLICY "profile_insert" ON profiles FOR INSERT
  TO authenticated WITH CHECK (id = auth.uid());

-- 자기 프로필 + 같은 조직 프로필 조회 가능
CREATE POLICY "profile_select" ON profiles FOR SELECT
  TO authenticated USING (
    id = auth.uid() OR
    org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid())
  );

-- 자기 프로필만 수정 가능
CREATE POLICY "profile_update" ON profiles FOR UPDATE
  TO authenticated USING (id = auth.uid());

-- admin이 같은 조직 멤버의 역할/현장 변경 가능
DROP POLICY IF EXISTS "admin_update_profiles" ON profiles;
CREATE POLICY "admin_update_profiles" ON profiles FOR UPDATE
  TO authenticated USING (
    org_id IN (
      SELECT p.org_id FROM profiles p 
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- ============================================
-- STEP 4: join_org_by_code 함수 재생성
-- ============================================
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
  
  SELECT id, name INTO target_org_id, target_org_name
  FROM public.organizations
  WHERE org_code = upper(code);
  
  IF target_org_id IS NULL THEN
    RETURN jsonb_build_object('error', '잘못된 조직 코드');
  END IF;
  
  -- 자동 생성된 빈 조직 삭제
  DELETE FROM public.organizations
  WHERE id IN (SELECT org_id FROM public.profiles WHERE id = current_user_id)
  AND id != target_org_id
  AND NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE org_id = organizations.id AND id != current_user_id
  );
  
  -- 프로필 업데이트
  UPDATE public.profiles
  SET org_id = target_org_id,
      name = COALESCE(NULLIF(user_name, ''), name),
      role = 'manager',
      sites = '{}'
  WHERE id = current_user_id;
  
  RETURN jsonb_build_object('success', true, 'org_name', target_org_name);
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- STEP 5: 기존 프로필 없는 유저 복구
-- ============================================
DO $$
DECLARE
  r RECORD;
  new_org_id UUID;
  org_code_val TEXT;
  user_name TEXT;
BEGIN
  FOR r IN 
    SELECT u.id, u.email
    FROM auth.users u
    LEFT JOIN public.profiles p ON u.id = p.id
    WHERE p.id IS NULL
  LOOP
    user_name := split_part(r.email, '@', 1);
    org_code_val := upper(substr(md5(gen_random_uuid()::text), 1, 6));
    
    INSERT INTO public.organizations (name, org_code)
    VALUES (user_name || '의 조직', org_code_val)
    RETURNING id INTO new_org_id;
    
    INSERT INTO public.profiles (id, org_id, name, role, sites)
    VALUES (r.id, new_org_id, user_name, 'admin', ARRAY['all']);
    
    RAISE NOTICE '복구 완료: % (조직코드: %)', r.email, org_code_val;
  END LOOP;
END $$;

-- ============================================
-- 결과 확인
-- ============================================
SELECT '=== 전체 유저 프로필 상태 ===' AS info;
SELECT u.email, p.name, p.role, o.org_code,
  CASE WHEN p.id IS NULL THEN '❌ 프로필 없음' ELSE '✅ 정상' END AS status
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
LEFT JOIN public.organizations o ON p.org_id = o.id
ORDER BY u.created_at DESC;
