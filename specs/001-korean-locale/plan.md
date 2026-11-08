# Implementation Plan: 한국어 로케일 지원

**Branch**: `001-korean-locale` | **Date**: 2026-11-09 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-korean-locale/spec.md`

## Summary

플러그인의 두 번역 카탈로그에 한국어를 추가한다. webapp은 `webapp/src/i18n/ko.json`(영어
원문 1,029키 전부)을 추가하면 `index.tsx`의 `registerTranslations`와 `getStaticIntl`이
로케일 이름으로 파일을 찾는 기존 구조 덕에 코드 변경 없이 적용된다. server는 `i18n/ko.json`
(12 id)을 추가하고 `i18n.Init()`에 로드 줄 하나를 넣는다. 품질은 테스트로 고정한다 —
webapp `translations.test.ts`를 로케일별로 돌려 키 집합·ICU 문법·자리표시자 집합 일치를
검사하고, server는 `i18n/i18n_test.go`를 신설해 `ko` 로케일이 한국어를, 미등록 id가 영어
폴백을 돌려주는지 확인한다. 용어는 `glossary.md`로 고정한다.

## Technical Context

**Language/Version**: Go 1.26 (루트 모듈, 패키지 `i18n/`) + TypeScript/React (webapp, Node 24.11)

**Primary Dependencies**: `github.com/nicksnyder/go-i18n/v2` v2.7.0 + `golang.org/x/text`
(server), `react-intl` + `@formatjs/cli` 6.18.0 + `@formatjs/icu-messageformat-parser`
(webapp, 이미 devDependency)

**Storage**: N/A — 번역 카탈로그는 저장소 파일(JSON)이며 server 쪽은 `embed.FS`로 바이너리에
포함된다

**Testing**: Go `go test ./i18n/...`(table-driven), webapp Jest `npm test -- src/i18n`

**Target Platform**: Mattermost 서버 플러그인(Linux 서버 + 브라우저 webapp 번들)

**Project Type**: 기존 플러그인에 로케일 추가 (데이터 파일 + 로더 1줄 + 테스트)

**Performance Goals**: N/A — 번역 파일은 webapp 번들에 포함되며 1,029키·약 50KB 수준이라
기존 `es.json` 방식과 같다

**Constraints**: `webapp/src/i18n/en.json`은 추출 전용이라 손으로 고치지 않는다(원칙 V).
한국어는 CLDR 복수 범주가 `other` 하나다. 제품명·서비스명은 원문 유지.

**Scale/Scope**: webapp 1,029키(약 46,700자 영어 원문, plural 15·select 2·tag 9), server 12 id.
`temp/korean` 브랜치의 초안 79키(webapp)·12 id(server, 그중 7개가 현재 id와 일치)를
참고한다.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 원칙 | 적용 | 판정 |
|---|---|---|
| I. 품질 게이트 | 기준선: 구현 전 `go test ./i18n/... ./streaming/... ./conversations/...`와 `cd webapp && npm test -- src/i18n` 실패 목록 저장. 마감: 같은 명령 + `make check-style`, `make check-i18n`(en.json 미변경 확인). 결과는 tasks.md 하단 표에 diff로 기록 | 통과 (계획에 반영) |
| II. AGENTS.md 관례 | `format/`·styled-components·감사 로그·OpenTelemetry는 이 기능과 무관(코드 경로를 새로 만들지 않는다). "새 사용자 문자열은 i18n을 거친다"는 이 기능이 지키는 쪽. Go 테스트는 표 기반(`i18n_test.go`의 로케일×id 표). 새 테스트 라이브러리 없음 — `@formatjs/icu-messageformat-parser`는 이미 테스트가 쓴다. `webapp/src/i18n/en.json` 손편집 금지 준수 | 통과 |
| III. 실패를 본 테스트만 인정 | (a) `i18n_test.go`는 로더에 ko 줄을 넣기 전에 작성해 "ko 로케일에서 영어가 돌아온다"로 실패를 본다. (b) webapp 테스트 확장은 `ko.json`이 없는 상태에서 먼저 작성해 "파일 없음/키 0개"로 실패를 본다. 그 뒤 카탈로그를 채워 통과시킨다. SC-003의 변조 3종(키 삭제·자리표시자 변경·문법 오류)은 구현 후 일시 변조로 실측한다 | 통과 (순서를 tasks에 고정) |
| IV. 라이선스·upstream 충실성 | 새 Go 파일에 Mattermost copyright 헤더. `plugin.json`·`public/bridgeclient/` 무접촉. 디렉터리 구조 변경 없음 | 통과 |
| V. i18n 동기화 | 이 기능 자체가 `ko.json` 도입. `en.json`(webapp)은 건드리지 않고 `make check-i18n`으로 증명. 비준 후속 TODO("ko.json이 생긴 뒤")는 이 PR 머지 뒤 constitution PATCH로 정리 | 통과 |
| VI. 브랜치 + PR | 브랜치 `001-korean-locale`을 첫 편집 전에 만들었다(spec 작성 시점). 이 브랜치는 `chore/speckit-superpowers-workflow` 위에 쌓여 있다 — 머지는 chore PR 뒤에 rebase해서 올린다. squash 금지 | 통과 (쌓인 브랜치임을 PR 본문에 명시) |
| VII. Spec 주도 | 이 문서가 그 산출물. implement 3-bis에서 `test-driven-development`·`verification-before-completion` 호출 | 통과 |
| VIII. 문서 언어·문체 | 산출물 한국어, 식별자 원형 | 통과 |

위반 없음 → Complexity Tracking 비움.

## Project Structure

### Documentation (this feature)

```text
specs/001-korean-locale/
├── plan.md              # 이 문서
├── research.md          # Phase 0: 로케일 전달 경로·복수형·초안 재활용 조사
├── data-model.md        # Phase 1: 두 카탈로그의 형태와 검증 규칙
├── glossary.md          # Phase 1: 용어집 (FR-007)
├── quickstart.md        # Phase 1: 종단 검증 절차
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks)
```

`contracts/`는 만들지 않는다 — 외부에 노출하는 인터페이스가 없다. 카탈로그 형태는
data-model.md가 담는다.

### Source Code (repository root)

```text
i18n/
├── i18n.go              # Init(): ko.json 로드 줄 추가
├── i18n_test.go         # 신설: 로케일×id 표 기반 테스트 (ko 번역·en 폴백·es 회귀)
├── en.json              # 원문 (불변)
├── es.json              # (불변)
└── ko.json              # 신설: 12 id, {id, translation} 배열

