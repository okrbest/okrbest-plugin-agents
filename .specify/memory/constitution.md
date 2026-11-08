<!--
Sync Impact Report
- Version change: (template) → 1.0.0 (최초 비준)
- 출처: okrbest(mattermost 포크) constitution 1.4.0의 구조를 따르되, 내용은 이 저장소의
  기존 관례(`AGENTS.md`, `Makefile`, `.github/workflows/ci.yml`, `plugin.json`,
  `scripts/fix_license_headers.sh`)에서 다시 도출했다. 원칙 번호(I~VIII)는 okrbest와
  같게 유지해 `/speckit-sync`·`speckit-implement` 배선의 원칙 참조가 그대로 통하게 했다.
- Added principles: I~VIII 전부 신설
- Templates requiring updates:
  - ✅ AGENTS.md (Workflow·핸드오프·언어 절 — 이번 비준과 함께 반영)
  - ✅ .cursor/rules/okrbest-workflow.mdc (구현 규율 절 — 이번 비준과 함께 반영)
  - ✅ SPEC_KIT_GUIDE.md (constitution 요약 ⑦ — 이번 비준과 함께 반영)
  - ✅ .specify/templates/tasks-template.md (완료 검증 과제 3종 고정)
  - ✅ .claude/.agents/.cursor speckit-implement (3-bis 규율 로드 + 게이트 명령)
- Follow-up TODOs:
  - `ko.json`(webapp·server)이 master에 들어오면 원칙 V의 "ko.json이 생긴 뒤" 단서를 지운다
  - 리브랜드가 master에 들어오면 원칙 IV에 리브랜드 규칙 문서 경로를 적는다
- 배선 검사: bash .specify/scripts/bash/check-workflow-wiring.sh
-->

# OKR.BEST Agents Plugin (okrbest-plugin-agents) Constitution

이 constitution은 `okrbest/okrbest-plugin-agents` 저장소(`mattermost/mattermost-plugin-agents`
포크, Mattermost `mattermost-ai` 플러그인)의 개발 규칙을 규정한다. 기존 관례(`AGENTS.md`,
`Makefile`, `.github/workflows/ci.yml`, `plugin.json`)에서 도출했으며, Spec Kit으로 생산되는
모든 spec 주도 작업에 적용된다. 문서 언어는 한국어, 코드 식별자·명령·경로는 원형 유지.

`AGENTS.md`는 upstream이 관리하는 코드 관례의 정본이고, 이 constitution은 그 위에 **증거를
요구하는 작업 규율**을 얹는다. 둘이 충돌하면 코드 관례는 `AGENTS.md`, 작업 절차는 이 문서가
기준이다.

## Core Principles

### I. 품질 게이트 (NON-NEGOTIABLE)

변경이 닿은 범위의 게이트를 머지 전에 통과해야 한다. 명령은 모두 저장소 루트에서 실행한다
(Go 패키지는 `server/` 아래가 아니라 루트에 있다).

- 기본 게이트: `make check-style`(golangci-lint + ESLint + 저장소 전용 vet) + `make test`
  (Go 단위 테스트 + webapp Jest).
- 머지 전 집계: `make check` — 위에 더해 `check-shards`(e2e spec의 CI shard 배정),
  `check-i18n`(webapp `en.json` 추출 드리프트), `check-locks`(lockfile 드리프트),
  `check-go-mods`(중첩 모듈 tidy). CI `verify-no-drift`·`lint`·`plugin-tests` 잡이 같은
  검사를 집행한다.
- 접촉 패키지만 빠르게 돌릴 때: `go test -v ./<pkg> -run TestName`,
  `cd webapp && npm run lint && npm run check-types && npm test`.
- 처음 받은 체크아웃은 `make apply`로 `server/manifest.go`를 생성해야 컴파일된다.

게이트를 통과하고 **그 출력을 완료 근거로 제시한다**. 출력이 없으면 통과한 것이 아니다.
게이트를 우회하는 커밋·머지 금지.

**회귀는 실패 목록 diff로 판정한다.** 구현을 시작하기 전에 기준선(변경 없는 상태의 실패
목록)을 저장하고, 마감 때 같은 게이트를 돌려 목록을 비교한다. 실패 개수 비교는 기준선이
더러운 저장소에서 무의미하다. 우리 변경과 무관한 기존 결함으로 게이트가 중단되면 그 사실을
기준선 목록으로 보인다 — 서술로 대신하지 않는다.

