# Tasks: 한국어 로케일 지원

**Input**: `/specs/001-korean-locale/` 설계 문서 (plan.md, spec.md, research.md, data-model.md,
quickstart.md, glossary.md)

**Tests**: 명세 FR-009와 constitution 원칙 III이 테스트를 요구한다. 테스트 과제는 구현 과제
**앞에** 두며, **실패 출력을 남긴 뒤에만** `[X]`로 표시한다.

**Organization**: 사용자 이야기별 단계. US1(webapp 화면)과 US2(server 안내)는 서로 독립이고,
US3(테스트가 깨짐을 잡는다)은 Phase 2의 테스트가 실제로 잡는지 변조로 실측하는 단계다.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 병렬 가능(다른 파일, 미완 과제 의존 없음)
- **[Story]**: US1 / US2 / US3
- 경로는 저장소 루트 기준

## Path Conventions

- server 카탈로그: `i18n/` (Go 패키지, 루트 모듈)
- webapp 카탈로그: `webapp/src/i18n/`
- 기준선·임시 산출물: 세션 스크래치 디렉터리 (저장소 밖)

---

## Phase 1: Setup (기준선)

**Purpose**: 변경 전 상태를 기록해 회귀를 목록 diff로 판정할 수 있게 한다 (원칙 I)

- [X] T001 `make apply`로 `server/manifest.go`가 있는지 확인하고, 작업 트리가 깨끗한 상태에서
      기준선을 저장한다: `go test ./i18n/... ./streaming/... ./conversations/... ./meetings/... 2>&1 | tee <scratch>/baseline-go.txt`,
      `cd webapp && npm test -- src/i18n 2>&1 | tee <scratch>/baseline-webapp.txt`,
      `make check-i18n 2>&1 | tee <scratch>/baseline-i18n.txt`. 실패 목록(FAIL 줄)만 추려
      `<scratch>/baseline-failures.txt`에 남긴다
- [X] T002 [P] `specs/001-korean-locale/glossary.md`의 용어를 `temp/korean` 초안과 대조해
      빠진 핵심 용어가 있으면 보강한다: `git show temp/korean:webapp/src/i18n/ko.json`,
      `git show temp/korean:i18n/ko.json`

---

## Phase 2: Foundational (테스트 먼저 — 구현 전 실패를 본다)

**Purpose**: 카탈로그 검증 규칙(data-model V1~V5, S1~S5)을 테스트로 고정한다. 이 단계의
테스트는 `ko.json`이 없고 로더에 ko 줄이 없는 상태에서 **반드시 실패해야** 한다.

**⚠️ CRITICAL**: 실패 출력을 저장하기 전에는 Phase 3 이후로 넘어가지 않는다.

- [X] T003 [P] `webapp/src/i18n/translations.test.ts` 확장: (1) `placeholders(message)` 도우미
      — `@formatjs/icu-messageformat-parser` AST에서 argument/number/date/time/plural/select의
      `value`와 tag의 `value`를 모으고 plural·select `options`·tag `children`을 재귀, pound 제외.
      (2) 로케일 표 `[['en', en], ['ko', ko]]`로 공통 검사("비어 있지 않다", "ICU 파싱")를
      `describe.each`로 돌린다. (3) 영어 전용 검사(`one` 범주, "1 things" 회귀)는 `en`에만.
      (4) `describe('ko.json')`에 V1 키 집합 일치(빠진 키·남는 키 각각 `toEqual([])`),
      V3 키별 자리표시자 집합 일치(어긋난 키 이름 배열), V4 plural은 `other`만, V5 빈 값 없음.
      `import ko from './ko.json'`은 파일이 없으면 컴파일 실패하므로 이 시점에 실패 출력이
      나온다 — 그 출력을 `<scratch>/red-webapp.txt`에 저장한다
