---
name: "speckit-implement"
description: "Execute the implementation plan by processing and executing all tasks defined in tasks.md"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "github-spec-kit"
  source: "templates/commands/implement.md"
---

<!-- okrbest-wiring: v1
     spec-kit 원본에 okrbest 구현 규율 배선을 넣은 파일이다. 원본에는 구현 규율을
     거는 단계가 없어 파이프라인은 돌지만 규율이 안 걸린다(근거: WORKFLOW_PORTING_GUIDE.md 4절).
     세 surface(.claude/.agents/.cursor)의 본문이 같아야 한다 — 3-bis의 규율 로드
     문단만 surface별로 갈라진다.
     검사: bash .specify/scripts/bash/check-workflow-wiring.sh -->

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution Checks

**Check for extension hooks (before implementation)**:
- Check if `.specify/extensions.yml` exists in the project root.
- If it exists, read it and look for entries under the `hooks.before_implement` key
- If the YAML cannot be parsed or is invalid, skip hook checking silently and continue normally
- Filter out hooks where `enabled` is explicitly `false`. Treat hooks without an `enabled` field as enabled by default.
- For each remaining hook, do **not** attempt to interpret or evaluate hook `condition` expressions:
  - If the hook has no `condition` field, or it is null/empty, treat the hook as executable
  - If the hook defines a non-empty `condition`, skip the hook and leave condition evaluation to the HookExecutor implementation
- When constructing slash commands from hook command names, replace dots (`.`) with hyphens (`-`). For example, `speckit.git.commit` → `/speckit-git-commit`.
- For each executable hook, output the following based on its `optional` flag:
  - **Optional hook** (`optional: true`):
    ```
    ## Extension Hooks

    **Optional Pre-Hook**: {extension}
    Command: `/{command}`
    Description: {description}

    Prompt: {prompt}
    To execute: `/{command}`
    ```
  - **Mandatory hook** (`optional: false`):
    ```
    ## Extension Hooks

    **Automatic Pre-Hook**: {extension}
    Executing: `/{command}`
    EXECUTE_COMMAND: {command}
    
    Wait for the result of the hook command before proceeding to the Outline.
    ```
- If no hooks are registered or `.specify/extensions.yml` does not exist, skip silently

## Outline

1. Run `.specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks` from repo root and parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

2. **Check checklists status** (if FEATURE_DIR/checklists/ exists):
   - Scan all checklist files in the checklists/ directory
   - For each checklist, count:
     - Total items: All lines matching `- [ ]` or `- [X]` or `- [x]`
     - Completed items: Lines matching `- [X]` or `- [x]`
     - Incomplete items: Lines matching `- [ ]`
   - Create a status table:

     ```text
     | Checklist | Total | Completed | Incomplete | Status |
     |-----------|-------|-----------|------------|--------|
     | ux.md     | 12    | 12        | 0          | ✓ PASS |
     | test.md   | 8     | 5         | 3          | ✗ FAIL |
     | security.md | 6   | 6         | 0          | ✓ PASS |
     ```

   - Calculate overall status:
     - **PASS**: All checklists have 0 incomplete items
     - **FAIL**: One or more checklists have incomplete items

   - **If any checklist is incomplete**:
     - Display the table with incomplete item counts
     - **STOP** and ask: "Some checklists are incomplete. Do you want to proceed with implementation anyway? (yes/no)"
     - Wait for user response before continuing
     - If user says "no" or "wait" or "stop", halt execution
     - If user says "yes" or "proceed" or "continue", proceed to step 3

   - **If all checklists are complete**:
     - Display the table showing all checklists passed
     - Automatically proceed to step 3

3. Load and analyze the implementation context:
   - **REQUIRED**: Read tasks.md for the complete task list and execution plan
   - **REQUIRED**: Read plan.md for tech stack, architecture, and file structure
   - **IF EXISTS**: Read data-model.md for entities and relationships
   - **IF EXISTS**: Read contracts/ for API specifications and test requirements
   - **IF EXISTS**: Read research.md for technical decisions and constraints
   - **IF EXISTS**: Read .specify/memory/constitution.md for governance constraints
   - **IF EXISTS**: Read quickstart.md for integration scenarios

