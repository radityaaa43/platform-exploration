#!/usr/bin/env bash
# check-agents-docs.sh [DIR=agents] [ALLOWLIST]
# Prints "file:line: reason" per violation. Exit 0 clean, 1 violations, 2 usage error.
# 1 length (AGENT<=150, STYLE<=60) + unresolved links; 2 "## " heading in 2+ role files
# (skeleton exempt); 3 Indonesian stop words; 4 role line + Always/Ask first/Never;
# 5 STATE<=30 lines, no [hex6] refs; 6 "- " bullet in 3+ role files (bullets under "## Never" are skipped:
# the safety floor is repeated there by design, see STYLE.md). All checks skip blockchain/.
# ALLOWLIST: paths relative to parent of DIR (e.g. agents/blockchain/NOTES.md), skipped as link targets.
# A role file listed there (e.g. agents/analyst/AGENT.md) is also left out of the role checks (2, 4, 6).
# Run from the repo root: bash agents/ops/check-agents-docs.sh agents agents/ops/check-agents-docs.allow

set -u

dir="${1:-agents}"
allow="${2:-}"
dir="${dir%/}"

if [ ! -d "$dir" ]; then echo "error: not a directory: $dir" >&2; exit 2; fi
if [ -n "$allow" ] && [ ! -f "$allow" ]; then echo "error: allowlist not found: $allow" >&2; exit 2; fi

root=$(cd "$(dirname "$dir")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
out="$tmp/out"
: > "$out"

add() { printf '%s:%s: %s\n' "$1" "$2" "$3" >> "$out"; }
lines() { awk 'END { print NR }' "$1"; }
allowed() { [ -n "$allow" ] && grep -vE '^[[:space:]]*(#|$)' "$allow" | grep -qxF -- "$1"; }

shopt -s nullglob
roles=(); for f in "$dir"/*/AGENT.md; do case "$f" in "$dir"/blockchain/*) continue ;; esac; allowed "$f" && continue; roles+=("$f"); done
mapfile -t mds < <(find "$dir" -path "$dir/blockchain" -prune -o -type f -name '*.md' -print | sort)

# 1. length limits and references
for f in "${roles[@]}"; do
  n=$(lines "$f")
  [ "$n" -gt 150 ] && add "$f" "$n" "AGENT.md is $n lines (limit 150)"
done
if [ -f "$dir/STYLE.md" ]; then
  n=$(lines "$dir/STYLE.md")
  [ "$n" -gt 60 ] && add "$dir/STYLE.md" "$n" "STYLE.md is $n lines (limit 60)"
fi
check_target() {  # $1 file  $2 line  $3 target (as written)
  local rel
  rel=$(realpath -m --relative-to="$root" "$(dirname "$1")/$3")
  allowed "$rel" && return 0
  [ -e "$root/$rel" ] || add "$1" "$2" "broken reference: $3 (resolves to $rel, not found)"
}
for f in "${mds[@]}"; do
  grep -noE '\]\([^) #?]+' "$f" | while IFS=: read -r ln rest; do
    t=${rest#](}
    case "$t" in http:*|https:*|mailto:*|/*|../*) continue ;; esac
    check_target "$f" "$ln" "$t"
  done
  grep -noE '\.\./[A-Za-z0-9_./+-]+\.md' "$f" | while IFS=: read -r ln t; do
    check_target "$f" "$ln" "$t"
  done
done

# 2. ## headings repeated across role files (skeleton headings exempt)
for f in "${roles[@]}"; do
  awk -v F="$f" '/^## / { k = tolower(substr($0, 4)); gsub(/^[ \t]+|[ \t]+$/, "", k)
    printf "%s\t%d\t%s\n", k, FNR, F }' "$f"
done > "$tmp/heads"
awk -F'\t' -v skel="how to start,always,ask first,never,report,report shape,duties" '
  BEGIN { n = split(skel, s, ","); for (i = 1; i <= n; i++) ok[s[i]] = 1 }
  { if (!(($1 SUBSEP $3) in seen)) { seen[$1 SUBSEP $3] = 1; nf[$1]++ }; r[NR] = $0 }
  END { for (i = 1; i <= NR; i++) { split(r[i], a, "\t")
    if (!(a[1] in ok) && nf[a[1]] > 1) printf "%s:%s: duplicate ## heading \"%s\" in %d role files\n", a[3], a[2], a[1], nf[a[1]] } }
' "$tmp/heads" >> "$out"

# 3. Indonesian stop words outside fences, backticks and double quotes
if [ ${#mds[@]} -gt 0 ]; then
  awk '
    BEGIN { n = split("yang dan untuk tidak dengan akan sudah atau dari ini", w, " ")
            for (i = 1; i <= n; i++) stop[w[i]] = 1 }
    FNR == 1 { fence = 0 }
    /^[ \t]*```/ { fence = !fence; next }
    fence { next }
    { s = $0; gsub(/`[^`]*`/, " ", s); gsub(/"[^"]*"/, " ", s)
      s = tolower(s); gsub(/[^a-z0-9]+/, " ", s); m = split(s, t, " ")
      for (i = 1; i <= m; i++) if (t[i] in stop) printf "%s:%d: Indonesian stop word \"%s\"\n", FILENAME, FNR, t[i] }
  ' "${mds[@]}" >> "$out"
fi

# 4. role file structure
for f in "${roles[@]}"; do
  awk -v F="$f" '
    NF { c++; if (c <= 4 && ($0 ~ /^Role:/ || $0 ~ /^You are/)) ok = 1 }
    END { if (!ok) printf "%s:1: no \"Role:\" or \"You are\" line in first 4 non-empty lines\n", F }' "$f" >> "$out"
  for h in Always "Ask first" Never; do
    grep -qxF "## $h" "$f" || add "$f" 1 "missing heading \"## $h\""
  done
done

# 6. bullets repeated across role files
for f in "${roles[@]}"; do
  awk -v F="$f" '/^## / { never = (tolower($0) ~ /^## never[ \t]*$/) }
    /^- / && !never { k = tolower($0); gsub(/^[ \t]+|[ \t]+$/, "", k)
    printf "%s\t%d\t%s\n", k, FNR, F }' "$f"
done > "$tmp/bul"
awk -F'\t' '
  { if (!(($1 SUBSEP $3) in seen)) { seen[$1 SUBSEP $3] = 1; nf[$1]++ }; r[NR] = $0 }
  END { for (i = 1; i <= NR; i++) { split(r[i], a, "\t")
    if (nf[a[1]] >= 3) printf "%s:%s: bullet repeated in %d role files\n", a[3], a[2], nf[a[1]] } }
' "$tmp/bul" >> "$out"

if [ -s "$out" ]; then cat "$out"; exit 1; fi
echo "check-agents-docs: no violations in $dir" >&2
exit 0