- [X] T004 [P] `i18n/i18n_test.go` 신설(Mattermost copyright 헤더, `package i18n`): 표 기반
      `TestLocalizerFunc` — `{name, lang, id, defaultMessage, want}` 행으로 `ko` 번역 전부,
      `es` 회귀 2건, 미등록 id의 `ko` 폴백 1건; `TestKoreanCatalogCoversEnglish` — `i18nFiles`를
      `fs.ReadFile`로 읽어 `en.json` id 집합 ⊆ `ko.json` id 집합을 단언하고 S5(`%` 서식
      개수 일치)도 같은 표에서 확인. `go test ./i18n/... 2>&1 | tee <scratch>/red-go.txt`로
      실패 출력(ko.json 없음 / 영어가 돌아옴)을 저장한다

**Checkpoint**: `red-webapp.txt`·`red-go.txt`에 실패가 있다. 없으면 테스트가 아무것도
검사하지 않는 것이다 — 되돌아가 고친다.

---

## Phase 3: User Story 1 - 한국어 사용자가 플러그인 화면을 한국어로 본다 (Priority: P1) 🎯 MVP

**Goal**: `webapp/src/i18n/ko.json`에 영어 원문 1,029키 전부를 glossary 기준으로 채운다.

**Independent Test**: `cd webapp && npm test -- src/i18n` 통과 + 한국어 계정으로
quickstart C1~C5에서 영어 문구 0개.

### Implementation for User Story 1

번역은 `en.json`의 키 순서대로 묶어 진행한다. 묶음마다 ICU·자리표시자 검사를 돌려 구조
오류를 바로 잡고, 마지막 묶음 뒤에 키 집합 검사가 통과한다. 모든 묶음이 같은 파일에
쓰므로 순차 실행한다.

- [X] T005 [US1] `webapp/src/i18n/ko.json` 생성: `en.json`의 키 순서를 그대로 따르는 스캐폴딩
      스크립트를 스크래치에 두고(저장소에 넣지 않는다), 1~200번째 키를 glossary 어조로
      번역해 기록한다. plural은 `other`만, 태그·자리표시자 이름은 원문 그대로
- [X] T006 [US1] 201~400번째 키 번역을 `webapp/src/i18n/ko.json`에 추가하고
      `cd webapp && npm test -- src/i18n -t "parses as ICU|자리표시자"`로 구조 검사
- [X] T007 [US1] 401~600번째 키 번역을 `webapp/src/i18n/ko.json`에 추가하고 같은 구조 검사
- [X] T008 [US1] 601~800번째 키 번역을 `webapp/src/i18n/ko.json`에 추가하고 같은 구조 검사
- [X] T009 [US1] 801~1,029번째 키 번역을 `webapp/src/i18n/ko.json`에 추가하고
      `cd webapp && npm test -- src/i18n` 전체 통과 출력을 `<scratch>/green-webapp.txt`에 저장
- [X] T010 [US1] 용어 일관성 점검: `ko.json`에서 glossary 핵심 용어의 변형(예 "툴"/"도구",
      "써머리"/"요약", "에이전트"/"봇")을 grep으로 찾아 glossary 쪽으로 통일한다. 제품명·
      서비스명이 번역되지 않았는지(`Mattermost`, `MCP`, `OpenAI` 등 grep) 확인한다

**Checkpoint**: webapp 테스트 전체 통과. 한국어 계정으로 화면을 보면 영어가 남지 않는다.

---

## Phase 4: User Story 2 - 서버 안내 메시지도 한국어다 (Priority: P2)

**Goal**: `i18n/ko.json`(12 id) 추가 + 로더 등록.

**Independent Test**: `go test ./i18n/...` 통과 + quickstart D1(한국어 안내)·D2(영어 유지).

### Implementation for User Story 2

- [X] T011 [P] [US2] `i18n/ko.json` 생성: `i18n/en.json`의 12 id 순서대로
      `{id, translation}` 배열. `temp/korean` 초안의 일치하는 7개 문구를 glossary 어조로
      다듬어 쓰고 나머지 5개(`agent_mention_reminder_fallback`,
      `multiplayer_channels_requires_professional`, `search_tools_unavailable`,
      `analysis_source_unavailable` 등)는 새로 쓴다. `%s`/`%d` 개수·순서 유지
