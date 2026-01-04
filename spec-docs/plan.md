# Mattermost AI Agents 구현 계획서

> Mattermost 기술 문서 (https://docs.mattermost.com) 기반 사용자 요구사항 대비 구현 방안

---

## 1. 프로젝트 개요

### 1.1 목적
Mattermost 플랫폼에 AI 에이전트 기능을 통합하여 팀 협업 생산성을 향상시키는 플러그인 개발

### 1.2 대상 사용자
- **일반 사용자**: AI 어시스턴트와 대화, 스레드/채널 요약, 시맨틱 검색
- **시스템 관리자**: LLM 서비스 설정, 봇 관리, 접근 제어
- **개발자**: 플러그인 확장, MCP 통합, API 연동

### 1.3 라이선스 요구사항

| 기능 | 라이선스 필요 여부 |
|------|-------------------|
| 기본 에이전트 설정 (1개) | 불필요 |
| DM/채널에서 에이전트와 대화 | 불필요 |
| 이미지 분석 (Vision) | 불필요 |
| 기본 도구 통합 | 불필요 |
| 다중 에이전트 구성 | Entry 이상 |
| 세부 접근 제어 | Entry 이상 |
| 시맨틱 검색 (Embedding Search) | Entry 이상 |
| MCP 지원 | Entry 이상 |
| 토큰 사용량 추적 | Entry 이상 |
| AI Actions 메뉴 | Entry 이상 |
| 채널/미팅 요약 | Entry 이상 |

---

## 2. 사용자 요구사항 분석

### 2.1 핵심 기능 요구사항

| # | 요구사항 | 우선순위 | 상태 |
|---|----------|---------|------|
| F-01 | AI 봇과 자연어 대화 | 높음 | ✅ 구현됨 |
| F-02 | 스레드 요약 기능 | 높음 | ✅ 구현됨 |
| F-03 | 채널 미읽은 메시지 요약 | 높음 | ✅ 구현됨 |
| F-04 | 시맨틱 검색 | 중간 | ✅ 구현됨 |
| F-05 | 이미지 분석 (Vision) | 중간 | ✅ 구현됨 |
| F-06 | 미팅 녹화 요약 | 중간 | ✅ 구현됨 |
| F-07 | 외부 도구 통합 (Jira, GitHub) | 중간 | ✅ 구현됨 |
| F-08 | MCP 서버 연동 | 낮음 | ✅ 구현됨 |
| F-09 | 다중 LLM 제공자 지원 | 높음 | ✅ 구현됨 |
| F-10 | 사용자별 접근 제어 | 높음 | ✅ 구현됨 |

### 2.2 비기능 요구사항

| # | 요구사항 | 우선순위 | 상태 |
|---|----------|---------|------|
| NF-01 | 응답 스트리밍 지원 | 높음 | ✅ 구현됨 |
| NF-02 | 토큰 사용량 추적 | 중간 | ✅ 구현됨 |
| NF-03 | Prometheus 메트릭스 | 중간 | ✅ 구현됨 |
| NF-04 | 다국어 지원 (i18n) | 중간 | ✅ 구현됨 |
| NF-05 | Enterprise 라이선스 연동 | 높음 | ✅ 구현됨 |

---

## 3. 요구사항별 구현 방안

### 3.1 F-01: AI 봇과 자연어 대화

#### Mattermost 기술 기반
- **Plugin Hook**: `MessageHasBeenPosted` - 메시지 수신 감지
- **API**: `Client4.CreatePost` - 응답 게시
- **Bot API**: 플러그인 봇 계정 자동 생성

#### 구현 방안
```
사용자 메시지 → MessageHasBeenPosted Hook → 봇 DM 여부 확인
→ 스레드 컨텍스트 로드 → LLM 요청 구성 → 스트리밍 응답
→ Post 생성/업데이트
```

#### 관련 코드
- `conversations/conversations.go` - 대화 흐름 관리
- `streaming/streaming.go` - 응답 스트리밍
- `bots/bots.go` - 봇 인스턴스 관리

#### 확장 포인트
- 사용자 지정 프롬프트 (Custom Instructions)
- 모델별 파라미터 조정
- 대화 히스토리 길이 제한

---

### 3.2 F-02/F-03: 스레드/채널 요약

#### Mattermost 기술 기반
- **Plugin API**: `GetPostThread`, `GetPostsSince` - 스레드/채널 게시물 조회
- **Webapp**: 커스텀 RHS (Right-Hand Sidebar) 컴포넌트
- **Post Actions**: 메시지 호버 시 AI Actions 메뉴

#### 구현 방안
```
AI Actions 메뉴 클릭 → 스레드/채널 게시물 조회 
→ 포맷팅 (사용자명, 시간 등) → LLM 요약 요청
→ RHS에 결과 표시
```

#### 관련 코드
- `threads/` - 스레드 요약 로직
- `channels/` - 채널 요약 로직
- `prompts/summarize_thread_system.tmpl` - 요약 프롬프트

#### 프롬프트 템플릿 예시
```
You are a helpful assistant that summarizes discussion threads.
The thread contains messages from these users: {{.Users}}

Thread content:
{{.Thread}}

Please provide a concise summary...
```

---

### 3.3 F-04: 시맨틱 검색 (Embedding Search)

#### Mattermost 기술 기반
- **Database**: PostgreSQL + pgvector 확장
- **Enterprise Feature**: 라이선스 검증 필요
- **Hook**: `MessageHasBeenPosted/Updated/Deleted` - 인덱스 동기화

#### 구현 방안
```
[인덱싱]
게시물 생성/수정 → Hook 감지 → 청킹 → 임베딩 생성 → pgvector 저장

[검색]
검색 쿼리 → 쿼리 임베딩 생성 → 벡터 유사도 검색
→ 권한 필터링 → 결과 반환
```

#### pgvector 스키마
```sql
CREATE TABLE llm_posts_embeddings (
    id TEXT PRIMARY KEY,
    post_id TEXT NOT NULL REFERENCES Posts(Id),
    embedding vector(1536),  -- OpenAI text-embedding-3-small
    content TEXT,
    -- 메타데이터
    team_id TEXT,
    channel_id TEXT,
    user_id TEXT,
    created_at BIGINT,
    -- 청킹 정보
    is_chunk BOOLEAN,
    chunk_index INTEGER,
    total_chunks INTEGER
);

CREATE INDEX ON llm_posts_embeddings 
    USING hnsw (embedding vector_l2_ops);
```

#### 제약사항
- **pgvector HNSW 인덱스**: 최대 2000 dimensions
- **권장 설정**: `text-embedding-3-small` (1536 dims) 또는 `text-embedding-3-large` (2000 dims로 축소)

---

### 3.4 F-05: 이미지 분석 (Vision)

#### Mattermost 기술 기반
- **File API**: `GetFile` - 첨부 파일 조회
- **Model Capability**: Vision 지원 모델 필요 (GPT-4o, Claude 3 등)

#### 구현 방안
```
메시지 + 이미지 첨부 → 파일 ID 추출 → 이미지 다운로드
→ Base64 인코딩 → LLM Vision API 호출 → 분석 결과 응답
```

#### 지원 형식
- JPEG, PNG, GIF, WebP
- 최대 파일 크기: 모델별 상이 (일반적으로 20MB)

---

### 3.5 F-06: 미팅 녹화 요약

#### Mattermost 기술 기반
- **Calls Plugin**: 녹화/트랜스크립션 제공
- **Integration**: Calls 플러그인 이벤트 연동

#### 구현 방안
```
통화 종료 → 트랜스크립션 생성 완료 → 요약 요청
→ 트랜스크립션 로드 → LLM 요약 → DM으로 결과 전송
```

#### 관련 코드
- `meetings/meetings.go` - 미팅 요약 서비스
- `subtitles/` - 자막/트랜스크립션 파싱

---

### 3.6 F-07: 외부 도구 통합

#### 도구 목록

| 도구 | 설명 | 요구사항 |
|------|------|---------|
| Server Search | Mattermost 시맨틱 검색 | Embedding Search 설정 |
| User Lookup | 사용자 정보 조회 | VIEW_MEMBERS 권한 |
| Jira | Jira 이슈 조회 | 공개 Jira 인스턴스 |
| GitHub | Issue/PR 조회 | GitHub 플러그인 설치 |

#### 구현 방안 (Function Calling)
```go
// llm/tools.go
type Tool struct {
    Name        string
    Description string
    Parameters  map[string]interface{}
    Handler     ToolHandler
}

// 도구 실행 흐름
LLM 응답 (tool_call) → 도구 선택 → 사용자 승인 요청
→ 승인 시 도구 실행 → 결과를 컨텍스트에 추가 → LLM 재호출
```

#### 보안 고려사항
- 도구 호출은 **DM에서만** 허용
- 각 도구 호출 시 **사용자 명시적 승인** 필요
- 결과는 사용자 권한 범위 내에서만 반환

---

### 3.7 F-08: MCP (Model Context Protocol) 통합

#### Mattermost 기술 기반
- **OAuth 2.0**: MCP 서버 인증
- **Plugin KV Store**: OAuth 토큰 저장
- **HTTP Client**: MCP 서버 통신

#### 구현 방안
```
[초기 설정]
MCP 서버 URL 등록 → OAuth 흐름 → 토큰 저장

[도구 호출]
MCP 도구 목록 캐싱 → 사용자 요청 시 도구 호출
→ 결과 반환
```

#### 지원 기능
- SSE (Server-Sent Events) 트랜스포트
- HTTP Streamable 트랜스포트
- OAuth 2.0 인증
- 도구 목록 캐싱

---

### 3.8 F-09: 다중 LLM 제공자 지원

#### 지원 제공자

| 제공자 | 인증 방식 | 특이사항 |
|--------|----------|---------|
| OpenAI | API Key | Responses API 지원 |
| Anthropic | API Key | Extended Thinking 지원 |
| Azure OpenAI | API Key + Endpoint | 기업용 |
| AWS Bedrock | IAM / Access Key | 다중 인증 방식 |
| OpenAI Compatible | API Key (선택) | Ollama, vLLM 등 |
| Cohere | API Key | - |
| Mistral | API Key | - |

#### 구현 방안
```go
// llm/language_model.go - 공통 인터페이스
type LanguageModel interface {
    ChatCompletion(req CompletionRequest, opts ...Option) (*TextStreamResult, error)
    ChatCompletionNoStream(req CompletionRequest, opts ...Option) (string, error)
    CountTokens(text string) int
    InputTokenLimit() int
}

// 제공자별 구현
// openai/openai.go
// anthropic/anthropic.go
// bedrock/bedrock.go
```

---

### 3.9 F-10: 접근 제어

#### Mattermost 기술 기반
- **Team/Channel Membership**: 팀/채널 멤버십 확인
- **User Roles**: 사용자 역할 기반 권한

#### 구현 방안
```go
// llm/configuration.go
type BotConfig struct {
    ChannelAccessLevel ChannelAccessLevel  // All, Allow, Block
    ChannelIDs         []string
    UserAccessLevel    UserAccessLevel     // All, Allow, Block
    UserIDs            []string
}

// 접근 제어 로직
// 1. 사용자 레벨 제한 확인
// 2. 채널 레벨 제한 확인
// 3. 둘 다 통과 시 접근 허용
```

---

## 4. 기술 구현 세부사항

### 4.1 Mattermost Plugin 아키텍처 활용

#### 서버 훅 (Server Hooks)

| 훅 | 용도 | 구현 위치 |
|----|------|----------|
| `OnActivate` | 플러그인 초기화 | `server/main.go` |
| `OnDeactivate` | 리소스 정리 | `server/main.go` |
| `OnConfigurationChange` | 설정 변경 감지 | `server/configuration.go` |
| `MessageHasBeenPosted` | 새 메시지 처리 | `server/main.go` |
| `MessageHasBeenUpdated` | 메시지 수정 시 재인덱싱 | `server/main.go` |
| `MessageHasBeenDeleted` | 인덱스에서 삭제 | `server/main.go` |
| `ServeHTTP` | API 요청 처리 | `api/api.go` |
| `ServeMetrics` | 메트릭스 엔드포인트 | `api/api.go` |

#### Webapp 확장

| 확장점 | 용도 | 구현 위치 |
|--------|------|----------|
| `RightHandSidebarComponent` | RHS 패널 | `webapp/src/components/rhs/` |
| `PostDropdownMenuComponent` | AI Actions 메뉴 | `webapp/src/index.tsx` |
| `SystemConsoleSection` | 관리 콘솔 | `webapp/src/components/system_console/` |

### 4.2 API 엔드포인트 설계

```
Plugin Base: /plugins/mattermost-ai

# 사용자 API
GET  /ai_threads              # AI 스레드 목록
GET  /ai_bots                 # 사용 가능한 봇 목록
POST /post/:postid/react      # 이모지 반응 생성
POST /post/:postid/analyze    # 스레드 분석
POST /post/:postid/stop       # 생성 중지
POST /post/:postid/regenerate # 재생성

# 검색 API
POST /search                  # 검색 쿼리
POST /search/run              # 검색 실행 (DM 응답)

# 채널 API
POST /channel/:channelid/interval  # 채널 범위 분석

# 관리자 API
POST /admin/reindex           # 재인덱싱 시작
GET  /admin/reindex/status    # 인덱싱 상태
POST /admin/reindex/cancel    # 인덱싱 취소
GET  /admin/mcp/tools         # MCP 도구 목록
POST /admin/models/fetch      # 모델 목록 가져오기

# Inter-Plugin API (LLM Bridge)
GET  /bridge/v1/agents        # 에이전트 목록
GET  /bridge/v1/services      # 서비스 목록
POST /bridge/v1/completion/agent/:agent      # 에이전트 완성
POST /bridge/v1/completion/service/:service  # 서비스 완성

# MCP 서버 API
ANY  /mcp-server/mcp          # MCP 엔드포인트
GET  /mcp-server/.well-known/oauth-protected-resource
```

### 4.3 데이터 흐름

```
┌─────────────────────────────────────────────────────────────────┐
│                        사용자 요청                               │
│  (DM 메시지 / AI Actions / 검색 / API 호출)                      │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      권한 검증 계층                              │
│  - 사용자 인증 (Mattermost Session)                             │
│  - 봇 접근 권한 (User/Channel Access Level)                      │
│  - 채널 멤버십 검증                                              │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      컨텍스트 구성                               │
│  - 시스템 프롬프트 로드                                          │
│  - 대화 히스토리 수집                                            │
│  - 도구 정보 주입 (MCP + 내장)                                   │
│  - 토큰 제한에 맞게 truncation                                   │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      LLM 요청/응답                               │
│  - 제공자별 API 호출 (OpenAI/Anthropic/Bedrock/...)             │
│  - 스트리밍 응답 처리                                            │
│  - 도구 호출 감지 및 실행                                        │
│  - 토큰 사용량 기록                                              │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      결과 전달                                   │
│  - Post 생성/업데이트 (스트리밍)                                 │
│  - RHS 표시 (요약/검색 결과)                                     │
│  - 메트릭스 기록                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. 배포 및 운영 가이드

### 5.1 사전 요구사항

| 항목 | 요구사항 |
|------|---------|
| Mattermost Server | v10.0 이상 (권장: v10.3+) |
| Database | PostgreSQL |
| 시맨틱 검색 사용 시 | PostgreSQL + pgvector 확장 |
| LLM 접근 | API Key 또는 네트워크 접근 |
| Enterprise 기능 | Entry/Enterprise 라이선스 |

### 5.2 설치 방법

#### 방법 1: 사전 설치 (Mattermost v10.3+)
- 기본 설치됨, System Console에서 설정만 필요

#### 방법 2: 수동 설치
```bash
# 빌드
make dist

# 배포 (로컬 개발)
make deploy

# 또는 System Console > Plugin Management에서 업로드
# dist/mattermost-ai-x.x.x.tar.gz
```

### 5.3 설정 체크리스트

```yaml
필수 설정:
  - [ ] LLM 서비스 추가 (API Key, 모델 선택)
  - [ ] 기본 봇 생성
  - [ ] Site URL 설정 확인

선택 설정:
  - [ ] 추가 봇 생성 (Enterprise)
  - [ ] 접근 제어 설정 (Enterprise)
  - [ ] Embedding Search 설정 (Enterprise)
  - [ ] MCP 서버 연동 (Enterprise)
  - [ ] 토큰 사용량 로깅 활성화
```

### 5.4 모니터링

#### 메트릭스 엔드포인트
```
GET /plugins/mattermost-ai/metrics

# 주요 메트릭스
- agents_http_requests_total
- agents_http_errors_total
- agents_llm_requests_total
- agents_api_time_seconds
```

#### 로깅
```bash
# 일반 로그
grep "plugin_id\":\"mattermost-ai" /path/to/mattermost.log

# 토큰 사용량 로그
cat /path/to/logs/agents/token_usage.log | jq .

# CSV 변환
jq -r '[.timestamp, .user_id, .bot_username, .total_tokens] | @csv' \
  logs/agents/token_usage.log > usage.csv
```

---

## 6. 향후 개선 계획

### 6.1 단기 (1-3개월)

| 항목 | 설명 | 우선순위 |
|------|------|---------|
| 프롬프트 캐싱 | Anthropic/OpenAI 캐싱 활용 | 높음 |
| 배치 임베딩 최적화 | 대량 인덱싱 성능 개선 | 중간 |
| 추가 MCP 서버 지원 | 인기 서버 통합 가이드 | 중간 |

### 6.2 중기 (3-6개월)

| 항목 | 설명 | 우선순위 |
|------|------|------|
| RAG 고도화 | 하이브리드 검색, 재순위화 | 높음 |
| 멀티모달 확장 | 문서 분석, 오디오 처리 | 중간 |
| 워크플로우 자동화 | 반복 작업 자동화 | 낮음 |

### 6.3 장기 (6개월+)

| 항목 | 설명 | 우선순위 |
|------|------|---------|
| 에이전트 체인 | 다중 에이전트 협업 | 중간 |
| 지식 베이스 | 조직별 지식 저장소 | 중간 |
| Fine-tuning 지원 | 조직 맞춤 모델 | 낮음 |

---

## 7. 참고 문서

### Mattermost 공식 문서
- [Plugin Development](https://developers.mattermost.com/integrate/plugins/)
- [Server Plugin Reference](https://developers.mattermost.com/integrate/plugins/server/)
- [Webapp Plugin Reference](https://developers.mattermost.com/integrate/plugins/webapp/)
- [Plugin API](https://pkg.go.dev/github.com/mattermost/mattermost/server/public/plugin)

### AI Agents 플러그인 문서
- [Admin Guide](./docs/admin_guide.md)
- [User Guide](./docs/user_guide.md)
- [Provider Configuration](./docs/providers.md)

### 외부 참고
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)
- [Anthropic API Reference](https://docs.anthropic.com/claude/reference)
- [AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [pgvector Documentation](https://github.com/pgvector/pgvector)

---

*문서 작성일: 2025-12-10*
*기반: Mattermost v11.2, AI Agents Plugin*

