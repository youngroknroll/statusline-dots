---
description: 메인 statusline(3행 도트 스타일)을 사용자 설정에 설치
---

이 플러그인의 메인 statusline 스크립트를 사용자 설정에 설치하세요. 플러그인 settings.json은 `subagentStatusLine`만 지원하므로, 메인 `statusLine`은 이 명령으로 한 번 설치해야 합니다.

다음 단계를 수행하세요:

1. 플러그인 스크립트 경로를 찾습니다. `${CLAUDE_PLUGIN_ROOT}/scripts/statusline-dots.sh`가 비어 있거나 해석되지 않으면 다음으로 찾으세요:
   `find ~/.claude/plugins -name "statusline-dots.sh" -path "*statusline-dots*" 2>/dev/null | head -1`
2. 스크립트를 `~/.claude/statusline-dots.sh`로 복사하고 `chmod +x`를 실행합니다. (플러그인 캐시 경로는 업데이트 시 바뀌므로 반드시 복사본을 참조해야 합니다)
3. `~/.claude/settings.json`에 다음 키를 병합합니다. 기존에 `statusLine` 키가 있으면 사용자에게 교체 여부를 먼저 확인받으세요:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline-dots.sh",
    "refreshInterval": 60
  }
}
```

4. `jq`가 설치돼 있는지 확인하고(`which jq`), 없으면 설치를 안내하세요 (macOS: `brew install jq`, Debian/Ubuntu: `sudo apt install jq`).
5. 다음 샘플 입력으로 스크립트가 정상 렌더링되는지 검증하고 결과를 보여주세요:

```bash
echo '{"model":{"display_name":"Test"},"workspace":{"current_dir":"'$PWD'"},"output_style":{"name":"default"},"context_window":{"context_window_size":200000,"used_percentage":25}}' | ~/.claude/statusline-dots.sh
```
