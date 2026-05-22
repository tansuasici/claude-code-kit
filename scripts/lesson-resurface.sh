#!/usr/bin/env bash
#
# lesson-resurface.sh — deterministic frontmatter scan + scoring for /lesson-resurface
#
# Backs the `/lesson-resurface` skill: scans tasks/lessons/ + _archive/, scores
# lessons by `applies_to` topic overlap with the task summary, resolves
# supersession chains, prints top-5 pointers (paths + frontmatter only — never
# bodies). The skill's SKILL.md delegates the deterministic loop here.
#
# Usage:
#   ./scripts/lesson-resurface.sh "<task summary>"
#   LESSON_QUERY="<task summary>" ./scripts/lesson-resurface.sh
#
# Exit codes:
#   0  matches found OR clean no-match (vocabulary miss)
#   1  tasks/lessons/ directory does not exist
#   2  usage error (no query supplied)
#
# Output goes to stdout. Format matches the SKILL.md "Phase 4: Emit pointers"
# example block verbatim.
#

set -uo pipefail

QUERY="${1:-${LESSON_QUERY:-}}"
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LESSONS_DIR="$ROOT/tasks/lessons"
ARCHIVE_DIR="$LESSONS_DIR/_archive"

if [ ! -d "$LESSONS_DIR" ]; then
  echo "lesson-resurface: $LESSONS_DIR does not exist" >&2
  exit 1
fi

if [ -z "$QUERY" ]; then
  echo "lesson-resurface: usage: $0 \"<task summary>\" (or set LESSON_QUERY env)" >&2
  exit 2
fi

# Helper: extract a frontmatter field from a lesson file. Reads only the YAML
# block between the first pair of `---` markers — body content is ignored.
get_field() {
  local file="$1" field="$2"
  awk -v field="$field" '
    BEGIN { in_fm = 0; count = 0 }
    /^---$/ {
      count++
      if (count == 1) { in_fm = 1; next }
      if (count == 2) { exit }
    }
    in_fm && $0 ~ "^" field ":" {
      sub("^" field ": *", "")
      print
      exit
    }
  ' "$file"
}

