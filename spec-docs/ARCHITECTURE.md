# Mattermost AI Agents Plugin - 아키텍처 문서

## 개요

이 프로젝트는 Mattermost 플랫폼을 위한 AI 에이전트 플러그인입니다. 다양한 LLM 제공자(OpenAI, Anthropic, AWS Bedrock 등)와 통합하여 채팅 기반의 AI 어시스턴트 기능을 제공합니다.

---

## 1. 저장소/빌드/실행 정보

### 기술 스택

| 구분 | 기술 |
|------|------|
| **Backend** | Go 1.24.6 |
| **Frontend** | React, TypeScript, styled-components |
| **Database** | PostgreSQL (Mattermost DB 공유) + pgvector |
| **빌드 도구** | Make, npm |
| **테스트** | Go test, Playwright (E2E), Jest |

### 주요 의존성

```
# Backend
- github.com/mattermost/mattermost/server/public  # Mattermost Plugin API
- github.com/gin-gonic/gin                        # HTTP Router
- github.com/anthropics/anthropic-sdk-go          # Anthropic Claude
- github.com/openai/openai-go/v2                  # OpenAI
- github.com/aws/aws-sdk-go-v2                    # AWS Bedrock
- github.com/modelcontextprotocol/go-sdk          # MCP (Model Context Protocol)
- github.com/pgvector/pgvector-go                 # Vector DB

# Frontend
- @mattermost/client                              # Mattermost JS Client
- react-intl                                      # i18n
- styled-components                               # CSS-in-JS
```

### 빌드 명령어

```bash
# 전체 빌드 (린트 + 테스트 + 배포 패키지 생성)
make all

# 개발용 빌드 및 배포
make deploy

# 테스트
make test

# E2E 테스트
make e2e

# 프롬프트 평가 (CI 모드)
make evals-ci
```

### 실행 환경

플러그인은 Mattermost 서버의 플러그인 런타임에서 실행됩니다:

```
Mattermost Server
└── Plugin Runtime
    └── mattermost-ai (이 플러그인)
        ├── Server Binary (Go)
        └── Webapp Bundle (React)
```

---

## 2. 디렉터리 구조 맵

