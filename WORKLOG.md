# WORKLOG

프로젝트 개발 및 테스트 기록입니다.

## 2026-08-13

### v1.2 Supabase sandbox 연동

운영 환경과 분리된 테스트 Supabase 프로젝트에 앱을 연결함.

연결 대상:

- 프로젝트: `leehk2275_barcode-photo-scanner`
- project ref: `rbifmyvpilvjqfmrfvhr`
- 작업 대상: `public.photo_targets`
- 사진 메타데이터: `public.item_photos`
- 이미지 파일: Storage `item-photos`

데이터:

- `온라인_바코드목록_취합_260812.xlsx`의 `Sheet1` A열 바코드 529건 등록
- 기존 모바일 테스트 샘플 3건 유지
- 총 532건, 전부 `pending` 상태로 준비

앱 수정 사항:

- 손상되어 중간에 잘린 `index.html`을 정상 페이지로 복원
- Supabase JS를 `2.112.3`으로 고정해 로드
- publishable key와 RLS를 사용하는 브라우저 직접 연결
- 앱 시작 시 `photo_targets`를 페이지 단위로 전체 조회
- 대상 목록 로딩 실패 시 스캔을 잠가 누락 판정 방지
- `pending` 대상 스캔 시 촬영 경고 팝업 표시
- `completed` 대상은 재촬영 팝업 없이 촬영 완료로 표시
- 촬영 파일을 `item-photos/{barcode}/...` 경로에 업로드
- 업로드 후 `item_photos`에 바코드, target id, Storage 경로, 기기 정보 기록
- 마지막으로 `photo_targets`를 `completed`로 변경
- 부분 실패 후 저장 재시도 시 이미 성공한 업로드/메타데이터 단계를 반복하지 않도록 처리
- 팝업 중 추가 스캔 잠금, iOS 경고음, Object URL 해제 유지
- GitHub 기본 라이트 UI 단일 스타일로 재구성

검증:

- HTML 모듈 JavaScript 문법 검사 통과
- DOM id 중복 검사 통과
- Supabase 연동 대상 문자열 및 고정 SDK 버전 검사 통과
- publishable key + RLS를 통한 Data API 조회에서 작업 대상 532건 확인
- Supabase Security Advisor 경고 0건 확인
- GitHub Pages 배포 상태 `built` 확인
- 배포본에서 `ONLINE` 및 작업 대상 532건 연결 확인
- `G59`, `N66` 작업 대상 경고 모달과 팝업 중 스캔 잠금 확인
- 비대상 바코드 정상 판정과 팝업 종료 후 입력 복귀 확인
- 배포본 브라우저 콘솔 오류 및 경고 0건 확인

남은 테스트:

- Android / iPhone에서 실제 촬영 파일 업로드 E2E 확인
- 테스트 완료 후 초기 샘플 3건 정리

### v1.1 mobile-test 보완

Android / iOS 실기기 테스트 전에 공통 안정성 보완을 진행함.

수정 사항:

- 작업 대상 팝업이 열린 동안 바코드 입력창을 비활성화
- 팝업 처리 중 추가 스캔이 뒤에서 입력되는 문제 방지
- `사진 촬영` 또는 `나중에 촬영` 처리 후 입력창 자동 복귀
- 촬영 미리보기용 `URL.createObjectURL()` 사용 후 `URL.revokeObjectURL()` 정리 추가
- 장시간 반복 촬영 시 모바일 브라우저 메모리 누수 가능성 완화
- iOS에서 Vibration API를 사용할 수 없는 경우를 대비해 Web Audio 기반 짧은 경고음 추가
- 경고음 재생이 브라우저 정책상 차단될 경우 오류 없이 건너뛰도록 처리
- 기존 다크 테마 CSS + 라이트 오버라이드 이중 구조를 제거
- GitHub 기본 라이트 UI만 사용하는 단일 스타일 구조로 정리
- `viewport-fit=cover` 추가로 iPhone 안전 영역 대응 개선
- Android / iOS 공통 모바일 테스트를 위한 상태 표시와 포커스 복귀 로직 정리