- [X] T012 [US2] `i18n/i18n.go`의 `Init()`에 `_, _ = bundle.LoadMessageFileFS(i18nFiles, "i18n/ko.json")`
      추가. `go test ./i18n/... 2>&1 | tee <scratch>/green-go.txt`로 통과 출력 저장.
      T012 전에 T011만 끝낸 상태로 테스트를 한 번 돌려 "ko 로케일에서 영어가 돌아온다"
      실패가 로더 줄 때문임을 확인한다(US3-4 근거)

**Checkpoint**: server 테스트 통과, es 회귀 없음.

---

## Phase 5: User Story 3 - 번역 파일이 깨지면 테스트가 먼저 잡는다 (Priority: P3)

**Goal**: SC-003 — Phase 2의 테스트가 실제 변조를 잡는지 실측한다. 변조는 즉시 되돌린다.

**Independent Test**: quickstart B1~B4 네 건 모두 "해당 키/원인을 이름으로 들어 실패".

### Implementation for User Story 3

- [X] T013 [US3] quickstart B1(키 삭제)·B2(자리표시자 변경)·B3(문법 오류) 변조를 차례로
      `webapp/src/i18n/ko.json`에 가하고 `cd webapp && npm test -- src/i18n`의 실패 메시지에
      해당 키가 나오는지 확인한다. 각 결과를 `<scratch>/mutation-{B1,B2,B3}.txt`에 저장하고
      `git checkout -- webapp/src/i18n/ko.json`이 아니라 변조 전 내용으로 되돌린다
      (ko.json은 새 파일이라 git에 없다 — 변조 전 복사본을 먼저 떠 둔다)
- [X] T014 [US3] quickstart B4: `i18n/i18n.go`의 ko 로드 줄을 주석 처리하고
      `go test ./i18n/...`가 "영어가 돌아왔다"로 실패하는지 확인해
      `<scratch>/mutation-B4.txt`에 저장한 뒤 되돌린다. 되돌린 뒤
      `git status --porcelain -- i18n webapp/src/i18n`이 새 파일 추가분만 보여야 한다

**Checkpoint**: 변조 4종 모두 잡혔다. 잡히지 않은 것이 있으면 Phase 2 테스트를 보강하고
다시 실측한다.

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: 증거를 모으고 문서를 맞춘다

- [ ] T015 [P] (건너뜀 — README·docs에 지원 언어 목록이 없다. 2026-11-09 grep 확인) `docs/user_guide.md` 또는 `README.md`의 지원 언어 언급이 있으면 한국어를
      추가한다(없으면 건너뛰고 사유 기록)
- [X] T016 constitution 원칙 V의 "`ko.json`이 생긴 뒤" 단서는 이 PR 머지 뒤 PATCH로
      정리한다 — 이 과제는 후속 PR 메모만 `specs/001-korean-locale/tasks.md` 하단에 남긴다

### 완료 검증 (고정 — 지우지 않는다)

증거를 남기는 과제다. 셋 다 없으면 게이트를 통과해도 결함이 남는다
(근거: WORKFLOW_PORTING_GUIDE.md 4-3·4-4절).

- [X] T017 품질 게이트 — `go test ./i18n/... ./streaming/... ./conversations/... ./meetings/...`,
      `cd webapp && npm test -- src/i18n`, `make check-i18n`, `make check-style`을 돌리고,
      실패 목록이 T001 기준선과 같은지 **diff로 보인다**. 개수 비교로 대신하지 않는다
- [ ] T018 (`미실행` — 이 세션에는 Docker·Mattermost 서버가 없다. 필요한 것: `make deploy` 대상 서버 + 한국어/영어 계정 2개) 종단 검증 — `make deploy` 후 quickstart C1~C5·D1~D2·E를 **실제 환경에서** 훑고
      절별 통과·실패를 기록한다. 환경이 없어 못 돌리면 `미실행`으로 적는다