`make check`가 실패하면 하위 타깃(`check-style`, `test`, `check-shards`, `check-i18n`,
`check-locks`)을 따로 돌려 어느 단계가 깨졌는지 분리한다. i18n·lockfile 드리프트는 타깃이
파일을 제자리에서 재생성하므로 diff를 검토하고 커밋한다.

### II. 저장소 관례의 정본은 AGENTS.md다 (NON-NEGOTIABLE)

코드 관례는 `AGENTS.md`의 "Conventions"·"Correctness and security"·"Audit logging"·
"OpenTelemetry tracing"·"Never do" 절이 정본이다. 이 constitution은 그 내용을 복제하지
않는다 — `/speckit-plan`의 Constitution Check는 아래 항목을 **plan.md에 명시적으로 점검
표시**해야 통과다.

- Mattermost 엔티티(post·user·channel·team·member)를 LLM이나 도구 출력용으로 포맷할 때는
  `format/` 패키지만 쓴다. 인라인 `fmt.Sprintf` 금지.
- webapp은 styled-components만 쓴다. 인라인 `style={{...}}` 금지. 새 사용자 문자열은 i18n을
  거친다.
- Go 테스트는 케이스가 둘 이상이면 표 기반이다. 새 테스트·mock 라이브러리 도입 금지.
  테스트 전용 LLM 도우미는 `llm/llmtest`에 둔다.
- 인가·요청 범위는 프롬프트가 아니라 코드로 강제한다. 조회 실패는 fail closed. 저장소·API
  오류는 전파하고 빈 결과로 바꾸지 않는다. 참조는 이름이 아니라 ID로 저장한다.
- 턴 동작·도구 정책을 바꾸면 모든 진입점(DM, 채널 @mention, 자동 응답, loop-in, regenerate,
  도구 승인/거부, ask-user 응답, 결과 공유, 검색, 스레드·채널 분석, 회의 요약, LLM Bridge)에
  같이 적용한다.
- 상태를 바꾸는 새 라우트는 `api/audit_events.go`에 감사 이벤트를 등록한다. 기록에 내용
  (프롬프트·도구 인자·메시지·자격증명)을 넣지 않는다.
- `ctx context.Context`를 첫 인자로 끝까지 전달한다. production 코드에 `context.Background()`
  지름길 금지.
- `webapp/dist/`·`server/dist/`·`dist/`·`webapp/src/i18n/en.json`은 손으로 고치지 않는다.
- 하위 디렉터리 작업은 해당 `AGENTS.md`(`mcpserver/`, `conversations/`, `bifrost/`, `mcp/`,
  `webapp/`, `e2e/`)를 먼저 읽는다.

`AGENTS.md`는 upstream 선별 반영으로 바뀔 수 있다. 바뀌면 이 절의 요약이 아니라 `AGENTS.md`
원문이 기준이며, 요약이 어긋난 것을 발견하면 PATCH 개정으로 맞춘다.

### III. 실패를 본 테스트만 인정한다

동작을 바꾸는 변경은 테스트를 동반한다. 테스트 과제는 **실패 출력을 남긴 뒤에만** 완료로
표시한다. 첫 실행부터 통과한 테스트는 구현을 되돌려 실패를 확인하거나 해당 과제 옆에
`미검증`으로 적는다. 실패를 못 본 테스트는 아무것도 잡지 못한 테스트다.

- Go: 패키지 옆 colocated `_test.go`, 표 기반. `httptest` 핸들러 등 테스트 고루틴 밖에서는
  `require`·`t.Fatal` 대신 `assert`.
- webapp: Jest(`webapp/jest.config.js`).
- e2e: `e2e/` Playwright + Testcontainers. 새 spec은 같은 변경에서
  `e2e/scripts/ci-test-groups.mjs`에 shard를 배정한다 (`make check-shards`가 검사).
- 평가(evals): 프롬프트·도구 동작을 바꾸면 `make evals-ci`로 영향 범위를 확인한다
  (`./mcpserver`는 Docker 필요).

**버그 수정은 수정 없이는 실패하는 테스트를 포함하고, 그 테스트는 바뀐 도우미만이 아니라
production 배선(라우트·훅·등록)을 통과해야 한다** (`AGENTS.md` 관례). 테스트는 실제 버그가
있을 때 깨지는 동작을 검사한다 — 검증 순서나 어느 오류가 먼저 나오는지 같은 구현 세부에는
단언하지 않는다. 통과를 위해 테스트를 약화·스킵·삭제하는 것을 금지한다. 테스트를
건너뛰려면 사유를 해당 과제 옆에 적는다 — 조용히 넘어가지 않는다.

