# ChartAgent backend

FaceMaxx와 같은 EC2에서 실행하되, 애플리케이션 코드·컨테이너·포트·환경 변수는 분리한 FastAPI 서비스입니다.

## 요청 흐름

1. 이미지 바이트/해상도/형식 검증
2. InsightSentry `/v3/symbols/{symbol}/info`로 심볼 실재 검증
3. 뉴스 옵션을 켠 경우 `/v3/newsfeed?related_symbols=...` 조회
4. Codex CLI로 `gpt-5.6-luna`, reasoning `low`, strict JSON schema 분석
5. Codex 실행·인증·타임아웃·스키마 오류 시 OpenAI Responses API의 같은 모델/스키마로 폴백

OpenAI 및 InsightSentry 키는 앱에 포함하지 않고 서버 환경 변수로만 주입합니다. InsightSentry는 `INSIGHTSENTRY_RAPIDAPI_KEY` / `INSIGHTSENTRY_RAPIDAPI_HOST` 방식을 우선 사용하고, 기존 Bearer API 키도 호환합니다. Codex 프로세스에는 두 API 키가 전달되지 않습니다.

## 로컬 실행

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8010 --reload
```

## 운영 배포 소스

이 디렉터리는 앱의 로컬 분석·작도 QA용 백엔드입니다. 실제 운영 소스와 자동 배포는 [facemaxx---app 저장소의 chartagent_backend](https://github.com/wrd1stProgrammer/facemaxx---app/tree/main/chartagent_backend)에 있습니다. 이 디렉터리로 운영 서비스를 덮어쓰지 않습니다. 운영 저장소의 `main`에 반영하면 기존 GitHub Actions가 EC2로 배포합니다.

## 버전별 작도 API

기존 `/v1/analyses`, `/v1/analysis-jobs`, `/v1/follow-ups`의 요청·응답, 프롬프트, 모델 기본값은 유지합니다. 신버전 iOS만 별도 `POST /v2/chart-annotations`를 호출합니다. 기존 앱에는 작도 응답 필드나 추가 작업을 삽입하지 않습니다. 앱의 분석 API base URL은 계속 `/chartagent/v1`이며 작도 요청만 같은 서버의 `/chartagent/v2/chart-annotations`로 보냅니다.

```bash
curl --fail-with-body http://127.0.0.1:8010/v2/chart-annotations \
  -F 'image=@/absolute/path/chart.png' \
  -F 'locale=ko' \
  -F 'report_context=</absolute/path/annotation-context.json'
```

`report_context`는 필수 JSON이며 `consensus`, 순서가 유지된 `scenarios`, `structure`, `trend_evidence`, 선택적 `trigger`·`invalidation`·`target`을 포함합니다. 요청 locale은 앱이 지원하는 16개 언어 코드입니다. 응답은 `locale`, `image_width`, `image_height`, `summary`, 최대 3개의 `annotations`를 포함합니다. 좌표는 EXIF 방향을 정규화한 전체 이미지 기준 0~1이며 원본 이미지는 수정하지 않습니다.

작도 종류는 `line`, `zone`, `arrow`, `channel`입니다. 추세선은 실제 스윙 접점에 연결하고 평행 채널은 두 기준점과 반대 경계 한 점으로 같은 기울기의 두 선을 계산합니다. 각 작도의 `detail`은 관찰 근거, `outlook`은 유지·돌파·이탈에 따른 다음 방향, `scenario_index`는 연결된 기존 분석 시나리오의 0부터 시작하는 인덱스 또는 null입니다. 기존 분석과 충돌하는 방향이나 근거 없는 미래 가격 경로를 만들지 않습니다. 서버와 앱에서 좌표 및 시나리오 범위를 검증합니다.

작도는 전용 provider 인스턴스와 실행 한도를 사용합니다. `CHARTAGENT_ANNOTATION_MODEL` 기본값은 `gpt-6-astra`이고 reasoning은 `medium`입니다. 운영 기본 `CHARTAGENT_ANNOTATION_PROVIDER=openai_api`는 작도 모델의 API를 직접 사용합니다. API 호출 100초(1회), 전체 요청 115초로 제한하며 `CHARTAGENT_ANNOTATION_MAX_CONCURRENCY` 기본값은 2입니다. 한도가 차면 대기열 없이 `503 annotations_busy`를 반환합니다. `CHARTAGENT_ANNOTATIONS_ENABLED=false`로 작도만 중지할 수 있습니다(설정 후 프로세스 재시작 필요). 로컬 QA에서 `CHARTAGENT_ANNOTATION_PROVIDER=codex_cli`를 지정하면 Codex 85초 이후 API 폴백을 사용하되 전체 115초를 넘기지 않습니다. 앱 저장소의 로컬 QA 기본값은 `codex_cli`입니다. 기존 v1 분석 한도와 설정은 변경하지 않습니다. 작도 실패 시 앱은 이미 받은 분석과 원본 차트를 유지하고 재시도를 제공합니다.

## 차트 이미지 위 핵심 작도

`POST /v2/chart-annotations`는 원본 이미지를 읽고 최대 3개의 추세선·영역·관찰된 반응 화살표·평행 채널과 짧은 설명을 반환합니다. 에이전트별로 생성하지 않고 결과 상단 이미지에 한 번 표시합니다. 이미지나 텍스트에 근거가 없으면 빈 작도 목록을 반환합니다. 원본 픽셀을 바꾸지 않으며, 좌표는 EXIF 방향을 정규화한 전체 이미지 기준 0~1입니다.

```bash
curl --fail-with-body http://127.0.0.1:8010/v2/chart-annotations \
  -F 'image=@/absolute/path/chart.png' \
  -F 'locale=ko' \
  -F 'report_context=</absolute/path/annotation-context.json'