- [X] T019 SC 검증 — spec.md의 SC-001~SC-005 각각을 **실측값**으로 확인한다 (추정 금지):
      SC-002는 `jq 'keys|length'`·`jq length`, SC-003은 T013~T014 결과, SC-005는
      `createIntl({locale:'ko'})`로 15개 plural 키를 count 1·2로 포맷한 출력

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 의존 없음
- **Foundational (Phase 2)**: T001 뒤. 두 테스트 과제(T003, T004)는 병렬 가능. **US1~US3 전부를 막는다**
- **US1 (Phase 3)**: T003의 실패 출력이 있어야 시작. T005→T009 순차(같은 파일), T010은 T009 뒤
- **US2 (Phase 4)**: T004의 실패 출력이 있어야 시작. US1과 독립 — 병렬 가능
- **US3 (Phase 5)**: US1·US2 완료 뒤(통과 상태에서 변조해야 "잡힘"을 볼 수 있다)
- **Polish**: 전부 뒤

### User Story Dependencies

- **US1 (P1)**: Phase 2 뒤 독립
- **US2 (P2)**: Phase 2 뒤 독립 (US1과 파일이 겹치지 않는다)
- **US3 (P3)**: US1·US2 모두 완료 뒤

### Parallel Opportunities

- T002 ∥ T001
- T003 ∥ T004 (webapp 테스트 / Go 테스트, 다른 파일)
- Phase 3 전체 ∥ Phase 4 전체 (US1 webapp / US2 server)
- T011은 T012와 순차이지만 US1의 어느 과제와도 병렬

---

## Parallel Example: Phase 2

```bash
# 두 테스트를 동시에 작성한다 (다른 파일):
Task: "webapp/src/i18n/translations.test.ts 확장 — 로케일 표 + ko 검사"
Task: "i18n/i18n_test.go 신설 — 로케일×id 표"
# 각각 실패 출력을 저장한 뒤에만 Phase 3/4로
```

---

## Implementation Strategy

### MVP First (US1만)

1. Phase 1 기준선 → Phase 2 테스트(실패 확인)
2. Phase 3 US1: webapp `ko.json` 1,029키
3. **STOP and VALIDATE**: `npm test -- src/i18n` 통과 + 한국어 계정 화면 확인
4. 여기까지만으로도 사용자가 체감하는 가치의 대부분이 나온다

### Incremental Delivery

1. US1 → webapp 테스트 통과 → 배포 가능
2. US2 → server 테스트 통과 → 오류 안내까지 한국어
3. US3 → 변조 실측으로 테스트의 가치 증명
4. Polish → 증거 표 기록 → PR

---

## Notes

- `webapp/src/i18n/en.json`은 어떤 과제도 건드리지 않는다. `make check-i18n`이 증명한다
- `temp/korean` 브랜치에서는 번역 문구만 참고하고 코드 변경은 가져오지 않는다
- 이 브랜치는 `chore/speckit-superpowers-workflow` 위에 쌓여 있다. PR은 chore PR 머지 뒤
  rebase해서 연다. 병합은 rebase merge만
- 테스트 과제(T003·T004)는 실패 출력 파일이 있어야 `[X]`. 첫 실행부터 통과하면 `미검증`으로
  적고 원인을 찾는다

## 완료 검증 기록 (2026-11-09)