예외: upstream 선별 반영(`/speckit-sync`)에서 원본 그대로 cherry-pick하는 커밋(`Upstream:`
참조 포함)은 테스트 동반 요건의 예외다. 대신 반영 직후 접촉 패키지 테스트로 회귀를
검증해야 한다. adapt(프로젝트 맞춤 수정) 커밋은 예외가 아니며 본 원칙을 그대로 따른다.

### IV. 라이선스·upstream 충실성 (NON-NEGOTIABLE)

이 저장소는 `mattermost/mattermost-plugin-agents`의 포크이며 Apache-2.0(`LICENSE.txt`)이다.
`enterprise/`는 별도 라이선스(`enterprise/LICENSE`)다.

- `Copyright (c) 2023-present Mattermost, Inc.` 헤더를 유지한다 — 제거·변경 금지.
  `make check-style`의 헤더 검사와 `scripts/fix_license_headers.sh`가 집행한다
  (`enterprise/`는 제외 경로).
- `NOTICE.txt`를 유지한다. 의존성을 바꾸면 upstream 방식대로 갱신한다.
- 플러그인 ID는 `mattermost-ai`로 고정한다(`plugin.json`). 설정 경로
  `/plugins/mattermost-ai/...`와 KV 키가 여기에 묶여 있어 바꾸면 기존 설치가 깨진다.
  리브랜드는 표시 문자열·아이콘 수준에서만 수행한다.
- `public/bridgeclient/`는 다른 플러그인이 import하는 **고정 공개 API**다. 내보낸 식별자의
  시그니처를 바꾸지 않는다.
- 디렉터리 이동·대규모 리네임 등 upstream과의 구조 변경은 최소화하여 선별 반영 충돌을 줄인다.
- `.github/workflows/`·`build/`(FIPS 이미지 핀 포함)는 신중 검토 경로다. 바꾸면 PR 본문에
  그 사실을 적는다.

### V. i18n 동기화

사용자에게 표시되는 문자열은 i18n을 거친다. 한국어는 이 포크의 1급 로케일이다.

- webapp: 문자열은 호출 지점에 `defineMessage`/`FormattedMessage`로 넣고,
  `webapp/src/i18n/en.json`은 **손으로 고치지 않는다** — `make check-style-fix`(또는
  `make i18n-extract`)가 소스에서 재추출하며 CI `check-i18n`이 드리프트를 막는다.
  `webapp/src/i18n/ko.json`이 생긴 뒤에는 `en.json`에 키가 추가·제거되는 변경마다 같은
  변경에서 `ko.json`을 동기화한다.
- server: `i18n/en.json`은 수동 관리({id, translation} 배열)다. 키를 추가·제거하면
  `i18n/ko.json`(생긴 뒤)도 같은 변경에서 맞춘다.

**upstream 선별 반영(sync) 예외**: upstream 커밋에 i18n 파일이 포함되어 충돌이 발생하면 그
커밋을 처리하는 자리에서 해결한다(우리 `ko.json` 문자열 보존). upstream이 `en.json`만 바꿔
`ko.json`에 번역 추가·제거가 필요해진 경우에는 sync 진행을 멈추지 않는다 — 필요 사실을
세션 마감 보고에 "i18n 후속 필요"로 적고 실제 반영은 별도 작업으로 넘긴다. 이 예외는 sync에만
적용되며, 포크 자체 기능 개발에는 위 원문이 그대로 적용된다.

### VI. 집중 브랜치 + PR (rebase 전용)

`master` 직접 커밋·push 금지. 작업당 브랜치 1개, PR 경유 머지. 병합은 커밋별 제목·본문이
보존되는 **rebase merge로 한정한다** — squash·merge commit 금지. 저장소 병합 설정이 rebase만
허용하도록 집행하며, 설정이 어긋나면 이 조항이 기준이다.

**브랜치는 구현 시작 전에 만든다.** 기준은 커밋 시점이 아니라 첫 파일 편집 시점이다. 버그
수정처럼 spec 파이프라인을 타지 않는 작업도 같다 — `master` 체크아웃 위에서 편집하다 커밋
직전에 브랜치를 만드는 패턴은 이 원칙 위반이다. 준수 여부는 reflog로 확인할 수 있다: 구현이
진행된 구간의 HEAD는 작업 브랜치여야 한다.

마감은 넷이다.

1. 품질 게이트 + 종단 검증 증거 제시 (원칙 I·III)
2. `git push -u origin <브랜치>` → `gh pr create --base master` (PR 본문은
   `.github/PULL_REQUEST_TEMPLATE.md` 형식, `release-note` 블록 포함)