webapp/src/i18n/
├── en.json              # 추출 전용 (불변 — make check-i18n으로 증명)
├── es.json              # (불변)
├── ko.json              # 신설: 1,029키, 평면 id→문자열
└── translations.test.ts # 확장: 로케일별 describe + 키 집합·자리표시자 일치 검사
```

**Structure Decision**: 기존 두 카탈로그 위치에 파일을 추가하는 것으로 끝낸다. webapp 로더
(`webapp/src/index.tsx`)는 로케일 이름으로 `require`하므로 건드리지 않는다. server 로더만
한 줄 바뀐다. 번역 생성은 구현 단계에서 영어 원문을 읽어 직접 작성하되, 스크립트 없이
사람이 읽는 JSON을 커밋한다(생성 도구를 저장소에 넣지 않는다 — 이후 갱신은 테스트가
빠진 키를 이름으로 알려 주므로 그 키만 채우면 된다).

## 검증 설계 (Phase 1 요약)

- **webapp 테스트 확장** (`translations.test.ts`): 기존 `describe('en.json')`을 로케일
  배열 `[['en', en], ['ko', ko]]`로 돌린다. 공통 검사는 "비어 있지 않다", "ICU 파싱".
  영어 전용 검사(`one` 범주, "1 things" 회귀)는 `en`에만 건다. `ko`에는 추가로
  (1) 키 집합이 `en`과 같다(빠진 키·남는 키를 각각 이름 배열로 단언), (2) 각 키의
  자리표시자 집합(인자 이름 + 태그 이름, plural/select 하위 포함)이 `en`과 같다,
  (3) plural 요소는 `other`만 가진다(한국어 CLDR).
- **server 테스트 신설** (`i18n/i18n_test.go`): `Init()` 후 `LocalizerFunc(bundle, lang)`로
  표 `{lang, id, default, want}` — `ko`는 한국어 문구, `es`는 기존 스페인어(회귀), 미등록
  id는 `ko`에서도 default 영어. 모든 `en.json` id가 `ko.json`에 있는지도 파일을 읽어
  단언한다(`embed`된 FS를 `fs.ReadFile`로 읽으면 된다 — 테스트는 같은 패키지).
- **종단 검증**: quickstart.md — `make deploy` 후 계정 언어 한국어로 5개 화면 확인,
  서버 안내 1건 확인. 환경이 없으면 `미실행`.

## Complexity Tracking

위반 없음.