```
okrbest-plugin-agents/
├── server/                    # 플러그인 메인 엔트리포인트
│   ├── main.go               # Plugin 구조체, 라이프사이클 훅
│   ├── configuration.go      # 설정 로드/업데이트
│   └── migrations.go         # 설정 마이그레이션
│
├── api/                       # HTTP API 핸들러
│   ├── api.go                # 라우터 설정, 미들웨어
│   ├── api_post.go           # 포스트 관련 API
│   ├── api_channel.go        # 채널 분석 API
│   ├── api_search.go         # 검색 API
│   ├── api_admin.go          # 관리자 API (재인덱싱 등)
│   └── api_llm_bridge.go     # 플러그인 간 LLM 브릿지 API
│
├── bots/                      # 봇 관리
│   ├── bots.go               # 봇 레지스트리
│   ├── bot.go                # 개별 봇 인스턴스
│   ├── permissions.go        # 접근 제어
│   └── mentions.go           # 멘션 처리
│
├── llm/                       # LLM 공통 인터페이스
│   ├── language_model.go     # LanguageModel 인터페이스
│   ├── configuration.go      # ServiceConfig, BotConfig
│   ├── completion_request.go # 요청/응답 구조체
│   ├── stream.go             # 스트리밍 처리
│   ├── tools.go              # Function Calling 도구
│   ├── prompts.go            # 프롬프트 템플릿 관리
│   └── token_tracking.go     # 토큰 사용량 추적
│
├── openai/                    # OpenAI 구현
│   └── openai.go             # OpenAI/Azure/Compatible API
│
├── anthropic/                 # Anthropic 구현
│   └── anthropic.go          # Claude API
│
├── bedrock/                   # AWS Bedrock 구현
│   └── bedrock.go            # Bedrock API
│
├── conversations/             # 대화 관리
│   ├── conversations.go      # 대화 흐름 처리
│   └── store.go              # 스레드 저장소
│
├── search/                    # 시맨틱 검색
│   ├── search.go             # 검색 서비스
│   └── embeddings.go         # 임베딩 초기화
│
├── embeddings/                # 임베딩 인터페이스
│   ├── embeddings.go         # 인터페이스 정의
│   └── composite.go          # Composite 검색 구현
│
├── postgres/                  # pgvector 구현
│   └── pgvector.go           # 벡터 저장소
│
├── indexer/                   # 포스트 인덱싱
│   ├── indexer.go            # 인덱서 서비스
│   └── indexer_job.go        # 재인덱싱 작업
│
├── mcp/                       # Model Context Protocol
│   ├── client_manager.go     # MCP 클라이언트 관리
│   ├── oauth_manager.go      # OAuth 흐름
│   └── tools_cache.go        # 도구 캐싱
│
├── mcpserver/                 # 내장 MCP 서버
│   └── plugin_handlers.go    # MCP 핸들러
│
├── streaming/                 # 스트리밍 서비스
│   └── streaming.go          # 포스트 스트리밍
│
├── meetings/                  # 미팅 기능
│   └── meetings.go           # 회의 요약
│
├── mmapi/                     # Mattermost API 래퍼
│   ├── client.go             # API 클라이언트
│   └── db.go                 # DB 클라이언트
│
├── mmtools/                   # 내장 도구
│   ├── provider.go           # 도구 제공자
│   └── search.go             # 검색 도구
│
├── config/                    # 설정 관리
│   └── config.go             # Config 구조체
│
├── database/                  # DB 스키마
│   └── schema.go             # 테이블 생성
│
├── prompts/                   # 프롬프트 템플릿
│   ├── *.tmpl                # Go 템플릿 파일들
│   └── prompts.go            # 임베드 설정
│
├── webapp/                    # 프론트엔드
│   └── src/
│       ├── index.tsx         # 플러그인 진입점
│       ├── client.tsx        # API 클라이언트
│       ├── bots.tsx          # 봇 상태 관리
│       └── components/       # React 컴포넌트
│           ├── rhs/          # 우측 사이드바
│           ├── llmbot_post/  # AI 응답 포스트
│           └── system_console/ # 관리 콘솔
│
├── e2e/                       # E2E 테스트
│   └── tests/                # Playwright 테스트
│
├── evals/                     # 프롬프트 평가
│   └── evals.go              # 평가 프레임워크
│
└── enterprise/                # 엔터프라이즈 기능
    └── license.go            # 라이선스 체크
```

---

## 3. 실행 흐름 (런타임 플로우)

### 3.1 플러그인 초기화 흐름

```
┌─────────────────────────────────────────────────────────────┐
│                    Mattermost Server                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  Plugin.OnActivate()                        │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 1. pluginAPI 초기화                                  │   │
│  │ 2. HTTP 클라이언트 생성 (LLM용, 외부용)              │   │
│  │ 3. 설정 마이그레이션 실행                            │   │
│  │ 4. Bots 서비스 초기화 → EnsureBots()                │   │
│  │ 5. Database 테이블 생성                              │   │
│  │ 6. Prompts 로드                                      │   │
│  │ 7. Embeddings Search 초기화 (라이선스 필요)          │   │
│  │ 8. Indexer, Search, MCP 서비스 초기화               │   │
│  │ 9. Conversations, Meetings 서비스 초기화             │   │
│  │ 10. API 라우터 생성                                  │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 대화 처리 흐름 (DM)

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  User Message    │────▶│  MessagePosted   │────▶│  Conversations   │
│  (봇 DM)         │     │  Hook            │     │  Service         │
└──────────────────┘     └──────────────────┘     └──────────────────┘
                                                           │
                    ┌──────────────────────────────────────┘
                    ▼
┌───────────────────────────────────────────────────────────────────┐
│                    handleDMToBot()                                │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ 1. 사용자/채널 권한 확인                                     │ │
│  │ 2. 스레드 히스토리 조회 (이전 대화)                          │ │
│  │ 3. LLM Context 구성                                          │ │
│  │    - System Prompt (프롬프트 템플릿)                         │ │
│  │    - 도구 정보 (MCP + 내장 도구)                             │ │
│  │    - 대화 히스토리                                           │ │
│  │ 4. Bot.LLM().ChatCompletion() 호출                           │ │
│  │ 5. 스트리밍 응답 처리 → Post 업데이트                        │ │
│  │ 6. Tool Call 감지 시 도구 실행 → 재귀 호출                   │ │
│  └─────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────┘
```