3-bis. **구현 규율 로드** (필수 — 다음 단계로 넘어가기 전에 수행한다):

   `Skill` 도구로 아래 둘을 호출한다. **자동 적용되지 않는다** — SessionStart 훅은
   `using-superpowers` 하나만 주입하며, 개별 스킬은 호출해야 지침이 로드된다.

   - `superpowers:test-driven-development`
   - `superpowers:verification-before-completion`

   예상 밖 실패를 만나면 그 자리에서 `superpowers:systematic-debugging`을 부른다.
   땜질 수정을 먼저 시도하지 않는다.

   방금 읽은 문서를 규율로 바꾼다. 각 행의 증거가 없으면 그 과제는 완료가 아니다.

   | 문서 | 뽑는 것 | 남길 증거 |
   |---|---|---|
   | tasks.md 테스트 과제 | TDD 대상 | 구현 전 실패 출력 |
   | tasks.md 구현 과제 | 위 실패가 통과로 바뀔 대상 | 같은 테스트의 통과 출력 |
   | plan.md Constitution Check | 단계별 게이트 | 게이트 출력 + 기준선 diff |
   | spec.md SC-### | 종단 판정 기준 | 실측값 (추정 금지) |
   | quickstart.md | 종단 검증 절차 | 절별 통과·실패 기록 |
   | contracts/ | 계약 테스트 대상 | 응답·문턱마다 대응하는 테스트 |

   **기준선을 먼저 측정한다.** 구현을 시작하기 전에, 작업 트리가 깨끗한 상태에서
   접촉 패키지 게이트를 돌려 실패 목록을 파일로 저장한다. 회귀는 실패 개수가 아니라
   목록 diff로 판정한다. 기준선이 더러운 저장소에서 개수 비교는 무의미하다.

   ```bash
   git status --porcelain          # 비어 있어야 한다
   # 진행 중 변경이 있으면 치웠다가 반드시 되돌린다
   git stash push -u -m baseline && <게이트 명령> > /tmp/baseline.txt; git stash pop
   ```

   okrbest-plugin-agents 게이트 (constitution 원칙 I — 저장소 루트에서 실행):

   - 공통: `make check-style && make test` (golangci-lint·ESLint·Go 단위 테스트·webapp Jest를 함께 돈다)
   - 접촉 패키지만 빠르게: `go test ./<pkg>/...`, `cd webapp && npm run lint && npm run check-types && npm test`
   - 머지 전 집계: `make check` (위에 더해 e2e shard 배정·i18n 추출·lockfile·중첩 모듈 드리프트)
   - 처음 받은 체크아웃은 `make apply`로 `server/manifest.go`를 먼저 생성해야 컴파일된다

   게이트가 우리 변경과 무관한 기존 결함으로 중단되면, 그 사실을 기준선 목록으로
   보인다. 서술로 대신하지 않는다.

