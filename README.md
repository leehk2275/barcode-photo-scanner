# Barcode Photo Scanner

모바일 환경에서 실물 바코드를 스캔하고, 사전에 지정된 작업 대상 바코드를 즉시 감지해 현장에서 사진 촬영까지 이어지도록 하는 독립형 웹앱입니다.

현재는 **테스트 단계**이며 운영 DB와 분리된 전용 Supabase 테스트 프로젝트에만 연결합니다.

## 목표

기존에는 작업 대상 바코드를 따로 모은 뒤 다시 사진 촬영하고 저장해야 했습니다. 이 프로젝트는 해당 과정을 줄여 아래 흐름으로 처리하는 것을 목표로 합니다.

1. 실물 바코드 스캔
2. 작업 대상 목록과 즉시 대조
3. 대상 바코드일 경우 경고 팝업 표시
4. `사진 촬영` 버튼으로 현재 휴대폰의 카메라 호출
5. 촬영 후 미리보기 및 저장 처리
6. 테스트 Supabase Storage 및 DB에 촬영 결과 저장
7. 최종적으로 miu-hub에서 접근 가능하도록 편입

## 현재 구현 범위

- 모바일 중심 UI
- GitHub 기본 라이트 UI를 참고한 독립 디자인
- 물리 바코드 스캐너 입력 + Enter 기반 판정
- Supabase `photo_targets` 작업 대상 바코드 판정
- 작업 대상 감지 시 경고 팝업
- 진동 알림 지원 기기에서 햅틱 동작
- `capture="environment"` 기반 후면 카메라 촬영 호출
- 촬영 이미지 미리보기 및 Storage 업로드
- 다시 촬영 / 저장 처리
- 최근 스캔 기록 표시
- `item_photos` 사진 메타데이터 기록
- `photo_targets` 촬영 완료 상태 반영
- 총 스캔 / 작업 대상 / 촬영 완료 카운트
- 연결 실패 시 스캔 잠금 및 재연결

## 테스트 데이터

테스트 Supabase의 `photo_targets`에는 아래 데이터가 등록되어 있습니다.

- 엑셀 `온라인_바코드목록_취합_260812.xlsx`의 `Sheet1` A열 바코드 529건
- 초기 모바일 테스트용 샘플 바코드 3건
- 전체 532건

## 현재 저장 방식

현재 버전은 다음 테스트 리소스에만 저장합니다.

- Supabase 프로젝트: `leehk2275_barcode-photo-scanner`
- 프로젝트 ref: `rbifmyvpilvjqfmrfvhr`
- 작업 대상: `public.photo_targets`
- 사진 메타데이터: `public.item_photos`
- 사진 파일: Storage `item-photos`
- 브라우저에는 publishable key만 포함하고 RLS 정책을 적용
- 운영 Supabase / 운영 데이터 변경: 없음

이 구성은 로그인 없이 실기기 E2E 테스트를 하기 위한 샌드박스 정책입니다. 운영 전환 시에는 Auth와 사용자별 권한을 포함해 RLS를 다시 잠가야 합니다.

## 테스트 순서

1. GitHub Pages에서 웹앱 실행
2. Android 실기기 테스트
   - 바코드 스캐너 입력
   - 작업 대상 감지
   - 진동 / 팝업
   - 카메라 호출
   - 촬영 및 미리보기
   - 화면 복귀 후 다음 스캔
3. iOS Safari 실기기 테스트
4. Android / iOS 간 UX 차이 수정
5. 테스트 Supabase 대상 조회 확인
6. Storage 업로드 및 바코드 매칭 확인
7. Android / iOS 실기기 E2E 검증
8. 운영용 Auth / RLS 설계
9. 운영 DB 연결
10. 통합 물건 조회 연동
11. miu-hub 편입

## 예정 기능

- 운영용 Auth 및 사용자별 권한
- 업로드 재시도 / 오프라인 큐
- 오류 및 업로드 실패 처리
- 중복 촬영 방지
- 작업 이력 저장
- Excel / CSV 다운로드
- 통합 물건 조회에서 사진 표시

## Repository

이 저장소는 테스트 및 개발용 독립 프로젝트입니다.

현재 메인 파일:

- `index.html`
- `README.md`
- `WORKLOG.md`

개발 기록은 `WORKLOG.md`에 누적합니다.
