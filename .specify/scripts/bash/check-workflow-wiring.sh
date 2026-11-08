#!/usr/bin/env bash

# 워크플로 배선 검사
#
# spec-kit + 구현 규율 결합 워크플로가 세 에이전트 surface에 동일하게 걸려 있는지
# 기계로 확인한다. WORKFLOW_PORTING_GUIDE.md 5절의 사람 눈 체크리스트를 대체한다.
#
# Usage: ./check-workflow-wiring.sh [--verbose] [--no-remote]
#
#   --verbose     통과 항목도 전부 출력
#   --no-remote   GitHub 저장소 설정 검사를 건너뛴다 (오프라인·CI)
#
# 종료 코드: 0 = 전부 통과, 1 = 실패 항목 있음

set -uo pipefail

VERBOSE=false
CHECK_REMOTE=true

for arg in "$@"; do
    case "$arg" in
        --verbose) VERBOSE=true ;;
        --no-remote) CHECK_REMOTE=false ;;
        --help|-h)
            sed -n '3,14p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "알 수 없는 옵션: $arg" >&2
            exit 2
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT" || exit 2

# 검사 대상 surface — 새 에이전트를 추가하면 여기에 한 줄 넣는다
SURFACES=(".claude" ".agents" ".cursor")

WIRING_MARKER="okrbest-wiring: v1"

FAIL=0
PASS=0

ok() {
    PASS=$((PASS + 1))
    if [ "$VERBOSE" = true ]; then
        printf '  \033[32mOK\033[0m   %s\n' "$1"
    fi
}

bad() {
    FAIL=$((FAIL + 1))
    printf '  \033[31mFAIL\033[0m %s\n' "$1"
    if [ -n "${2:-}" ]; then
        printf '       → %s\n' "$2"
    fi
}

skip() {
    printf '  \033[33mSKIP\033[0m %s\n' "$1"
}

section() {
    printf '\n\033[1m%s\033[0m\n' "$1"
}

# ---------------------------------------------------------------------------
section "1. speckit-implement 배선 마커"

for s in "${SURFACES[@]}"; do
    f="$s/skills/speckit-implement/SKILL.md"
    if [ ! -f "$f" ]; then
        bad "$f 없음" "surface가 빠졌거나 경로가 바뀌었다"
        continue
    fi
    if grep -qF "$WIRING_MARKER" "$f"; then
        ok "$f 배선됨"
    else
        bad "$f 배선 없음" "WORKFLOW_PORTING_GUIDE.md 4-2절의 네 곳을 넣고 '<!-- $WIRING_MARKER -->' 마커를 남긴다"
    fi
done

# ---------------------------------------------------------------------------
section "2. 규율 문장이 증거를 요구하나"

for s in "${SURFACES[@]}"; do
    f="$s/skills/speckit-implement/SKILL.md"
    [ -f "$f" ] || continue

    # 원본의 빠져나갈 구멍 — 남아 있으면 실패
    if grep -q 'Follow TDD approach.*Execute test tasks before' "$f"; then
        bad "$f: 원본 TDD 문장이 남아 있다" "실패 출력을 요구하는 문장으로 교체한다"
    else
        ok "$f: TDD 문장 교체됨"
    fi

    if grep -q 'Tests before code.*If you need to' "$f"; then
        bad "$f: 'If you need to' 면제 조항이 남아 있다" "tasks.md가 지정한 모든 쌍에 적용한다로 바꾼다"
    else
        ok "$f: 면제 조항 제거됨"
    fi

    # quickstart.md 소비 단계 — 읽기(Read quickstart)만 있고 검증에 안 쓰이면 실패
    if grep -q '종단 검증' "$f"; then
        ok "$f: quickstart.md 소비 단계 있음"
    else
        bad "$f: quickstart.md를 읽기만 하고 쓰지 않는다" "9. Completion validation에 종단 검증을 넣는다"
    fi

    if grep -q '기준선' "$f"; then
        ok "$f: 기준선 측정 지시 있음"
    else
        bad "$f: 기준선 측정 지시 없음" "회귀는 개수가 아니라 실패 목록 diff로 판정한다"
    fi
done

# ---------------------------------------------------------------------------
section "3. surface 간 스킬 목록 동기화"

ref_surface="${SURFACES[0]}"
ref_list="$(ls "$ref_surface/skills" 2>/dev/null | grep '^speckit-' | sort)"

for s in "${SURFACES[@]:1}"; do
    cur_list="$(ls "$s/skills" 2>/dev/null | grep '^speckit-' | sort)"
    if [ "$ref_list" = "$cur_list" ]; then
        ok "$s/skills 목록이 $ref_surface와 같다"
    else
        diff_out="$(diff <(echo "$ref_list") <(echo "$cur_list") | tr '\n' ' ')"
        bad "$s/skills 목록이 $ref_surface와 다르다" "$diff_out"
    fi
