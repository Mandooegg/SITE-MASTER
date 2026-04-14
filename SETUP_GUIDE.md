# SITE-MASTER Supabase 설정 가이드

## 1단계: Supabase 프로젝트 생성

1. [supabase.com](https://supabase.com) 접속 → **Start your project**
2. GitHub 계정으로 로그인
3. **New Project** 클릭
   - Organization: 기본값 또는 새로 생성
   - Name: `site-master`
   - Database Password: 안전한 비밀번호 설정 (메모해두세요)
   - Region: `Northeast Asia (Tokyo)` ← 한국에서 가장 빠름
4. 프로젝트 생성 완료 (1~2분 소요)

## 2단계: 데이터베이스 테이블 생성

1. Supabase 대시보드 → 좌측 **SQL Editor** 클릭
2. **New query** 클릭
3. `supabase_schema.sql` 파일 내용을 전체 복사하여 붙여넣기
4. **Run** 클릭
5. 초록색 "Success" 메시지 확인

## 3단계: Authentication 설정

1. 좌측 **Authentication** → **Providers**
2. **Email** 활성화 확인 (기본값 ON)
3. (선택) **Confirm email** 비활성화 → 개발 단계에서 이메일 인증 없이 바로 사용 가능

## 4단계: API 키 확인

1. 좌측 **Settings** → **API**
2. 아래 두 값을 복사:
   - **Project URL**: `https://xxxxxxxx.supabase.co`
   - **anon public key**: `eyJhbGci...` (긴 문자열)

## 5단계: index.html에 설정 입력

`index.html` 파일을 텍스트 에디터로 열고, 상단의 아래 부분을 찾아서 수정:

```javascript
var SUPABASE_URL='YOUR_SUPABASE_URL';
var SUPABASE_KEY='YOUR_SUPABASE_ANON_KEY';
```

↓ 4단계에서 복사한 값으로 교체:

```javascript
var SUPABASE_URL='https://xxxxxxxx.supabase.co';
var SUPABASE_KEY='eyJhbGci...your-key-here...';
```

## 6단계: 배포

### GitHub Pages (무료)
1. GitHub에 새 저장소 생성 (`site-master`)
2. `index.html` 업로드
3. Settings → Pages → Source: `main` → Save
4. `https://사용자명.github.io/site-master/` 로 접속

### Netlify (무료)
1. [netlify.com](https://netlify.com) 접속
2. `index.html`을 드래그 앤 드롭
3. 즉시 배포 완료

## 사용 방법

### 첫 사용 (회원가입)
1. 배포된 URL 접속
2. **☁️ 클라우드** 탭 선택
3. 이메일 + 비밀번호 입력 → **회원가입**
4. 가입 완료 후 **로그인**
5. 기본 현장 2개가 자동 생성됨

### 팀원 초대
1. 관리자가 Supabase 대시보드 → **Table Editor** → `profiles` 테이블
2. 팀원이 회원가입하면 `profiles`에 자동 생성됨
3. `role`을 `manager`로, `sites`를 `["site1"]` 등으로 수정

### 오프라인 사용
- **💾 로컬** 탭으로 로그인하면 기존처럼 localStorage만 사용
- 인터넷 없는 현장에서도 작동
- 클라우드 데이터와는 별개

## 데이터 구조

| 테이블 | 설명 |
|--------|------|
| organizations | 조직 (회사) |
| profiles | 사용자 프로필 (auth.users와 연동) |
| sites | 현장 정보 |
| buildings | 건물(동) |
| progress | 시공현황 (층-호별) |
| proc_rules | 발주 규칙 |
| proc_orders | 발주 현황 |
| alerts | 알림 |
| inspections | 검수/테스트 |
| edit_history | 수정 이력 |

## RLS (Row Level Security)

같은 조직(organization)에 소속된 사용자만 해당 조직의 데이터에 접근할 수 있도록 보안 정책이 설정되어 있습니다.

## 문제 해결

### "Supabase 미설정" 표시
→ SUPABASE_URL과 SUPABASE_KEY가 정확히 입력되었는지 확인

### 회원가입 후 로그인 안됨
→ Supabase Authentication → Providers → Email의 "Confirm email" 비활성화

### 데이터가 안 보임
→ Supabase SQL Editor에서 스키마가 정상 실행되었는지 확인
→ Table Editor에서 테이블이 생성되었는지 확인

### 로컬에서 테스트
```
python3 -m http.server 8080
```
→ `http://localhost:8080` 접속