3. 사용자 병합 승인 후 `gh pr merge --rebase --delete-branch`
4. `git switch master && git pull --ff-only`

커밋 메시지는 `AGENTS.md` "Pull requests and commits"를 따른다 — 한 줄 제목, 선택적
Jira 접두사(`MM-12345:`) 또는 짧은 범위(`fix:`, `docs:`, `webapp:`), 본문은 한국어 허용.
**에이전트를 `Co-Authored-By`로 적지 않는다.** PR은 집중적·최소 범위로 유지하고 무관한
리팩터·설정 변경을 섞지 않는다. 새 의존성은 근거를 PR 본문에 남긴다.

예외: upstream 선별 반영 커밋(`Upstream:` 참조 포함)은 추적성 보존을 위해 원본 커밋 제목을
유지하며, sync PR은 여러 upstream 커밋을 묶을 수 있다. rebase merge 한정은 sync PR에서 특히
중요하다 — squash하면 커밋별 `Upstream:` 참조가 소실되어 반영 추적이 끊긴다.

### VII. Spec 주도 개발 워크플로

기능 작업은 Spec Kit 파이프라인을 따른다:
`constitution → specify → (clarify) → plan → tasks → (analyze) → implement`.
명세 정본은 `specs/<NNN-feature>/`에 커밋한다. upstream `.gitignore`는 `specs/`를 무시하지만
이 포크는 추적한다 — `bash .specify/scripts/bash/check-workflow-wiring.sh`가 확인한다.

**구현 규율은 자동으로 걸리지 않는다 — 이 문단이 그 사실의 정본이다.** superpowers
SessionStart 훅은 `using-superpowers` 하나만 주입한다. 개별 규율은 `speckit-implement`의
"구현 규율 로드"(3-bis) 단계에서 호출해야 지침이 로드된다.

| 규율 | 어디서 걸리나 | 남길 증거 |
|---|---|---|
| 실패 테스트 우선 (`test-driven-development`) | 3-bis에서 `Skill` 호출 | 구현 전 실패 출력 |
| 증거 기반 완료 선언 (`verification-before-completion`) | 3-bis에서 `Skill` 호출 | 게이트 출력 + 기준선 diff |
| 근본 원인 우선 디버깅 (`systematic-debugging`) | 예상 밖 실패를 만난 자리 | 원인 규명 기록 |

Cursor에는 superpowers 플러그인이 없다(Claude Code·Codex 전용). Cursor로 작업할 때는
`.cursor/rules/okrbest-workflow.mdc`의 구현 규율 절이 같은 요구를 담는다. 어느 도구를 쓰든
남겨야 하는 증거는 같다.

종단 검증은 게이트와 별개 단계다. 이 플러그인의 결함은 실제 Mattermost에 `make deploy`로
올린 뒤 DM·채널 @mention·도구 승인 같은 진입점을 직접 조작해야 드러나는 것이 많다.
`quickstart.md`를 실제 환경에서 훑고 절별 통과·실패를 적는다. 환경이 없으면 `미실행`으로
적는다 — 통과로 적지 않는다.

superpowers는 원칙 I·III을 운영화하고, spec-kit은 spec/plan 산출물을 소유한다.

예외: upstream 선별 반영(`/speckit-sync`)의 cherry-pick/adapt 커밋은 커밋별 의도 분석·대화형
승인을 거치므로 spec 파이프라인 요건의 예외다. 대규모·큰 영향 upstream 커밋은 spec 분기로
본 파이프라인에 합류한다.

### VIII. 명세 문서 언어와 문체

`specs/<NNN-feature>/`의 spec-kit 산출물(`spec.md`, `plan.md`, `tasks.md`, `checklists/`,
분석 노트)은 **한국어로 쓴다**. 코드 식별자, 파일 경로(`conversations/`, `webapp/src/` 등),
셸 명령(`make check`, `go test ./...` 등), FR/SC 식별자, BDD 키워드(Given/When/Then)는 원형을
유지한다. 템플릿이 영어로 산출되더라도 작성·갱신할 때 한국어로 옮긴다. `AGENTS.md`와
하위 `AGENTS.md`는 upstream이 영어로 관리하는 파일이므로 번역하지 않는다 — 이 포크가 덧붙이는
절만 한국어다.

언어만 정하면 절반이다. 문체를 안 정하면 한국어이긴 하되 번역투인 문서가 나온다.
**문체 규칙의 정본은 여기 한 곳이다.** 에이전트 파일(`AGENTS.md`, `.cursor/rules/*.mdc`)에는
압축본과 이 원칙 참조만 싣는다 — 전문을 복사하면 갈라진다.