done

# ---------------------------------------------------------------------------
section "4. tasks 템플릿에 검증 과제가 고정됐나"

TASKS_TEMPLATE=".specify/templates/tasks-template.md"
if [ -f "$TASKS_TEMPLATE" ]; then
    for needle in "품질 게이트" "종단 검증" "SC 검증"; do
        if grep -q "$needle" "$TASKS_TEMPLATE"; then
            ok "$TASKS_TEMPLATE: '$needle' 과제 있음"
        else
            bad "$TASKS_TEMPLATE: '$needle' 과제 없음" "Phase N Polish에 고정한다"
        fi
    done
else
    bad "$TASKS_TEMPLATE 없음"
fi

# ---------------------------------------------------------------------------
section "5. 에이전트 파일이 '자동 아님'을 알리나"

# 이 저장소의 정본은 AGENTS.md다. CLAUDE.md는 `@AGENTS.md` import 한 줄이어야 한다 (AGENTS.md 자체 규칙).
AGENT_FILES=("AGENTS.md" ".cursor/rules/okrbest-workflow.mdc")
if [ -f CLAUDE.md ] && grep -qx '@AGENTS.md' CLAUDE.md; then
    ok "CLAUDE.md: @AGENTS.md import 한 줄 (정본은 AGENTS.md)"
else
    bad "CLAUDE.md가 @AGENTS.md import가 아니다" "CLAUDE.md에 내용을 복제하지 않는다 — AGENTS.md를 고친다"
fi
for f in "${AGENT_FILES[@]}"; do
    if [ ! -f "$f" ]; then
        bad "$f 없음"
        continue
    fi
    if grep -q '자동 적용되지 않는다' "$f"; then
        ok "$f: 자동 적용 아님을 명시"
    else
        bad "$f: '자동 적용되지 않는다'가 없다" "훅은 using-superpowers만 주입한다는 사실을 적는다"
    fi
done

# ---------------------------------------------------------------------------
section "6. 반대로 작동하는 문장이 남았나"

# 팀원용 가이드가 '규율은 자동'이라고 가르치면 배선이 상쇄된다
BANNED_PATTERNS=('자동으로 지켜지는' '자동 작동' '자동으로 작동' '별도 호출 없이')
for f in "SPEC_KIT_GUIDE.md" "AGENTS.md" ".cursor/rules/okrbest-workflow.mdc" ".specify/memory/constitution.md"; do
    [ -f "$f" ] || continue
    hits=""
    for p in "${BANNED_PATTERNS[@]}"; do
        if grep -q "$p" "$f"; then
            hits="$hits '$p'"
        fi
    done
    if [ -z "$hits" ]; then
        ok "$f: 금지 문장 없음"
    else
        bad "$f: 금지 문장 발견 —$hits" "규율은 자동이 아니다. 문장을 지우거나 고친다"
    fi
done

# ---------------------------------------------------------------------------
section "7. 문체 규칙 정본이 저장소에 있나"

CONSTITUTION=".specify/memory/constitution.md"
if [ -f "$CONSTITUTION" ]; then
    if grep -q '번역투' "$CONSTITUTION"; then
        ok "$CONSTITUTION: 문체 규칙 정본 있음"
    else
        bad "$CONSTITUTION: 문체 규칙이 없다" "개인 홈(~/.claude/CLAUDE.md)에만 두면 다른 도구에서 안 걸린다"
    fi

    for needle in "그 출력을 완료 근거로 제시" "실패 출력을 남긴 뒤에만"; do
        if grep -q "$needle" "$CONSTITUTION"; then
            ok "$CONSTITUTION: 증거 요구 문구 '$needle' 있음"
        else
            bad "$CONSTITUTION: '$needle' 없음" "'하라'로 끝나는 원칙은 사후에 형식만 맞춰도 위반이 아니다"
        fi
    done
else
    bad "$CONSTITUTION 없음"
fi

# ---------------------------------------------------------------------------
section "8. .gitignore 스크래치 경로"

for p in "docs/superpowers/" ".worktrees"; do
    if grep -q "^${p%/}" .gitignore 2>/dev/null; then
        ok ".gitignore: $p 있음"
    else
        bad ".gitignore: $p 없음"
    fi
done

# surface 디렉터리가 통째로 ignore되면 새 스킬이 조용히 커밋에서 빠진다.
# okrbest에서 `.cursor/` 전체가 ignore돼 있어 새로 만든 스킬이 안 잡혔다.
for s in "${SURFACES[@]}"; do
    probe="$s/skills/speckit-implement/SKILL.md"
    [ -f "$probe" ] || continue
    if git check-ignore -q "$probe" 2>/dev/null; then
        bad "$s/skills 가 .gitignore로 무시된다" "새 스킬이 커밋에서 조용히 빠진다. '!$s/skills/' 예외를 넣는다"
    else
        ok "$s/skills 가 커밋 대상이다"
    fi
