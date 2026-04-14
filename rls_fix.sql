-- ============================================
-- SITE-MASTER RLS 수정 패치
-- Supabase SQL Editor에서 실행하세요
-- ============================================

-- 기존 정책 삭제 (에러 무시 가능)
DROP POLICY IF EXISTS "org_access" ON organizations;
DROP POLICY IF EXISTS "own_profile" ON profiles;
DROP POLICY IF EXISTS "org_profiles" ON profiles;
DROP POLICY IF EXISTS "org_access" ON sites;
DROP POLICY IF EXISTS "org_access" ON buildings;
DROP POLICY IF EXISTS "org_access" ON progress;
DROP POLICY IF EXISTS "org_access" ON proc_rules;
DROP POLICY IF EXISTS "org_access" ON proc_orders;
DROP POLICY IF EXISTS "org_access" ON alerts;
DROP POLICY IF EXISTS "org_access" ON inspections;
DROP POLICY IF EXISTS "org_access" ON edit_history;

-- Organizations: 로그인한 사용자는 생성 가능, 자기 조직만 조회
CREATE POLICY "org_insert" ON organizations FOR INSERT
  TO authenticated WITH CHECK (true);
CREATE POLICY "org_select" ON organizations FOR SELECT
  TO authenticated USING (
    id IN (SELECT org_id FROM profiles WHERE id = auth.uid())
  );
CREATE POLICY "org_update" ON organizations FOR UPDATE
  TO authenticated USING (
    id IN (SELECT org_id FROM profiles WHERE id = auth.uid())
  );

-- Profiles: 자기 프로필 생성/수정, 같은 조직 프로필 조회
CREATE POLICY "profile_insert" ON profiles FOR INSERT
  TO authenticated WITH CHECK (id = auth.uid());
CREATE POLICY "profile_select" ON profiles FOR SELECT
  TO authenticated USING (
    id = auth.uid() OR
    org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid())
  );
CREATE POLICY "profile_update" ON profiles FOR UPDATE
  TO authenticated USING (id = auth.uid());

-- Sites: 같은 조직 데이터 접근
CREATE POLICY "sites_all" ON sites FOR ALL
  TO authenticated USING (
    org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid())
  ) WITH CHECK (
    org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid())
  );

-- Buildings
CREATE POLICY "buildings_all" ON buildings FOR ALL
  TO authenticated USING (
    site_id IN (SELECT id FROM sites WHERE org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()))
  ) WITH CHECK (
    site_id IN (SELECT id FROM sites WHERE org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()))
  );

-- Progress
CREATE POLICY "progress_all" ON progress FOR ALL
  TO authenticated USING (
    site_id IN (SELECT id FROM sites WHERE org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()))
  ) WITH CHECK (
    site_id IN (SELECT id FROM sites WHERE org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()))
  );

-- Proc Rules
CREATE POLICY "proc_rules_all" ON proc_rules FOR ALL
  TO authenticated USING (
    site_id IN (SELECT id FROM sites WHERE org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()))
  ) WITH CHECK (
    site_id IN (SELECT id FROM sites WHERE org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()))
  );

-- Proc Orders
CREATE POLICY "proc_orders_all" ON proc_orders FOR ALL
  TO authenticated USING (
    site_id IN (SELECT id FROM sites WHERE org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()))
  ) WITH CHECK (
    site_id IN (SELECT id FROM sites WHERE org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()))
  );

-- Alerts
CREATE POLICY "alerts_all" ON alerts FOR ALL
  TO authenticated USING (
    site_id IN (SELECT id FROM sites WHERE org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()))
  ) WITH CHECK (
    site_id IN (SELECT id FROM sites WHERE org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()))
  );

-- Inspections
CREATE POLICY "inspections_all" ON inspections FOR ALL
  TO authenticated USING (
    site_id IN (SELECT id FROM sites WHERE org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()))
  ) WITH CHECK (
    site_id IN (SELECT id FROM sites WHERE org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()))
  );

-- Edit History
CREATE POLICY "history_all" ON edit_history FOR ALL
  TO authenticated USING (
    org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid())
  ) WITH CHECK (
    org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid())
  );