### 3.3 HTTP API 요청 흐름

```
┌─────────┐     ┌─────────────┐     ┌─────────────┐     ┌───────────┐
│ Client  │────▶│ ServeHTTP() │────▶│ Gin Router  │────▶│ Handler   │
└─────────┘     └─────────────┘     └─────────────┘     └───────────┘
                                           │
                    ┌──────────────────────┼──────────────────────┐
                    │                      │                      │
                    ▼                      ▼                      ▼
            ┌───────────────┐      ┌───────────────┐      ┌───────────────┐
            │ Middleware    │      │ Middleware    │      │ Middleware    │
            │ - Auth        │      │ - Bot Check   │      │ - Post Auth   │
            └───────────────┘      └───────────────┘      └───────────────┘
```

---

## 4. 핵심 모듈/컴포넌트 설명

### 4.1 LLM 추상화 계층

```go
// llm/language_model.go
type LanguageModel interface {
    ChatCompletion(request CompletionRequest, opts ...CompletionRequestOption) (*TextStreamResult, error)
    ChatCompletionNoStream(request CompletionRequest, opts ...CompletionRequestOption) (string, error)
    CountTokens(text string) int
    InputTokenLimit() int
}
```

**지원 제공자:**
- `openai/` - OpenAI GPT, Azure OpenAI, OpenAI Compatible API
- `anthropic/` - Claude 모델
- `bedrock/` - AWS Bedrock (Claude, Titan 등)
- `asage/` - Azure OpenAI 별도 구현

### 4.2 봇 관리 시스템

```go
// bots/bots.go
type MMBots struct {
    bots []*Bot  // 활성 봇 인스턴스들
}

// bots/bot.go  
type Bot struct {
    mmBot  *model.Bot       // Mattermost 봇 엔티티
    cfg    llm.BotConfig    // 봇 설정
    llm    llm.LanguageModel // LLM 인스턴스
}
```

**주요 기능:**
- 봇 생성/업데이트 자동화 (`EnsureBots`)
- 채널/사용자 접근 제어
- 서비스-봇 매핑 관리

### 4.3 대화 서비스

```go
// conversations/conversations.go
type Conversations struct {
    prompts          *llm.Prompts
    mmclient         mmapi.Client
    streamingService streaming.Service
    contextBuilder   *llmcontext.Builder
    bots             *bots.MMBots
    // ...
}
```

**책임:**
- DM 메시지 처리
- 스레드 컨텍스트 관리
- 도구 호출 조율
- 응답 스트리밍

### 4.4 시맨틱 검색 시스템

```
┌──────────────────────────────────────────────────────────────┐
│                    Search System                             │
│  ┌───────────────┐   ┌──────────────────┐   ┌─────────────┐ │
│  │ EmbeddingSearch│◀─▶│ EmbeddingProvider │◀─▶│  OpenAI    │ │
│  │ (Composite)   │   │ (Interface)       │   │ Embeddings │ │
│  └───────────────┘   └──────────────────┘   └─────────────┘ │
│         │                                                    │
│         ▼                                                    │
│  ┌───────────────┐                                          │
│  │  VectorStore  │◀────────────────────────────────────────┐│
│  │  (pgvector)   │   PostgreSQL + pgvector Extension      ││
│  └───────────────┘                                          │
└──────────────────────────────────────────────────────────────┘
```