커밋:

`0e5c9e70eeb55add52ad5167b299507d57674551`

현재 단계에서는 여전히 실제 Supabase / 운영 DB / Storage와 연결하지 않음.

다음 테스트 항목:

### Android Chrome

- 물리 바코드 스캐너 입력
- Enter 처리
- 작업 대상 감지
- 팝업 중 추가 스캔 차단
- 진동 + 경고음
- 후면 카메라 호출
- 촬영 후 웹앱 복귀
- 미리보기
- 저장 후 다음 스캔 포커스 복귀
- 연속 촬영 시 메모리 / 화면 이상 여부

### iOS Safari

- 물리 바코드 스캐너 입력
- Enter 처리
- 작업 대상 감지
- 팝업 중 추가 스캔 차단
- 경고음 재생 여부
- 카메라 선택 UI 또는 직접 카메라 진입 방식 확인
- 후면 카메라 촬영
- 촬영 후 Safari 복귀
- 미리보기
- 저장 후 다음 스캔 포커스 복귀
- 홈 화면 추가 실행 시 동작 차이 확인

---

## 2026-08-12

### 프로젝트 방향 확정

- 독립형 모바일 웹앱으로 개발 시작
- 최종적으로 `miu-hub`에서 접근 가능하도록 연결 예정
- 실제 운영 중인 Supabase / DB에는 테스트 완료 전까지 연결하지 않기로 결정
- 개발 순서를 아래와 같이 확정
  1. GitHub 테스트 저장소 생성
  2. GitHub Pages 기반 모바일 테스트
  3. Android 실기기 확인
  4. iOS Safari 실기기 확인
  5. 스캔 / 팝업 / 카메라 UX 안정화
  6. Supabase 연결
  7. 실제 DB 연결
  8. 촬영본 Storage 업로드 및 통합 물건 조회 연동
  9. miu-hub 편입

### UI 방향

- `miu-hub`의 기존 UI를 복제하지 않음
- 독립 프로그램 자체 UI를 GitHub 기본 라이트 UI와 유사한 방향으로 설계
- 주요 디자인 기준
  - 흰색 기본 배경
  - 연한 회색 섹션 및 카드
  - 얇은 회색 테두리
  - GitHub 스타일 버튼 / 입력창 / 배지
  - 모바일 우선 레이아웃

### 1차 테스트 버전 구현

구현된 기능:

- 물리 바코드 스캐너 입력 지원
- Enter 기준 바코드 판정
- 코드 내부 샘플 작업 대상 목록과 대조
- 작업 대상 감지 시 경고 팝업
- 지원 기기에서 진동 알림
- `사진 촬영` 버튼
- `input type="file" + accept="image/*" + capture="environment"` 기반 카메라 호출
- 촬영 이미지 미리보기
- 다시 촬영
- 저장 완료 상태 처리
- 최근 스캔 목록
- 총 스캔 / 작업 대상 / 촬영 완료 카운터

### 현재 테스트용 대상 바코드

- `SB260812345`
- `CR61234567`
- `TT21234567`

### 데이터 연결 상태

현재는 아래 항목을 연결하지 않음.

- Supabase
- 운영 DB
- Supabase Storage
- 통합 물건 조회

현재 촬영 완료 상태는 프론트엔드 테스트용으로만 처리됨.

### GitHub 저장소 생성

Repository:

`i7444636/barcode-photo-scanner`

초기 테스트 버전 커밋:

`db42bf1b9ebc44cbe0c8d26b97d3459001429c98`

추가 문서:

- `README.md`
- `WORKLOG.md`

---

앞으로 기능 추가, 버그 수정, 테스트 결과 및 주요 결정사항을 날짜별로 이 파일에 계속 누적합니다.
