#!/usr/bin/env bash
# upstream-sync.sh — okrbest-plugin-agents upstream 선별 반영 도구 (기계적 신호 수집 전용)
#
# 판단(cherry-pick/adapt/exclude/spec)은 /speckit-sync 스킬의 LLM 워크플로가 수행한다.
# 이 스크립트는 목록 갱신과 판단 재료(신호) 수집만 담당한다.
#
# 사용법:
#   upstream-sync.sh update            미반영 목록 재생성 (fetch + 차감 규칙 적용)
#   upstream-sync.sh status            남은 개수·마지막 반영 커밋·부록 집계
#   upstream-sync.sh next [n]          오래된 순 앞 n개 (기본 1) full hash + 제목
#   upstream-sync.sh signals <hash>    LLM 판단 재료 출력
#   upstream-sync.sh exclude <hash> <사유>     제외 부록에 기록 후 update
#   upstream-sync.sh to-spec <hash> <specID>   spec 부록에 기록 후 update
#   upstream-sync.sh private-module <hash> <설명>   비공개 사설 모듈 의존 부록에 기록 후 update
#     (upstream 구현이 비공개 모듈에 있어 인터페이스·스캐폴딩만 반영되고
#      실제 기능은 이 포크가 별도 개발해야 하는 경우.
#      cherry-pick/adapt로 이미 반영한 커밋도, exclude한 커밋도 기록 가능 — 후속 개발 대상 추적용.)

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
LEDGER="$REPO_ROOT/docs/upstream-master-unmerged-commits.md"
UPSTREAM_BRANCH="upstream-master"
UPSTREAM_REMOTE_REF="upstream/master"
UPSTREAM_URL="https://github.com/mattermost/mattermost-plugin-agents"
BASE_BRANCH="${SYNC_BASE_BRANCH:-master}"   # 테스트 시 오버라이드 가능

cd "$REPO_ROOT"

# ---------- 공통 ----------

# master..upstream-master 중 "처리 완료"로 간주해 차감할 full hash 목록
processed_hashes() {
    {
        # 1) picked/adapted: 포크 자체 커밋($UPSTREAM_BRANCH..$BASE_BRANCH) 본문의 cherry-pick/Upstream 참조
        #    (upstream 커밋 자체의 릴리스 브랜치 cherry-pick 문구 오검출 방지)
        git log "$UPSTREAM_BRANCH..$BASE_BRANCH" --grep='cherry picked from commit' --grep='Upstream: ' \
            --pretty=format:'%B' 2>/dev/null |
            grep -oE '(cherry picked from commit |Upstream: '"$UPSTREAM_URL"'/commit/)[0-9a-f]{40}' |
            grep -oE '[0-9a-f]{40}$' || true
        # 2) excluded / spec / private-module: ledger 부록 섹션의 링크 URL 속 full hash
        if [[ -f "$LEDGER" ]]; then
            awk '/^## (제외된 커밋|spec 전환 커밋|Mattermost 비공개 사설 모듈 커밋)/,0' "$LEDGER" |
                grep -oE "$UPSTREAM_URL/commit/[0-9a-f]{40}" |
                grep -oE '[0-9a-f]{40}' || true
        fi
    } | sort -u
}

# 부록 섹션 보존 추출 (없으면 기본 골격)
appendix_section() {
    local title="$1"  # "제외된 커밋" | "spec 전환 커밋"
    local extra_col="$2"  # "사유" | "spec"
    if [[ -f "$LEDGER" ]] && grep -q "^## $title" "$LEDGER"; then
        awk -v t="^## $title" '$0 ~ t {f=1} f && /^## / && $0 !~ t {exit} f {print}' "$LEDGER"
    else
        printf '## %s\n\n| 커밋 해시 | 커밋 제목 | %s |\n|---|---|---|\n' "$title" "$extra_col"
    fi
}

