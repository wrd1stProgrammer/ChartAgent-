# ChartAgent

차트 캡처를 올리면 선택한 3~5명의 픽셀 에이전트가 독립적으로 검토하고, 서로의 근거를 교차 확인한 뒤 조건부 합의를 내는 SwiftUI 앱입니다.

## 현재 기능

- 사진에서 차트 선택·정규화
- InsightSentry 기반 심볼 검색·검증
- 선택적 최신 뉴스 반영
- ChartAgent 전용 FastAPI 서버의 구조화 분석
- Codex CLI `gpt-5.6-luna` / reasoning `low` 우선, 실패 시 OpenAI Responses API 자동 폴백
- 서버가 반환한 회의 대사를 에이전트 말풍선으로 재생
- 실제 분석 결과·업로드 이미지를 기기에 저장
- 선택한 에이전트에게 실제 후속 질문
- 차트 아님, 판독 불가, 심볼 불일치, 연결 실패의 구분된 재시도 UI

## 구성

- `ChartAgent/`: iOS 앱
- `backend/`: ChartAgent 전용 FastAPI 서버
- `backend/deploy/`: 기존 FaceMaxx EC2에 분리 배포하는 Docker Compose/Nginx 예시
- `ANALYSIS_IMPLEMENTATION_PLAN.md`: API, 모델, 폴백, 배포 계약

## 개발 확인

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project ChartAgent.xcodeproj -scheme ChartAgent \
  -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build

cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
.venv/bin/pytest -q
```

실제 배포에는 `backend/.env.example`을 기준으로 OpenAI/InsightSentry key와 FaceMaxx의 공유 Codex 인증 volume을 주입합니다. API key는 iOS 앱에 포함되지 않습니다.
