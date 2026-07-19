# statusline-dots

<img width="1334" height="304" alt="image" src="https://github.com/user-attachments/assets/5399b97e-d2a6-494b-950c-a3f89329c4b6" />

Claude Code용 3행 도트 스타일 statusline + 서브에이전트 패널 커스텀 행 플러그인.

```
Fable 5 (1M context) | 🧠 high | 📂 my-project (main*) | ◑ default | ⚡ 4097f271
current ▓▓▓▓▓░░░░░ 53% ↻8:41am (in 3h27m) | weekly ▓▓▓░░░░░░░ 30% ↻jul 19, 7:14am (in 1d2h)
context ▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 14%
```

서브에이전트 패널:

```
● backend-tdd-coach → API 마이그레이션 검토 중 · 2m14s · 45.2k (22%)
✓ code-reviewer → 리뷰 완료 · 3m12s · 37.1k (18%)
● Explore → 테스트 파일 비교 중 · 45s · 12.0k (6%)
```

## 표시 항목

- **1행**: 모델명(컨텍스트 크기) · 🧠 effort 레벨 · 📂 폴더명(git 브랜치, dirty `*`) · ◑ output style · ⚡ 세션 ID 앞 8자리
- **2행**: 5시간 사용 한도(`current`)와 주간 한도(`weekly`) — 사용률 바 + 리셋 시각/카운트다운
- **3행**: 컨텍스트 창 사용량 바 + %
- 색상: 사용률 50%↑ 노랑, 80%↑ 빨강 / effort는 high=노랑, xhigh·max=빨강, 그 외 초록
- effort·세션 ID 등 데이터가 없는 세그먼트는 자동으로 숨겨짐
- 서브에이전트 이름: 에이전트 타입(예: `code-reviewer`, `Explore`)을 자동 표시 — 이름별로 고정 색상 배정. Claude Code가 stdin에 이름을 주지 않으므로 task id로 세션의 `subagents/agent-<id>.meta.json`에서 `agentType`을 조회
- 서브에이전트 작업설명·토큰 사용량(컨텍스트 창을 알면 `%`)은 Claude Code가 native로 제공 — 추가 비용 없음
- 서브에이전트 실행시간: `45s` → `2m14s` → `1h03m` 형식. Claude Code가 주는 `startTime` 기준이며, 값이 없으면 이 구간은 생략됨
- 서브에이전트 상태 아이콘: ● 실행 중 / ✓ 완료 / ✗ 실패 / ⏸ 대기(blocked·waiting)

## 요구사항

`bash`와 `jq`가 필요합니다.

| 환경 | jq 설치 | 비고 |
|---|---|---|
| macOS | `brew install jq` | |
| Debian·Ubuntu | `sudo apt install jq` | |
| Fedora·RHEL | `sudo dnf install jq` | |
| Arch | `sudo pacman -S jq` | |
| Windows | `winget install jqlang.jq` (또는 `scoop install jq`, `choco install jq`) | **Git Bash 필수** — 아래 참고 |

그 외 의존성은 `date`, `awk`, `sed`, `tr`, `cut`, `git`, `dirname`뿐이며 모두 표준 도구입니다. `date`는 BSD(macOS)와 GNU(Linux) 양쪽 옵션을 자동으로 시도합니다.

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

설치 절차는 macOS·Linux·Windows가 동일합니다. 아래는 환경별로 추가로 알아둘 점입니다.

### Linux

별도 조치 없이 동작합니다. `jq`만 설치돼 있으면 됩니다.

### Windows

Claude Code는 statusline 커맨드를 **Git Bash가 설치돼 있으면 Git Bash로, 없으면 PowerShell로** 실행합니다. 이 플러그인은 bash 스크립트이므로 [Git for Windows](https://gitforwindows.org/) 설치가 필수입니다. 없으면 PowerShell이 스크립트를 해석하지 못해 statusline이 표시되지 않습니다.

- `~`는 `%USERPROFILE%`로 확장되므로 `~/.claude/statusline-dots.sh` 경로가 그대로 동작합니다.
- `~/.claude/settings.json`을 직접 편집한다면 경로에 **슬래시(`/`)만** 쓰세요. Git Bash가 백슬래시를 이스케이프 문자로 처리해 경로가 조용히 깨지고, 오류 메시지도 뜨지 않습니다.
- `jq`가 Git Bash의 `PATH`에 있어야 합니다. Git Bash에서 `which jq`로 확인하세요.

#### 서브에이전트 패널만 안 뜨는 경우 (미검증)

메인 statusline은 나오는데 서브에이전트 패널만 표시되지 않는다면, 이 플러그인의 `settings.json`이 쓰는 `${CLAUDE_PLUGIN_ROOT}` 변수가 Windows에서 백슬래시 경로로 치환되는 것이 원인일 수 있습니다. **이 변수의 Windows 치환 형식은 Claude Code 공식 문서에 명시돼 있지 않아 추정이며, 확인되지 않았습니다.**

해당된다면 메인 statusline과 같은 방식으로 우회할 수 있습니다. Git Bash에서:

```bash
# 설치된 캐시본을 우선 찾고, 없으면 마켓플레이스 체크아웃에서 찾습니다
src=$(find ~/.claude/plugins/cache -name subagent-statusline.sh -path '*statusline-dots*' 2>/dev/null | head -1)
[ -z "$src" ] && src=$(find ~/.claude/plugins -name subagent-statusline.sh -path '*statusline-dots*' 2>/dev/null | head -1)
cp "$src" ~/.claude/subagent-statusline.sh && chmod +x ~/.claude/subagent-statusline.sh
```

그리고 `~/.claude/settings.json`에 다음을 병합하세요. 플러그인 경로 대신 복사본을 직접 가리키므로 변수 치환을 거치지 않습니다.

```json
{
  "subagentStatusLine": {
    "type": "command",
    "command": "~/.claude/subagent-statusline.sh"
  }
}
```

이 방식은 플러그인을 업데이트해도 복사본이 갱신되지 않으므로, 업데이트 후에는 위 `cp`를 다시 실행해야 합니다.

> Windows 동작은 Claude Code 공식 문서를 근거로 작성했으며, 실제 Windows 환경에서 검증되지 않았습니다. 문제를 겪으시거나 위 우회가 효과가 있었다면 이슈로 알려주세요.

## 제거

```
/plugin uninstall statusline-dots@statusline-dots
```

메인 statusline까지 제거하려면 `~/.claude/settings.json`의 `statusLine` 키와 `~/.claude/statusline-dots.sh`를 삭제하세요.

## 라이선스

MIT