md_escape_row() {
    # stdin: full\x1fsubject\x1fdate → markdown 표 행
    while IFS=$'\x1f' read -r full subj date; do
        subj="${subj//\\/\\\\}"
        subj="${subj//|/\\|}"
        subj="${subj//[/\\[}"
        subj="${subj//]/\\]}"
        printf '| %s | [%s](%s/commit/%s) | %s |\n' "${full:0:8}" "$subj" "$UPSTREAM_URL" "$full" "$date"
    done
}

# ---------- update ----------

cmd_update() {
    git fetch upstream --quiet || echo "WARN: git fetch upstream 실패 — 로컬 상태로 진행" >&2
    # 로컬 추적 브랜치 fast-forward (체크아웃 없이)
    if git rev-parse --verify -q "$UPSTREAM_REMOTE_REF" >/dev/null; then
        git update-ref "refs/heads/$UPSTREAM_BRANCH" "$(git rev-parse "$UPSTREAM_REMOTE_REF")"
    fi

    local processed pending_rows last_synced_line total
    processed="$(processed_hashes)"

    # 오래된 순 미반영 목록 (처리 완료 차감)
    pending_rows="$(
        git log "$BASE_BRANCH..$UPSTREAM_BRANCH" --reverse --date=format:%Y-%m-%d \
            --pretty=tformat:'%H%x1f%s%x1f%ad' |
        while IFS=$'\x1f' read -r full subj date; do
            grep -qx "$full" <<<"$processed" && continue
            printf '%s\x1f%s\x1f%s\n' "$full" "$subj" "$date"
        done | md_escape_row
    )"
    total="$(grep -c '^|' <<<"$pending_rows" || true)"
    [[ -z "$pending_rows" ]] && total=0

    # 마지막 반영 커밋 = 분기점 이후 처리된 것 중 가장 최근(오래된 순 진행 가정), 없으면 merge-base
    local last_hash
    last_hash="$(
        git log "$BASE_BRANCH..$UPSTREAM_BRANCH" --reverse --pretty=tformat:'%H' |
        while read -r full; do
            if grep -qx "$full" <<<"$processed"; then echo "$full"; fi
        done | tail -1
    )"
    [[ -z "$last_hash" ]] && last_hash="$(git merge-base "$BASE_BRANCH" "$UPSTREAM_BRANCH")"
    last_synced_line="$(git log -1 --date=format:%Y-%m-%d --pretty=tformat:'%H%x1f%s%x1f%ad' "$last_hash" | md_escape_row |
        sed 's/^| /**마지막 반영 커밋:** `/; s/ | \[/` | [/; s/ |$//')"

    local excluded_sec spec_sec private_module_sec
    excluded_sec="$(appendix_section "제외된 커밋" "사유")"
    spec_sec="$(appendix_section "spec 전환 커밋" "spec")"
    private_module_sec="$(appendix_section "Mattermost 비공개 사설 모듈 커밋" "비공개 모듈 · 비고")"

    {
        echo "# upstream-master 미반영 커밋 목록"
        echo
        echo "\`$BASE_BRANCH\`에 반영되지 않은 \`$UPSTREAM_BRANCH\`(mattermost/mattermost-plugin-agents) 커밋 목록 (오래된 순)."
        echo "\`/speckit-sync\` 스킬이 이 목록을 갱신·소비한다. 반영 완료된 커밋은 목록에서 제거된다."
        echo
        echo "- 갱신일: $(date '+%Y-%m-%d %H:%M')"
        echo "- 기준: \`git log $BASE_BRANCH..$UPSTREAM_BRANCH\` − 처리 완료(cherry-pick/adapt 커밋 본문의 upstream 참조, 하단 부록의 제외·spec 전환)"
        echo "- 남은 커밋: ${total}개"
        echo
        echo "$last_synced_line"
        echo
        echo "| 커밋 해시 | 커밋 제목 | 커밋 일자 |"
        echo "|---|---|---|"
        [[ -n "$pending_rows" ]] && echo "$pending_rows"
        echo
        echo "$excluded_sec"
        echo
        echo "$spec_sec"
        echo
        echo "$private_module_sec"
    } >"$LEDGER"

    echo "updated: $LEDGER (남은 커밋 ${total}개)"
}