done

# 명세 정본 specs/<NNN>/ 가 무시되면 spec·plan·tasks가 조용히 커밋에서 빠진다.
# upstream(mattermost-plugin-agents)의 .gitignore가 specs/ 를 통째로 막고 있었다.
if git check-ignore -q "specs/000-probe/spec.md" 2>/dev/null; then
    bad "specs/ 가 .gitignore로 무시된다" "upstream이 넣은 'specs/' 줄을 지운다 — 명세 정본이 커밋에서 빠진다"
else
    ok "specs/ 가 커밋 대상이다"
fi

# ---------------------------------------------------------------------------
section "9. 기본 브랜치 보호 (ruleset + classic 둘 다 본다)"

if [ "$CHECK_REMOTE" = false ]; then
    skip "--no-remote로 건너뜀"
elif ! command -v gh >/dev/null 2>&1; then
    skip "gh 없음"
elif ! gh auth status >/dev/null 2>&1; then
    skip "gh 인증 안 됨"
else
    # `gh repo view`는 upstream remote를 기준 저장소로 잡을 수 있다 (포크에서 흔하다).
    # origin URL에서 직접 뽑아야 우리 저장소를 본다.
    slug="$(git remote get-url origin 2>/dev/null \
        | sed -E 's#^git@[^:]+:##; s#^https?://[^/]+/##; s#\.git$##')"
    if [ -z "$slug" ] || [ "${slug#*/}" = "$slug" ]; then
        skip "origin에서 저장소 식별 실패 (slug='$slug')"
    else
        default_branch="$(gh api "repos/$slug" --jq .default_branch 2>/dev/null)"
        if [ -z "$default_branch" ]; then
            skip "$slug 조회 실패 (권한 또는 네트워크)"
            default_branch=""
        fi
    fi

    if [ -n "${default_branch:-}" ]; then

        # classic branch protection — 없어도 ruleset이 덮으면 통과다
        classic=false
        gh api "repos/$slug/branches/$default_branch/protection" >/dev/null 2>&1 && classic=true

        # ruleset — ~DEFAULT_BRANCH를 포함하고 pull_request 규칙이 active인가
        ruleset=false
        if gh api "repos/$slug/rulesets" --jq '.[].id' 2>/dev/null | while read -r rid; do
                gh api "repos/$slug/rulesets/$rid" --jq \
                    'select(.enforcement=="active")
                     | select(.conditions.ref_name.include[]? | test("DEFAULT_BRANCH|'"$default_branch"'"))
                     | select([.rules[].type] | index("pull_request"))
                     | .name' 2>/dev/null
            done | grep -q .; then
            ruleset=true
        fi

        if [ "$classic" = true ] || [ "$ruleset" = true ]; then
            ok "$default_branch 보호됨 (classic=$classic, ruleset=$ruleset)"
        else
            bad "$default_branch에 보호가 없다" "직접 push가 막히지 않으면 PR 규칙은 문서로만 남는다"
        fi

        # 머지 방식 — rebase만 남아야 Upstream: 참조가 보존된다
        merge_cfg="$(gh api "repos/$slug" --jq '[.allow_squash_merge,.allow_merge_commit,.allow_rebase_merge] | @tsv' 2>/dev/null)"
        squash="$(echo "$merge_cfg" | cut -f1)"
        mergecommit="$(echo "$merge_cfg" | cut -f2)"
        rebase="$(echo "$merge_cfg" | cut -f3)"
        if [ -z "$squash" ]; then
            # 관리 권한이 없으면 API 응답에서 이 필드들이 아예 빠진다
            skip "$slug 머지 설정을 읽을 권한이 없다"
        elif [ "$squash" = "false" ] && [ "$mergecommit" = "false" ] && [ "$rebase" = "true" ]; then
            ok "머지 방식이 rebase 전용"
        else
            bad "머지 방식이 rebase 전용이 아니다 (squash=$squash, merge_commit=$mergecommit, rebase=$rebase)" \
                "gh api -X PATCH repos/$slug -F allow_squash_merge=false -F allow_merge_commit=false -F allow_rebase_merge=true"
        fi
    fi
fi

# ---------------------------------------------------------------------------
printf '\n'
if [ "$FAIL" -eq 0 ]; then
    printf '\033[32m통과 %d건, 실패 0건\033[0m\n' "$PASS"
    exit 0
else
    printf '\033[31m통과 %d건, 실패 %d건\033[0m\n' "$PASS" "$FAIL"
    printf '상세: WORKFLOW_PORTING_GUIDE.md 4절·5절\n'
    exit 1
fi
