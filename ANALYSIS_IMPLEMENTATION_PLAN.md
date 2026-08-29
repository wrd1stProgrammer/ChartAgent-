# ChartAgent 실제 분석 구현 및 배포 계획

기준일: 2026-08-14

## 1. 현재 구현 구조

```text
iOS ChartAgent
  ├─ 차트 이미지 선택·정규화
  ├─ InsightSentry 심볼 검색 결과 선택
  ├─ 시간대 / 뉴스 반영 / 에이전트 3~5명 선택
  ├─ POST /chartagent/v1/analyses
  └─ 결과와 이미지를 기기에 보관
                 │
                 ▼
기존 FaceMaxx EC2
  └─ ChartAgent 전용 FastAPI 컨테이너 :8010
       ├─ 이미지 형식·크기·해상도 검증
       ├─ InsightSentry 심볼 실재 여부 검증
       ├─ [뉴스 ON] 최신 관련 뉴스 조회
       ├─ Codex CLI: gpt-5.6-luna / low / strict JSON
       └─ 실패 시 OpenAI Responses API: gpt-5.6-luna / low
```

- FaceMaxx와는 EC2, Nginx, Codex 인증 volume만 공유한다.
- ChartAgent의 코드, 컨테이너, localhost 포트, 환경 변수, health check는 분리한다.
- API key는 iOS 바이너리에 넣지 않고 서버에만 둔다.
- 업로드 원본은 요청 처리용 임시 디렉터리에만 쓰고 응답 후 삭제한다.

## 2. 실제 API

### `GET /v1/symbols/search?query=`

- InsightSentry 검색 결과를 앱에 반환한다.
- 사용자는 자유 텍스트를 입력한 뒤 반드시 검색 결과를 선택해야 한다.

### `POST /v1/analyses`

multipart 필드:

- `image`
- `symbol_code`
- `timeframe`
- `include_news`
- `active_agent_ids`

처리:

1. JPEG/PNG/WEBP, 12MB 이하, 최소 320×240을 검증한다.
2. InsightSentry `GET /v3/symbols/{symbol}/info`로 심볼을 확정한다.
3. 뉴스가 켜졌을 때만 `GET /v3/newsfeed`를 호출한다.
4. Codex CLI에 이미지와 strict JSON schema를 전달한다.
5. Codex 실행, 인증, timeout, model, schema 어떤 실패든 발생하면 OpenAI API로 단 한 번 폴백한다.
6. AI 응답이 차트 아님, 판독 불가, 심볼 불일치라고 판단하면 422 코드로 중단한다.
7. 성공한 구조화 결과만 앱에 반환한다.

### `POST /v1/follow-ups`

- 선택한 에이전트 ID, 질문, 기존 구조화 리포트만 전송한다.
- 원본 이미지를 서버에 보관하거나 다시 전송하지 않는다.
- 후속 질문도 Codex 우선, OpenAI 폴백이다.

## 3. 모델·토큰 전략

- 주 분석: `gpt-5.6-luna`, reasoning `low`
- 폴백: Responses API의 동일 모델과 reasoning
- 이미지: 긴 변 2,200px 이하 JPEG, quality 0.86, API `detail: high`
- 출력 상한: 2,800 tokens
- 에이전트 5회 호출 대신 요청 1회에서 3~5개 독립 의견, 상호 검증, 합의, 회의 대사를 받는다.
- 뉴스는 선택 시에만 최대 6건의 제목·출처·시각·짧은 본문을 전달한다.
- 보이지 않는 가격, 지표, 다른 시간대, 실시간 수급은 생성하지 못하게 프롬프트와 스키마를 제한한다.

## 4. 회의 UI 연결

1. API 응답 전에는 이미지 해독, 심볼 검증, 뉴스 조회처럼 실제 요청 상태만 표시한다.
2. 응답이 도착하면 선택된 에이전트만 상하좌우 경로로 회의 위치에 모인다.
3. `meeting_script`를 한 줄씩 클라이언트에서 재생한다.
4. 말풍선은 현재 화자 머리 위에만 타이핑하고 다음 화자 전에 제거한다.
5. 회의 기록과 말풍선은 서버가 반환한 동일 대사를 쓴다.

이 구조는 에이전트마다 API를 다시 호출하지 않으면서도 회의처럼 보이게 한다. 네트워크가 빠른 경우는 결과를 버퍼링하고, 느린 경우는 중립적인 작업 상태를 유지한다.

## 5. 실패 상태

| 상황 | 서버 | iOS |
|---|---|---|
| 지원하지 않는/손상 이미지 | 422 | 다른 이미지 선택 안내 |
| 작은 이미지 | 422 | 더 큰 캡처 안내 |
| 심볼 없음 | 422 | 검색 결과 재선택 |
| 차트 아님/판독 불가/심볼 불일치 | 422 | 입력 유지 + 구체적 재시도 안내 |
| Codex CLI 실패 | 즉시 OpenAI 폴백 | 별도 중단 없음 |
| Codex + OpenAI 모두 실패 | 502 | 같은 입력 재시도 |
| InsightSentry 연결 실패 | 503 | 잠시 후 재시도 |
| 네트워크 실패 | - | 입력 유지 + 재시도 |

## 6. 배포 순서

1. `backend/.env.example`을 복사해 EC2에 `.env`를 만든다.
2. OpenAI와 InsightSentry key를 주입한다.
3. FaceMaxx의 Codex volume 이름을 `SHARED_CODEX_VOLUME`로 지정한다.
4. `backend/Dockerfile`로 이미지를 빌드하고 `backend/deploy/docker-compose.yml`로 실행한다.
5. 기존 TLS Nginx server block에 `backend/deploy/nginx-chartagent.conf.example`을 추가한다.
6. `/chartagent/health`, 심볼 검색, 유효/무효 이미지 각 1건만 smoke test한다.
7. iOS 실기기는 `https://facemaxx.nostalgia-drive.com/chartagent/v1/`을 사용한다.

## 7. 이번 구현 범위와 다음 작업

완료된 코드 범위:

- ChartAgent 전용 FastAPI 서버와 Docker/Nginx 배포 구성
- Codex CLI Luna low 고정 및 OpenAI 자동 폴백
- InsightSentry 심볼 검색·검증·뉴스
- iOS 업로드, 실제 회의, 결과, 기록, 후속 질문
- 타입이 있는 실패 UI와 입력 보존

배포 전 필수 외부 작업:

- EC2에 ChartAgent `.env` 비밀번호 주입
- ChartAgent 이미지 build/push 후 compose up
- Nginx location 반영과 reload
- 실제 API key를 사용한 smoke test

서버 인증 정보가 현재 작업 폴더에 없으므로, 이 세 가지는 코드 완성과 별도의 배포 단계로 남긴다.