# ---------- status ----------

cmd_status() {
    [[ -f "$LEDGER" ]] || { echo "ledger 없음 — 먼저 update 실행" >&2; exit 1; }
    grep -E '^- 남은 커밋|^\*\*마지막 반영 커밋' "$LEDGER"
    local ex sp pm
    ex="$(awk '/^## 제외된 커밋/,/^## spec 전환 커밋/' "$LEDGER" | grep -c '^| [0-9a-f]' || true)"
    sp="$(awk '/^## spec 전환 커밋/,/^## Mattermost 비공개 사설 모듈 커밋/' "$LEDGER" | grep -c '^| [0-9a-f]' || true)"
    pm="$(awk '/^## Mattermost 비공개 사설 모듈 커밋/,0' "$LEDGER" | grep -c '^| [0-9a-f]' || true)"
    echo "- 제외된 커밋: ${ex}개 / spec 전환: ${sp}개 / 비공개 모듈 의존: ${pm}개"
}

# ---------- next ----------

cmd_next() {
    local n="${1:-1}" processed
    processed="$(processed_hashes)"
    git log "$BASE_BRANCH..$UPSTREAM_BRANCH" --reverse --date=format:%Y-%m-%d \
        --pretty=tformat:'%H%x1f%s%x1f%ad' |
    while IFS=$'\x1f' read -r full subj date; do
        grep -qx "$full" <<<"$processed" && continue
        printf '%s\t%s\t%s\n' "$full" "$date" "$subj"
    done | awk -v n="$n" 'NR<=n'   # head는 SIGPIPE+pipefail로 비정상 종료 유발
}

# ---------- signals ----------