**요구사항:** Enterprise 라이선스, pgvector 확장

### 4.5 MCP (Model Context Protocol)

```go
// mcp/client_manager.go
type ClientManager struct {
    mcpClients    map[string]*MCPClient
    oauthManager  *OAuthManager
    toolsCache    *ToolsCache
    embeddedServer EmbeddedMCPServer
}
```

**기능:**
- 외부 MCP 서버 연결 관리
- OAuth 인증 흐름
- 도구 목록 캐싱
- 내장 MCP 서버 제공

---

## 5. 데이터 모델/저장소 접근

### 5.1 데이터베이스 테이블

#### LLM_PostMeta
스레드 제목 저장용
```sql
CREATE TABLE LLM_PostMeta (
    RootPostID TEXT PRIMARY KEY REFERENCES Posts(ID) ON DELETE CASCADE,
    Title TEXT NOT NULL
);
```

#### llm_posts_embeddings
벡터 검색용 (pgvector)
```sql
CREATE TABLE llm_posts_embeddings (
    id TEXT PRIMARY KEY,
    post_id TEXT NOT NULL REFERENCES Posts(Id) ON DELETE CASCADE,
    team_id TEXT NOT NULL,
    channel_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    content TEXT NOT NULL,
    embedding vector(N),  -- dimensions 설정값
    created_at BIGINT NOT NULL,
    is_chunk BOOLEAN DEFAULT FALSE,
    chunk_index INTEGER,
    total_chunks INTEGER
);
```

### 5.2 플러그인 설정 저장

설정은 Mattermost의 플러그인 설정 시스템을 통해 저장됩니다:
```
PluginSettings.Plugins["mattermost-ai"].config
├── services[]      # LLM 서비스 목록 (API Key 포함)
├── bots[]          # 봇 설정 목록
├── defaultBotName  # 기본 봇 이름
└── embeddingSearchConfig  # 검색 설정
```

### 5.3 주요 데이터 흐름

```
┌─────────────────────────────────────────────────────────────┐
│                        데이터 소스                          │
├──────────────┬──────────────┬──────────────┬───────────────┤
│ Posts        │ Channels     │ Users        │ Teams         │
│ (Mattermost) │ (Mattermost) │ (Mattermost) │ (Mattermost)  │
└──────────────┴──────────────┴──────────────┴───────────────┘
       │                │              │              │
       ▼                ▼              ▼              ▼
┌─────────────────────────────────────────────────────────────┐
│                      mmapi.Client                           │
│   - pluginAPI 래퍼                                          │
│   - 권한 검증 포함                                          │
└─────────────────────────────────────────────────────────────┘
```

---

## 6. 외부 연동/인터페이스

### 6.1 LLM 제공자 연동

| 제공자 | 엔드포인트 | 인증 방식 |
|--------|-----------|----------|
| OpenAI | `api.openai.com` | API Key |
| Anthropic | `api.anthropic.com` | API Key |
| Azure OpenAI | `*.openai.azure.com` | API Key |
| AWS Bedrock | AWS SDK | IAM / Access Key |
| OpenAI Compatible | 사용자 지정 | API Key (선택) |

### 6.2 Inter-Plugin API (LLM Bridge)

다른 플러그인에서 AI 기능 사용 가능:

```
POST /plugins/mattermost-ai/bridge/v1/completion/agent/:agent
POST /plugins/mattermost-ai/bridge/v1/completion/service/:service
GET  /plugins/mattermost-ai/bridge/v1/agents
GET  /plugins/mattermost-ai/bridge/v1/services
```