| 항목 | 명령 | 결과 | 증거 |
|---|---|---|---|
| 기준선 (T001) | `go test ./i18n/... ./streaming/... ./conversations/... ./meetings/...` | meetings 4건 실패(Docker provider 없음), streaming·conversations ok, i18n 테스트 없음 | scratch `baseline-go.txt`, `baseline-failures.txt` |
| 기준선 (T001) | `cd webapp && npm test -- src/i18n` / `make check-i18n` | 4 passed / exit 0 | `baseline-webapp.txt`, `baseline-i18n.txt` |
| RED webapp (T003) | `npm test -- src/i18n` (ko.json 없음) | `Cannot find module './ko.json'` | `red-webapp.txt` |
| RED Go (T004) | `go test ./i18n/...` (ko.json 없음) | `catalog ko.json must be embedded` + **es도 영어 반환** (upstream 버그: `"i18n/es.json"` 경로) | `red-go.txt` |
| RED Go 2 (T011→T012 사이) | `go test ./i18n/...` (ko.json 있음, 로더 미등록) | 12 id 전부 `must come from ko.json, not the English default` | `red-go-unregistered.txt` |
| RED Go 3 (폴백) | `go test ./i18n/...` (로더 등록 후) | `panic: message ... not found in language "ko"` — `MustLocalize`가 로드된 로케일의 누락 id에 패닉 | `green-go.txt` 1차 |
| GREEN Go (T012) | `go test ./i18n/...` | ok — 등록 로케일(ko·es), 커버리지 12 id, 폴백 4사례 | `green-go.txt` |
| GREEN webapp (T009) | `npm test -- src/i18n` | 12 passed / 12 | `green-webapp.txt` |
| 품질 게이트 (T017) | 위 Go 명령 재실행, 실패 목록 diff | **기준선과 동일** (meetings Docker 4건, 시간 값만 다름). i18n·streaming·conversations ok | `final-go.txt`, `final-failures.txt` |
| 품질 게이트 (T017) | `make check-i18n` | exit 0, `webapp/src/i18n/en.json` 변경 없음 (`git status` 빈 출력) | `final-i18n.txt` |
| 품질 게이트 (T017) | `make check-style` | exit 0, golangci-lint `0 issues`, ESLint·tsc 통과 (1차에서 테스트 파일 TS2769 2건 → 타입 지정으로 해결 후 재실행) | `final-check-style.txt` |
| 회귀 (quickstart E) | `cd webapp && npm test` 전체 | 128 suites / 2,138 tests passed | `final-webapp-full.txt` |
| 종단 검증 (T018) | `make deploy` + quickstart C1~C5·D1~D2 | **`미실행`** — Docker·Mattermost 서버 없음 | — |
| SC-001 | quickstart C1~C5 | **`미실행`** (T018과 같은 이유) | — |
| SC-002 | `jq 'keys\|length'` / `jq length` | webapp en 1,029 = ko 1,029 / server en 12 = ko 12 | 위 명령 출력 |
| SC-003 | 변조 B1·B2·B3·B4 (T013·T014) | 4/4 잡힘 — B1 `has exactly the keys of en.json`(+3kygeI2), B2 `keeps the placeholders`(+LrF3BGz), B3 `parses as ICU`(+CwN9C/Q), B4 `must come from ko.json`. 되돌린 뒤 `sha256sum -c` OK | `mutation-B1..B4.txt` |
| SC-004 | Go 실패 목록 diff + webapp 전체 스위트 | 회귀 0건 | 위 두 행 |
| SC-005 | `createIntl({locale:'ko'})`로 plural 15키 count 1·2 포맷 + 테스트 `shows the count wherever the English message shows it` | 15/15 — "도구 1개"/"도구 2개" 등 숫자 표시. 영어가 버전 목록을 쓰는 2키(CWe34Njp, ej/vvDq0 =1 분기)는 영어와 같이 목록 표시 | 명령 출력 |

### 구현 중 발견한 upstream 결함 (이 PR에서 함께 수정)

1. `i18n/i18n.go` `Init()`이 `"i18n/es.json"` 경로로 로드했다. `//go:embed *.json`의 FS는
   패키지 디렉터리가 루트라 `"es.json"`이어야 하고, 오류를 `_, _ =`로 버려서 **서버 스페인어
   안내가 한 번도 로드된 적이 없었다**. `"es.json"`으로 고쳤다 (테스트 `TestLocalizerFuncReturnsRegisteredLocale/spanish`).
2. `LocalizerFunc`가 `MustLocalize`를 써서, 로드된 로케일에 없는 id를 만나면 **패닉**했다
   (go-i18n은 영어 폴백과 함께 `MessageNotFoundErr`를 돌려준다). 1번을 고치면 es.json에 없는
   5개 id에서 스페인어 사용자가 바로 이 경로를 탄다. `Localize` + 기본 메시지 폴백으로 고쳤다
   (테스트 `TestLocalizerFuncFallsBackToDefaultMessage`). 두 수정 모두 upstream에 보낼 가치가 있다.

### 후속 메모 (T016)

- constitution 원칙 V의 "`ko.json`이 생긴 뒤" 단서는 이 PR 머지 뒤 PATCH(1.0.1)로 지운다.
- 번역은 1차본이다. 화면 확인(T018) 뒤 어색한 문구는 같은 브랜치 또는 후속 PR로 고친다.
