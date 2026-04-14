# SITE-MASTER 건설현장 관리시스템

한국 아파트 건설 현장을 위한 올인원 시공관리 웹앱입니다.

## 주요 기능

- **3D 시공현황** — 동별/호별 시공 상태를 3D로 시각화, 터치로 상태 변경
- **태양 시뮬레이션** — 현장 좌표 기반 그림자 방향 확인
- **발주 자동 알림** — N층 완료 시 발주 트리거
- **공장검수 추적** — 검수/테스트 상태 관리
- **엑셀 연동** — 시공현황 엑셀 업로드/다운로드
- **역할 분리** — 관리자(현장 생성/배정) / 현장담당(배정 현장만)
- **모바일 대응** — 핀치 줌, 터치 조작, 반응형 UI

## 시작하기

### 방법 1: GitHub Pages (가장 간단)

1. 이 저장소를 Fork
2. Settings → Pages → Source: `main` → Save
3. `https://사용자명.github.io/site-master/` 접속

### 방법 2: 로컬 실행

```bash
python3 -m http.server 8080
```
브라우저에서 `http://localhost:8080` 접속

### 방법 3: Supabase 클라우드 연동

[SETUP_GUIDE.md](./SETUP_GUIDE.md) 참고

## 테스트 계정 (로컬 모드)

| ID | PW | 역할 | 접근 범위 |
|---|---|---|---|
| admin | 1234 | 관리자 | 전체 현장 + 현장 생성/배정 |
| manager1 | 1234 | 현장담당 | 세종시 행복아파트 |
| manager2 | 1234 | 현장담당 | 대전 한빛아파트 |

## 파일 구성

```
index.html          ← 앱 전체 (이 파일 하나로 동작)
supabase_schema.sql ← Supabase DB 스키마 (클라우드 사용시)
SETUP_GUIDE.md      ← Supabase 설정 가이드
README.md           ← 이 파일
```

## 기술 스택

- HTML/CSS/JS (단일 파일, ES5 호환)
- Three.js (3D 렌더링, CDN)
- SheetJS (엑셀, CDN)
- Supabase (클라우드 동기화, 선택)