**인증:** `Mattermost-Plugin-ID` 헤더 필수

### 6.3 MCP 서버 연동

```yaml
# 설정 예시
mcp:
  servers:
    - name: "github"
      url: "https://github.com/modelcontextprotocol/servers/github"
      oauth:
        clientId: "xxx"
        clientSecret: "yyy"
```

### 6.4 Webhook/이벤트

플러그인이 구독하는 Mattermost 훅:
- `MessageHasBeenPosted` - 새 메시지 (봇 대화, 인덱싱)
- `MessageHasBeenUpdated` - 메시지 수정 (재인덱싱)
- `MessageHasBeenDeleted` - 메시지 삭제 (인덱스 제거)
- `EmailNotificationWillBeSent` - 봇 알림 차단
- `NotificationWillBePushed` - 봇 푸시 알림 차단

---

## 7. 설정/구성 (Configurability)

### 7.1 서비스 설정 구조

```go
type ServiceConfig struct {
    ID                      string
    Name                    string
    Type                    string  // openai, anthropic, bedrock, azure, openaicompatible
    APIKey                  string
    APIURL                  string
    DefaultModel            string
    InputTokenLimit         int
    OutputTokenLimit        int
    StreamingTimeoutSeconds int
    SendUserID              bool
    UseResponsesAPI         bool  // OpenAI Responses API 사용
}
```

### 7.2 봇 설정 구조

```go
type BotConfig struct {
    ID                 string
    Name               string
    DisplayName        string
    ServiceID          string  // 연결된 서비스
    CustomInstructions string
    EnableVision       bool
    DisableFunctions   bool
    EnabledNativeTools []string
    ChannelAccessLevel ChannelAccessLevel
    ChannelIDs         []string
    UserAccessLevel    UserAccessLevel
    UserIDs            []string
    ReasoningEnabled   bool
    ReasoningEffort    string
}
```

### 7.3 환경 변수

| 변수 | 용도 |
|------|------|
| `MM_CLOUD_INSTALLATION_ID` | Cloud 인스턴스 식별 |
| `OPENAI_API_KEY` | 평가용 OpenAI 키 |
| `ANTHROPIC_API_KEY` | 평가용 Anthropic 키 |
| `LLM_PROVIDER` | 평가 제공자 선택 |

### 7.4 설정 마이그레이션

`server/migrations.go`에서 버전별 설정 마이그레이션 처리:
- 서비스/봇 ID 자동 생성
- 레거시 설정 포맷 변환
- 기본값 설정

---

## 8. 에러 처리/로깅/관측성 (Observability)

### 8.1 로깅

```go
// Mattermost Plugin API 로깅 사용
pluginAPI.Log.Error("message", "key", value)
pluginAPI.Log.Info("message", "key", value)
pluginAPI.Log.Debug("message", "key", value)
```

**로그 위치:** `{mattermost}/logs/mattermost.log`

### 8.2 메트릭스

Prometheus 형식 메트릭스 제공 (`/plugins/mattermost-ai/metrics`):

```go
// metrics/metrics.go
type Metrics interface {
    IncrementHTTPRequests()
    IncrementHTTPErrors()
    ObserveAPIEndpointDuration(endpoint, method, status string, elapsed float64)
    IncrementLLMRequests(botUsername string)
    ObserveLLMResponseTime(botUsername string, elapsed float64)
    IncrementPluginCrashes()
}
```

### 8.3 토큰 사용량 추적

```go
// llm/token_tracking.go
type TokenCounts struct {
    InputTokens       int
    OutputTokens      int
    CacheCreated      int
    CacheRead         int
    ReasoningTokens   int
}
```

로깅 활성화: `enableTokenUsageLogging: true`

### 8.4 에러 처리 패턴

