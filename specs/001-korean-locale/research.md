# Research: 한국어 로케일 지원

Technical Context에 NEEDS CLARIFICATION은 없었다. 아래는 계획을 확정하기 위해 코드에서
직접 확인한 사실과 그에 따른 결정이다.

## 1. webapp은 로케일을 어떻게 고르나

- **확인**: `webapp/src/index.tsx`의 `registerTranslations((locale) => require(`./i18n/${locale}.json`))`
  과 `getStaticIntl()`(`state.entities.i18n.locale`, 기본 `'en'`) 둘 다 로케일 문자열로
  파일을 동적 `require`한다. 실패하면 `{}` 또는 `en.json`으로 폴백한다.
- **결정**: `webapp/src/i18n/ko.json`만 추가한다. 코드 변경 없음.
- **근거**: Mattermost webapp의 사용자 로케일 값은 `ko`(언어 코드)다. webpack은 동적
  `require`의 디렉터리 패턴(`./i18n/*.json`)을 컨텍스트 모듈로 번들하므로 새 파일이
  자동으로 포함된다 — `es.json`이 지금 그렇게 들어간다.
- **대안 검토**: 로케일 정규화(`ko-KR`→`ko`)를 webapp에 넣는 안 — Mattermost가 이미
  언어 코드로 넘기므로 불필요. 범위 밖으로 둔다.

## 2. server는 로케일을 어떻게 받나

- **확인**: `i18n.LocalizerFunc(bundle, lang)`을 `streaming/streaming.go`,
  `conversations/handle_messages.go`, `meetings/meeting_summarization.go` 등이
  `user.Locale` 또는 `fallbackLocale(...)`(서버 기본 로케일)로 호출한다. `Init()`은
  `language.English` 기본 번들에 `es.json`만 `LoadMessageFileFS`로 올린다.
- **결정**: `Init()`에 `_, _ = bundle.LoadMessageFileFS(i18nFiles, "i18n/ko.json")` 추가.
  `//go:embed *.json`이라 파일은 자동 포함된다.
- **근거**: go-i18n v2는 파일명에서 언어 태그를 읽는다(`ko.json` → `ko`). 미등록 id는
  `MustLocalize`의 `DefaultMessage`(영어)로 폴백하므로 FR-005를 만족한다.
- **주의**: 기존 코드가 로드 오류를 버린다(`_, _ =`). ko 파일 형식 오류는 조용히 영어
  폴백이 된다 — 그래서 `i18n_test.go`가 실제 한국어 문구를 단언해야 한다(US3-4).

## 3. 한국어 복수형

- **확인**: CLDR 한국어 복수 규칙은 cardinal `other` 하나. react-intl(Intl.PluralRules)과
  go-i18n 모두 CLDR을 따른다. 영어 원문의 plural 15개는 모두 `one`/`other` 두 분기.
- **결정**: 한국어 번역은 `{count, plural, other {도구 #개}}` 형태로 `other`만 둔다.
  테스트에서 `ko`의 plural 요소에 `one`이 없는지 단언한다(실수로 영어 구조를 복사하면
  잡힌다). 영어 전용 검사("one 범주 필수")는 `en`에만 건다.
- **대안 검토**: `one`을 남겨 두기 — 문법상 허용되지만 Intl.PluralRules('ko')가 절대
  선택하지 않아 죽은 분기가 된다. 명시적으로 금지하는 쪽이 유지보수에 낫다.

## 4. 자리표시자 집합 비교 방법

- **확인**: 테스트가 이미 `@formatjs/icu-messageformat-parser`를 쓴다. AST에서
  `isArgumentElement`/`isPluralElement`/`isSelectElement`/`isTagElement`/`isNumberElement`/
  `isDateElement`/`isTimeElement`의 `value`를 모으면 인자 이름 집합이 나오고, 태그는
  `value`가 태그 이름이다. plural/select의 `options`와 tag의 `children`을 재귀하면 된다.
  `#`(pound)은 이름이 없으므로 제외.
- **결정**: `placeholders(message): Set<string>` 도우미를 테스트 파일 안에 두고 `en`과
  `ko`의 집합을 키별로 비교한다. 새 라이브러리 없음(원칙 II).

## 5. 기존 초안(`temp/korean`) 재활용

- **확인**: webapp 초안 79키는 과거 `es.json` 세대의 키라 현재 `en.json` 1,029키와 해시가
  대부분 다르다. 문구 자체는 참고 가치가 있다(용어·어조). server 초안 12 id 중 7개가
  현재 id와 일치한다(`no_longer_access_error`, `stream_to_post_*`, `summairize_subscription_error`,
  `summarize_call_recording_processing*`, `summarize_recording`, `summarize_transcription`).
- **결정**: 초안을 **용어와 어조의 기준**으로만 쓴다(glossary.md로 추출). 파일을 그대로
  가져오지 않고 현재 원문 기준으로 새로 채운다. `temp/korean`의 다른 코드 변경은 가져오지
  않는다.

## 6. 용어·어조 기준

- **결정**: Mattermost 공식 한국어 번역의 관례를 따른다 — 존댓말 "~합니다/~하세요",
  버튼·메뉴는 명사형("새 채팅", "재생성"), 설정 항목은 명사구, 오류 안내는 "~할 수
  없습니다". 제품·서비스명(Mattermost, Agents, MCP, OpenAI, Anthropic, Azure, Bedrock,
  Ollama 등)과 기술 용어(API, LLM, 토큰, OAuth)는 원문 또는 통용 음차.
- **근거**: 플러그인 문구가 Mattermost 본체 화면 안에 섞여 보이므로 본체 번역과 어조가
  다르면 이질감이 난다. 세부는 glossary.md.

## 7. `en.json` 불변 증명

- **확인**: `make check-i18n`은 `en.json`을 재추출해 diff가 나면 실패한다.
- **결정**: 마감 게이트에 `make check-i18n`을 넣어 webapp 원문을 건드리지 않았음을 증명한다.
