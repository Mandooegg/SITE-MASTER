-- ============================================
-- SITE-MASTER Supabase Schema
-- Supabase SQL Editor에서 실행하세요
-- ============================================

-- 1. 조직 테이블
CREATE TABLE organizations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL DEFAULT 'My Organization',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. 프로필 (Supabase Auth와 연동)
CREATE TABLE profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  org_id UUID REFERENCES organizations(id),
  name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'manager' CHECK (role IN ('admin','manager')),
  sites TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. 현장
CREATE TABLE sites (
  id TEXT PRIMARY KEY,
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  info JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. 건물(동)
CREATE TABLE buildings (
  id TEXT PRIMARY KEY,
  site_id TEXT REFERENCES sites(id) ON DELETE CASCADE,
  number TEXT,
  name TEXT NOT NULL,
  type TEXT DEFAULT 'plate',
  basement INT DEFAULT 2,
  floors INT DEFAULT 25,
  units INT DEFAULT 4,
  pos_x INT DEFAULT 0,
  pos_z INT DEFAULT 0,
  rot INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. 시공현황 (층-호별 상태)
CREATE TABLE progress (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  site_id TEXT REFERENCES sites(id) ON DELETE CASCADE,
  building_id TEXT REFERENCES buildings(id) ON DELETE CASCADE,
  floor_key TEXT NOT NULL,
  unit TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','inprogress','complete')),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID REFERENCES auth.users(id),
  UNIQUE(building_id, floor_key, unit)
);

-- 6. 발주 규칙
CREATE TABLE proc_rules (
  id TEXT PRIMARY KEY,
  site_id TEXT REFERENCES sites(id) ON DELETE CASCADE,
  material TEXT NOT NULL,
  cond_floor INT NOT NULL,
  lead_days INT NOT NULL,
  target TEXT DEFAULT 'all',
  active BOOLEAN DEFAULT TRUE
);

-- 7. 발주 현황
CREATE TABLE proc_orders (
  id TEXT PRIMARY KEY,
  site_id TEXT REFERENCES sites(id) ON DELETE CASCADE,
  material TEXT NOT NULL,
  order_date DATE,
  status TEXT DEFAULT 'ready',
  manager_id UUID REFERENCES auth.users(id),
  note TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. 알림
CREATE TABLE alerts (
  id TEXT PRIMARY KEY,
  site_id TEXT REFERENCES sites(id) ON DELETE CASCADE,
  rule_id TEXT,
  material TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT DEFAULT 'normal',
  date DATE DEFAULT CURRENT_DATE,
  read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. 검수
CREATE TABLE inspections (
  id TEXT PRIMARY KEY,
  site_id TEXT REFERENCES sites(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  category TEXT DEFAULT 'factory',
  target TEXT,
  vendor TEXT,
  date DATE,
  status TEXT DEFAULT 'scheduled',
  manager TEXT,
  location TEXT,
  note TEXT DEFAULT '',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. 수정이력
CREATE TABLE edit_history (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  time TEXT NOT NULL,
  user_name TEXT NOT NULL,
  action TEXT NOT NULL,
  detail TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- RLS (Row Level Security) 정책
-- ============================================

ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE buildings ENABLE ROW LEVEL SECURITY;
ALTER TABLE progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE proc_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE proc_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE edit_history ENABLE ROW LEVEL SECURITY;

-- 같은 조직 소속이면 읽기/쓰기 허용
CREATE POLICY "org_access" ON sites FOR ALL USING (
  org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid())
);
CREATE POLICY "org_access" ON buildings FOR ALL USING (
  site_id IN (SELECT id FROM sites WHERE org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()))
);
CREATE POLICY "org_access" ON progress FOR ALL USING (
  site_id IN (SELECT id FROM sites WHERE org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()))
);
CREATE POLICY "org_access" ON proc_rules FOR ALL USING (
  site_id IN (SELECT id FROM sites WHERE org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()))
);
CREATE POLICY "org_access" ON proc_orders FOR ALL USING (
  site_id IN (SELECT id FROM sites WHERE org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()))
);
CREATE POLICY "org_access" ON alerts FOR ALL USING (
  site_id IN (SELECT id FROM sites WHERE org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()))
);
CREATE POLICY "org_access" ON inspections FOR ALL USING (
  site_id IN (SELECT id FROM sites WHERE org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid()))
);
CREATE POLICY "org_access" ON edit_history FOR ALL USING (
  org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid())
);
CREATE POLICY "own_profile" ON profiles FOR ALL USING (id = auth.uid());
CREATE POLICY "org_profiles" ON profiles FOR SELECT USING (
  org_id IN (SELECT org_id FROM profiles WHERE id = auth.uid())
);
CREATE POLICY "org_access" ON organizations FOR ALL USING (
  id IN (SELECT org_id FROM profiles WHERE id = auth.uid())
);

-- ============================================
-- 자동 업데이트 트리거
-- ============================================
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sites_updated BEFORE UPDATE ON sites
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER progress_updated BEFORE UPDATE ON progress
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER inspections_updated BEFORE UPDATE ON inspections
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ============================================
-- 초기 데이터 (테스트용 - 선택사항)
-- 실제로는 앱에서 회원가입 후 자동 생성됩니다
-- ============================================