```go
// API 에러
c.AbortWithError(http.StatusBadRequest, fmt.Errorf("message"))

// 서비스 에러 (로깅 후 계속)
if err != nil {
    pluginAPI.Log.Error("failed to ...", "error", err)
    // Continue without feature
}

// 치명적 에러 (플러그인 활성화 실패)
return fmt.Errorf("failed to ...: %w", err)
```

---

## 9. 테스트 구조와 품질 게이트

### 9.1 단위 테스트

```bash
# 전체 테스트
make test

# 특정 패키지
go test -v ./conversations/...

# 특정 테스트
go test -v ./server/... -run TestName
```

**테스트 컨벤션:**
- Table-driven 테스트 선호
- 모킹 라이브러리 사용 금지 (직접 구현)
- `*_test.go` 파일명

### 9.2 E2E 테스트

```bash
# 전체 E2E
make e2e

# 특정 테스트
cd e2e && npx playwright test filename.spec.ts --reporter=list
```

**테스트 헬퍼:**
- `e2e/helpers/mmcontainer.ts` - Mattermost 컨테이너 관리
- `e2e/helpers/bot-config.ts` - 봇 설정 헬퍼

### 9.3 프롬프트 평가

```bash
# 인터랙티브 모드
make evals

# CI 모드
make evals-ci

# 특정 제공자
LLM_PROVIDER=anthropic make evals-ci
```

**평가 대상 패키지:** `conversations`, `threads`, `channels`, `react`

### 9.4 품질 게이트

```yaml
# CI 파이프라인
- lint: golangci-lint, eslint
- test: go test, jest
- build: dist-ci
- e2e: playwright (선택)
```

---

## 10. 변경 포인트 가이드

### 10.1 새 LLM 제공자 추가

1. 새 패키지 생성: `newprovider/newprovider.go`
2. `LanguageModel` 인터페이스 구현
3. `bots/bots.go`의 `getLLM()` 함수에 케이스 추가
4. `llm/service_types.go`에 상수 추가
5. Webapp 시스템 콘솔에 UI 추가

### 10.2 새 API 엔드포인트 추가

1. `api/api_*.go`에 핸들러 함수 작성
2. `api/api.go`의 `ServeHTTP()`에 라우트 등록
3. 필요시 미들웨어 추가
4. `webapp/src/client.tsx`에 클라이언트 함수 추가

### 10.3 새 프롬프트 추가

1. `prompts/` 디렉토리에 `.tmpl` 파일 생성
2. `prompts/prompts.go`의 `PromptsFolder` 임베드 확인
3. `llm/prompts.go`의 `Format()` 메서드로 사용

### 10.4 DB 스키마 변경

1. `database/schema.go`에 테이블/마이그레이션 추가
2. `SetupTables()` 함수에서 호출
3. 기존 데이터 마이그레이션 처리

### 10.5 설정 구조 변경

1. `llm/configuration.go` 또는 `config/config.go` 수정
2. `server/migrations.go`에 마이그레이션 함수 추가
3. Webapp 시스템 콘솔 UI 업데이트

---

## 추가 제안

### A. 보안 고려사항

- API Key는 Mattermost 설정에 **평문으로 저장**됨 → DB 접근 권한 관리 필요
- LLM 요청 시 사용자 데이터가 외부 서버로 전송됨 → 데이터 정책 검토
- MCP OAuth 토큰은 KV 스토어에 저장됨

### B. 성능 최적화 포인트

- `streaming/` 패키지의 청크 처리 로직
- `embeddings/` 배치 임베딩 생성
- `mcp/tools_cache.go` 도구 목록 캐싱

### C. 라이선스 제한 기능

Enterprise 라이선스 필요:
- Embedding Search (시맨틱 검색)
- 일부 고급 기능

### D. 개발 팁

```bash
# 핫 리로드 개발
make watch

# 디버거 연결
make attach-headless

# 로그 실시간 확인
make logs-watch
```

---

*문서 작성일: 2025-12-10*
*프로젝트 버전: 기반 커밋 참조*