4. **Project Setup Verification**:
   - **REQUIRED**: Create/verify ignore files based on actual project setup:

   **Detection & Creation Logic**:
   - Check if the following command succeeds to determine if the repository is a git repo (create/verify .gitignore if so):

     ```sh
     git rev-parse --git-dir 2>/dev/null
     ```

   - Check if Dockerfile* exists or Docker in plan.md → create/verify .dockerignore
   - Check if .eslintrc* exists → create/verify .eslintignore
   - Check if eslint.config.* exists → ensure the config's `ignores` entries cover required patterns
   - Check if .prettierrc* exists → create/verify .prettierignore
   - Check if .npmrc or package.json exists → create/verify .npmignore (if publishing)
   - Check if terraform files (*.tf) exist → create/verify .terraformignore
   - Check if .helmignore needed (helm charts present) → create/verify .helmignore

   **If ignore file already exists**: Verify it contains essential patterns, append missing critical patterns only
   **If ignore file missing**: Create with full pattern set for detected technology

   **Common Patterns by Technology** (from plan.md tech stack):
   - **Node.js/JavaScript/TypeScript**: `node_modules/`, `dist/`, `build/`, `*.log`, `.env*`
   - **Python**: `__pycache__/`, `*.pyc`, `.venv/`, `venv/`, `dist/`, `*.egg-info/`
   - **Java**: `target/`, `*.class`, `*.jar`, `.gradle/`, `build/`
   - **C#/.NET**: `bin/`, `obj/`, `*.user`, `*.suo`, `packages/`
   - **Go**: `*.exe`, `*.test`, `vendor/`, `*.out`
   - **Ruby**: `.bundle/`, `log/`, `tmp/`, `*.gem`, `vendor/bundle/`
   - **PHP**: `vendor/`, `*.log`, `*.cache`, `*.env`
   - **Rust**: `target/`, `debug/`, `release/`, `*.rs.bk`, `*.rlib`, `*.prof*`, `.idea/`, `*.log`, `.env*`
   - **Kotlin**: `build/`, `out/`, `.gradle/`, `.idea/`, `*.class`, `*.jar`, `*.iml`, `*.log`, `.env*`
   - **C++**: `build/`, `bin/`, `obj/`, `out/`, `*.o`, `*.so`, `*.a`, `*.exe`, `*.dll`, `.idea/`, `*.log`, `.env*`
   - **C**: `build/`, `bin/`, `obj/`, `out/`, `*.o`, `*.a`, `*.so`, `*.exe`, `*.dll`, `autom4te.cache/`, `config.status`, `config.log`, `.idea/`, `*.log`, `.env*`
   - **Swift**: `.build/`, `DerivedData/`, `*.swiftpm/`, `Packages/`
   - **R**: `.Rproj.user/`, `.Rhistory`, `.RData`, `.Ruserdata`, `*.Rproj`, `packrat/`, `renv/`
   - **Universal**: `.DS_Store`, `Thumbs.db`, `*.tmp`, `*.swp`, `.vscode/`, `.idea/`

   **Tool-Specific Patterns**:
   - **Docker**: `node_modules/`, `.git/`, `Dockerfile*`, `.dockerignore`, `*.log*`, `.env*`, `coverage/`
   - **ESLint**: `node_modules/`, `dist/`, `build/`, `coverage/`, `*.min.js`
   - **Prettier**: `node_modules/`, `dist/`, `build/`, `coverage/`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`
   - **Terraform**: `.terraform/`, `*.tfstate*`, `*.tfvars`, `.terraform.lock.hcl`
   - **Kubernetes/k8s**: `*.secret.yaml`, `secrets/`, `.kube/`, `kubeconfig*`, `*.key`, `*.crt`

5. Parse tasks.md structure and extract:
   - **Task phases**: Setup, Tests, Core, Integration, Polish
   - **Task dependencies**: Sequential vs parallel execution rules
   - **Task details**: ID, description, file paths, parallel markers [P]
   - **Execution flow**: Order and dependency requirements

6. Execute implementation following the task plan:
   - **Phase-by-phase execution**: Complete each phase before moving to the next
   - **Respect dependencies**: Run sequential tasks in order, parallel tasks [P] can run together  
   - **TDD (증거 기반)**: 테스트 과제는 **실패 출력을 남긴 뒤에만** `[X]`로 표시한다.
     첫 실행에서 통과한 테스트는 구현을 되돌려 실패를 확인하거나 해당 과제 옆에
     `미검증`으로 적는다. 실패를 못 본 테스트는 아무것도 잡지 못한 테스트다
   - **File-based coordination**: Tasks affecting the same files must run sequentially
   - **Validation checkpoints**: Verify each phase completion before proceeding

7. Implementation execution rules:
   - **Setup first**: Initialize project structure, dependencies, configuration
   - **Tests before code**: tasks.md가 테스트 과제를 지정한 **모든 쌍**에 적용한다.
     건너뛰려면 사유를 해당 과제 옆에 적는다 (조용히 넘어가지 않는다)
   - **Core development**: Implement models, services, CLI commands, endpoints
   - **Integration work**: Database connections, middleware, logging, external services
   - **Polish and validation**: Unit tests, performance optimization, documentation

8. Progress tracking and error handling:
   - Report progress after each completed task
   - Halt execution if any non-parallel task fails
   - For parallel tasks [P], continue with successful tasks, report failed ones
   - Provide clear error messages with context for debugging
   - Suggest next steps if implementation cannot proceed
   - **IMPORTANT** For completed tasks, make sure to mark the task off as [X] in the tasks file.

9. Completion validation — **증거 없이 완료를 선언하지 않는다**:

   - **품질 게이트** — 접촉 패키지 게이트를 돌리고, 실패 목록이 3-bis에서 저장한
     기준선과 같은지 **diff로 보인다**. 새 실패가 하나라도 있으면 완료가 아니다
   - **종단 검증** — 빌드·배포한 뒤 `quickstart.md`의 시나리오를 **실제 환경에서**
     훑는다. 절별로 통과·실패를 적는다. 환경이 없어 못 돌리면 `미실행`으로 적고
     무엇이 필요한지 남긴다 — 통과로 적지 않는다
   - **SC 검증** — `spec.md`의 SC-### 각각을 **실측값**으로 확인한다. 추정·유추 금지
   - **결과 기록** — 위 셋을 `tasks.md` 하단에 표로 남긴다 (항목 · 명령 · 결과 · 증거)
   - Verify all required tasks are completed
   - Check that implemented features match the original specification
   - Confirm the implementation follows the technical plan

   단위 테스트가 통과해도 화면을 조작해야만 드러나는 결함은 남는다. 종단 검증은
   게이트와 별개 단계다 — 게이트를 통과했다는 이유로 건너뛰지 않는다.

10. 세션 마감 (constitution 원칙 VI):

   위 증거를 사용자에게 제시한 뒤 진행한다. `master` 직접 커밋 금지.

   ```bash
   git push -u origin "$(git branch --show-current)"
   gh pr create --base master --fill
   # 사용자 확인 후
   gh pr merge --rebase --delete-branch
   git switch master && git pull --ff-only
   ```

   squash·merge commit은 저장소 설정으로 막혀 있다 (`Upstream:` 참조 보존). 커밋 제목·PR 본문
   형식은 AGENTS.md "Pull requests and commits" 절을 따른다 — 에이전트 `Co-Authored-By` 금지.
   rebase 병합 뒤 로컬 브랜치는 SHA가 바뀌어 `git branch -d`가 거부한다 — `-D`를 쓴다.

Note: This command assumes a complete task breakdown exists in tasks.md. If tasks are incomplete or missing, suggest running `/speckit-tasks` first to regenerate the task list.

## Mandatory Post-Execution Hooks

**You MUST complete this section before reporting completion to the user.**

Check if `.specify/extensions.yml` exists in the project root.
- If it does not exist, or no hooks are registered under `hooks.after_implement`, skip to the Completion Report.
- If it exists, read it and look for entries under the `hooks.after_implement` key.
- If the YAML cannot be parsed or is invalid, skip hook checking silently and continue to the Completion Report.
- Filter out hooks where `enabled` is explicitly `false`. Treat hooks without an `enabled` field as enabled by default.
- For each remaining hook, do **not** attempt to interpret or evaluate hook `condition` expressions:
  - If the hook has no `condition` field, or it is null/empty, treat the hook as executable
  - If the hook defines a non-empty `condition`, skip the hook and leave condition evaluation to the HookExecutor implementation
- When constructing slash commands from hook command names, replace dots (`.`) with hyphens (`-`). For example, `speckit.git.commit` → `/speckit-git-commit`.
- For each executable hook, output the following based on its `optional` flag:
  - **Mandatory hook** (`optional: false`) — **You MUST emit `EXECUTE_COMMAND:` for each mandatory hook**:
    ```
    ## Extension Hooks

    **Automatic Hook**: {extension}
    Executing: `/{command}`
    EXECUTE_COMMAND: {command}
    ```
  - **Optional hook** (`optional: true`):
    ```
    ## Extension Hooks

    **Optional Hook**: {extension}
    Command: `/{command}`
    Description: {description}

    Prompt: {prompt}
    To execute: `/{command}`
    ```

## Completion Report

Report final status with summary of completed work.

## Done When

- [ ] All tasks in tasks.md completed and marked `[X]`
- [ ] 3-bis의 구현 규율을 호출했고, 테스트 과제마다 구현 전 실패 출력이 남았다
- [ ] 품질 게이트 실패 목록이 기준선과 같다 (diff로 제시)
- [ ] quickstart.md 종단 검증을 실제 환경에서 돌렸다 (못 돌렸으면 `미실행`으로 기록)
- [ ] spec.md의 SC-###를 실측값으로 확인했다
- [ ] 위 결과를 tasks.md 하단에 표로 기록했다
- [ ] Extension hooks dispatched or skipped according to the rules in Mandatory Post-Execution Hooks above
- [ ] Completion reported to user with summary of completed work
