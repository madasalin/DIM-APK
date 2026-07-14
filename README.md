# DIM Mobile (Android)

데스크톱 `DMD.py`(DIM — 4CH 측정 프로그램)의 안드로이드 버전입니다.
R1~R4 값 카드, R1~R4 실시간 그래프, FTDI USB OTG 실장비 통신, MZERO/MCLEAR
영점 명령, 통신 포맷 그대로의 데모 송출 테스트까지 데스크톱과 동일한 형식으로 포팅했습니다.

## 이번 업데이트 내용

- **빌드 버전 고정**: GitHub Actions 빌드 에러를 잡기 위해 AGP 8.7.3 / Kotlin 2.0.21 /
  Gradle 8.10.2 조합으로 맞춰뒀습니다. (이전 버전 조합에서 컴파일 에러가 났던 부분)
- **그래프 성능 개선**: 스캔 시간이 길어져 샘플이 수천 개가 쌓여도 화면엔 최대
  300개 점만 그리도록 다운샘플링했습니다. R1~R3 판정값/R4 Runout 계산은 항상
  원본 전체 데이터로 계산되므로 **정확도에는 영향 없음** — 그래프 렌더링만 가벼워집니다.
- **로그인 화면 추가**: 앱을 처음 실행하면 아이디/비밀번호를 물어봅니다.
  - 아이디: `ddtcj`
  - 비밀번호: `ddtcj`
  - 한 번 로그인하면 다음부터는 자동으로 바로 메인 화면으로 들어갑니다.
    (환경설정 화면 맨 아래 "로그아웃" 버튼으로 다시 로그인 화면을 띄울 수 있습니다)
- **로고 적용**: 업로드해주신 `app_icon.svg`를 앱 아이콘(런처 아이콘) 전 해상도와
  로그인 화면 상단, 메인 화면 상단바에 적용했습니다.

## 이 작업 환경에서 APK를 직접 만들지 못하는 이유

이 프로젝트를 만든 환경(Claude 샌드박스)에는 Android SDK/Flutter SDK가 설치되어
있지 않고 네트워크도 제한되어 있어, 여기서 바로 APK를 컴파일할 수 없습니다.
대신 `.github/workflows/build_apk.yml` 워크플로우를 함께 넣어뒀습니다 — 이 저장소를
GitHub에 올리기만 하면 Actions가 자동으로 APK를 빌드해서
**Actions → 실행 결과 → Artifacts(dim-mobile-apk)** 또는 **Releases** 탭에 올려줍니다.

## 사용 방법 (GitHub Actions로 APK 받기)

1. 이 폴더 전체를 새 GitHub 저장소에 푸시합니다.
   ```bash
   cd dim_android
   git init
   git add .
   git commit -m "DIM mobile — 로그인/로고/성능개선"
   git branch -M main
   git remote add origin <본인 저장소 URL>
   git push -u origin main
   ```
2. GitHub 저장소의 **Actions** 탭에서 `Build DIM Android APK` 워크플로우가
   자동으로 실행되는 것을 확인합니다.
3. 빌드가 끝나면:
   - **Actions → 해당 실행 → Artifacts → `dim-mobile-apk`** 에서 다운로드, 또는
   - 저장소 **Releases** 탭에 자동으로 올라온 `app-release.apk` 다운로드
4. 안드로이드 기기에 APK를 설치합니다. (출처를 알 수 없는 앱 설치 허용 필요)
5. 앱 실행 → 아이디/비밀번호에 `ddtcj` / `ddtcj` 입력 → 로그인

## 로컬 PC에 Flutter/Android Studio가 있다면

```bash
flutter pub get
flutter build apk --release
# 결과물: build/app/outputs/flutter-apk/app-release.apk
```

## 앱 사용법

1. 처음 실행 시 아이디/비밀번호(`ddtcj`/`ddtcj`) 입력 → 로그인
2. 우측 상단 톱니바퀴(환경설정) → USB 장치 목록에서 FTDI 장치 선택 → **연결**
   (안드로이드가 USB 권한 팝업을 띄우면 허용)
3. 홈 화면에서 **스캔시작**을 누르면:
   - 장치가 연결되어 있으면 → 실제 `START` 명령을 반복 전송해 실측 데이터로 스캔
   - 연결이 안 되어 있으면 → 자동으로 데모(가상 통신 포맷)로 스캔 (경고 문구 표시)
4. **MZERO** = 영점설정, **MCLEAR** = 영점 초기화 (연결 안 된 상태에서는 mock 오프셋으로 대체)
5. **데모 송출 테스트 (통신 포맷)** = 실제 장비와 100% 동일한 바이트 포맷(ENQ/ID/DataNum/
   Data.../ETX/@@/CRLF)으로 프레임을 만들고 그대로 파싱까지 왕복 검증하는 버튼입니다.
6. **엔지니어 모드** 스위치를 켜면 R1~R4 실시간 그래프가 나타납니다.
   (R4는 Deflector 자동 제거 알고리즘 결과 — 제거된 점은 빨강, Valley는 노랑 점으로 표시)

## 실제 장비 데이터 수신 후 조정할 부분

데스크톱과 마찬가지로 "기본" 골격만 구현되어 있습니다. 실측 데이터를 받으면:

- `lib/protocol.dart` — 프레임 필드 순서/자리수/구분자가 사양과 다르면 이 파일만 수정
- `lib/usb_serial_service.dart` / `lib/measurement_controller.dart` —
  `START` 요청-응답 방식이 아니라 장비가 상시로 데이터를 흘려보내는 방식이라면
  `_runRealScan()`의 반복 전송 로직을 "상시 리더 스레드" 방식으로 교체
- 화면(`home_screen.dart`, `widgets/`)과 알고리즘(`algorithms.dart`)은 그대로 재사용됩니다.

## 폴더 구조

```
lib/
  main.dart                 앱 진입점 (로그인 → 메인)
  login_screen.dart          로그인 화면 (ddtcj/ddtcj, 최초 1회만)
  theme.dart                 색상/폰트(데스크톱과 동일 팔레트)
  settings.dart               환경설정 모델 (SharedPreferences 영속 저장)
  protocol.dart               ENQ/ETX 프로토콜 파서/빌더
  algorithms.dart              R4 Deflector 자동 제거 + Runout(Method 3) 계산
  usb_serial_service.dart      FTDI(등) USB OTG 시리얼 통신 래퍼
  measurement_controller.dart  스캔/영점/버퍼/결과 계산 컨트롤러
  settings_screen.dart         환경설정 화면 (USB 장치 선택 + 로그아웃)
  home_screen.dart             메인 화면 (값 카드 + 컨트롤 + 그래프)
  widgets/
    value_card.dart            R1~R4 값 카드
    channel_chart.dart          R1~R4 실시간 그래프 (다운샘플링 적용)
assets/
  logo.png / logo.svg          앱 로고
android/                       네이티브 안드로이드 프로젝트 (Gradle, 매니페스트, 아이콘 등)
.github/workflows/build_apk.yml   APK 자동 빌드
```

