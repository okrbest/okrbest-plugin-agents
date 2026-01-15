# Mattermost Agents 플러그인 개발 가이드

Agents 플러그인의 아키텍처, 기능 구조 및 커스터마이징 방안을 정리한 문서입니다.
Mattermost AI 플러그인 공식 기술 문서를 참조하여 작성되었습니다.

- GitHub: https://github.com/mattermost/mattermost-plugin-ai
- 플러그인 개발 문서: https://developers.mattermost.com/extend/plugins/

---

## 목차

1. [플러그인 개요](#1-플러그인-개요)
2. [시스템 아키텍처](#2-시스템-아키텍처)
3. [디렉토리 구조](#3-디렉토리-구조)
4. [핵심 모듈 상세](#4-핵심-모듈-상세)
5. [LLM 공급자 연동](#5-llm-공급자-연동)
6. [API 명세](#6-api-명세)
7. [MCP (Model Context Protocol)](#7-mcp-model-context-protocol)
8. [웹앱 구조](#8-웹앱-구조)
9. [개발 가이드](#9-개발-가이드)
10. [배포/운영 가이드](#10-배포운영-가이드)
11. [트러블슈팅](#11-트러블슈팅)

---

## 1. 플러그인 개요

### 1.1 소개

Mattermost Agents 플러그인은 AI 기능을 Mattermost 워크스페이스에 직접 통합하는 플러그인입니다. 
로컬 LLM을 자체 인프라에서 실행하거나 클라우드 공급자에 연결하여 데이터와 배포를 완전히 제어할 수 있습니다.

### 1.2 주요 기능

| 기능 | 설명 |
|------|------|
| **다중 AI 어시스턴트** | 특화된 성격과 기능을 가진 여러 에이전트 구성 |
| **스레드 및 채널 요약** | 긴 토론의 간결한 요약을 한 번의 클릭으로 제공 |
| **액션 아이템 추출** | 스레드에서 자동으로 액션 아이템 식별 및 추출 |
| **회의 녹취** | 회의 녹음의 녹취 및 요약 |
| **시맨틱 검색** | 자연어를 사용하여 Mattermost 인스턴스 전체에서 관련 콘텐츠 검색 |
| **스마트 반응** | AI가 문맥에 적합한 이모지 반응 제안 |
| **직접 대화** | 전용 채널에서 AI 어시스턴트와 직접 채팅 |
| **유연한 LLM 지원** | 로컬 모델, 클라우드 공급자, OpenAI 호환 API 지원 |

### 1.3 시스템 요구사항

- **Mattermost 서버**: v10.0 이상 권장 (v9.11+ ESR 지원)
- **데이터베이스**: PostgreSQL (시맨틱 검색을 위해 pgvector 확장 필요)
- **개발 환경**:
  - Go 1.24+
  - Node.js 20.11+
  - LLM 공급자 접근 (OpenAI, Anthropic 등)

### 1.4 라이선스 요구사항

| 기능 | 라이선스 필요 여부 |
|------|------------------|
| 기본 에이전트 구성 (단일 에이전트) | 불필요 |
| DM 및 채널에서 에이전트와 채팅 | 불필요 |
| 이미지 분석 (비전 기능) | 불필요 |
| 기본 도구 통합 | 불필요 |
| 다중 에이전트 구성 | Entry, Enterprise+ |
| 세분화된 접근 제어 | Entry, Enterprise+ |
| 임베딩 검색 (시맨틱 AI 검색) | Entry, Enterprise+ |
| MCP 지원 | Entry, Enterprise+ |
| 사용량 분석 및 토큰 추적 | Entry, Enterprise+ |
| AI 액션 메뉴 (스레드 요약) | Entry, Enterprise+ |
| 채널 요약 (읽지 않은 메시지) | Entry, Enterprise+ |
| 녹음된 회의 녹취 및 요약 | Entry, Enterprise+ |

---

## 2. 시스템 아키텍처

### 2.1 전체 아키텍처

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Mattermost Server                                │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                     Agents Plugin                                   │ │
│  │                                                                     │ │
│  │  ┌──────────┐  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐ │ │
│  │  │   API    │  │Conversations│  │   Streaming  │  │   Search    │ │ │
│  │  │ Handler  │  │   Service   │  │   Service    │  │   Service   │ │ │
│  │  └────┬─────┘  └──────┬──────┘  └──────┬───────┘  └──────┬──────┘ │ │
│  │       │               │                │                 │         │ │
│  │  ┌────┴───────────────┴────────────────┴─────────────────┴──────┐ │ │
│  │  │                       Bots Service                            │ │ │
│  │  │   ┌─────────────────────────────────────────────────────────┐ │ │ │
│  │  │   │                    LLM Abstraction                       │ │ │ │
│  │  │   │  ┌────────┐ ┌──────────┐ ┌─────────┐ ┌────────────────┐ │ │ │ │
│  │  │   │  │ OpenAI │ │Anthropic │ │ Bedrock │ │OpenAI Compatible│ │ │ │ │
│  │  │   │  └────────┘ └──────────┘ └─────────┘ └────────────────┘ │ │ │ │
│  │  │   └─────────────────────────────────────────────────────────┘ │ │ │
│  │  └───────────────────────────────────────────────────────────────┘ │ │
│  │                                                                     │ │
│  │  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────────────┐│ │
│  │  │ MCP Client  │  │   Indexer    │  │      MCP Server             ││ │
│  │  │   Manager   │  │   Service    │  │  (Embedded/HTTP)            ││ │
│  │  └─────────────┘  └──────────────┘  └─────────────────────────────┘│ │
│  └────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────────┐
        │              External Services               │
        │  ┌─────────┐ ┌─────────┐ ┌───────────────┐  │
        │  │  LLM    │ │  MCP    │ │   External    │  │
        │  │Providers│ │ Servers │ │   APIs        │  │
        │  └─────────┘ └─────────┘ └───────────────┘  │
        └─────────────────────────────────────────────┘
```

### 2.2 데이터 흐름

```
User Request → API Handler → Bot Selection → Context Building → LLM Request
                                                                     │
                                                                     ▼
User Response ← WebSocket Event ← Streaming Service ← LLM Response ←─┘
```

### 2.3 서비스-에이전트 아키텍처

플러그인은 **서비스-에이전트 분리 아키텍처**를 사용합니다:

```json
{
  "services": [
    {
      "id": "service-uuid",
      "name": "OpenAI Service",
      "type": "openai",
      "apiKey": "sk-...",
      "defaultModel": "gpt-4o"
    }
  ],
  "bots": [
    {
      "id": "bot-001",
      "name": "ai",
      "displayName": "AI Assistant",
      "serviceID": "service-uuid",
      "customInstructions": "You are a helpful assistant."
    }
  ]
}
```

- **Services**: LLM 공급자 연결 설정 (API 키, 모델, 엔드포인트)
- **Bots (Agents)**: 서비스 ID를 참조하고 에이전트 개성 및 접근 제어 정의

---

## 3. 디렉토리 구조

```
okrbest-plugin-agents/
├── anthropic/           # Anthropic Claude LLM 통합
│   ├── anthropic.go     # Anthropic API 클라이언트 구현
│   └── anthropic_test.go
├── api/                 # HTTP API 핸들러
│   ├── api.go           # 메인 API 라우터 및 핸들러
│   ├── api_admin.go     # 관리자 API (재인덱싱, MCP 도구)
│   ├── api_channel.go   # 채널 관련 API
│   ├── api_llm_bridge.go # 플러그인 간 LLM Bridge API
│   ├── api_oauth.go     # OAuth 콜백 처리
│   ├── api_post.go      # 포스트 관련 API (요약, 분석 등)
│   ├── api_search.go    # 검색 API
│   ├── mcp_handlers.go  # MCP 관련 핸들러
│   └── middleware_mcp.go # MCP 인증 미들웨어
├── asage/               # ASage LLM 통합 (실험적)
│   ├── asage.go         # ASage Provider 구현 (스트리밍 미지원)
│   └── client.go        # ASage API 클라이언트
├── bedrock/             # AWS Bedrock LLM 통합
│   ├── bedrock.go       # Bedrock Converse API 클라이언트
│   └── bedrock_test.go
├── bots/                # 봇 관리 및 LLM 래퍼
│   ├── bot.go           # Bot 구조체 및 메서드
│   ├── bots.go          # MMBots 관리자 (봇 생성/관리)
│   ├── mentions.go      # 멘션 감지
│   └── permissions.go   # 권한 검사
├── build/               # 빌드 스크립트 및 설정
├── channels/            # 채널 관련 유틸리티
├── chunking/            # 텍스트 청킹 알고리즘
│   ├── chunker.go       # 청킹 전략 구현
│   └── text_splitting.go # 텍스트 분할 유틸리티
├── cmd/                 # CLI 도구
│   └── evalviewer/      # 평가 뷰어 TUI 애플리케이션
├── config/              # 설정 관리
│   └── config.go        # 플러그인 설정 구조체 및 컨테이너
├── conversations/       # 대화 처리 서비스
│   ├── conversations.go # 대화 서비스 메인
│   ├── handle_messages.go # 메시지 처리 로직
│   ├── regeneration.go  # 응답 재생성
│   ├── store.go         # 대화 저장소
│   └── tool_handling.go # 도구 호출 처리
├── database/            # 데이터베이스 스키마
│   └── schema.go        # 테이블 정의
├── docs/                # 문서
│   ├── admin_guide.md   # 관리자 가이드
│   ├── providers.md     # LLM 공급자 설정 가이드
│   └── user_guide.md    # 사용자 가이드
├── e2e/                 # E2E 테스트 (Playwright)
├── embeddings/          # 임베딩 및 벡터 검색
│   ├── embeddings.go    # EmbeddingSearch 인터페이스 정의
│   ├── composite.go     # Composite 임베딩 검색 구현
│   └── mock_provider.go # 테스트용 Mock 프로바이더
├── enterprise/          # 엔터프라이즈 라이선스 검사
├── evals/               # LLM 평가 프레임워크
├── format/              # 텍스트 포맷팅 유틸리티
├── i18n/                # 국제화
├── indexer/             # 포스트 인덱싱 서비스
├── llm/                 # LLM 추상화 레이어
│   ├── language_model.go # LanguageModel 인터페이스
│   ├── configuration.go  # ServiceConfig, BotConfig
│   ├── completion_request.go # 요청 구조체
│   ├── context.go       # Context 구조체
│   ├── stream.go        # 스트리밍 응답 및 이벤트 타입
│   ├── stream_generator.go # 스트림 생성기
│   ├── tools.go         # 도구/함수 호출
│   ├── annotations.go   # 인용/어노테이션 타입
│   ├── prompts.go       # 프롬프트 관리
│   ├── logging.go       # LLM 로깅 래퍼
│   ├── token_tracking.go # 토큰 사용량 추적
│   ├── truncation.go    # 컨텍스트 자르기
│   ├── model_fetcher.go # 모델 목록 조회
│   └── service_types.go # 서비스 타입 상수
├── llmcontext/          # LLM 컨텍스트 빌더
├── mcp/                 # MCP 클라이언트
│   ├── mcp.go           # 패키지 개요 및 타입
│   ├── client.go        # MCP 서버 연결 클라이언트
│   ├── client_manager.go # 사용자별 클라이언트 관리
│   ├── oauth_manager.go # OAuth 인증 관리
│   ├── embedded_session_store.go # 임베디드 세션 저장
│   └── tools_cache.go   # 도구 캐시
├── mcpserver/           # MCP 서버 (Mattermost를 MCP로 노출)
│   ├── server.go        # 메인 서버
│   ├── http_server.go   # HTTP 전송 서버
│   ├── stdio_server.go  # stdio 전송 서버
│   ├── plugin_handlers.go # 플러그인 핸들러
│   └── tools/           # MCP 도구 구현
│       ├── provider.go  # 도구 프로바이더
│       ├── channels.go  # 채널 관련 도구
│       ├── posts.go     # 포스트 관련 도구
│       ├── search.go    # 검색 도구
│       ├── teams.go     # 팀 관련 도구
│       ├── users.go     # 사용자 관련 도구
│       ├── access_mode.go # 접근 모드 관리
│       └── file_utils.go # 파일 유틸리티
├── meetings/            # 회의 녹취/요약 서비스
├── metrics/             # Prometheus 메트릭
├── mmapi/               # Mattermost API 래퍼
├── mmtools/             # Mattermost 내장 도구
├── openai/              # OpenAI LLM 통합
│   └── openai.go        # OpenAI API 클라이언트
├── postgres/            # PostgreSQL pgvector 통합
│   └── pgvector.go      # pgvector 벡터 저장소 구현
├── prompts/             # 프롬프트 템플릿
│   ├── direct_message_question_system.tmpl
│   ├── summarize_thread_system.tmpl
│   ├── summarize_channel_range_system.tmpl
│   ├── meeting_summary_system.tmpl
│   ├── search_system.tmpl
│   └── ...
├── public/              # 공개 API (Bridge Client)
│   └── bridgeclient/    # 다른 플러그인용 클라이언트
├── search/              # 시맨틱 검색 서비스
│   └── search.go        # RAG 기반 검색
├── server/              # 플러그인 메인
│   ├── main.go          # 플러그인 진입점 및 초기화
│   ├── configuration.go # 설정 로딩
│   ├── migrations.go    # DB 마이그레이션
│   └── embedded_mcp_server.go # 임베디드 MCP 서버
├── react/               # 이모지 반응 생성
│   └── react.go         # AI 기반 이모지 선택
├── streaming/           # 스트리밍 응답 서비스
│   └── streaming.go     # WebSocket 스트리밍
├── subtitles/           # 자막/녹취 처리
│   └── subtitles.go     # VTT, SRT, Zoom Chat 파싱
├── threads/             # 스레드 분석
│   └── threads.go       # 요약, 액션 아이템, 열린 질문
├── webapp/              # React 프론트엔드
│   ├── src/
│   │   ├── components/  # UI 컴포넌트
│   │   │   ├── rhs/     # 오른쪽 사이드바 패널
│   │   │   ├── llmbot_post/ # LLM 봇 포스트 렌더링
│   │   │   ├── system_console/ # 시스템 콘솔 설정
│   │   │   └── ...
│   │   ├── hooks.tsx    # React 훅
│   │   ├── redux.tsx    # Redux 스토어
│   │   ├── client.tsx   # API 클라이언트
│   │   └── websocket.ts # WebSocket 이벤트 처리
│   └── i18n/            # 프론트엔드 번역
├── plugin.json          # 플러그인 매니페스트
├── Makefile             # 빌드 스크립트
└── CLAUDE.md            # AI 어시스턴트용 개발 가이드
```

---

## 4. 핵심 모듈 상세

### 4.0 플러그인 설정 (`config/`)

플러그인 전체 설정을 관리하는 구조체입니다:

```go
// config/config.go
type Config struct {
    Services                 []llm.ServiceConfig              `json:"services"`                 // LLM 서비스 목록
    Bots                     []llm.BotConfig                  `json:"bots"`                     // 봇(에이전트) 목록
    DefaultBotName           string                           `json:"defaultBotName"`           // 기본 봇 이름
    TranscriptGenerator      string                           `json:"transcriptBackend"`        // 녹취 생성 봇
    EnableLLMTrace           bool                             `json:"enableLLMTrace"`           // LLM 요청/응답 로깅
    EnableTokenUsageLogging  bool                             `json:"enableTokenUsageLogging"`  // 토큰 사용량 로깅
    AllowedUpstreamHostnames string                           `json:"allowedUpstreamHostnames"` // 허용된 업스트림 호스트
    AllowUnsafeLinks         bool                             `json:"allowUnsafeLinks"`         // 안전하지 않은 링크 허용
    EmbeddingSearchConfig    embeddings.EmbeddingSearchConfig `json:"embeddingSearchConfig"`    // 임베딩 검색 설정
    MCP                      mcp.Config                       `json:"mcp"`                      // MCP 설정
}
```

### 4.1 LLM 추상화 레이어 (`llm/`)

#### LanguageModel 인터페이스

```go
// llm/language_model.go
type LanguageModel interface {
    ChatCompletion(conversation CompletionRequest, opts ...LanguageModelOption) (*TextStreamResult, error)
    ChatCompletionNoStream(conversation CompletionRequest, opts ...LanguageModelOption) (string, error)
    CountTokens(text string) int
    InputTokenLimit() int
}

// LanguageModelConfig - 옵션으로 전달되는 설정
type LanguageModelConfig struct {
    Model              string              // 모델 오버라이드
    MaxGeneratedTokens int                 // 최대 생성 토큰 수
    EnableVision       bool                // 비전 활성화
    JSONOutputFormat   *jsonschema.Schema  // JSON 출력 스키마
    ToolsDisabled      bool                // 도구 비활성화
    ReasoningDisabled  bool                // 추론 비활성화
}

// LanguageModelOption 함수들
func WithModel(model string) LanguageModelOption              // 모델 지정
func WithMaxGeneratedTokens(maxTokens int) LanguageModelOption // 최대 토큰 수
func WithJSONOutput[T any]() LanguageModelOption              // JSON 출력 형식
func WithToolsDisabled() LanguageModelOption                  // 도구 비활성화
func WithReasoningDisabled() LanguageModelOption              // 추론 비활성화
```

#### CompletionRequest 구조체

```go
// llm/completion_request.go
type CompletionRequest struct {
    Posts   []Post    // 대화 히스토리
    Context *Context  // 추가 컨텍스트 (도구, 사용자 정보 등)
}

type Post struct {
    Role               PostRole   // system, user, bot
    Message            string     // 메시지 내용
    Files              []File     // 첨부 파일 (이미지 등)
    ToolUse            []ToolCall // 도구 호출
    Reasoning          string     // 추론 과정 (thinking)
    ReasoningSignature string     // 추론 서명 (검증용)
}
```

#### 서비스 설정

```go
// llm/configuration.go
type ServiceConfig struct {
    ID                      string `json:"id"`
    Name                    string `json:"name"`
    Type                    string `json:"type"`          // openai, anthropic, bedrock, asage, etc.
    APIKey                  string `json:"apiKey"`
    OrgID                   string `json:"orgId"`         // OpenAI Organization ID
    DefaultModel            string `json:"defaultModel"`
    APIURL                  string `json:"apiURL"`        // OpenAI Compatible/Azure/ASage용
    Region                  string `json:"region"`        // AWS Bedrock용
    AWSAccessKeyID          string `json:"awsAccessKeyID"`
    AWSSecretAccessKey      string `json:"awsSecretAccessKey"`
    InputTokenLimit         int    `json:"tokenLimit"`
    OutputTokenLimit        int    `json:"outputTokenLimit"`
    StreamingTimeoutSeconds int    `json:"streamingTimeoutSeconds"`
    SendUserID              bool   `json:"sendUserID"`
    UseResponsesAPI         bool   `json:"useResponsesAPI"` // OpenAI Responses API
}

type BotConfig struct {
    ID                 string             `json:"id"`
    Name               string             `json:"name"`           // 사용자명
    DisplayName        string             `json:"displayName"`    // 표시 이름
    CustomInstructions string             `json:"customInstructions"`
    ServiceID          string             `json:"serviceID"`      // 연결된 서비스
    Model              string             `json:"model"`          // 서비스 기본 모델 오버라이드
    EnableVision       bool               `json:"enableVision"`
    DisableTools       bool               `json:"disableTools"`
    ChannelAccessLevel ChannelAccessLevel `json:"channelAccessLevel"`
    ChannelIDs         []string           `json:"channelIDs"`
    UserAccessLevel    UserAccessLevel    `json:"userAccessLevel"`
    UserIDs            []string           `json:"userIDs"`
    TeamIDs            []string           `json:"teamIDs"`
    MaxFileSize        int64              `json:"maxFileSize"`    // 최대 파일 크기 제한
    EnabledNativeTools []string           `json:"enabledNativeTools"` // web_search, file_search, code_interpreter
    ReasoningEnabled   bool               `json:"reasoningEnabled"`
    ReasoningEffort    string             `json:"reasoningEffort"`    // OpenAI: minimal/low/medium/high
    ThinkingBudget     int                `json:"thinkingBudget"`     // Anthropic (최소 1024, OutputTokenLimit까지)
}
```

### 4.2 봇 관리 서비스 (`bots/`)

#### MMBots 구조체

```go
// bots/bots.go
type MMBots struct {
    pluginAPI             *pluginapi.Client
    licenseChecker        *enterprise.LicenseChecker
    config                Config
    llmUpstreamHTTPClient *http.Client
    tokenLogger           *mlog.Logger
    metrics               llm.MetricsObserver
    bots                  []*Bot
}

// 주요 메서드
func (b *MMBots) EnsureBots() error                      // 봇 생성/업데이트/삭제
func (b *MMBots) GetBotByUsername(botUsername string) *Bot
func (b *MMBots) GetBotByID(botID string) *Bot
func (b *MMBots) GetBotForDMChannel(channel *model.Channel) *Bot
func (b *MMBots) GetBotMentioned(text string) *Bot
func (b *MMBots) GetAllBots() []*Bot
```

#### LLM 래퍼 체인

```go
// bots/bots.go - getLLM 메서드
func (b *MMBots) getLLM(serviceConfig llm.ServiceConfig, botConfig llm.BotConfig) (llm.LanguageModel, error) {
    // 1. 기본 LLM 클라이언트 생성
    var result llm.LanguageModel
    switch serviceConfig.Type {
    case llm.ServiceTypeOpenAI:
        result = openai.New(...)
    case llm.ServiceTypeAnthropic:
        result = anthropic.New(...)
    case llm.ServiceTypeBedrock:
        result, err = bedrock.New(...)
    // ...
    }
    
    // 2. Truncation 래퍼 추가
    result = llm.NewLLMTruncationWrapper(result)
    
    // 3. 토큰 사용량 로깅 래퍼 (선택적)
    if b.tokenLogger != nil && b.config.EnableTokenUsageLogging() {
        result = llm.NewTokenUsageLoggingWrapper(result, botConfig.Name, b.tokenLogger, b.metrics)
    }
    
    // 4. 디버그 로깅 래퍼 (선택적)
    if b.config.EnableLLMLogging() {
        result = llm.NewLanguageModelLogWrapper(b.pluginAPI.Log, result)
    }
    
    return result, nil
}
```

### 4.3 대화 서비스 (`conversations/`)

```go
// conversations/conversations.go
type Conversations struct {
    prompts          *llm.Prompts
    mmClient         mmapi.Client
    streamingService streaming.Service
    contextBuilder   *llmcontext.Builder
    bots             *bots.MMBots
    db               *mmapi.DBClient
    licenseChecker   *enterprise.LicenseChecker
    i18n             *i18n.Bundle
    meetingsService  MeetingsService
}

// 사용자 요청 처리
func (c *Conversations) ProcessUserRequest(bot *bots.Bot, postingUser *model.User, 
    channel *model.Channel, post *model.Post) (*llm.TextStreamResult, error) {
    
    // 1. LLM 컨텍스트 생성 (도구, 사용자 정보 포함)
    context := c.contextBuilder.BuildLLMContextUserRequest(bot, postingUser, channel,
        c.contextBuilder.WithLLMContextTools(bot))
    
    // 2. OAuth 인증 에러 알림 (MCP 서버)
    if context.Tools != nil {
        authErrors := context.Tools.GetAuthErrors()
        if len(authErrors) > 0 {
            c.sendOAuthNotifications(bot, userID, channelID, postID, authErrors)
        }
    }
    
    // 3. 대화 처리
    return c.ProcessUserRequestWithContext(bot, postingUser, channel, post, context)
}

// AI 스레드 목록 조회
func (c *Conversations) GetAIThreads(userID string) ([]AIThread, error)

// 제목 생성
func (c *Conversations) GenerateTitle(bot *bots.Bot, request string, postID string, 
    context *llm.Context) error
```

### 4.4 스트리밍 서비스 (`streaming/`)

```go
// streaming/streaming.go
type Service interface {
    StreamToNewPost(ctx context.Context, botID string, requesterUserID string, 
        stream *llm.TextStreamResult, post *model.Post, respondingToPostID string) error
    StreamToNewDM(ctx context.Context, botID string, stream *llm.TextStreamResult, 
        userID string, post *model.Post, respondingToPostID string) error
    StreamToPost(ctx context.Context, stream *llm.TextStreamResult, post *model.Post, userLocale string)
    StopStreaming(postID string)
    GetStreamingContext(inCtx context.Context, postID string) (context.Context, error)
    FinishStreaming(postID string)
}

// WebSocket 이벤트 타입
const PostStreamingControlCancel = "cancel"
const PostStreamingControlEnd = "end"
const PostStreamingControlStart = "start"

// 포스트 속성
const ToolCallProp = "pending_tool_call"
const ReasoningSummaryProp = "reasoning_summary"
const ReasoningSignatureProp = "reasoning_signature"
const AnnotationsProp = "annotations"
```

#### 스트리밍 이벤트 처리

```go
// streaming/streaming.go - StreamToPost
func (p *MMPostStreamService) StreamToPost(ctx context.Context, stream *llm.TextStreamResult, 
    post *model.Post, userLocale string) {
    
    for {
        select {
        case event := <-stream.Stream:
            switch event.Type {
            case llm.EventTypeText:
                // 텍스트 청크 처리
                post.Message += textChunk
                p.sendPostStreamingUpdateEventWithBroadcast(post, post.Message, broadcast)
                
            case llm.EventTypeReasoning:
                // 추론 과정 스트리밍
                reasoningBuffer.WriteString(reasoningChunk)
                p.sendPostStreamingReasoningEventWithBroadcast(post, reasoningBuffer.String(), 
                    "reasoning_summary", broadcast)
                
            case llm.EventTypeReasoningEnd:
                // 추론 완료 - 저장
                post.AddProp(ReasoningSummaryProp, reasoningData.Text)
                post.AddProp(ReasoningSignatureProp, reasoningData.Signature)
                
            case llm.EventTypeToolCalls:
                // 도구 호출 요청
                post.AddProp(ToolCallProp, string(toolCallJSON))
                p.mmClient.UpdatePost(post)
                p.mmClient.PublishWebSocketEvent("postupdate", map[string]interface{}{
                    "post_id":   post.Id,
                    "control":   "tool_call",
                    "tool_call": string(toolCallJSON),
                }, broadcast)
                
            case llm.EventTypeAnnotations:
                // 인용/참조 어노테이션
                post.AddProp(AnnotationsProp, string(annotationsJSON))
                p.sendPostStreamingAnnotationsEventWithBroadcast(post, string(annotationsJSON), broadcast)
                
            case llm.EventTypeEnd:
                // 스트림 완료
                p.mmClient.UpdatePost(post)
                return
                
            case llm.EventTypeError:
                // 에러 처리
                post.Message = "Sorry! An error occurred..."
                p.mmClient.UpdatePost(post)
                return
            }
        case <-ctx.Done():
            // 취소됨
            return
        }
    }
}
```

### 4.5 도구 시스템 (`llm/tools.go`)

#### ToolCall 구조체

```go
// llm/tools.go
type ToolCall struct {
    ID          string          `json:"id"`          // 도구 호출 고유 ID
    Name        string          `json:"name"`        // 도구 이름
    Description string          `json:"description"` // 도구 설명
    Arguments   json.RawMessage `json:"arguments"`   // 도구 인자 (JSON)
    Result      string          `json:"result"`      // 실행 결과
    Status      ToolCallStatus  `json:"status"`      // 현재 상태
}

// ToolCallStatus 열거형
const (
    ToolCallStatusPending  ToolCallStatus = iota // 사용자 승인/거부 대기 중
    ToolCallStatusAccepted                       // 사용자가 승인함 (아직 미해결)
    ToolCallStatusRejected                       // 사용자가 거부함
    ToolCallStatusError                          // 승인됨, 실행 중 에러 발생
    ToolCallStatusSuccess                        // 승인됨, 성공적으로 해결됨
)
```

#### ToolStore 구조체

```go
type ToolStore struct {
    tools      map[string]Tool      // 이름별 도구 맵
    log        TraceLog             // 트레이스 로그
    doTrace    bool                 // 트레이스 활성화 여부
    authErrors []ToolAuthError      // OAuth 인증 에러 목록
}

// 주요 메서드
func (s *ToolStore) AddTools(tools []Tool)
func (s *ToolStore) ResolveTool(name string, argsGetter ToolArgumentGetter, context *Context) (string, error)
func (s *ToolStore) GetTools() []Tool
func (s *ToolStore) GetToolsInfo() []ToolInfo  // 도구 기본 정보만 반환
func (s *ToolStore) GetAuthErrors() []ToolAuthError
```

### 4.6 Annotation 구조체 (`llm/annotations.go`)

인용/참조 어노테이션을 표현하는 구조체입니다:

```go
// llm/annotations.go
type AnnotationType string

const (
    AnnotationTypeURLCitation AnnotationType = "url_citation" // 웹 검색 인용
)

type Annotation struct {
    Type       AnnotationType `json:"type"`                 // 어노테이션 타입
    StartIndex int            `json:"start_index"`          // 메시지 텍스트에서 시작 위치 (0-based)
    EndIndex   int            `json:"end_index"`            // 메시지 텍스트에서 종료 위치 (0-based)
    URL        string         `json:"url"`                  // 출처 URL
    Title      string         `json:"title"`                // 출처 제목
    CitedText  string         `json:"cited_text,omitempty"` // 인용된 텍스트 (선택)
    Index      int            `json:"index"`                // 표시 인덱스 (1-based, UI용)
}
```

### 4.7 Context 구조체 (`llm/context.go`)

```go
// llm/context.go
type Context struct {
    // Server
    Time        string              // 현재 시간 (RFC1123 형식)
    ServerName  string              // 서버 이름
    CompanyName string              // 회사 이름

    // Location
    Team    *model.Team             // 팀 정보
    Channel *model.Channel          // 채널 정보
    Thread  []Post                  // 스레드 포스트들 (포맷팅됨)

    // User that is making the request
    RequestingUser *model.User      // 요청한 사용자

    // Bot Specific
    BotName            string       // 봇 이름
    BotUsername        string       // 봇 사용자명
    BotUserID          string       // 봇 사용자 ID
    BotModel           string       // 사용 중인 모델
    CustomInstructions string       // 봇 커스텀 지시사항

    Tools             *ToolStore    // 사용 가능한 도구들
    DisabledToolsInfo []ToolInfo    // 현재 컨텍스트에서 비활성화된 도구 정보
    Parameters        map[string]interface{} // 템플릿 파라미터
}
```

### 4.8 검색 서비스 (`search/`)

```go
// search/search.go
type Search struct {
    embeddings.EmbeddingSearch
    mmclient         mmapi.Client
    prompts          *llm.Prompts
    streamingService streaming.Service
    licenseChecker   *enterprise.LicenseChecker
}

// RAG 기반 검색 결과
type RAGResult struct {
    PostID      string  `json:"postId"`
    ChannelID   string  `json:"channelId"`
    ChannelName string  `json:"channelName"`
    UserID      string  `json:"userId"`
    Username    string  `json:"username"`
    Content     string  `json:"content"`
    Score       float32 `json:"score"`
}

// 검색 실행 및 DM으로 응답
func (s *Search) RunSearch(ctx context.Context, userID string, bot *bots.Bot, 
    query, teamID, channelID string, maxResults int) (map[string]string, error)

// 즉시 검색 결과 반환
func (s *Search) SearchQuery(ctx context.Context, userID string, bot *bots.Bot, 
    query, teamID, channelID string, maxResults int) (Response, error)
```

### 4.9 프롬프트 템플릿 (`prompts/`)

주요 프롬프트 템플릿:

| 템플릿 | 용도 |
|--------|------|
| `direct_message_question_system.tmpl` | DM 대화 시스템 프롬프트 |
| `summarize_thread_system.tmpl` | 스레드 요약 |
| `summarize_channel_range_system.tmpl` | 채널 범위 요약 |
| `summarize_channel_since_system.tmpl` | 특정 시점 이후 요약 |
| `summarize_chunk_system.tmpl` | 청크 요약 |
| `find_action_items_system.tmpl` | 액션 아이템 추출 |
| `find_action_items_user.tmpl` | 액션 아이템 사용자 프롬프트 |
| `find_open_questions_system.tmpl` | 열린 질문 찾기 |
| `find_open_questions_user.tmpl` | 열린 질문 사용자 프롬프트 |
| `meeting_summary_system.tmpl` | 회의 요약 시스템 프롬프트 |
| `meeting_summary_user.tmpl` | 회의 요약 사용자 프롬프트 |
| `meeting_summary_general.tmpl` | 회의 요약 일반 |
| `search_system.tmpl` | 검색 시스템 프롬프트 |
| `search_user.tmpl` | 검색 사용자 프롬프트 |
| `search_results.tmpl` | 검색 결과 포맷 |
| `emoji_select_system.tmpl` | 이모지 반응 선택 |
| `standard_personality.tmpl` | 기본 성격 정의 |
| `standard_personality_without_locale.tmpl` | 로케일 없는 기본 성격 |
| `locale.tmpl` | 로케일 설정 |
| `thread_user.tmpl` | 스레드 사용자 프롬프트 |

#### 프롬프트 변수 사용

```go
// llm/prompts.go
type Prompts struct {
    templates map[string]*template.Template
}

func (p *Prompts) Format(templateName string, context *Context) (string, error) {
    // context.Parameters에서 템플릿 변수 사용
}
```

---

## 5. LLM 공급자 연동

### 5.1 지원 공급자

| 공급자 | 타입 | 필수 설정 | 선택 설정 |
|--------|------|----------|----------|
| **OpenAI** | `openai` | API Key | Organization ID |
| **Anthropic** | `anthropic` | API Key | - |
| **AWS Bedrock** | `bedrock` | Region | API Key, AWS 자격증명 |
| **Azure OpenAI** | `azure` | API Key, API URL | - |
| **ASage** | `asage` | API Key, API URL | - |
| **Cohere** | `cohere` | API Key | - |
| **Mistral** | `mistral` | API Key | - |
| **OpenAI Compatible** | `openaicompatible` | API URL | API Key |

### 5.2 OpenAI 구현

```go
// openai/openai.go
type OpenAI struct {
    client           *openai.Client
    config           Config
    llmUpstreamClient *http.Client
}

type Config struct {
    APIKey               string
    APIURL               string
    OrgID                string
    DefaultModel         string
    InputTokenLimit      int
    OutputTokenLimit     int
    StreamingTimeout     time.Duration
    SendUserID           bool
    EmbeddingModel       string        // 임베딩 모델명
    EmbeddingDimensions  int           // 임베딩 차원 수
    UseResponsesAPI      bool          // OpenAI Responses API 사용
    EnabledNativeTools   []string      // 네이티브 도구 (web_search, file_search, code_interpreter)
    ReasoningEnabled     bool          // 추론 활성화
    ReasoningEffort      string        // 추론 노력도 (minimal/low/medium/high)
    DisableStreamOptions bool          // 호환 API용: stream_options 비활성화
    UseMaxTokens         bool          // 호환 API용: max_tokens 사용 (max_completion_tokens 대신)
}

func New(config Config, httpClient *http.Client) *OpenAI
func NewCompatible(config Config, httpClient *http.Client) *OpenAI  // OpenAI 호환 API용
func NewAzure(config Config, httpClient *http.Client) *OpenAI       // Azure OpenAI용
```

### 5.3 Anthropic 구현

```go
// anthropic/anthropic.go
type Anthropic struct {
    client       *anthropic.Client
    config       Config
    httpClient   *http.Client
}

func New(serviceConfig llm.ServiceConfig, botConfig llm.BotConfig, 
    httpClient *http.Client) *Anthropic
```

### 5.4 AWS Bedrock 구현

```go
// bedrock/bedrock.go
type Bedrock struct {
    client            *bedrockruntime.Client
    model             string
    inputTokenLimit   int
    outputTokenLimit  int
    streamingTimeout  time.Duration
}

func New(config llm.ServiceConfig, httpClient *http.Client) (*Bedrock, error)

// 인증 우선순위:
// 1. AWS IAM 자격증명 필드 (AWS Access Key ID + Secret)
// 2. Bearer 토큰 (API Key 필드의 base64 인코딩된 Bedrock 콘솔 키)
// 3. 기본 자격증명 체인 (환경 변수, IAM 역할 등)
```

### 5.5 새로운 LLM 공급자 추가

새로운 공급자를 추가하려면:

1. **패키지 생성**: `newprovider/newprovider.go`
2. **LanguageModel 인터페이스 구현**:

```go
package newprovider

type NewProvider struct {
    // 클라이언트 필드
}

func New(config llm.ServiceConfig, httpClient *http.Client) *NewProvider {
    return &NewProvider{...}
}

func (n *NewProvider) ChatCompletion(req llm.CompletionRequest, 
    opts ...llm.LanguageModelOption) (*llm.TextStreamResult, error) {
    // 구현
}

func (n *NewProvider) ChatCompletionNoStream(req llm.CompletionRequest, 
    opts ...llm.LanguageModelOption) (string, error) {
    // 구현
}

func (n *NewProvider) CountTokens(text string) int {
    // 토큰 카운팅 구현
}

func (n *NewProvider) InputTokenLimit() int {
    return n.inputTokenLimit
}
```

3. **서비스 타입 추가** (`llm/service_types.go`):

```go
const ServiceTypeNewProvider = "newprovider"
```

4. **bots/bots.go에 등록**:

```go
func (b *MMBots) getLLM(serviceConfig llm.ServiceConfig, botConfig llm.BotConfig) (llm.LanguageModel, error) {
    switch serviceConfig.Type {
    // ...
    case llm.ServiceTypeNewProvider:
        result = newprovider.New(serviceConfig, b.llmUpstreamHTTPClient)
    // ...
    }
}
```

---

## 6. API 명세

### 6.1 API 라우터 구조

```go
// api/api.go - ServeHTTP
func (a *API) ServeHTTP(c *plugin.Context, w http.ResponseWriter, r *http.Request) {
    router := gin.Default()
    
    // LLM Bridge API v1 (플러그인 간 전용)
    llmBridgeRoute := router.Group("/bridge/v1")
    llmBridgeRoute.Use(a.interPluginAuthorizationRequired)
    llmBridgeRoute.GET("/agents", a.handleGetAgents)
    llmBridgeRoute.GET("/services", a.handleGetServices)
    llmBridgeRoute.POST("/completion/agent/:agent", a.handleAgentCompletionStreaming)
    llmBridgeRoute.POST("/completion/agent/:agent/nostream", a.handleAgentCompletionNoStream)
    llmBridgeRoute.POST("/completion/service/:service", a.handleServiceCompletionStreaming)
    llmBridgeRoute.POST("/completion/service/:service/nostream", a.handleServiceCompletionNoStream)
    
    // MCP 서버 엔드포인트
    mcpServerGroup := router.Group("/mcp-server")
    mcpServerGroup.GET("/.well-known/oauth-protected-resource", ...)
    mcpServerGroup.Any("/mcp", ...)  // 인증 미들웨어 적용
    
    // 일반 API (Mattermost 인증 필요)
    router.Use(a.MattermostAuthorizationRequired)
    router.GET("/oauth/callback", a.handleOAuthCallback)
    router.GET("/ai_threads", a.handleGetAIThreads)
    router.GET("/ai_bots", a.handleGetAIBots)
    
    // 봇 필수 API
    botRequiredRouter := router.Group("")
    botRequiredRouter.Use(a.aiBotRequired)
    
    // 포스트 관련 API
    postRouter := botRequiredRouter.Group("/post/:postid")
    postRouter.Use(a.postAuthorizationRequired)
    postRouter.POST("/react", a.handleReact)
    postRouter.POST("/analyze", a.handleThreadAnalysis)
    postRouter.POST("/transcribe/file/:fileid", a.handleTranscribeFile)
    postRouter.POST("/summarize_transcription", a.handleSummarizeTranscription)
    postRouter.POST("/stop", a.handleStop)
    postRouter.POST("/regenerate", a.handleRegenerate)
    postRouter.POST("/tool_call", a.handleToolCall)
    postRouter.POST("/postback_summary", a.handlePostbackSummary)
    
    // 채널 관련 API
    channelRouter := botRequiredRouter.Group("/channel/:channelid")
    channelRouter.Use(a.channelAuthorizationRequired)
    channelRouter.POST("/interval", a.handleInterval)
    
    // 관리자 API
    adminRouter := router.Group("/admin")
    adminRouter.Use(a.mattermostAdminAuthorizationRequired)
    adminRouter.POST("/reindex", a.handleReindexPosts)
    adminRouter.GET("/reindex/status", a.handleGetJobStatus)
    adminRouter.POST("/reindex/cancel", a.handleCancelJob)
    adminRouter.GET("/mcp/tools", a.handleGetMCPTools)
    adminRouter.POST("/mcp/tools/cache/clear", a.handleClearMCPToolsCache)
    adminRouter.POST("/models/fetch", a.handleFetchModels)
    
    // 검색 API
    searchRouter := botRequiredRouter.Group("/search")
    searchRouter.POST("", a.handleSearchQuery)
    searchRouter.POST("/run", a.handleRunSearch)
}
```

### 6.2 주요 API 엔드포인트

#### 일반 사용자 API

| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | `/ai_threads` | 사용자의 AI 대화 스레드 목록 |
| GET | `/ai_bots` | 사용자에게 허용된 AI 봇 목록 |
| GET | `/oauth/callback` | MCP OAuth 콜백 |

#### 포스트 관련 API

| 메서드 | 경로 | 설명 |
|--------|------|------|
| POST | `/post/:postid/react` | AI 이모지 반응 제안 |
| POST | `/post/:postid/analyze` | 스레드 분석 (요약, 액션아이템 등) |
| POST | `/post/:postid/transcribe/file/:fileid` | 파일 녹취 |
| POST | `/post/:postid/summarize_transcription` | 녹취 요약 |
| POST | `/post/:postid/stop` | 스트리밍 중지 |
| POST | `/post/:postid/regenerate` | 응답 재생성 |
| POST | `/post/:postid/tool_call` | 도구 호출 승인/거부 |
| POST | `/post/:postid/postback_summary` | 요약 공유 |

#### 채널 관련 API

| 메서드 | 경로 | 설명 |
|--------|------|------|
| POST | `/channel/:channelid/interval` | 채널 범위 요약 |

#### 검색 API

| 메서드 | 경로 | 설명 |
|--------|------|------|
| POST | `/search` | 검색 쿼리 (즉시 응답) |
| POST | `/search/run` | 검색 실행 (DM으로 응답) |

#### 관리자 API

| 메서드 | 경로 | 설명 |
|--------|------|------|
| POST | `/admin/reindex` | 포스트 재인덱싱 시작 |
| GET | `/admin/reindex/status` | 인덱싱 작업 상태 |
| POST | `/admin/reindex/cancel` | 인덱싱 작업 취소 |
| GET | `/admin/mcp/tools` | MCP 도구 목록 |
| POST | `/admin/mcp/tools/cache/clear` | MCP 도구 캐시 클리어 |
| POST | `/admin/models/fetch` | 서비스에서 모델 목록 조회 |

#### LLM Bridge API (플러그인 간)

| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | `/bridge/v1/agents` | 에이전트 목록 |
| GET | `/bridge/v1/services` | 서비스 목록 |
| POST | `/bridge/v1/completion/agent/:agent` | 에이전트로 스트리밍 완료 |
| POST | `/bridge/v1/completion/agent/:agent/nostream` | 에이전트로 비스트리밍 완료 |
| POST | `/bridge/v1/completion/service/:service` | 서비스로 스트리밍 완료 |
| POST | `/bridge/v1/completion/service/:service/nostream` | 서비스로 비스트리밍 완료 |

---

## 7. MCP (Model Context Protocol)

### 7.1 개요

MCP는 AI 에이전트가 외부 도구 및 서비스와 표준화된 방식으로 상호작용할 수 있게 하는 프로토콜입니다.

### 7.2 MCP 클라이언트 (`mcp/`)

외부 MCP 서버에 연결하는 클라이언트 구현:

```go
// mcp/mcp.go
type Config struct {
    Enabled            bool                 `json:"enabled"`
    EnablePluginServer bool                 `json:"enablePluginServer"`
    Servers            []ServerConfig       `json:"servers"`
    EmbeddedServer     EmbeddedServerConfig `json:"embeddedServer"`
    IdleTimeoutMinutes int                  `json:"idleTimeoutMinutes"`
}

type ServerConfig struct {
    URL           string            `json:"url"`
    CustomHeaders map[string]string `json:"customHeaders"`
    Name          string            `json:"name"`
}

// mcp/client_manager.go
type ClientManager struct {
    // 사용자별 클라이언트 관리
    userClients map[string]*UserClients
    // OAuth 인증 관리
    oauthManager *OAuthManager
    // 임베디드 MCP 서버
    embeddedServer EmbeddedMCPServer
    // ...
}

func (m *ClientManager) GetUserClients(userID string) (*UserClients, error)
func (m *ClientManager) GetToolsCache() *ToolsCache
func (m *ClientManager) ProcessOAuthCallback(ctx context.Context, userID, state, code string) (*OAuthSession, error)
```

### 7.3 MCP 서버 (`mcpserver/`)

Mattermost를 MCP 서버로 노출하여 외부 AI 에이전트가 접근할 수 있게 함:

#### 제공 도구

| 도구 | 설명 |
|------|------|
| `read_post` | 특정 포스트 및 스레드 읽기 |
| `read_channel` | 채널의 최근 포스트 조회 |
| `search_posts` | 포스트 검색 |
| `create_post` | 포스트 생성 |
| `dm_self` | 자신에게 DM 전송 |
| `create_channel` | 채널 생성 |
| `get_channel_info` | 채널 정보 조회 |
| `get_channel_members` | 채널 멤버 목록 |
| `add_user_to_channel` | 채널에 사용자 추가 |
| `get_team_info` | 팀 정보 조회 |
| `get_team_members` | 팀 멤버 목록 |
| `search_users` | 사용자 검색 |

#### 서버 구현

```go
// mcpserver/server.go
type Server struct {
    toolProvider *tools.Provider
    logger       logger.Logger
}

// mcpserver/http_server.go - HTTP 전송
type HTTPServer struct {
    server *Server
    // Streamable HTTP 전송 (SSE 아님)
}

// mcpserver/plugin_handlers.go - 플러그인 핸들러
type PluginMCPHandlers struct {
    server       *Server
    // OAuth 메타데이터, MCP 핸들러 등
}

func (h *PluginMCPHandlers) OAuthMetadataHandler(w http.ResponseWriter, r *http.Request)
func (h *PluginMCPHandlers) MCPHandler(w http.ResponseWriter, r *http.Request)
```

#### 인증 방식

1. **OAuth 2.0**: 동적 클라이언트 등록 (DCR) 또는 수동 등록 지원
2. **Personal Access Token**: Bearer 토큰 인증

### 7.4 내장 도구 통합 (`mmtools/`)

플러그인 내장 도구:

```go
// mmtools/mmtools.go
type MMToolProvider struct {
    mmClient      mmapi.Client
    searchService *search.Search
    httpClient    *http.Client
}

// 제공 도구:
// - Server Search: 시맨틱 검색
// - User Lookup: 사용자 정보 조회
// - Jira Integration: Jira 이슈 조회
// - GitHub Integration: GitHub 이슈/PR 조회
```

---

## 8. 웹앱 구조

### 8.1 디렉토리 구조

```
webapp/src/
├── components/
│   ├── rhs/                    # 오른쪽 사이드바
│   │   ├── rhs.tsx             # RHS 메인 컴포넌트
│   │   ├── rhs_header.tsx      # 헤더
│   │   ├── rhs_new_tab.tsx     # 새 탭
│   │   ├── common.tsx          # 공통 컴포넌트
│   │   └── thread_item.tsx     # 스레드 아이템
│   ├── llmbot_post/            # LLM 봇 포스트
│   │   ├── llmbot_post.tsx     # 메인 포스트 컴포넌트
│   │   ├── controls_bar.tsx    # 컨트롤 바 (중지, 재생성 등)
│   │   ├── reasoning_display.tsx # 추론 과정 표시
│   │   └── permalink_data.ts   # 퍼머링크 데이터
│   ├── citations/              # 인용 표시
│   │   ├── citation_component.tsx # 인용 컴포넌트
│   │   ├── citation_processor.tsx # 인용 처리기
│   │   └── types.ts            # 인용 타입 정의
│   ├── system_console/         # 시스템 콘솔 설정
│   │   ├── agents_settings.tsx # 에이전트 설정
│   │   ├── services_settings.tsx # 서비스 설정
│   │   ├── mcp_settings.tsx    # MCP 설정
│   │   └── ...
│   ├── citations/              # 인용 표시
│   ├── tool_card.tsx           # 도구 호출 카드
│   ├── tool_approval_set.tsx   # 도구 승인/거부
│   ├── bot_selector.tsx        # 봇 선택기
│   ├── post_menu.tsx           # 포스트 메뉴 (AI Actions)
│   └── unreads_summarize.tsx   # 읽지 않은 메시지 요약
├── hooks.tsx                   # React 훅
├── redux.tsx                   # Redux 스토어
├── client.tsx                  # API 클라이언트
├── websocket.ts                # WebSocket 이벤트
├── bots.tsx                    # 봇 관련 유틸리티
└── i18n/                       # 번역 파일
    ├── en.json
    ├── es.json
    └── ko.json
```

### 8.2 WebSocket 이벤트 처리

```typescript
// webapp/src/websocket.ts
export const handleWebsocketPostUpdateEvent = (
    dispatch: Dispatch<AnyAction>,
    event: WebSocketEvent
) => {
    const data = event.data;
    
    if (data.control === 'start') {
        // 스트리밍 시작
        dispatch(startPostStreaming(data.post_id));
    } else if (data.control === 'end') {
        // 스트리밍 완료
        dispatch(finishPostStreaming(data.post_id));
    } else if (data.control === 'cancel') {
        // 스트리밍 취소
        dispatch(cancelPostStreaming(data.post_id));
    } else if (data.control === 'tool_call') {
        // 도구 호출
        dispatch(updatePostToolCall(data.post_id, data.tool_call));
    } else if (data.control === 'reasoning_summary') {
        // 추론 과정 업데이트
        dispatch(updatePostReasoning(data.post_id, data.reasoning));
    } else if (data.control === 'annotations') {
        // 어노테이션 업데이트
        dispatch(updatePostAnnotations(data.post_id, data.annotations));
    } else if (data.next) {
        // 텍스트 청크
        dispatch(updatePostContent(data.post_id, data.next));
    }
};
```

### 8.3 Redux 상태 관리

```typescript
// webapp/src/redux.tsx
// 플러그인 전역 상태 (리듀서로 관리)
interface PluginState {
    bots: AIBotInfo[] | null;          // AI 봇 목록
    botChannelId: string;               // 현재 봇 DM 채널 ID
    selectedPostId: string;             // 선택된 포스트 ID
    searchEnabled: boolean;             // 검색 기능 활성화 여부
    allowUnsafeLinks: boolean;          // 안전하지 않은 링크 허용 여부
}

// 스트리밍 상태는 LLMBotPost 컴포넌트의 로컬 상태로 관리됨
interface LLMBotPostState {
    message: string;                    // 현재 메시지 내용
    generating: boolean;                // 스트리밍 중 여부
    precontent: boolean;                // 첫 콘텐츠 대기 중
    toolCalls: ToolCall[];              // 도구 호출 목록
    annotations: Annotation[];          // 어노테이션 목록
    reasoningSummary: string;           // 추론 요약
    showReasoning: boolean;             // 추론 표시 여부
    isReasoningCollapsed: boolean;      // 추론 접힘 상태
}
```

---

## 9. 개발 가이드

### 9.1 개발 환경 설정

```bash
# 1. 저장소 클론
git clone https://github.com/mattermost/mattermost-plugin-ai.git
cd mattermost-plugin-ai

# 2. 환경 변수 설정 (원격 서버 개발 시)
export MM_SERVICESETTINGS_SITEURL=http://localhost:8065
export MM_ADMIN_USERNAME=<YOUR_USERNAME>
export MM_ADMIN_PASSWORD=<YOUR_PASSWORD>

# 3. 빌드 및 배포
make deploy
```

### 9.2 주요 Make 명령

```bash
make help          # 모든 명령 목록
make deploy        # 빌드 및 배포
make check-style   # 코드 스타일 검사
make check-style-fix # 코드 스타일 자동 수정
make test          # 테스트 실행
make e2e           # E2E 테스트
make evals         # 프롬프트 평가 (TUI)
make evals-ci      # 프롬프트 평가 (CI 모드)
```

### 9.3 코드 스타일 가이드라인

```
- Go: goimports 표준 포맷팅
- TypeScript/React:
  - 4칸 들여쓰기
  - PascalCase 컴포넌트 이름
  - 엄격한 타이핑
  - styled-components 사용 (style 속성 사용 금지)
- 파일 이름: snake_case
- 모든 파일에 라이선스 헤더 포함
- 에러 처리: 모든 에러를 명시적으로 처리
- 테스트: 가능하면 테이블 기반 테스트 작성
- 국제화: 새 텍스트에 항상 i18n 적용
- 목킹: 사용하지 않음 (새 테스트 라이브러리 도입 금지)
```

### 9.4 테스트

#### 단위 테스트

```bash
# 전체 테스트
make test

# 특정 테스트
go test -v ./server/path/to/package -run TestName
```

#### E2E 테스트

```bash
# 전체 E2E 테스트
make e2e

# 특정 파일
cd e2e && npx playwright test filename.spec.ts --reporter=list
```

#### 벤치마크 테스트

```bash
# 스트리밍 벤치마크
go test -bench=. -benchmem ./llm/... ./streaming/...

# CPU 프로파일링
go test -bench=BenchmarkReadAll -cpuprofile=cpu.prof ./llm/...
```

### 9.5 프롬프트 평가

```bash
# 기본 실행 (모든 공급자)
make evals

# 특정 공급자
LLM_PROVIDER=anthropic make evals

# 특정 모델
ANTHROPIC_MODEL=claude-3-opus-20240229 make evals

# 다중 공급자
LLM_PROVIDER=openai,anthropic make evals

# OpenAI 호환 API
LLM_PROVIDER=openaicompatible OPENAI_COMPATIBLE_API_URL=http://localhost:8080/v1 OPENAI_COMPATIBLE_MODEL=llama-3 make evals
```

### 9.6 새 기능 추가 가이드

#### 새 프롬프트 템플릿 추가

1. `prompts/` 디렉토리에 `.tmpl` 파일 생성
2. `prompts/prompts_vars.go`에 상수 추가:

```go
const PromptNewFeatureSystem = "new_feature_system"
```

3. 사용:

```go
prompt, err := c.prompts.Format(prompts.PromptNewFeatureSystem, context)
```

#### 새 API 엔드포인트 추가

1. `api/` 디렉토리에 핸들러 함수 추가
2. `api/api.go`의 라우터에 등록:

```go
router.POST("/new_endpoint", a.handleNewEndpoint)
```

#### 새 도구 추가

1. `mmtools/` 또는 `mcpserver/tools/`에 구현:

```go
func (t *MMToolProvider) NewTool(ctx context.Context, args map[string]interface{}) (string, error) {
    // 구현
}
```

2. 도구 정의 추가:

```go
var newToolDefinition = llm.Tool{
    Name:        "new_tool",
    Description: "Tool description",
    InputSchema: llm.NewJSONSchemaFromStruct[NewToolInput](),
}
```

---

## 10. 배포/운영 가이드

### 10.1 플러그인 빌드

```bash
# 프로덕션 빌드
make dist

# 결과물
dist/mattermost-ai-X.X.X.tar.gz
```

### 10.2 설치

```bash
# mmctl 사용
mmctl plugin install dist/mattermost-ai-X.X.X.tar.gz

# 또는 System Console > Plugins > Upload Plugin
```

### 10.3 메트릭

메트릭 엔드포인트: `/plugins/mattermost-ai/metrics` (기본 포트 8067)

| 메트릭 | 설명 |
|--------|------|
| `agents_system_plugin_start_timestamp_seconds` | 플러그인 시작 시간 |
| `agents_system_plugin_info` | 플러그인 버전 및 설치 ID |
| `agents_api_time_seconds` | API 실행 시간 |
| `agents_http_requests_total` | 총 API 요청 수 |
| `agents_http_errors_total` | 총 HTTP API 에러 수 |
| `agents_llm_requests_total` | 총 LLM 요청 수 |

### 10.4 토큰 사용량 추적

활성화 시 `logs/agents/token_usage.log`에 JSON 형식으로 기록:

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "user_id": "user123",
  "team_id": "team456",
  "bot_username": "ai",
  "input_tokens": 150,
  "output_tokens": 300,
  "total_tokens": 450
}
```

로그 변환:

```bash
# JSON 배열로 변환
jq -s '.' logs/agents/token_usage.log > token_usage.json

# CSV로 변환
echo "timestamp,user_id,team_id,bot_username,input_tokens,output_tokens,total_tokens" > token_usage.csv
jq -r '[.timestamp, .user_id, .team_id, .bot_username, .input_tokens, .output_tokens, .total_tokens] | @csv' logs/agents/token_usage.log >> token_usage.csv
```

### 10.5 데이터베이스 테이블

플러그인이 사용하는 주요 테이블:

| 테이블 | 설명 |
|--------|------|
| `LLM_PostMeta` | AI 대화 스레드 제목 (RootPostID, Title) |
| `llm_posts_embeddings` | 임베딩 벡터 (pgvector, HNSW 인덱스 사용) |

---

## 11. 트러블슈팅

### 11.1 일반적인 문제

#### 플러그인 활성화 실패

**증상**: 설치 후 활성화 버튼이 작동하지 않음

**해결**:
1. 서버 로그 확인: `System Console > Logs`
2. 라이선스 확인 (일부 기능은 라이선스 필요)
3. PostgreSQL 버전 및 pgvector 확장 확인

#### WebSocket 연결 문제

**증상**: 스트리밍 응답이 작동하지 않음

**해결**:
1. 브라우저 개발자 도구에서 WebSocket 연결 상태 확인
2. 프록시 설정 확인:

```nginx
location ~ /api/v[0-9]+/(users/)?websocket$ {
    proxy_pass http://mattermost;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 86400;
}
```

#### LLM 연결 오류

**증상**: "Error accessing LLM" 메시지

**해결**:
1. API 키 유효성 확인
2. 네트워크 연결 확인
3. LLM Trace 활성화하여 상세 로그 확인

### 11.2 디버깅

#### 서버 로그

```bash
# 플러그인 로그 필터링
grep "plugin_ai" /var/log/mattermost/mattermost.log
```

#### LLM Trace 활성화

System Console에서 LLM Trace 옵션 활성화 시 모든 LLM 요청/응답이 로깅됨.

#### API 테스트

```bash
# API 직접 테스트
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8065/plugins/mattermost-ai/ai_bots
```

### 11.3 일반적인 오류 메시지

| 오류 | 원인 | 해결 |
|------|------|------|
| `requires professional license` | 라이선스 필요 기능 | 적절한 라이선스 적용 |
| `bot creation failed` | 봇 생성 실패 | 봇 계정 활성화 확인 |
| `permission denied` | 권한 부족 | 사용자 역할/팀 멤버십 확인 |
| `service not found` | 서비스 미설정 | System Console에서 서비스 구성 |
| `model not available` | 모델 접근 불가 | 공급자에서 모델 활성화 확인 |

---

## 부록: 체크리스트

### 개발 환경 설정 체크리스트

- [ ] Go 1.24+ 설치
- [ ] Node.js 20.11+ 설치
- [ ] Mattermost 개발 서버 설정
- [ ] `make deploy` 성공
- [ ] 플러그인 활성화 확인
- [ ] LLM 공급자 API 키 준비

### 배포 전 체크리스트

- [ ] 모든 테스트 통과 (`make test`, `make e2e`)
- [ ] 코드 스타일 검사 (`make check-style`)
- [ ] 라이선스 요구사항 확인
- [ ] 설정 검증
- [ ] 롤백 계획 수립

### 보안 체크리스트

- [ ] API 키 안전한 저장
- [ ] 권한 검사 구현 확인
- [ ] 입력값 검증
- [ ] 도구 호출 사용자 승인 필요
- [ ] DM에서만 도구 실행

---

## 참고 링크

- [GitHub Repository](https://github.com/mattermost/mattermost-plugin-ai)
- [Mattermost Plugin Developer Setup](https://developers.mattermost.com/integrate/plugins/developer-setup/)
- [Mattermost Plugin API Reference](https://developers.mattermost.com/extend/plugins/server/reference/)
- [Model Context Protocol Specification](https://spec.modelcontextprotocol.io/)
