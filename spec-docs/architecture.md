# Mattermost Agents 플러그인 아키텍처 문서

이 문서는 Mattermost Agents 플러그인의 상세 아키텍처를 설명합니다.

---

## 목차

1. [전체 시스템 아키텍처](#1-전체-시스템-아키텍처)
2. [서버 아키텍처](#2-서버-아키텍처)
3. [웹앱 아키텍처](#3-웹앱-아키텍처)
4. [데이터 흐름](#4-데이터-흐름)
5. [LLM 추상화 계층](#5-llm-추상화-계층)
6. [MCP 아키텍처](#6-mcp-아키텍처)
7. [스트리밍 아키텍처](#7-스트리밍-아키텍처)
8. [검색 및 임베딩 아키텍처](#8-검색-및-임베딩-아키텍처)
9. [보안 아키텍처](#9-보안-아키텍처)
10. [확장성 설계](#10-확장성-설계)

---

## 1. 전체 시스템 아키텍처

### 1.1 고수준 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Mattermost Platform                                 │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                          Mattermost Server                                   ││
│  │                                                                              ││
│  │   ┌──────────────────────────────────────────────────────────────────────┐  ││
│  │   │                    Agents Plugin (Go Backend)                         │  ││
│  │   │                                                                       │  ││
│  │   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │  ││
│  │   │  │   Plugin    │  │   HTTP/API  │  │  WebSocket  │  │   Plugin    │ │  ││
│  │   │  │    Core     │  │   Handler   │  │   Events    │  │   Hooks     │ │  ││
│  │   │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘ │  ││
│  │   │         │                │                │                │         │  ││
│  │   │  ┌──────┴────────────────┴────────────────┴────────────────┴──────┐  │  ││
│  │   │  │                      Service Layer                              │  │  ││
│  │   │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │  │  ││
│  │   │  │  │Conversa- │ │ Bots     │ │Streaming │ │ Search   │          │  │  ││
│  │   │  │  │tions     │ │ Manager  │ │ Service  │ │ Service  │          │  │  ││
│  │   │  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘          │  │  ││
│  │   │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │  │  ││
│  │   │  │  │Meetings  │ │ Indexer  │ │   MCP    │ │ Context  │          │  │  ││
│  │   │  │  │ Service  │ │ Service  │ │ Manager  │ │ Builder  │          │  │  ││
│  │   │  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘          │  │  ││
│  │   │  └─────────────────────────────────────────────────────────────────┘  │  ││
│  │   │                                │                                       │  ││
│  │   │  ┌─────────────────────────────┴─────────────────────────────────────┐│  ││
│  │   │  │                    LLM Abstraction Layer                          ││  ││
│  │   │  │  ┌────────┐ ┌──────────┐ ┌─────────┐ ┌────────────────┐          ││  ││
│  │   │  │  │ OpenAI │ │Anthropic │ │ Bedrock │ │OpenAI Compatible│          ││  ││
│  │   │  │  └────────┘ └──────────┘ └─────────┘ └────────────────┘          ││  ││
│  │   │  │  ┌────────┐ ┌──────────┐ ┌─────────┐                              ││  ││
│  │   │  │  │ Azure  │ │  Cohere  │ │ Mistral │                              ││  ││
│  │   │  │  └────────┘ └──────────┘ └─────────┘                              ││  ││
│  │   │  └───────────────────────────────────────────────────────────────────┘│  ││
│  │   └───────────────────────────────────────────────────────────────────────┘  ││
│  │                                                                              ││
│  │   ┌──────────────────────────────────────────────────────────────────────┐  ││
│  │   │                    Agents Plugin (React Frontend)                     │  ││
│  │   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │  ││
│  │   │  │    RHS      │  │  Post Menu  │  │   System    │  │  WebSocket  │ │  ││
│  │   │  │   Panel     │  │  (Actions)  │  │   Console   │  │   Handler   │ │  ││
│  │   │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘ │  ││
│  │   └──────────────────────────────────────────────────────────────────────┘  ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
│  ┌───────────────────┐  ┌───────────────────┐  ┌───────────────────────────────┐│
│  │  PostgreSQL + DB  │  │  File Storage     │  │       Redis (Optional)        ││
│  │  (+ pgvector)     │  │                   │  │                               ││
│  └───────────────────┘  └───────────────────┘  └───────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────────┘
                │                                              │
                ▼                                              ▼
┌───────────────────────────────────┐    ┌─────────────────────────────────────────┐
│       External LLM Providers      │    │           External MCP Servers           │
│  ┌───────┐ ┌──────────┐ ┌──────┐ │    │  ┌────────────┐  ┌─────────────────────┐ │
│  │OpenAI │ │Anthropic │ │ AWS  │ │    │  │ Atlassian  │  │    Custom MCP       │ │
│  │  API  │ │   API    │ │Bedrock│ │    │  │    MCP     │  │      Servers        │ │
│  └───────┘ └──────────┘ └──────┘ │    │  └────────────┘  └─────────────────────┘ │
└───────────────────────────────────┘    └─────────────────────────────────────────┘
```

### 1.2 컴포넌트 개요

| 계층 | 컴포넌트 | 역할 |
|------|----------|------|
| **Frontend** | RHS Panel | AI 대화 인터페이스 |
| **Frontend** | Post Menu | AI 액션 메뉴 (요약, 분석) |
| **Frontend** | System Console | 관리자 설정 UI |
| **Backend** | API Handler | HTTP 요청 처리 |
| **Backend** | Service Layer | 비즈니스 로직 |
| **Backend** | LLM Layer | LLM 공급자 추상화 |
| **External** | LLM Providers | AI 모델 서비스 |
| **External** | MCP Servers | 외부 도구 통합 |

---

## 2. 서버 아키텍처

### 2.1 플러그인 초기화 흐름

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          Plugin Initialization Flow                           │
└──────────────────────────────────────────────────────────────────────────────┘

main() ─────────────────────────────────────────────────────────────────────────►
    │
    ▼
┌─────────────┐
│ OnActivate  │
└──────┬──────┘
       │
       ├──► Create PluginAPI Client
       │
       ├──► Initialize License Checker
       │
       ├──► Run Database Migrations
       │         │
       │         └──► Migration v1: ServiceID Migration
       │         └──► Migration v2: Service Config Migration
       │
       ├──► Initialize Token Logger
       │
       ├──► Initialize MMBots Service
       │         │
       │         └──► EnsureBots() ──► Create/Update Mattermost Bots
       │
       ├──► Setup Database Tables (LLM_PostMeta, llm_posts_embeddings)
       │
       ├──► Initialize Prompts Manager (Load .tmpl files)
       │
       ├──► Initialize Streaming Service
       │
       ├──► Initialize Search Infrastructure (Embeddings + pgvector)
       │
       ├──► Initialize Indexer Service
       │
       ├──► Initialize MCP Client Manager
       │         │
       │         ├──► Create OAuth Manager
       │         └──► Create Embedded MCP Server (if enabled)
       │
       ├──► Initialize Context Builder
       │
       ├──► Initialize Conversations Service
       │
       ├──► Initialize Meetings Service
       │
       ├──► Initialize MCP Handlers (for HTTP server)
       │
       └──► Initialize API Service
                 │
                 └──► Register HTTP Routes
```

### 2.2 서비스 의존성 그래프

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           Service Dependency Graph                               │
└─────────────────────────────────────────────────────────────────────────────────┘

                            ┌─────────────────┐
                            │   API Service   │
                            └────────┬────────┘
                                     │
         ┌───────────────────────────┼───────────────────────────┐
         │                           │                           │
         ▼                           ▼                           ▼
┌─────────────────┐        ┌─────────────────┐        ┌─────────────────┐
│  Conversations  │        │    Meetings     │        │     Search      │
│    Service      │        │    Service      │        │    Service      │
└────────┬────────┘        └────────┬────────┘        └────────┬────────┘
         │                          │                          │
         │                          │                          │
         ▼                          ▼                          ▼
┌─────────────────┐        ┌─────────────────┐        ┌─────────────────┐
│    MMBots       │◄───────│   Streaming     │◄───────│   Embeddings    │
│    Service      │        │    Service      │        │    Search       │
└────────┬────────┘        └─────────────────┘        └─────────────────┘
         │
         │
         ▼
┌─────────────────┐        ┌─────────────────┐        ┌─────────────────┐
│    LLM Layer    │◄───────│  Token Logger   │◄───────│    Metrics      │
│  (OpenAI, etc)  │        │                 │        │    Service      │
└─────────────────┘        └─────────────────┘        └─────────────────┘
         │
         │
         ▼
┌─────────────────┐        ┌─────────────────┐
│   HTTP Client   │        │  MCP Client     │
│  (Upstream LLM) │        │    Manager      │
└─────────────────┘        └─────────────────┘
```

### 2.3 서비스 컴포넌트 상세

#### 2.3.1 Bots Service (`bots/`)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              MMBots Service                                   │
└──────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────────┐
│  MMBots                                                                        │
│  ├── bots: []*Bot               ← 활성 봇 목록                                 │
│  ├── config: Config             ← 플러그인 설정 인터페이스                      │
│  ├── licenseChecker             ← 라이선스 검증                                │
│  ├── llmUpstreamHTTPClient      ← LLM API 호출용 HTTP 클라이언트               │
│  ├── tokenLogger                ← 토큰 사용량 로거                             │
│  └── metrics                    ← 메트릭 관찰자                                │
│                                                                                │
│  Methods:                                                                      │
│  ├── EnsureBots()               ← 봇 생성/업데이트/삭제 (클러스터 뮤텍스 사용)   │
│  ├── GetBotByUsername()         ← 사용자명으로 봇 조회                          │
│  ├── GetBotByID()               ← ID로 봇 조회                                 │
│  ├── GetBotForDMChannel()       ← DM 채널의 봇 조회                            │
│  ├── GetBotMentioned()          ← 텍스트에서 멘션된 봇 찾기                     │
│  ├── CheckUsageRestrictions()   ← 권한 검사                                    │
│  └── GetTranscribe()            ← 녹취 서비스 반환                              │
└───────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────────┐
│  Bot (Individual)                                                              │
│  ├── cfg: BotConfig             ← 봇 설정 (이름, 서비스ID, 권한 등)            │
│  ├── service: ServiceConfig     ← 연결된 LLM 서비스 설정                       │
│  ├── mmBot: *model.Bot          ← Mattermost 봇 객체                           │
│  └── llm: LanguageModel         ← LLM 인스턴스 (래퍼 체인 적용됨)              │
│                                                                                │
│  Methods:                                                                      │
│  ├── GetConfig() BotConfig                                                     │
│  ├── GetMMBot() *model.Bot                                                     │
│  ├── LLM() LanguageModel                                                       │
│  └── ServiceConfig() ServiceConfig                                             │
└───────────────────────────────────────────────────────────────────────────────┘
```

#### 2.3.2 Conversations Service (`conversations/`)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           Conversations Service                               │
└──────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────────┐
│  Conversations                                                                 │
│  ├── prompts: *llm.Prompts           ← 프롬프트 템플릿 관리자                  │
│  ├── mmClient: mmapi.Client          ← Mattermost API 클라이언트              │
│  ├── streamingService                ← 스트리밍 서비스                        │
│  ├── contextBuilder                  ← LLM 컨텍스트 빌더                      │
│  ├── bots: *bots.MMBots              ← 봇 서비스                              │
│  ├── db: *mmapi.DBClient             ← 데이터베이스 클라이언트                 │
│  ├── licenseChecker                  ← 라이선스 검사                          │
│  ├── i18n: *i18n.Bundle              ← 국제화                                 │
│  └── meetingsService                 ← 회의 서비스 (순환 의존성 해결용)        │
│                                                                                │
│  Core Methods:                                                                 │
│  ├── ProcessUserRequest()            ← 사용자 요청 처리 (메인 진입점)          │
│  ├── ProcessUserRequestWithContext() ← 컨텍스트 포함 처리                      │
│  ├── GenerateTitle()                 ← 대화 제목 자동 생성                     │
│  └── GetAIThreads()                  ← 사용자의 AI 스레드 목록                 │
│                                                                                │
│  Conversion Methods:                                                           │
│  ├── PostToAIPost()                  ← MM Post → LLM Post 변환                │
│  ├── ThreadToLLMPosts()              ← 스레드 → LLM Posts 변환                │
│  └── existingConversationToLLMPosts()← 기존 대화 변환                          │
│                                                                                │
│  Handler Methods (handle_messages.go):                                         │
│  ├── MessageHasBeenPosted()          ← 새 메시지 처리 (후크)                   │
│  └── handleBotMessage()              ← 봇 메시지 처리                          │
└───────────────────────────────────────────────────────────────────────────────┘
```

#### 2.3.3 Streaming Service (`streaming/`)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                            Streaming Service                                  │
└──────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────────┐
│  MMPostStreamService                                                           │
│  ├── contexts: map[string]postStreamContext  ← 활성 스트리밍 컨텍스트          │
│  ├── contextsMutex: sync.Mutex               ← 동시성 제어                     │
│  ├── mmClient: Client                        ← MM 클라이언트                   │
│  └── i18n: *i18n.Bundle                      ← 국제화                          │
│                                                                                │
│  Methods:                                                                      │
│  ├── StreamToNewPost()           ← 새 포스트로 스트리밍                        │
│  ├── StreamToNewDM()             ← 새 DM으로 스트리밍                          │
│  ├── StreamToPost()              ← 기존 포스트로 스트리밍 (메인 루프)          │
│  ├── GetStreamingContext()       ← 스트리밍 컨텍스트 획득                      │
│  ├── StopStreaming()             ← 스트리밍 중지                               │
│  └── FinishStreaming()           ← 스트리밍 완료 정리                          │
│                                                                                │
│  WebSocket Events:                                                             │
│  ├── sendPostStreamingUpdateEventWithBroadcast()    ← 텍스트 업데이트          │
│  ├── sendPostStreamingControlEventWithBroadcast()   ← 제어 이벤트              │
│  ├── sendPostStreamingReasoningEventWithBroadcast() ← 추론 이벤트              │
│  └── sendPostStreamingAnnotationsEventWithBroadcast()← 어노테이션 이벤트       │
└───────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────────┐
│  Event Types (from LLM Stream)                                                 │
│  ├── EventTypeText          ← 텍스트 청크                                     │
│  ├── EventTypeEnd           ← 스트림 종료                                     │
│  ├── EventTypeError         ← 에러 발생                                       │
│  ├── EventTypeToolCalls     ← 도구 호출 요청                                  │
│  ├── EventTypeReasoning     ← 추론 과정 청크                                  │
│  ├── EventTypeReasoningEnd  ← 추론 완료                                       │
│  ├── EventTypeAnnotations   ← 인용/참조 어노테이션                            │
│  └── EventTypeUsage         ← 토큰 사용량 데이터                              │
└───────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. 웹앱 아키텍처

### 3.1 컴포넌트 계층 구조

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          Webapp Component Hierarchy                           │
└──────────────────────────────────────────────────────────────────────────────┘

                              ┌─────────────────┐
                              │    Plugin       │
                              │    Index.tsx    │
                              └────────┬────────┘
                                       │
         ┌─────────────────────────────┼─────────────────────────────┐
         │                             │                             │
         ▼                             ▼                             ▼
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│   RHS Panel     │         │   Post Menu     │         │ System Console  │
│   Component     │         │   Component     │         │    Settings     │
└────────┬────────┘         └────────┬────────┘         └────────┬────────┘
         │                           │                           │
    ┌────┴────┐              ┌───────┴───────┐           ┌───────┴───────┐
    ▼         ▼              ▼               ▼           ▼               ▼
┌───────┐ ┌───────┐    ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐
│RHS    │ │RHS    │    │AI Actions │ │Unreads    │ │Agents     │ │Services   │
│Header │ │Thread │    │Dropdown   │ │Summarize  │ │Settings   │ │Settings   │
└───────┘ └───┬───┘    └───────────┘ └───────────┘ └───────────┘ └───────────┘
              │
    ┌─────────┼─────────┐
    ▼         ▼         ▼
┌───────┐ ┌───────┐ ┌───────┐
│LLMBot │ │Tool   │ │Search │
│Post   │ │Card   │ │Results│
└───────┘ └───────┘ └───────┘
```

### 3.2 Redux 상태 관리

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              Redux State Tree                                 │
└──────────────────────────────────────────────────────────────────────────────┘

pluginState: {
    │
    ├── bots: AIBotInfo[] | null
    │       {
    │           id: string,
    │           displayName: string,
    │           username: string,
    │           lastIconUpdate: number,
    │           dmChannelID: string,
    │           channelAccessLevel: ChannelAccessLevel,
    │           channelIDs: string[],
    │           userAccessLevel: UserAccessLevel,
    │           userIDs: string[]
    │       }
    │
    ├── botChannelId: string              ← 현재 봇 DM 채널 ID
    │
    ├── selectedPostId: string            ← 선택된 포스트 ID
    │
    ├── searchEnabled: boolean            ← 검색 기능 활성화 여부
    │
    ├── allowUnsafeLinks: boolean         ← 안전하지 않은 링크 허용 여부
    │
    └── callsPostButtonClickedTranscription: function | false  ← Calls 통합
}

Note: 스트리밍 상태(isStreaming, content, reasoning, toolCalls, annotations)는
      컴포넌트 레벨(LLMBotPost)에서 WebSocket 이벤트를 통해 관리됨
```

### 3.3 WebSocket 이벤트 처리

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        WebSocket Event Flow                                   │
└──────────────────────────────────────────────────────────────────────────────┘

Server                                         Client (Browser)
   │                                                │
   │  ══════════ WebSocket Connection ══════════   │
   │                                                │
   │  ─── "postupdate" event ──────────────────►  │
   │      {                                         │
   │        post_id: "xxx",                         │     ┌─────────────────┐
   │        control: "start"                        │ ──► │handleWebsocket- │
   │      }                                         │     │PostUpdateEvent  │
   │                                                │     └────────┬────────┘
   │  ─── "postupdate" event ──────────────────►  │              │
   │      {                                         │              ▼
   │        post_id: "xxx",                         │     ┌─────────────────┐
   │        next: "Hello, I am..."                  │ ──► │ Redux Dispatch  │
   │      }                                         │     │ updateContent   │
   │                                                │     └────────┬────────┘
   │  ─── "postupdate" event ──────────────────►  │              │
   │      {                                         │              ▼
   │        post_id: "xxx",                         │     ┌─────────────────┐
   │        control: "reasoning_summary",           │ ──► │ Redux Dispatch  │
   │        reasoning: "Let me think..."            │     │ updateReasoning │
   │      }                                         │     └────────┬────────┘
   │                                                │              │
   │  ─── "postupdate" event ──────────────────►  │              ▼
   │      {                                         │     ┌─────────────────┐
   │        post_id: "xxx",                         │ ──► │ Redux Dispatch  │
   │        control: "tool_call",                   │     │ updateToolCall  │
   │        tool_call: "[{...}]"                    │     └────────┬────────┘
   │      }                                         │              │
   │                                                │              ▼
   │  ─── "postupdate" event ──────────────────►  │     ┌─────────────────┐
   │      {                                         │ ──► │ Redux Dispatch  │
   │        post_id: "xxx",                         │     │ finishStreaming │
   │        control: "end"                          │     └─────────────────┘
   │      }                                         │
   │                                                │
```

---

## 4. 데이터 흐름

### 4.1 사용자 메시지 처리 흐름

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        User Message Processing Flow                           │
└──────────────────────────────────────────────────────────────────────────────┘

User types message in channel                    
         │                                       
         ▼                                       
┌─────────────────┐                              
│ Mattermost      │                              
│ Message Posted  │                              
└────────┬────────┘                              
         │                                       
         ▼                                       
┌─────────────────┐    Hook: MessageHasBeenPosted
│ Plugin Hook     │─────────────────────────────►
│ Triggered       │                              
└────────┬────────┘                              
         │                                       
         ├──────────────────────────────────────┐
         │                                      │
         ▼                                      ▼
┌─────────────────┐                    ┌─────────────────┐
│ Indexer Service │                    │ Conversations   │
│ IndexPost()     │                    │ MessageHasBeenPosted()
└─────────────────┘                    └────────┬────────┘
         │                                      │
         ▼                                      ├─► Check: Is DM with AI Bot?
┌─────────────────┐                             ├─► Check: Is AI Bot mentioned?
│ Generate        │                             │
│ Embeddings      │                             ▼
└────────┬────────┘                    ┌─────────────────┐
         │                             │ Build LLM       │
         ▼                             │ Context         │
┌─────────────────┐                    └────────┬────────┘
│ Store in        │                             │
│ pgvector        │                             ▼
└─────────────────┘                    ┌─────────────────┐
                                       │ Get Bot &       │
                                       │ LLM Instance    │
                                       └────────┬────────┘
                                                │
                                                ▼
                                       ┌─────────────────┐
                                       │ Process User    │
                                       │ Request         │
                                       └────────┬────────┘
                                                │
                    ┌───────────────────────────┴───────────────────────────┐
                    │                                                       │
                    ▼                                                       ▼
           ┌─────────────────┐                                    ┌─────────────────┐
           │ New Conversation│                                    │ Continue        │
           │ (no root post)  │                                    │ Conversation    │
           └────────┬────────┘                                    └────────┬────────┘
                    │                                                      │
                    ▼                                                      ▼
           ┌─────────────────┐                                    ┌─────────────────┐
           │ Format System   │                                    │ Get Thread Data │
           │ Prompt          │                                    │ Convert to      │
           └────────┬────────┘                                    │ LLM Posts       │
                    │                                             └────────┬────────┘
                    │                                                      │
                    └────────────────────┬─────────────────────────────────┘
                                         │
                                         ▼
                                ┌─────────────────┐
                                │ LLM.ChatCompletion()
                                │ (Streaming)     │
                                └────────┬────────┘
                                         │
                                         ▼
                                ┌─────────────────┐
                                │ StreamToNewPost │
                                │ / StreamToNewDM │
                                └────────┬────────┘
                                         │
                    ┌────────────────────┼────────────────────┐
                    │                    │                    │
                    ▼                    ▼                    ▼
           ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
           │ Stream Text     │  │ Handle Tool     │  │ Handle          │
           │ to Post         │  │ Calls           │  │ Reasoning       │
           └─────────────────┘  └─────────────────┘  └─────────────────┘
                    │                    │                    │
                    └────────────────────┼────────────────────┘
                                         │
                                         ▼
                                ┌─────────────────┐
                                │ Update Post     │
                                │ via WebSocket   │
                                └─────────────────┘
```

### 4.2 도구 호출 흐름

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           Tool Call Flow                                      │
└──────────────────────────────────────────────────────────────────────────────┘

LLM Response with tool_use
         │
         ▼
┌─────────────────┐
│ Streaming       │
│ EventTypeToolCalls
└────────┬────────┘
         │
         ▼
┌─────────────────┐                    ┌─────────────────┐
│ Add tool_call   │                    │ WebSocket Event │
│ prop to post    │──────────────────► │ control:        │
│                 │                    │ "tool_call"     │
└────────┬────────┘                    └────────┬────────┘
         │                                      │
         ▼                                      ▼
┌─────────────────┐                    ┌─────────────────┐
│ Update Post     │                    │ Client renders  │
│ in Database     │                    │ ToolCard        │
└─────────────────┘                    │ component       │
                                       └────────┬────────┘
                                                │
                                                ▼
                                       ┌─────────────────┐
                                       │ User clicks     │
                                       │ Approve/Reject  │
                                       └────────┬────────┘
                                                │
                           ┌────────────────────┴────────────────────┐
                           │                                         │
                           ▼                                         ▼
                  ┌─────────────────┐                       ┌─────────────────┐
                  │ Approved        │                       │ Rejected        │
                  │ POST /tool_call │                       │ POST /tool_call │
                  └────────┬────────┘                       └────────┬────────┘
                           │                                         │
                           ▼                                         ▼
                  ┌─────────────────┐                       ┌─────────────────┐
                  │ Execute Tool    │                       │ Mark as         │
                  │ (MCP/Internal)  │                       │ Rejected        │
                  └────────┬────────┘                       └────────┬────────┘
                           │                                         │
                           ▼                                         ▼
                  ┌─────────────────┐                       ┌─────────────────┐
                  │ Get Tool Result │                       │ Continue        │
                  │                 │                       │ without tool    │
                  └────────┬────────┘                       └─────────────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │ Send result to  │
                  │ LLM for next    │
                  │ response        │
                  └────────┬────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │ Stream new      │
                  │ response        │
                  └─────────────────┘
```

---

## 5. LLM 추상화 계층

### 5.1 LanguageModel 인터페이스

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                       LanguageModel Interface                                 │
└──────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────────┐
│  <<interface>>                                                                 │
│  LanguageModel                                                                 │
│  ├── ChatCompletion(CompletionRequest, ...Option) (*TextStreamResult, error) │
│  ├── ChatCompletionNoStream(CompletionRequest, ...Option) (string, error)    │
│  ├── CountTokens(text string) int                                             │
│  └── InputTokenLimit() int                                                    │
└───────────────────────────────────────────────────────────────────────────────┘
                                    ▲
                                    │ implements
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
┌───────┴───────┐          ┌───────┴───────┐          ┌───────┴───────┐
│    OpenAI     │          │   Anthropic   │          │    Bedrock    │
│  (+ Azure,    │          │               │          │               │
│   Compatible) │          │               │          │               │
└───────────────┘          └───────────────┘          └───────────────┘
        │                           │                           │
        │                           │                           │
        ▼                           ▼                           ▼
┌───────────────┐          ┌───────────────┐          ┌───────────────┐
│ openai.Client │          │anthropic.Client          │bedrockruntime.│
│ (go-openai)   │          │ (native impl) │          │ Client (AWS)  │
└───────────────┘          └───────────────┘          └───────────────┘
```

### 5.2 LLM 래퍼 체인

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          LLM Wrapper Chain                                    │
└──────────────────────────────────────────────────────────────────────────────┘

         Request                                                Response
            │                                                      ▲
            ▼                                                      │
┌───────────────────────────────────────────────────────────────────────────────┐
│                        LanguageModelLogWrapper                                 │
│                        (Debug Logging - Optional)                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │ Log request/response for debugging                                       │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────────────┘
            │                                                      ▲
            ▼                                                      │
┌───────────────────────────────────────────────────────────────────────────────┐
│                      TokenUsageLoggingWrapper                                  │
│                      (Token Tracking - Optional)                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │ Track input/output tokens, log to token_usage.log                        │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────────────┘
            │                                                      ▲
            ▼                                                      │
┌───────────────────────────────────────────────────────────────────────────────┐
│                        LLMTruncationWrapper                                    │
│                        (Context Truncation - Always)                           │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │ Truncate context to fit within token limits                              │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────────────┘
            │                                                      ▲
            ▼                                                      │
┌───────────────────────────────────────────────────────────────────────────────┐
│                          Base LLM Client                                       │
│                     (OpenAI / Anthropic / Bedrock)                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │ Actual API call to LLM provider                                          │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────────────┘
            │                                                      ▲
            ▼                                                      │
         HTTP Request ──────────────────────────────────────► HTTP Response
                            External LLM API
```

### 5.3 CompletionRequest 구조

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         CompletionRequest Structure                           │
└──────────────────────────────────────────────────────────────────────────────┘

CompletionRequest
│
├── Posts: []Post
│   │
│   ├── Post[0] (System)
│   │   ├── Role: "system"
│   │   └── Message: "You are a helpful AI assistant..."
│   │
│   ├── Post[1] (User)
│   │   ├── Role: "user"
│   │   ├── Message: "What is the weather today?"
│   │   └── Files: []File (images for vision)
│   │
│   ├── Post[2] (Bot)
│   │   ├── Role: "bot"
│   │   ├── Message: "I'll check the weather for you."
│   │   ├── ToolUse: []ToolCall
│   │   └── Reasoning: "Let me think about this..."
│   │
│   └── Post[n] (User/Bot continues...)
│
└── Context: *Context
    │
    ├── RequestingUser: *model.User
    │   └── User who made the request
    │
    ├── Channel: *model.Channel
    │   └── Channel context
    │
    ├── Bot: *BotConfig
    │   └── Bot configuration (custom instructions)
    │
    ├── Tools: *ToolStore
    │   ├── GetToolsInfo() []ToolInfo
    │   └── GetTools() []Tool
    │
    ├── DisabledToolsInfo: []ToolInfo
    │   └── Tools disabled in non-DM context
    │
    └── Parameters: map[string]interface{}
        └── Template parameters for prompts
```

---

## 6. MCP 아키텍처

### 6.1 MCP 클라이언트 아키텍처

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         MCP Client Architecture                               │
└──────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────────┐
│                            ClientManager                                       │
│  ├── config: Config                    ← MCP 설정                             │
│  ├── log: LogService                   ← 로깅 서비스                          │
│  ├── pluginAPI: *pluginapi.Client      ← 플러그인 API                         │
│  ├── oauthManager: *OAuthManager       ← OAuth 인증 관리                      │
│  ├── embeddedServer: EmbeddedMCPServer ← 임베디드 서버 (선택)                  │
│  ├── httpClient: *http.Client          ← HTTP 클라이언트                      │
│  ├── toolsCache: *ToolsCache           ← 도구 캐시                            │
│  └── userClients: map[string]*UserClients ← 사용자별 클라이언트               │
└───────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ manages
                                    ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                            UserClients                                         │
│  ├── userID: string                    ← 사용자 ID                            │
│  ├── clients: map[string]*Client       ← 서버별 클라이언트                    │
│  └── embeddedClient: *Client           ← 임베디드 서버 클라이언트             │
└───────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ contains
                                    ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                              Client                                            │
│  ├── serverConfig: ServerConfig        ← 서버 설정 (URL, 헤더)                │
│  ├── mcpClient: *mcp.Client            ← MCP 프로토콜 클라이언트              │
│  ├── tools: []Tool                     ← 서버에서 제공하는 도구               │
│  └── oauthSession: *OAuthSession       ← OAuth 세션 (인증 필요 시)            │
│                                                                                │
│  Methods:                                                                      │
│  ├── Connect(ctx) error                ← 서버 연결                            │
│  ├── Tools() []Tool                    ← 도구 목록 반환                       │
│  ├── CallTool(name, args) (string, error) ← 도구 실행                         │
│  └── Close() error                     ← 연결 종료                            │
└───────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 MCP 서버 아키텍처

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         MCP Server Architecture                               │
└──────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────────┐
│                              Server                                            │
│  ├── toolProvider: *tools.Provider     ← 도구 제공자                          │
│  └── logger: Logger                    ← 로거                                 │
└───────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ uses
                                    ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                          tools.Provider                                        │
│  ├── mmClient: Client                  ← Mattermost API 클라이언트            │
│  └── logger: Logger                    ← 로거                                 │
│                                                                                │
│  Available Tools:                                                              │
│  ├── read_post          ← 포스트 읽기                                         │
│  ├── read_channel       ← 채널 포스트 읽기                                    │
│  ├── search_posts       ← 포스트 검색                                         │
│  ├── create_post        ← 포스트 생성                                         │
│  ├── dm_self            ← 자신에게 DM 전송                                    │
│  ├── create_channel     ← 채널 생성                                           │
│  ├── get_channel_info   ← 채널 정보                                           │
│  ├── get_channel_members← 채널 멤버                                           │
│  ├── add_user_to_channel← 채널에 사용자 추가                                  │
│  ├── get_team_info      ← 팀 정보                                             │
│  ├── get_team_members   ← 팀 멤버                                             │
│  └── search_users       ← 사용자 검색                                         │
└───────────────────────────────────────────────────────────────────────────────┘

Transport Options:
┌───────────────────────────────────────────────────────────────────────────────┐
│  HTTPServer (Streamable HTTP)                                                  │
│  └── /plugins/mattermost-ai/mcp-server/mcp                                    │
│      ├── OAuth 2.0 인증 (DCR 지원)                                            │
│      └── Personal Access Token 인증                                           │
└───────────────────────────────────────────────────────────────────────────────┘
┌───────────────────────────────────────────────────────────────────────────────┐
│  InMemoryServer (Embedded)                                                     │
│  └── AI 에이전트 내부에서 직접 접근                                           │
└───────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. 스트리밍 아키텍처

### 7.1 스트림 이벤트 처리

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        Stream Event Processing                                │
└──────────────────────────────────────────────────────────────────────────────┘

LLM Provider ──────────────────────────────────────────────────────────────────►
     │
     │  HTTP/SSE Stream
     ▼
┌─────────────────┐
│ LLM Client      │
│ (OpenAI/etc)    │
└────────┬────────┘
         │
         │  Parse chunks into events
         ▼
┌─────────────────┐
│ TextStreamResult│
│ .Stream channel │
└────────┬────────┘
         │
         │  StreamEvent{Type, Value}
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        StreamToPost Event Loop                               │
│                                                                              │
│  for {                                                                       │
│      select {                                                                │
│      case event := <-stream.Stream:                                          │
│          switch event.Type {                                                 │
│                                                                              │
│          case EventTypeText:                                                 │
│              ┌────────────────────────────────────────────────────────────┐ │
│              │ 1. Append text to messageBuilder                           │ │
│              │ 2. Send WebSocket "postupdate" with content                │ │
│              └────────────────────────────────────────────────────────────┘ │
│                                                                              │
│          case EventTypeReasoning:                                            │
│              ┌────────────────────────────────────────────────────────────┐ │
│              │ 1. Append to reasoningBuffer                               │ │
│              │ 2. Send WebSocket "reasoning_summary" event                │ │
│              └────────────────────────────────────────────────────────────┘ │
│                                                                              │
│          case EventTypeReasoningEnd:                                         │
│              ┌────────────────────────────────────────────────────────────┐ │
│              │ 1. Send "reasoning_summary_done" event                     │ │
│              │ 2. Store in post props (ReasoningSummaryProp)              │ │
│              │ 3. Store signature (ReasoningSignatureProp)                │ │
│              └────────────────────────────────────────────────────────────┘ │
│                                                                              │
│          case EventTypeToolCalls:                                            │
│              ┌────────────────────────────────────────────────────────────┐ │
│              │ 1. Set status to "pending" for all tools                   │ │
│              │ 2. Store in post props (ToolCallProp)                      │ │
│              │ 3. Update post in database                                 │ │
│              │ 4. Send WebSocket "tool_call" event                        │ │
│              │ 5. Return (wait for user approval)                         │ │
│              └────────────────────────────────────────────────────────────┘ │
│                                                                              │
│          case EventTypeAnnotations:                                          │
│              ┌────────────────────────────────────────────────────────────┐ │
│              │ 1. Store in post props (AnnotationsProp)                   │ │
│              │ 2. Send WebSocket "annotations" event                      │ │
│              └────────────────────────────────────────────────────────────┘ │
│                                                                              │
│          case EventTypeEnd:                                                  │
│              ┌────────────────────────────────────────────────────────────┐ │
│              │ 1. Final update to database                                │ │
│              │ 2. Send WebSocket "end" event                              │ │
│              │ 3. Return                                                  │ │
│              └────────────────────────────────────────────────────────────┘ │
│                                                                              │
│          case EventTypeError:                                                │
│              ┌────────────────────────────────────────────────────────────┐ │
│              │ 1. Set error message                                       │ │
│              │ 2. Save partial reasoning if any                           │ │
│              │ 3. Update post with error                                  │ │
│              │ 4. Return                                                  │ │
│              └────────────────────────────────────────────────────────────┘ │
│          }                                                                   │
│                                                                              │
│      case <-ctx.Done():                                                      │
│          // Handle cancellation                                              │
│      }                                                                       │
│  }                                                                           │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. 검색 및 임베딩 아키텍처

### 8.1 임베딩 검색 흐름

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        Embedding Search Architecture                          │
└──────────────────────────────────────────────────────────────────────────────┘

                              Indexing Flow
                              ─────────────
New/Updated Post ───────────────────────────────────────────────────────────────►
         │
         ▼
┌─────────────────┐
│ Indexer Service │
│ IndexPost()     │
└────────┬────────┘
         │
         ├──► Filter: Skip system messages, empty posts
         │
         ▼
┌─────────────────┐
│ Chunking        │
│ Service         │
└────────┬────────┘
         │
         ├──► Strategy: Sentences / Paragraphs / Fixed Size
         │
         ▼
┌─────────────────┐
│ Embeddings      │
│ Provider        │
└────────┬────────┘
         │
         ├──► API call to embedding model
         │    (e.g., OpenAI text-embedding-3-small)
         │
         ▼
┌─────────────────┐
│ PostgreSQL      │
│ pgvector        │
└─────────────────┘


                              Search Flow
                              ───────────
User Query ─────────────────────────────────────────────────────────────────────►
         │
         ▼
┌─────────────────┐
│ Search Service  │
│ SearchQuery()   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Generate Query  │
│ Embedding       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ pgvector        │
│ Similarity      │
│ Search          │
└────────┬────────┘
         │
         │  SELECT * FROM embeddings
         │  ORDER BY embedding <=> $query_embedding
         │  LIMIT $max_results
         │
         ▼
┌─────────────────┐
│ Permission      │
│ Filtering       │
└────────┬────────┘
         │
         ├──► Filter results based on user's channel access
         │
         ▼
┌─────────────────┐
│ Enrich Results  │
│ (RAGResult)     │
└────────┬────────┘
         │
         ├──► Add channel names, usernames, metadata
         │
         ▼
┌─────────────────┐
│ Generate Answer │
│ with LLM        │
└────────┬────────┘
         │
         ├──► Use search_system.tmpl prompt
         │
         ▼
┌─────────────────┐
│ Return Response │
└─────────────────┘
```

### 8.2 데이터베이스 스키마

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           Database Schema                                     │
└──────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────────┐
│  Table: LLM_PostMeta                                                           │
│  ├── RootPostID: TEXT PRIMARY KEY REFERENCES Posts(ID) ← 스레드 루트 포스트 ID│
│  └── Title:      TEXT NOT NULL               ← AI 생성 제목                   │
└───────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────────┐
│  Table: llm_posts_embeddings                                                   │
│  ├── id:           TEXT PRIMARY KEY        ← Post ID 또는 chunk ID            │
│  ├── post_id:      TEXT NOT NULL           ← 원본 포스트 ID (FK → Posts)      │
│  ├── team_id:      TEXT NOT NULL           ← 팀 ID                            │
│  ├── channel_id:   TEXT NOT NULL           ← 채널 ID                          │
│  ├── user_id:      TEXT NOT NULL           ← 작성자 ID                        │
│  ├── content:      TEXT NOT NULL           ← 텍스트 콘텐츠                    │
│  ├── embedding:    VECTOR(dimensions)      ← 임베딩 벡터 (pgvector)           │
│  ├── created_at:   BIGINT NOT NULL         ← 생성 시간                        │
│  ├── is_chunk:     BOOLEAN DEFAULT FALSE   ← 청크 여부                        │
│  ├── chunk_index:  INTEGER                 ← 청크 인덱스 (NULL if not chunk)  │
│  └── total_chunks: INTEGER                 ← 전체 청크 수 (NULL if not chunk) │
│                                                                                │
│  Indexes:                                                                      │
│  ├── llm_posts_embeddings_embedding_idx USING hnsw (embedding vector_l2_ops)  │
│  ├── llm_posts_embeddings_post_id_idx ON (post_id)                            │
│  └── llm_posts_embeddings_is_chunk_idx ON (is_chunk)                          │
└───────────────────────────────────────────────────────────────────────────────┘
```

---

## 9. 보안 아키텍처

### 9.1 인증 및 권한 흐름

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        Authentication & Authorization                         │
└──────────────────────────────────────────────────────────────────────────────┘

HTTP Request ─────────────────────────────────────────────────────────────────►
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          API Router Middleware                               │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ MattermostAuthorizationRequired                                        │ │
│  │ ├── Check: Mattermost-User-Id header                                   │ │
│  │ └── Reject: 401 Unauthorized if missing                                │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                               │                                              │
│                               ▼                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ interPluginAuthorizationRequired (Bridge API only)                     │ │
│  │ ├── Check: Mattermost-Plugin-ID header                                 │ │
│  │ └── Reject: 401 Unauthorized if missing                                │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                               │                                              │
│                               ▼                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ aiBotRequired                                                          │ │
│  │ ├── Get: botUsername from query parameter                              │ │
│  │ └── Set: Bot in context                                                │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                               │                                              │
│                               ▼                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ postAuthorizationRequired                                              │ │
│  │ ├── Check: User has permission to read post/channel                    │ │
│  │ ├── Check: Bot access restrictions for channel/user                    │ │
│  │ └── Reject: 403 Forbidden if not permitted                             │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                               │                                              │
│                               ▼                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ mattermostAdminAuthorizationRequired (Admin API only)                  │ │
│  │ ├── Check: User has MANAGE_SYSTEM permission                           │ │
│  │ └── Reject: 403 Forbidden if not admin                                 │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 9.2 도구 실행 보안

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        Tool Execution Security                                │
└──────────────────────────────────────────────────────────────────────────────┘

Tool Call Request ──────────────────────────────────────────────────────────────►
         │
         ▼
┌─────────────────┐
│ Check: Is DM?   │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌───────┐ ┌───────┐
│  Yes  │ │  No   │
│  DM   │ │Channel│
└───┬───┘ └───┬───┘
    │         │
    ▼         ▼
┌───────┐ ┌───────────────────────────────────────────┐
│Execute│ │ BLOCKED: Tools disabled in public channels │
│ Tool  │ │ DisabledToolsInfo provided for awareness   │
└───┬───┘ └───────────────────────────────────────────┘
    │
    ▼
┌─────────────────┐
│ User Approval   │
│ Required?       │
└────────┬────────┘
    │
    ├──► Yes: Show ToolCard, wait for Approve/Reject
    │
    ▼
┌─────────────────┐
│ Execute Tool    │
│ with User's     │
│ Permissions     │
└─────────────────┘

Security Rules:
┌───────────────────────────────────────────────────────────────────────────────┐
│ 1. Tools only execute in Direct Messages (DMs)                                │
│ 2. Every tool call requires explicit user approval                            │
│ 3. Tool results respect user's Mattermost permissions                         │
│ 4. MCP OAuth sessions are per-user                                            │
│ 5. API keys never exposed to client                                           │
└───────────────────────────────────────────────────────────────────────────────┘
```

### 9.3 봇 접근 제어

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           Bot Access Control                                  │
└──────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────────┐
│  BotConfig Access Levels                                                       │
│                                                                                │
│  ChannelAccessLevel:                                                           │
│  ├── ChannelAccessLevelAll (0)    ← 모든 채널 허용                            │
│  ├── ChannelAccessLevelAllow (1)  ← 지정된 채널만 허용                        │
│  ├── ChannelAccessLevelBlock (2)  ← 지정된 채널 차단                          │
│  └── ChannelAccessLevelNone (3)   ← 모든 채널 차단                            │
│                                                                                │
│  UserAccessLevel:                                                              │
│  ├── UserAccessLevelAll (0)       ← 모든 사용자 허용                          │
│  ├── UserAccessLevelAllow (1)     ← 지정된 사용자만 허용                      │
│  ├── UserAccessLevelBlock (2)     ← 지정된 사용자 차단                        │
│  └── UserAccessLevelNone (3)      ← 모든 사용자 차단                          │
│                                                                                │
│  TeamIDs:                                                                      │
│  └── 지정된 팀에서만 봇 사용 가능                                             │
└───────────────────────────────────────────────────────────────────────────────┘

CheckUsageRestrictions(userID, bot, channel) error
         │
         ├──► Check TeamIDs: Is user in allowed team?
         │
         ├──► Check UserAccessLevel:
         │    ├── All: Allow
         │    ├── Allow: Is user in UserIDs?
         │    ├── Block: Is user NOT in UserIDs?
         │    └── None: Block
         │
         └──► Check ChannelAccessLevel:
              ├── All: Allow
              ├── Allow: Is channel in ChannelIDs?
              ├── Block: Is channel NOT in ChannelIDs?
              └── None: Block
```

---

## 10. 확장성 설계

### 10.1 새 LLM 공급자 추가

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                      Adding New LLM Provider                                  │
└──────────────────────────────────────────────────────────────────────────────┘

Step 1: Create Provider Package
──────────────────────────────
newprovider/
├── newprovider.go       ← Main implementation
└── newprovider_test.go  ← Tests

Step 2: Implement LanguageModel Interface
─────────────────────────────────────────
type NewProvider struct {
    client     *newprovider.Client
    config     Config
    httpClient *http.Client
}

func (n *NewProvider) ChatCompletion(req llm.CompletionRequest, 
    opts ...llm.LanguageModelOption) (*llm.TextStreamResult, error) {
    // 1. Apply options
    // 2. Convert CompletionRequest to provider format
    // 3. Make API call with streaming
    // 4. Return TextStreamResult with event channel
}

func (n *NewProvider) ChatCompletionNoStream(req llm.CompletionRequest, 
    opts ...llm.LanguageModelOption) (string, error) {
    // Non-streaming version
}

func (n *NewProvider) CountTokens(text string) int {
    // Token counting (or estimation)
}

func (n *NewProvider) InputTokenLimit() int {
    return n.config.InputTokenLimit
}

Step 3: Add Service Type
────────────────────────
// llm/service_types.go
const ServiceTypeNewProvider = "newprovider"

Step 4: Register in Bots Service
────────────────────────────────
// bots/bots.go - getLLM method
case llm.ServiceTypeNewProvider:
    result = newprovider.New(
        config.NewProviderConfigFromServiceConfig(serviceConfig, botConfig),
        b.llmUpstreamHTTPClient,
    )

Step 5: Add Validation
──────────────────────
// llm/configuration.go - IsValidService
case ServiceTypeNewProvider:
    return service.APIKey != "" && service.DefaultModel != ""

Step 6: Add System Console UI
─────────────────────────────
// webapp/src/components/system_console/services_settings.tsx
Add new provider option with required fields
```

### 10.2 새 도구 추가

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           Adding New Tool                                     │
└──────────────────────────────────────────────────────────────────────────────┘

Option A: Internal Tool (mmtools/)
──────────────────────────────────

Step 1: Define Input Schema
type NewToolInput struct {
    Param1 string `json:"param1" jsonschema:"description=Parameter description"`
    Param2 int    `json:"param2" jsonschema:"description=Another parameter"`
}

Step 2: Define Tool
var newToolDefinition = llm.Tool{
    Name:        "new_tool",
    Description: "What this tool does",
    InputSchema: llm.NewJSONSchemaFromStruct[NewToolInput](),
}

Step 3: Implement Handler
func (t *MMToolProvider) NewTool(ctx context.Context, 
    args NewToolInput, userID string) (string, error) {
    // Implementation
    // Check permissions
    // Execute operation
    // Return result as string
}

Step 4: Register Tool
func (t *MMToolProvider) GetTools() []llm.Tool {
    return []llm.Tool{
        // ... existing tools
        newToolDefinition,
    }
}

func (t *MMToolProvider) ExecuteTool(ctx context.Context, 
    name string, args map[string]interface{}, userID string) (string, error) {
    switch name {
    // ... existing cases
    case "new_tool":
        var input NewToolInput
        // Parse args
        return t.NewTool(ctx, input, userID)
    }
}


Option B: MCP Server Tool (mcpserver/tools/)
────────────────────────────────────────────

Step 1: Create Tool File
// mcpserver/tools/new_tool.go

Step 2: Define Schema
type NewToolInput struct {
    Param1 string `json:"param1"`
}

Step 3: Implement Tool
func (p *Provider) NewTool(ctx context.Context, 
    userID string, input NewToolInput) (*mcpgolang.CallToolResult, error) {
    // Check permissions
    // Execute operation
    // Return result
    return &mcpgolang.CallToolResult{
        Content: []mcpgolang.Content{
            mcpgolang.TextContent{Text: "Result"},
        },
    }, nil
}

Step 4: Register in Provider
// mcpserver/tools/provider.go
func (p *Provider) GetTools() []mcpgolang.Tool {
    return []mcpgolang.Tool{
        // ... existing tools
        {
            Name:        "new_tool",
            Description: "What this tool does",
            InputSchema: jsonSchemaFromStruct[NewToolInput](),
        },
    }
}
```

### 10.3 새 프롬프트 템플릿 추가

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                       Adding New Prompt Template                              │
└──────────────────────────────────────────────────────────────────────────────┘

Step 1: Create Template File
────────────────────────────
// prompts/new_feature_system.tmpl
You are a helpful assistant specialized in {{.Feature}}.

{{if .Context}}
Context: {{.Context}}
{{end}}

{{if .Tools}}
Available tools: {{range .Tools}}
- {{.Name}}: {{.Description}}
{{end}}
{{end}}

Please help the user with: {{.Request}}

Step 2: Add Template Name Constant
──────────────────────────────────
// prompts/prompts_vars.go
const PromptNewFeatureSystem = "new_feature_system"

Step 3: Use in Code
───────────────────
context := llm.NewContext()
context.Parameters = map[string]interface{}{
    "Feature": "code review",
    "Context": "User is reviewing a Go file",
    "Tools":   availableTools,
    "Request": userMessage,
}

prompt, err := prompts.Format(prompts.PromptNewFeatureSystem, context)
if err != nil {
    return err
}
```

---

## 부록: 컴포넌트 참조표

### A. 서버 패키지 요약

| 패키지 | 목적 | 주요 타입 |
|--------|------|----------|
| `api` | HTTP API 핸들러 | `API`, 각종 핸들러 |
| `anthropic` | Anthropic Claude 통합 | `Anthropic` |
| `asage` | ASage LLM 통합 (실험적, 스트리밍 미지원) | `Provider` |
| `bedrock` | AWS Bedrock 통합 | `Bedrock` |
| `bots` | 봇 관리 | `MMBots`, `Bot` |
| `channels` | 채널 범위/시간 기반 요약 | `Channels` |
| `chunking` | 텍스트 청킹 | `Chunker` |
| `config` | 설정 관리 | `Configuration` |
| `conversations` | 대화 처리 | `Conversations` |
| `database` | DB 스키마 및 마이그레이션 | `SetupTables` |
| `embeddings` | 임베딩/벡터 검색 | `EmbeddingSearch` |
| `enterprise` | 라이선스 검사 | `LicenseChecker` |
| `format` | 포스트 데이터 포맷팅 | `ThreadData`, `PostBody` |
| `i18n` | 서버 국제화 | `Bundle`, `LocalizerFunc` |
| `indexer` | 포스트 인덱싱 | `Indexer` |
| `llm` | LLM 추상화 | `LanguageModel`, `CompletionRequest` |
| `llmcontext` | 컨텍스트 빌드 | `Builder` |
| `mcp` | MCP 클라이언트 | `ClientManager`, `Client` |
| `mcpserver` | MCP 서버 | `Server`, `HTTPServer` |
| `meetings` | 회의 서비스 | `Service` |
| `metrics` | 메트릭 | `Metrics` |
| `mmapi` | MM API 래퍼 | `Client` |
| `mmtools` | 내장 도구 | `MMToolProvider` |
| `openai` | OpenAI 통합 | `OpenAI` |
| `postgres` | PostgreSQL pgvector 벡터 저장소 | `PGVector` |
| `public/bridgeclient` | 플러그인 간 Bridge API 클라이언트 | `Client` |
| `react` | 이모지 반응 생성 | `React` |
| `search` | 검색 서비스 | `Search` |
| `server` | 플러그인 메인 및 초기화 | `Plugin` |
| `streaming` | 스트리밍 | `MMPostStreamService` |
| `subtitles` | 자막/녹취 처리 | `Subtitles` |
| `threads` | 스레드 분석 (요약, 액션 아이템 등) | `Threads` |

### B. 웹앱 컴포넌트 요약

| 컴포넌트 | 위치 | 용도 |
|----------|------|------|
| `RHS` | `components/rhs/` | 메인 AI 패널 |
| `LLMBotPost` | `components/llmbot_post/` | AI 응답 렌더링 |
| `ToolCard` | `components/tool_card.tsx` | 도구 호출 UI |
| `ToolApprovalSet` | `components/tool_approval_set.tsx` | 도구 승인 세트 |
| `PostMenu` | `components/post_menu.tsx` | AI 액션 메뉴 |
| `SystemConsole` | `components/system_console/` | 관리자 설정 |
| `BotSelector` | `components/bot_selector.tsx` | 봇 선택기 |
| `SearchSources` | `components/search_sources.tsx` | 검색 결과 소스 |
| `SearchButton` | `components/search_button.tsx` | 검색 버튼 |
| `SearchHints` | `components/search_hints.tsx` | 검색 힌트 |
| `AskAiInput` | `components/ask_ai_input.tsx` | AI 질문 입력 |
| `UnreadsSummarize` | `components/unreads_summarize.tsx` | 읽지 않은 메시지 요약 |
| `ConfirmationDialog` | `components/confirmation_dialog.tsx` | 확인 다이얼로그 |
| `PostbackPost` | `components/postback_post.tsx` | 포스트백 포스트 |
| `Citations` | `components/citations/` | 인용/출처 표시 |
| `PostText` | `components/post_text.tsx` | 포스트 텍스트 렌더링 |
| `PostPreview` | `components/post_preview.tsx` | 포스트 미리보기 |

### C. 주요 파일 경로

| 기능 | 파일 경로 |
|------|----------|
| 플러그인 진입점 | `server/main.go` |
| API 라우터 | `api/api.go` |
| LLM 인터페이스 | `llm/language_model.go` |
| 봇 관리 | `bots/bots.go` |
| 대화 처리 | `conversations/conversations.go` |
| 스트리밍 | `streaming/streaming.go` |
| 검색 | `search/search.go` |
| MCP 클라이언트 | `mcp/client_manager.go` |
| MCP 서버 | `mcpserver/server.go` |
| 프롬프트 | `prompts/*.tmpl` |
| 웹앱 진입점 | `webapp/src/index.tsx` |
| Redux | `webapp/src/redux.tsx` |
| WebSocket | `webapp/src/websocket.ts` |
