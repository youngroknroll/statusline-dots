# statusline-dots

Claude Code용 3행 도트 스타일 statusline + 서브에이전트 패널 커스텀 행 플러그인.

```
Fable 5 (1M context) | 🧠 high | 📂 my-project (main*) | ◑ default | ⚡ 4097f271
current ▓▓▓▓▓░░░░░ 53% ↻8:41am (in 3h27m) | weekly ▓▓▓░░░░░░░ 30% ↻jul 19, 7:14am (in 1d2h)
context ▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 14%
```

서브에이전트 패널:

```
● backend-tdd-coach → API 마이그레이션 검토 중 · 45.2k (22%)
✓ code-reviewer → 리뷰 완료 · 37.1k (18%)
● Explore → 테스트 파일 비교 중 · 12.0k (6%)
```

## 표시 항목

- **1행**: 모델명(컨텍스트 크기) · 🧠 effort 레벨 · 📂 폴더명(git 브랜치, dirty `*`) · ◑ output style · ⚡ 세션 ID 앞 8자리
- **2행**: 5시간 사용 한도(`current`)와 주간 한도(`weekly`) — 사용률 바 + 리셋 시각/카운트다운
- **3행**: 컨텍스트 창 사용량 바 + %
- 색상: 사용률 50%↑ 노랑, 80%↑ 빨강 / effort는 high=노랑, xhigh·max=빨강, 그 외 초록
- effort·세션 ID 등 데이터가 없는 세그먼트는 자동으로 숨겨짐
- 서브에이전트 이름: 에이전트 타입(예: `code-reviewer`, `Explore`)을 자동 표시 — 이름별로 고정 색상 배정. Claude Code가 stdin에 이름을 주지 않으므로 task id로 세션의 `subagents/agent-<id>.meta.json`에서 `agentType`을 조회
- 서브에이전트 작업설명·토큰 사용량(컨텍스트 창을 알면 `%`)은 Claude Code가 native로 제공 — 추가 비용 없음
- 서브에이전트 상태 아이콘: ● 실행 중 / ✓ 완료 / ✗ 실패 / ⏸ 대기(blocked·waiting)

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

## 제거

```
/plugin uninstall statusline-dots@statusline-dots
```

메인 statusline까지 제거하려면 `~/.claude/settings.json`의 `statusLine` 키와 `~/.claude/statusline-dots.sh`를 삭제하세요.

## 라이선스

MIT