- **번역투 금지**
  - "~하는 것을 확실히 하세요" → "~한다"
  - "~에 직면하다" → "~가 생긴다"
  - "~를 가지고 있다" → "~가 있다"
  - "~되어질 수 있다" 같은 이중 피동 → 능동으로
  - 불필요한 "~적인", "~에 있어서", "~를 통해", "~와 관련하여"
- **명사화 금지** — 동사로 쓸 수 있으면 동사로 쓴다.
  "증거 요구 없음" → "증거를 요구하지 않는다"
- **영어 은유 직역 금지** — bridge·lever·hub·surface·axis 계열은 한국어에서 굳지 않아
  물리적 뜻으로 먼저 읽힌다. 동사로 푼다. "다리를 놓는다" → "잇는다"
- **소제목에 관형절("~하는 X") 금지** — 서술문이나 의문형으로 쓴다. 수식어가 앞에 붙는
  한국어에서는 핵심어가 맨 뒤로 밀려 훑기 어렵다
- 짧은 문장, 능동태, 단정적 서술. 주어 남발 금지("그것은", "이것은"은 대부분 뺀다)

## 기술·범위 제약

- Go 1.26 루트 모듈 + 중첩 모듈 셋(`loadtest/controller/`, `cmd/evalviewer/`,
  `build/releasenotes/`). Go 버전·`go mod tidy`·`go fix`는 네 모듈에 모두 적용하고, 버전을
  올릴 때는 `build/fips.mk`의 `FIPS_IMAGE` 태그 절차(`AGENTS.md` Gotchas)를 따른다.
- webapp은 React/TypeScript, Node는 `.nvmrc`(24.11) 기준, npm 전용 — `webapp/package-lock.json`·
  `e2e/package-lock.json`을 같은 변경에서 커밋한다 (`make check-locks`).
- 스위핑 Go 명령은 `$(go list ./... | grep -v node_modules)`를 쓴다 — `webapp/node_modules/`에
  Go 파일이 섞여 있다.
- `postgres/pgvector_test.go`·`mcpserver` 평가는 Docker가 필요하다. 없으면 `미실행`으로 적는다.
- 플러그인 설정은 활성화 시 플러그인 DB로 이전된다. 자동화는 Mattermost 서버 config가 아니라
  `GET`/`PUT /plugins/mattermost-ai/admin/config`를 쓴다.
- 비밀값·자격증명(LLM API 키, `.pat`, `.env`)은 커밋 금지. `.specify/`·`specs/`에도 금지 —
  평가 로그·대화 샘플을 명세에 붙일 때 키·토큰이 섞이지 않았는지 확인한다.
- 이 저장소는 `mattermost/mattermost-plugin-agents`의 포크이며 원격은
  `okrbest/okrbest-plugin-agents`(GitHub)다. 로컬 브랜치 `upstream-master`가 `upstream/master`를
  추적하고, 미반영 목록은 `docs/upstream-master-unmerged-commits.md`다.

## 개발 워크플로

작은 수정은 브랜치 + PR로 직행. 기능·API·도구 정책 변경은 spec-kit 파이프라인으로 명세를
먼저 만든다. 복잡한 기능은 superpowers `brainstorming`으로 의도를 정리한 뒤
`/speckit-specify`로 넘긴다(핸드오프 규칙은 `AGENTS.md` 참조). 기본 머지 대상은 `master`이며
리뷰된 PR + CI 통과가 조건이다.

## Governance

이 constitution은 다른 관례·문서보다 우선한다(코드 관례는 원칙 II에 따라 `AGENTS.md`에
위임). 개정은 PR로 제안하고 버전을 시맨틱 버저닝으로 올린다(MAJOR: 원칙 제거·재정의, MINOR:
원칙 추가·실질 확장, PATCH: 문구 명확화). 모든 PR·리뷰는 원칙 준수를 확인해야 하며, 원칙
위반이 필요한 경우 그 근거를 plan의 Complexity Tracking에 문서화한다.
`/speckit-plan`·`/speckit-analyze`가 Constitution Check 게이트로 자동 참조한다.

**원칙은 증거를 요구하는 형태로 쓴다.** "하라"로 끝나는 원칙은 사후에 형식만 맞춰도 위반이
아니게 되어 지켜지지 않는다. 원칙을 쓰거나 고칠 때 스스로 묻는다 — 이 원칙을 어겼는지
무엇으로 확인하나? 답이 없으면 그 원칙은 장식이다.

**Version**: 1.0.0 | **Ratified**: 2026-11-09 | **Last Amended**: 2026-11-09
