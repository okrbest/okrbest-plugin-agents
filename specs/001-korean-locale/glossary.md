# 용어집: Agents 플러그인 한국어 번역

FR-007·FR-008의 기준이다. 이후 upstream 반영으로 영어 키가 늘어나면 이 표에 맞춰 채운다.
Mattermost 본체 한국어 번역과 같은 화면에 섞여 보이므로 본체 관례를 우선한다.

## 어조

- 문장은 존댓말 "~합니다 / ~하세요 / ~할 수 없습니다". 명령형 안내는 "~하세요".
- 버튼·메뉴 항목은 명사형 또는 짧은 동사형: "새 채팅", "재생성", "복사", "승인", "거부".
- 설정 항목 이름은 명사구, 콜론은 원문에 있을 때만 유지: "토큰 제한", "API 키".
- 물음표·느낌표·말줄임표는 원문을 따른다. "…" 대신 원문처럼 "..." 사용.
- 자리표시자(`{agent}`, `{count}`, `<b>…</b>`)는 이름 그대로, 조사는 자리표시자 뒤에 붙인다:
  "{agent}에게 물어보세요". 받침 변동이 생기는 조사(이/가, 을/를, 은/는)는 가능한 한
  "에게/의/로"처럼 변동 없는 조사로 문장을 바꾸거나 "(을)를"을 피하고 문장을 재구성한다.

## 원문 유지 (번역하지 않음)

Mattermost, Agents(제품명으로 쓰일 때), MCP, LLM, API, OAuth, JSON, URL, ID, Enterprise,
Professional(플랜 등급명), OpenAI, Anthropic, Azure, AWS Bedrock, Ollama, Grafana, Tempo,
OTLP, Playwright, Markdown, @mention 형식의 사용자명, 코드 조각.

## 핵심 용어

| 영어 | 한국어 | 비고 |
|---|---|---|
| agent | 에이전트 | 봇 역할. "AI 에이전트"로 풀지 않는다 |
| agents (제품명) | Agents | 플러그인 이름으로 쓰일 때 원문 |
| chat | 채팅 | "새 채팅", "채팅 기록" |
| conversation / thread | 대화 / 스레드 | thread는 Mattermost 본체 용어 "스레드" |
| channel / DM / group message | 채널 / 다이렉트 메시지 / 그룹 메시지 | 본체 관례 |
| post / message | 게시물 / 메시지 | 본체 관례 |
| tool | 도구 | "도구 호출", "도구 승인" |
| tool call / approve / reject | 도구 호출 / 승인 / 거부 | |
| review (tool policy) | 검토 | "검토되지 않은 도구" |
| summarize / summary | 요약하다 / 요약 | "스레드 요약", "새 메시지 요약" |
| action items | 액션 아이템 | 기존 초안 유지 |
| open questions | 미해결 질문 | |
| meeting / recording / transcription | 회의 / 녹음 / 전사 | |
| call | 통화 | Mattermost Calls 맥락 |
| search / semantic search / embedding | 검색 / 의미 검색 / 임베딩 | |
| vision | 비전 | 이미지 입력 기능명, 기존 초안 유지 |
| system prompt / custom instructions | 시스템 프롬프트 / 사용자 정의 지시사항 | |
| LLM service / provider | LLM 서비스 / 제공자 | 설정 화면 |
| model | 모델 | |
| token limit / input tokens / output tokens | 토큰 제한 / 입력 토큰 / 출력 토큰 | |
| API key / secret / organization ID | API 키 / 비밀 키 / 조직 ID | |
| streaming | 스트리밍 | |
| regenerate / stop generating | 재생성 / 생성 중지 | |
| copy / edit / delete / rename | 복사 / 편집 / 삭제 / 이름 바꾸기 | 본체 관례 |
| enable / disable / enabled / disabled | 활성화 / 비활성화 / 활성화됨 / 비활성화됨 | |
| allow / block (users, channels) | 허용 / 차단 | |
| permission / access | 권한 / 접근 | |
| System Console | 시스템 콘솔 | 본체 관례 |
| System Admin | 시스템 관리자 | |
| license / plan | 라이선스 / 플랜 | "Enterprise 플랜" |
| upgrade | 업그레이드 | |
| settings / configuration | 설정 / 구성 | 화면 제목은 "설정" |
| default agent | 기본 에이전트 | |
| display name / username | 표시 이름 / 사용자 이름 | 본체 관례 |
| skill(s) | 스킬 | Agents 스킬 기능 |
| personal / shared (skills, agents) | 개인 / 공유 | |
| MCP server / connection | MCP 서버 / 연결 | |
| connect / disconnect / reconnect | 연결 / 연결 해제 / 다시 연결 | |
| workspace | 워크스페이스 | |
| history / version(s) | 기록 / 버전 | "버전 기록" |
| restore | 복원 | |
| artifact | 아티팩트 | HTML 아티팩트 기능 |
| attachment / file | 첨부 파일 / 파일 | |
| error / failed / retry | 오류 / 실패 / 다시 시도 | |
| loading / processing | 불러오는 중 / 처리 중 | |
| cancel / confirm / save / close | 취소 / 확인 / 저장 / 닫기 | |
| learn more | 자세히 알아보기 | 본체 관례 |
| ask anything | 무엇이든 물어보세요 | 기존 초안 유지 |
| brainstorm ideas about | 다음에 대한 아이디어 브레인스토밍 | 기존 초안 유지 |
| trace / telemetry | 추적 / 텔레메트리 | 설정 화면 |
| audit log | 감사 로그 | |

## 복수형 패턴

영어 `{count, plural, one {# tool} other {# tools}}` → 한국어 `{count, plural, other {도구 #개}}`.
단위 명사: 도구 → 개, 에이전트 → 개(또는 "명"이 아닌 "개"로 통일), 스킬 → 개, 버전 → 개,
서비스 → 개, 사용자 → 명, 메시지 → 개.
