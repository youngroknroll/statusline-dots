#!/bin/bash
# subagentStatusLine renderer: <이름> → <작업설명> · <토큰>
# stdin:  {"session_id", "transcript_path", "columns": N,
#          "tasks": [{id, label, description, status, startTime, tokenCount,
#          contextWindowSize, ...}]}
# stdout: one JSON line per task: {"id": "...", "content": "..."}
#
# 이름(agentType)은 stdin에 없다. task id로 meta.json을 조회해 얻는다.
set -uo pipefail

ESC=$'\033'
BOLD="${ESC}[1m"; DIM="${ESC}[2m"; RESET="${ESC}[0m"
CYAN="${ESC}[36m"; GREEN="${ESC}[32m"; YELLOW="${ESC}[33m"; RED="${ESC}[31m"
BLUE="${ESC}[34m"; MAGENTA="${ESC}[35m"

# 이름별 안정적 색상: agentType 문자합을 팔레트에 매핑 (RED는 실패 아이콘용이라 제외)
NAME_PALETTE=("$CYAN" "$GREEN" "$YELLOW" "$BLUE" "$MAGENTA")
name_color() {
  local s="$1" sum=0 i c
  for ((i = 0; i < ${#s}; i++)); do
    printf -v c '%d' "'${s:i:1}" 2>/dev/null || c=0
    sum=$((sum + c))
  done
  printf '%s' "${NAME_PALETTE[$((sum % ${#NAME_PALETTE[@]}))]}"
}

# 실행시간: 45s / 2m14s / 1h03m — 자리폭을 좁게 유지하려 단위는 최대 두 개
fmt_elapsed() {
  local secs=$1
  local h=$((secs / 3600)) m=$(((secs % 3600) / 60)) s=$((secs % 60))
  if [ "$h" -gt 0 ]; then
    printf '%dh%02dm' "$h" "$m"
  elif [ "$m" -gt 0 ]; then
    printf '%dm%02ds' "$m" "$s"
  else
    printf '%ds' "$s"
  fi
}

# 전체 입력을 먼저 읽어 top-level 컨텍스트(메타 조회 경로)를 확보한다.
# Claude Code는 subagentStatusLine stdin에 에이전트 이름을 넣어주지 않는다.
# 실제 이름(agentType)은 <session>/subagents/agent-<task id>.meta.json 에만 있다.
input=$(cat)
transcript_path=$(printf '%s' "$input" | jq -r '.transcript_path // empty')
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty')
meta_dir=""
if [ -n "$transcript_path" ] && [ -n "$session_id" ]; then
  meta_dir="$(dirname "$transcript_path")/$session_id/subagents"
fi

printf '%s' "$input" | jq -r '
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

  # 실제 에이전트 이름: task id → agent-<id>.meta.json 의 agentType
  agent_type=""
  if [ -n "$meta_dir" ] && [ -f "$meta_dir/agent-$id.meta.json" ]; then
    agent_type=$(jq -r '.agentType // empty' "$meta_dir/agent-$id.meta.json" 2>/dev/null)
  fi

  # 슬러그: agentType > name 필드 > label의 "슬러그: 설명" 규약
  slug="$agent_type"
  [ -z "$slug" ] && slug="$name"
  if [ -z "$slug" ] && [[ "$label" == *:* ]]; then
    slug="${label%%:*}"
  fi
  if [ -n "$slug" ] && [ "$slug" != "$label" ]; then
    display_name="$slug"
    label="${label#"$slug":}"; label="${label# }"
  else
    display_name="agent"
  fi

  # 작업설명 (40자 초과 시 말줄임)
  desc="$label"
  [ "${#desc}" -gt 40 ] && desc="${desc:0:39}…"

  # 토큰: 45.2k, 컨텍스트 창 크기를 알면 사용률 %도 부기
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

  # 실행시간: startTime을 못 읽었거나 시계가 어긋나면 표기를 생략한다
  elapsed=""
  if [ "$start_epoch" -gt 0 ] 2>/dev/null; then
    secs=$(( $(date +%s) - start_epoch ))
    [ "$secs" -ge 0 ] && elapsed="$(fmt_elapsed "$secs") · "
  fi

  nc=$(name_color "$display_name")
  content="${icon} ${nc}${BOLD}${display_name}${RESET} → ${desc} · ${DIM}${elapsed}${tok}${RESET}"

  jq -cn --arg id "$id" --arg content "$content" '{id: $id, content: $content}'
done

exit 0
