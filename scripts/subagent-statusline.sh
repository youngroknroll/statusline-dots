#!/bin/bash
# subagentStatusLine renderer: <이름> → <작업설명> · <진척률> · <토큰>
# stdin:  {"columns": N, "tasks": [{id, name, label, description, status,
#          startTime, tokenCount, contextWindowSize, ...}]}
# stdout: one JSON line per task: {"id": "...", "content": "..."}
#
# 진척률 convention: workers write "N/M current step" (single line) to
# /tmp/claude-progress/<agent-name>. The file only counts if its mtime is newer
# than the task's startTime, so leftovers from earlier runs are ignored.
# (Moved out of ~/.claude/progress on 2026-07-18: writes into ~/.claude are
# classified as sensitive-file edits and trigger a permission prompt per
# worker; /tmp is prompt-free and reboot-clearing is fine for ephemeral
# progress. The mtime staleness check already guards stale leftovers.)
set -uo pipefail

PROGRESS_DIR="/tmp/claude-progress"

ESC=$'\033'
BOLD="${ESC}[1m"; DIM="${ESC}[2m"; RESET="${ESC}[0m"
CYAN="${ESC}[36m"; GREEN="${ESC}[32m"; YELLOW="${ESC}[33m"; RED="${ESC}[31m"

jq -r '
  .tasks[]? |
  [ .id,
    (.name // ""),
    ((.label // .description // "") | gsub("[\\t\\n\\r]"; " ")),
    (.status // ""),
    ((.tokenCount // 0) | floor),
    ((.contextWindowSize // 0) | floor),
    ((.startTime // "") | tostring |
      if test("^[0-9]+$") then (tonumber / 1000 | floor)
      else (sub("\\.[0-9]+"; "") | (fromdateiso8601? // 0)) end)
  ] | map(tostring) | join("")
' | while IFS=$'\x1f' read -r id name label status tokens ctx start_epoch; do
  [ -n "$id" ] || continue

  # 슬러그: name 필드가 있으면 그것, 없으면 label의 "슬러그: 설명" 규약에서 추출
  slug="$name"
  if [ -z "$slug" ] && [[ "$label" == *:* ]]; then
    slug="${label%%:*}"
  fi
  if [ -n "$slug" ] && [ "$slug" != "$label" ]; then
    display_name="$slug"
    label="${label#"$slug":}"; label="${label# }"
  else
    display_name="agent"
  fi

  # 진척률: progress file must be fresher than this task's start
  progress=""; step=""
  safe_name="${slug//[^a-zA-Z0-9._-]/_}"
  pfile="$PROGRESS_DIR/$safe_name"
  if [ -f "$pfile" ]; then
    mtime=$(stat -f %m "$pfile" 2>/dev/null || stat -c %Y "$pfile" 2>/dev/null || echo 0)
    if [ "$mtime" -ge "$start_epoch" ]; then
      line=""
      IFS= read -r line < "$pfile" || true
      if [[ "$line" =~ ^([0-9]+)/([0-9]+)[[:space:]]*(.*)$ ]]; then
        n="${BASH_REMATCH[1]}"; m="${BASH_REMATCH[2]}"; step="${BASH_REMATCH[3]}"
        if [ "$m" -gt 0 ]; then
          filled=$(( n * 5 / m ))
          [ "$n" -gt 0 ] && [ "$filled" -eq 0 ] && filled=1
          [ "$filled" -gt 5 ] && filled=5
          bar=""
          for ((i = 0; i < 5; i++)); do
            if [ "$i" -lt "$filled" ]; then bar+="▓"; else bar+="░"; fi
          done
          progress="${GREEN}${bar}${RESET} ${n}/${m}"
        fi
      fi
    fi
  fi

  # 작업설명: live step from the progress file wins over the spawn label
  desc="$label"
  [ -n "$step" ] && desc="$step"
  [ "${#desc}" -gt 40 ] && desc="${desc:0:39}…"

  # 토큰: 45.2k, plus context % when the window size is known
  if [ "$tokens" -ge 1000 ]; then
    tok=$(awk -v t="$tokens" 'BEGIN { printf "%.1fk", t / 1000 }')
  else
    tok="$tokens"
  fi
  if [ "$ctx" -gt 0 ]; then
    pct=$(( tokens * 100 / ctx ))
    tok="${tok} (${pct}%)"
  fi

  case "$status" in
    done|completed|success) icon="${GREEN}✓${RESET}" ;;
    failed|error)           icon="${RED}✗${RESET}" ;;
    blocked|waiting)        icon="${YELLOW}⏸${RESET}" ;;
    *)                      icon="${CYAN}●${RESET}" ;;
  esac

  content="${icon} ${BOLD}${display_name}${RESET} → ${desc}"
  [ -n "$progress" ] && content="${content} · ${progress}"
  content="${content} · ${DIM}${tok}${RESET}"

  jq -cn --arg id "$id" --arg content "$content" '{id: $id, content: $content}'
done

exit 0
