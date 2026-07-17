# statusline-dots

Claude Code용 3행 도트 스타일 statusline + 서브에이전트 패널 커스텀 행 플러그인.

```
Fable 5 (1M context) | 🧠 high | 📂 my-project (main*) | ◑ default | ⚡ 4097f271
current ▓▓▓▓▓░░░░░ 53% ↻8:41am (in 3h27m) | weekly ▓▓▓░░░░░░░ 30% ↻jul 19, 7:14am (in 1d2h)
context ▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 14%
```

서브에이전트 패널:

```
● backend → 마이그레이션 검토 중 · ▓▓▓░░ 2/3 · 45.2k (22%)
✓ panel-live → 마무리 중 · ▓▓▓▓▓ 4/4 · 37.1k (18%)
⏸ reviewer → idle — 오케스트레이터 검증 대기 · 12.0k (6%)
```

## 표시 항목

- **1행**: 모델명(컨텍스트 크기) · 🧠 effort 레벨 · 📂 폴더명(git 브랜치, dirty `*`) · ◑ output style · ⚡ 세션 ID 앞 8자리
- **2행**: 5시간 사용 한도(`current`)와 주간 한도(`weekly`) — 사용률 바 + 리셋 시각/카운트다운
- **3행**: 컨텍스트 창 사용량 바 + %
- 색상: 사용률 50%↑ 노랑, 80%↑ 빨강 / effort는 high=노랑, xhigh·max=빨강, 그 외 초록
- effort·세션 ID 등 데이터가 없는 세그먼트는 자동으로 숨겨짐
- 서브에이전트 상태 아이콘: ● 실행 중 / ✓ 완료 / ✗ 실패 / ⏸ idle(워커 자기선언)

## 요구사항

- `bash`, `jq` (macOS: `brew install jq`, Debian/Ubuntu: `sudo apt install jq`)
- macOS/Linux 지원

## 설치

Claude Code 안에서:

```
/plugin marketplace add youngroknroll/statusline-dots
/plugin install statusline-dots@statusline-dots
```

설치하면 **서브에이전트 패널**은 즉시 적용됩니다. **메인 statusline**은 플러그인 settings로는 배포할 수 없어(Claude Code 제약) 명령 한 번이 더 필요합니다:

```
/statusline-dots:install
```

## 서브에이전트 진척 바 규약 (선택)

패널의 `▓▓▓░░ N/M` 진척 바는 워커 에이전트가 진행 상황을 파일로 보고할 때만 표시됩니다. 규약 없이 사용해도 `슬러그 → 라벨 · 토큰` 형태로 정상 동작합니다.

진척 바를 쓰려면 CLAUDE.md(또는 오케스트레이션 지침)에 다음을 추가하세요:

```
병렬 워커를 Agent 도구로 띄울 때:
- name 파라미터를 주지 말 것 (팀메이트가 되면 커스텀 패널이 적용되지 않음)
- description을 "슬러그: 설명" 형태로 시작할 것 (예: "backend: API 구현")
- 워커 프롬프트에 다음 규약을 포함할 것:

  [진행 보고] 작업 시작 시 전체 단계 수 M을 정하고, 단계가 바뀔 때마다 실행:
  mkdir -p /tmp/claude-progress && printf '%s' 'N/M 현재 단계 설명' > /tmp/claude-progress/<슬러그>

  작업을 마치고 후속 지시·검증을 기다릴 때는:
  printf '%s' 'idle 사유' > /tmp/claude-progress/<슬러그>
  → 패널에 "⏸ 슬러그 → idle — 사유"로 표시됨 (사유 생략 시 "대기 중")
```

## 제거

```
/plugin uninstall statusline-dots@statusline-dots
```

메인 statusline까지 제거하려면 `~/.claude/settings.json`의 `statusLine` 키와 `~/.claude/statusline-dots.sh`를 삭제하세요.

## 라이선스

MIT