# Helper: list all lesson files (active + archive), skipping templates/index.
list_lessons() {
  for f in "$LESSONS_DIR"/*.md; do
    [ -f "$f" ] || continue
    local base
    base=$(basename "$f")
    [ "$base" = "_TEMPLATE.md" ] && continue
    [ "$base" = "_index.md" ] && continue
    printf '%s\n' "$f"
  done
  if [ -d "$ARCHIVE_DIR" ]; then
    for f in "$ARCHIVE_DIR"/*.md; do
      [ -f "$f" ] || continue
      printf '%s\n' "$f"
    done
  fi
}

# Phase 1: discover canonical applies_to vocabulary from all lessons.
VOCAB=""
while IFS= read -r f; do
  raw=$(get_field "$f" "applies_to")
  [ -z "$raw" ] && continue
  cleaned=$(printf '%s' "$raw" | tr -d "[]\"'" | tr ',' '\n' | tr -d ' ')
  VOCAB="${VOCAB}${cleaned}"$'\n'
done < <(list_lessons)
VOCAB=$(printf '%s' "$VOCAB" | grep -v '^$' | sort -u)

# Phase 1: match the query against vocabulary (substring + lower-case).
QUERY_LOWER=$(printf '%s' "$QUERY" | tr '[:upper:]' '[:lower:]')
MATCHED_TOPICS=""
while IFS= read -r topic; do
  [ -z "$topic" ] && continue
  if printf '%s' "$QUERY_LOWER" | grep -q -- "$topic"; then
    MATCHED_TOPICS="${MATCHED_TOPICS}${topic}"$'\n'
  fi
done <<<"$VOCAB"
MATCHED_TOPICS=$(printf '%s' "$MATCHED_TOPICS" | grep -v '^$' || true)

if [ -z "$MATCHED_TOPICS" ]; then
  echo "No matching topics found in applies_to vocabulary; no lessons to resurface."
  exit 0
fi

# Build a single space-separated topic list for grep ops.
TOPICS_LIST=$(printf '%s' "$MATCHED_TOPICS" | tr '\n' ' ')

# Phase 2: score every lesson. Output rows: score<TAB>path<TAB>applies_to<TAB>status<TAB>confidence<TAB>title
SCORED=""
while IFS= read -r f; do
  applies_to=$(get_field "$f" "applies_to")
  tags=$(get_field "$f" "tags")
  status=$(get_field "$f" "status")
  confidence=$(get_field "$f" "confidence")
  title=$(get_field "$f" "title")
  score=0

  applies_clean=" $(printf '%s' "$applies_to" | tr -d "[]\"'" | tr ',' ' ') "
  tags_clean=" $(printf '%s' "$tags" | tr -d "[]\"'" | tr ',' ' ') "

  for topic in $TOPICS_LIST; do
    if printf '%s' "$applies_clean" | grep -wq -- "$topic"; then
      score=$((score + 3))
    fi
    if printf '%s' "$tags_clean" | grep -wq -- "$topic"; then
      score=$((score + 1))
    fi
  done

  case "$status" in
    archived) score=$((score - 2)) ;;
    superseded) score=$((score - 1)) ;;
  esac

  [ "$confidence" = "high" ] && score=$((score + 1))

  if [ "$score" -gt 0 ]; then
    SCORED="${SCORED}${score}"$'\t'"${f}"$'\t'"${applies_to}"$'\t'"${status}"$'\t'"${confidence}"$'\t'"${title}"$'\n'
  fi
done < <(list_lessons)

# Sort by score descending (tab-separated, numeric on field 1).
SCORED=$(printf '%s' "$SCORED" | grep -v '^$' | sort -t$'\t' -k1,1 -rn)

if [ -z "$SCORED" ]; then
  TOPICS_CSV=$(printf '%s' "$MATCHED_TOPICS" | tr '\n' ',' | sed 's/,$//; s/,/, /g')
  printf 'No archived/superseded lessons match topics [%s]. Proceed with the Top Rules already in context.\n' "$TOPICS_CSV"
  exit 0
fi

# Phase 3: resolve supersession chains. Drop a superseded lesson if some active
# lesson supersedes it AND that active lesson is already in our match list.
FILTERED=""
while IFS=$'\t' read -r score path applies_to status confidence title; do
  [ -z "$path" ] && continue
  drop=0
  if [ "$status" = "superseded" ]; then
    base=$(basename "$path" .md)
    while IFS= read -r active; do
      active_status=$(get_field "$active" "status")
      [ "$active_status" = "active" ] || continue
      supersedes=$(get_field "$active" "supersedes" | tr -d "[]\"'" | tr ',' ' ')
      if printf ' %s ' "$supersedes" | grep -wq -- "$base"; then
        active_base=$(basename "$active" .md)
        # Is the successor already in match list?
        if printf '%s' "$SCORED" | grep -q -- "${active_base}\.md"$'\t'; then
          drop=1
          break
        fi
      fi
    done < <(list_lessons)
  fi
  if [ "$drop" -eq 0 ]; then
    FILTERED="${FILTERED}${score}"$'\t'"${path}"$'\t'"${applies_to}"$'\t'"${status}"$'\t'"${confidence}"$'\t'"${title}"$'\n'
  fi
done <<<"$SCORED"

# Phase 4: emit pointers (top 5).
TOPICS_CSV=$(printf '%s' "$MATCHED_TOPICS" | tr '\n' ',' | sed 's/,$//; s/,/, /g')
echo "Matched lessons for topics [$TOPICS_CSV]:"
echo ""

COUNT=0
TOTAL=0
TMP_FILTERED=$(printf '%s' "$FILTERED" | grep -v '^$' || true)
TOTAL=$(printf '%s\n' "$TMP_FILTERED" | grep -c '^' 2>/dev/null || echo 0)
# grep -c with empty input on macOS yields blank; coerce.
[ -z "$TOTAL" ] && TOTAL=0

while IFS=$'\t' read -r score path applies_to status confidence title; do
  [ -z "$path" ] && continue
  COUNT=$((COUNT + 1))
  [ "$COUNT" -gt 5 ] && break

  rel_path="${path#$ROOT/}"
  echo "$COUNT. $rel_path"
  echo "   applies_to: $applies_to"
  echo "   status: $status | confidence: $confidence"
  echo "   title: $title"
  echo ""
done <<<"$TMP_FILTERED"

if [ "$TOTAL" -gt 5 ]; then
  echo "… $((TOTAL - 5)) more matched (not shown)."
  echo ""
fi

echo "These are pointers, not content. Read any that look relevant before proceeding; the bodies were intentionally NOT loaded."
exit 0
