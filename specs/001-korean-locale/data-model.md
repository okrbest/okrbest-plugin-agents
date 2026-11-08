# Data Model: 한국어 로케일 지원

이 기능의 "데이터"는 두 번역 카탈로그 파일이다. 런타임 상태 변화는 없다.

## 1. webapp 번역 카탈로그 — `webapp/src/i18n/ko.json`

| 항목 | 내용 |
|---|---|
| 형태 | 평면 JSON 객체 `{ "<key>": "<message>" }` |
| 키 | 영어 원문 추출 시 생성된 내용 해시(`[sha512:contenthash:base64:8]`, 예 `"+3kygeI2"`). 사람이 만들지 않고 `en.json`에서 그대로 가져온다 |
| 값 | ICU MessageFormat 문자열 (react-intl) |
| 정렬 | `en.json`과 같은 키 순서(추출기가 정렬한 순서)로 둔다 — diff 리뷰를 위해 |

**검증 규칙** (FR-003·FR-009, `translations.test.ts`가 집행)

- V1. `keys(ko) == keys(en)` — 빠진 키·남는 키 모두 0.
- V2. 모든 값이 ICU로 파싱된다.
- V3. 키마다 `placeholders(ko[k]) == placeholders(en[k])`. placeholders = 인자 이름
  (argument/number/date/time/plural/select의 `value`) ∪ 태그 이름(tag의 `value`),
  plural/select `options`·tag `children` 재귀 포함. `#`는 제외.
- V4. plural 요소는 `other` 분기만 가진다(한국어 CLDR). `=0`·`=1` 같은 정확값 분기는
  원문에 있을 때만 허용하되, 현재 원문에는 없다.
- V5. 빈 문자열 값 없음.

## 2. server 번역 카탈로그 — `i18n/ko.json`

| 항목 | 내용 |
|---|---|
| 형태 | JSON 배열 `[{ "id": "agents.<name>", "translation": "<message>" }]` (go-i18n v2 메시지 파일) |
| id | `i18n/en.json`의 12개 id와 1:1 |
| 값 | Go `fmt.Sprintf` 서식 문자열(코드가 `params`를 `Sprintf`로 끼운다). 원문의 `%s`·`%d` 순서와 개수를 유지 |

현재 id 12개:

```
agents.agent_mention_reminder_fallback
agents.multiplayer_channels_requires_professional
agents.no_longer_access_error
agents.search_tools_unavailable
agents.stream_to_post_access_llm_error
agents.stream_to_post_llm_not_return
agents.summairize_subscription_error
agents.summarize_call_recording_processing
agents.summarize_call_recording_processing_error
agents.summarize_recording
agents.summarize_transcription
agents.analysis_source_unavailable
```

**검증 규칙** (`i18n/i18n_test.go`가 집행)

- S1. `en.json`의 모든 id가 `ko.json`에 있다(`embed.FS`를 읽어 집합 비교).
- S2. `LocalizerFunc(Init(), "ko")(id, default)`가 `ko.json`의 translation을 돌려준다
  (표본 id 전부 — 표 기반).
- S3. `LocalizerFunc(Init(), "es")`는 기존 스페인어를 그대로 돌려준다(회귀).
- S4. 미등록 id는 `ko`에서 default(영어)를 돌려준다.
- S5. `%s`/`%d` 동사 개수가 원문과 같다(값 안의 `%` 서식 개수 비교).

## 3. 용어집 — `specs/001-korean-locale/glossary.md`

| 항목 | 내용 |
|---|---|
| 형태 | 표: 영어 용어 → 한국어 → 비고(원문 유지 여부, 예문) |
| 역할 | FR-007·FR-008의 기준. 이후 upstream 반영으로 키가 늘 때 번역자가 참조 |

## 관계

```
en.json (webapp, 추출 전용) ──키 집합 1:1──> ko.json (webapp)
i18n/en.json (server, 수동)  ──id 집합 1:1──> i18n/ko.json (server)
glossary.md ──용어 기준──> 두 ko.json
```

상태 전이 없음.