cmd_signals() {
    local hash="$1"
    git rev-parse --verify -q "$hash^{commit}" >/dev/null || { echo "잘못된 해시: $hash" >&2; exit 1; }

    echo "=== COMMIT ==="
    git log -1 --date=format:%Y-%m-%d --pretty=format:'%H%n%s%n%ad%n' "$hash"

    echo "=== SIZE ==="
    git show --stat --format= "$hash" | tail -1

    echo "=== MERGE-TREE (cherry-pick 충돌 예측) ==="
    if git merge-tree --write-tree --merge-base="$hash^" "$BASE_BRANCH" "$hash" >/tmp/mt.$$ 2>&1; then
        echo "CLEAN"
    elif grep -q '^usage: git merge-tree' /tmp/mt.$$; then
        # git < 2.38: --write-tree 미지원 → 구식 merge-tree로 충돌 마커 검사
        git merge-tree "$hash^" "$BASE_BRANCH" "$hash" >/tmp/mt.$$ 2>/dev/null || true
        if grep -q '^+<<<<<<<' /tmp/mt.$$; then
            echo "CONFLICT (legacy merge-tree)"
            grep -B6 '^+<<<<<<<' /tmp/mt.$$ | awk '$1=="our"{print $NF}' | sort -u | awk "NR<=20"
        else
            echo "CLEAN (legacy merge-tree)"
        fi
    else
        echo "CONFLICT"
        # --name-only 출력부에서 충돌 파일 추출
        sed -n '2,$p' /tmp/mt.$$ | grep -E '^[^ ]' | awk "NR<=20" || true
    fi
    rm -f /tmp/mt.$$

    local paths
    paths="$(git diff-tree --no-commit-id --name-only -r "$hash")"

    echo "=== MISSING PATHS (HEAD에 없는 터치 경로) ==="
    while IFS= read -r p; do
        git cat-file -e "$BASE_BRANCH:$p" 2>/dev/null || echo "$p"
    done <<<"$paths" | awk "NR<=20"

    echo "=== PROTECTED PATHS (신중 검토 경로 접촉 — CI·빌드·공개 API·매니페스트) ==="
    grep -E '^(\.github/workflows/|build/|public/bridgeclient/|plugin\.json$|go\.mod$|webapp/package\.json$)' <<<"$paths" | awk "NR<=20" || echo "(없음)"

    echo "=== FORK HISTORY (터치 경로의 우리 자체 커밋 — 우리가 이 영역을 바꿨는가) ==="
    # 포크 자체 커밋 = master에만 있는 커밋 (upstream에 없는 것)
    local -a path_arr=()
    while IFS= read -r p; do [[ -n "$p" ]] && path_arr+=("$p"); done <<<"$paths"
    if [[ ${#path_arr[@]} -gt 0 ]]; then
        git log --oneline "$UPSTREAM_BRANCH..$BASE_BRANCH" --max-count=10 -- "${path_arr[@]}" 2>/dev/null || true
    fi
}

# ---------- exclude / to-spec ----------

append_appendix() {
    local title="$1" hash="$2" info="$3" extra_col="${4:-비고}"
    local full subj
    full="$(git rev-parse "$hash^{commit}")"
    subj="$(git log -1 --pretty=format:'%s' "$full")"
    subj="${subj//|/\\|}"; subj="${subj//[/\\[}"; subj="${subj//]/\\]}"
    info="${info//|/\\|}"
    # 섹션 마지막 표 행 뒤에 추가. 섹션이 아직 없으면(신규 카테고리 최초 사용) 파일 끝에 새로 만든다.
    # (Windows에서 python3가 미동작 App Execution Alias로 깨진 경우 python으로 폴백)
    local py=python3
    "$py" -c '' >/dev/null 2>&1 || py=python
    "$py" - "$LEDGER" "$title" "$extra_col" "| ${full:0:8} | [$subj]($UPSTREAM_URL/commit/$full) | $info |" <<'EOF'
import sys
path, title, extra_col, row = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
lines = open(path, encoding="utf-8").read().splitlines()
out, in_sec, inserted = [], False, False
for l in lines:
    if l.startswith("## "):
        if in_sec and not inserted:
            out.append(row); inserted = True
        in_sec = l == f"## {title}"
    out.append(l)
if in_sec and not inserted:
    out.append(row); inserted = True
if not inserted:
    # 섹션이 파일에 아예 없었던 경우 — 새 섹션을 끝에 생성
    if out and out[-1] != "":
        out.append("")
    out += [f"## {title}", "", f"| 커밋 해시 | 커밋 제목 | {extra_col} |", "|---|---|---|", row]
open(path, "w", encoding="utf-8").write("\n".join(out) + "\n")
EOF
}

cmd_exclude() { append_appendix "제외된 커밋" "$1" "$2" "사유"; cmd_update; }
cmd_tospec()  { append_appendix "spec 전환 커밋" "$1" "$2" "spec"; cmd_update; }
cmd_privatemodule() { append_appendix "Mattermost 비공개 사설 모듈 커밋" "$1" "$2" "비공개 모듈 · 비고"; cmd_update; }

# ---------- 진입점 ----------

case "${1:-}" in
    update)  cmd_update ;;
    status)  cmd_status ;;
    next)    cmd_next "${2:-1}" ;;
    signals) [[ $# -ge 2 ]] || { echo "signals <hash>" >&2; exit 1; }; cmd_signals "$2" ;;
    exclude) [[ $# -ge 3 ]] || { echo "exclude <hash> <사유>" >&2; exit 1; }; cmd_exclude "$2" "$3" ;;
    to-spec) [[ $# -ge 3 ]] || { echo "to-spec <hash> <specID>" >&2; exit 1; }; cmd_tospec "$2" "$3" ;;
    private-module) [[ $# -ge 3 ]] || { echo "private-module <hash> <설명>" >&2; exit 1; }; cmd_privatemodule "$2" "$3" ;;
    *) sed -n '2,17p' "$0"; exit 1 ;;
esac