```

작도는 이미지 좌표 정확도를 위해 기본 `gpt-6-astra` / `medium`을 사용합니다. `CHARTAGENT_ANNOTATION_MODEL`로 작도 모델만 설정할 수 있으며, 기존 분석/후속 질문의 `gpt-5.6-luna` / `low` 설정은 유지합니다. 평행 채널은 기준선의 두 점과 반대쪽 경계의 한 점을 받아 같은 기울기의 두 선으로 계산하며, 폭이 없거나 이미지 밖으로 나가는 채널은 거부합니다. 요청 언어는 지원하는 16개 locale로 제한하고 응답의 locale 및 로컬 캐시와 대조합니다. iOS는 보고서를 먼저 보여주고 작도를 별도로 불러오며, 분석 ID와 언어별로 로컬에 저장합니다. 원본 전환·번호 선택·전체 화면 확대는 같은 이미지 좌표를 공유합니다.

`report_context`는 `consensus`, 순서가 유지된 `scenarios`, `structure`, `trend_evidence`, 선택적 `trigger`·`invalidation`·`target`을 담는 JSON입니다. 앱은 실제 분석에서 이 문맥을 구성합니다. 각 작도의 `detail`은 관찰 근거, `outlook`은 유지·돌파·실패 조건에 따른 다음 방향, `scenario_index`는 연결된 분석 시나리오의 0부터 시작하는 인덱스 또는 null입니다. 서버와 앱이 실제 시나리오 범위를 검사합니다. 추세선은 실제 스윙 접점에만 그리며 미래 가격 경로를 만들어 그리지 않습니다. 앱에서는 작도 아래의 조건별 시나리오 버튼으로 해당 분석 항목에 이동합니다. 변경된 문맥을 반영하기 위해 작도 캐시는 API v2와 문맥 v3을 함께 구분합니다.

iOS DEBUG 빌드에서 `CHARTAGENT_ANNOTATION_IMAGE`와 `CHARTAGENT_ANNOTATION_RECORD`에 원본 이미지/실제 분석 JSON 경로를 지정하고, `--chartagent-screen=annotations`로 실행하면 실제 `AnalysisResultView`가 열립니다. `CHARTAGENT_ANNOTATION_DOCUMENT`는 실응답 JSON 재생, `CHARTAGENT_ANNOTATION_EXPORT`는 같은 SwiftUI 캔버스의 고해상도 PNG 저장 경로입니다. 문서를 생략하면 `CHARTAGENT_API_BASE_URL`의 로컬 작도 API에 직접 요청합니다. `scripts/review_chart_annotations.py`는 제공된 manifest를 읽어 실제 모델 분석과 HTTP 작도 응답을 저장합니다. 이 QA 경로의 종목 메타데이터는 제공된 캡처에서 가져오며 실시간 시장 검증·뉴스 수집은 실행하지 않습니다. 테스트 이미지와 결과는 앱 번들에 포함하지 않습니다. 새 엔드포인트를 배포해야 운영 앱에서도 작도가 생성됩니다.
