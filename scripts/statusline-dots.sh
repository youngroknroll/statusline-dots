#!/bin/bash
# statusline-dots — 3행 도트 스타일 statusline
#  1행: 모델 (컨텍스트 크기) | 🧠 effort | 📂 폴더 (브랜치*) | ◑ output style | ⚡ 세션 ID
#  2행: current 5시간 한도 바·%·리셋  |  weekly 주간 한도 바·%·리셋
#  3행: context 컨텍스트 창 도트 바·%

input=$(cat)

# ── 색상 ──────────────────────────────────────────────
BLUE="\033[38;2;97;175;239m"
RED="\033[38;2;224;108;117m"
GREEN="\033[38;2;152;195;121m"
YELLOW="\033[38;2;229;192;123m"
GRAY="\033[38;2;120;120;130m"
DIM="\033[38;2;90;90;100m"
TEXT="\033[38;2;200;200;210m"
RESET="\033[0m"

# ── 필드 추출 ─────────────────────────────────────────
model=$(echo "$input" | jq -r '.model.display_name // "?"')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
style=$(echo "$input" | jq -r '.output_style.name // "default"')
dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "?" | split("/") | last')
fh_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
fh_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
sd_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)
sd_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')
session_id=$(echo "$input" | jq -r '.session_id // empty')

# 컨텍스트 크기 라벨
if [ "$ctx_size" -ge 1000000 ] 2>/dev/null; then ctx_label="1M context"; else ctx_label="$((ctx_size/1000))k context"; fi

# git 브랜치 (+dirty *)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "."')
branch=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
    [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null | head -1)" ] && dirty="${RED}*${RESET}" || dirty=""
fi

# ── 헬퍼 ──────────────────────────────────────────────
pct_color() {  # 사용률에 따라 색
    local p=$1
    if [ "$p" -ge 80 ] 2>/dev/null; then printf '%s' "$RED"
    elif [ "$p" -ge 50 ] 2>/dev/null; then printf '%s' "$YELLOW"
    else printf '%s' "$GREEN"; fi
}

dot_bar() {  # $1=pct $2=width $3=filled색 $4=empty색
    local pct=$1 width=$2 fc=$3 ec=$4
    local filled=$(( (pct * width + 50) / 100 ))
    [ "$filled" -gt "$width" ] && filled=$width
    local fpart="" epart="" i
    for ((i=0; i<filled; i++)); do fpart+="▓"; done
    for ((i=filled; i<width; i++)); do epart+="░"; done
    printf '%b%s%b%s%b' "$fc" "$fpart" "$ec" "$epart" "$RESET"
}

epoch_fmt() {  # $1=epoch $2=format — BSD(macOS)와 GNU(Linux) date 모두 지원
    LC_ALL=C date -r "$1" "$2" 2>/dev/null || LC_ALL=C date -d "@$1" "$2" 2>/dev/null
}

fmt_reset() {  # $1=epoch $2=short|long → "↻5:00pm (in 3h59m)"
    local epoch=$1 mode=$2 now diff rel abs
    now=$(date +%s)
    diff=$((epoch - now))
    [ $diff -lt 0 ] && diff=0
    local d=$((diff/86400)) h=$(( (diff%86400)/3600 )) m=$(( (diff%3600)/60 ))
    if [ $d -gt 0 ]; then rel="${d}d${h}h"; elif [ $h -gt 0 ]; then rel="${h}h${m}m"; else rel="${m}m"; fi
    if [ "$mode" = "long" ]; then
        abs=$(epoch_fmt "$epoch" '+%b %e, %l:%M%p' | tr '[:upper:]' '[:lower:]' | tr -s ' ')
    else
        abs=$(epoch_fmt "$epoch" '+%l:%M%p' | tr 'APM' 'apm' | tr -s ' ' | sed 's/^ //')
    fi
    printf '↻%s (in %s)' "$abs" "$rel"
}

# ── 1행: 모델 | 컨텍스트% | 폴더(브랜치) | 스타일 ─────
line1=""
line1+=$(printf '%b%s (%s)%b' "$BLUE" "$model" "$ctx_label" "$RESET")
if [ -n "$effort" ]; then
    case "$effort" in
        max|xhigh) e_color=$RED ;;
        high) e_color=$YELLOW ;;
        *) e_color=$GREEN ;;
    esac
    line1+=$(printf ' %b|%b ' "$DIM" "$RESET")
    line1+=$(printf '🧠 %b%s%b' "$e_color" "$effort" "$RESET")
fi
line1+=$(printf ' %b|%b ' "$DIM" "$RESET")
if [ -n "$branch" ]; then
    line1+=$(printf '📂 %b%s%b (%b%s%b%b)' "$GREEN" "$dir" "$RESET" "$GREEN" "$branch" "$RESET" "$dirty")
else
    line1+=$(printf '📂 %b%s%b' "$GREEN" "$dir" "$RESET")
fi
line1+=$(printf ' %b|%b ' "$DIM" "$RESET")
line1+=$(printf '◑ %b%s%b' "$TEXT" "$style" "$RESET")
if [ -n "$session_id" ]; then
    line1+=$(printf ' %b|%b ' "$DIM" "$RESET")
    line1+=$(printf '⚡ %b%s%b' "$TEXT" "${session_id:0:8}" "$RESET")
fi
echo -e "$line1"

# ── 2행: current / weekly 한도 ────────────────────────
if [ -n "$fh_pct" ] || [ -n "$sd_pct" ]; then
    line2=""
    if [ -n "$fh_pct" ]; then
        line2+=$(printf '%bcurrent%b ' "$TEXT" "$RESET")
        line2+=$(dot_bar "$fh_pct" 10 "$(pct_color "$fh_pct")" "$DIM")
        line2+=$(printf ' %b%s%%%b' "$(pct_color "$fh_pct")" "$fh_pct" "$RESET")
        [ -n "$fh_reset" ] && line2+=$(printf ' %b%s%b' "$GRAY" "$(fmt_reset "$fh_reset" short)" "$RESET")
    fi
    if [ -n "$sd_pct" ]; then
        [ -n "$fh_pct" ] && line2+=$(printf ' %b|%b ' "$DIM" "$RESET")
        line2+=$(printf '%bweekly%b ' "$TEXT" "$RESET")
        line2+=$(dot_bar "$sd_pct" 10 "$(pct_color "$sd_pct")" "$DIM")
        line2+=$(printf ' %b%s%%%b' "$(pct_color "$sd_pct")" "$sd_pct" "$RESET")
        [ -n "$sd_reset" ] && line2+=$(printf ' %b%s%b' "$GRAY" "$(fmt_reset "$sd_reset" long)" "$RESET")
    fi
    echo -e "$line2"
fi

# ── 3행: context 도트 바 ──────────────────────────────
line3=$(printf '%bcontext%b ' "$TEXT" "$RESET")
line3+=$(dot_bar "$ctx_pct" 40 "$GRAY" "$DIM")
line3+=$(printf ' %b%s%%%b' "$GRAY" "$ctx_pct" "$RESET")
echo -e "$line3"
