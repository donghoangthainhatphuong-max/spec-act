# SPECACT

**S**ecure **P**ersonal **E**cosystem for **C**ontent, **A**ccess, and **C**ontrol **T**rust

*소셜 네트워크가 아닙니다. 내가 통제하는 개인 콘텐츠 네트워크로, 주권이 있고, 소유하며, 통제합니다.*

[English](README.md) · [Tiếng Việt](README.vi.md) · [中文](README.zh.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Русский](README.ru.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Español](README.es.md) · [ไทย](README.th.md) · [Bahasa Indonesia](README.id.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [Türkçe](README.tr.md)

---

SPECACT는 **내가 고른 사람에게만** 글과 사진을 공유하는 Vue 3 PWA입니다. 우리의 서버도 데이터베이스도 없습니다.

- 모든 데이터는 **내 Google 드라이브의 `SPECACT` 폴더**에 저장됩니다.
- 누가 글을 볼 수 있는지는 **Google 드라이브 권한**이 결정합니다. 권한이 없으면 링크가 있어도 접근할 수 없습니다.
- 로딩 후 브라우저는 **Google과만 통신**합니다(CSP가 그 외 모든 곳을 차단). 웹 호스트는 정적 파일만 제공합니다.
- 모든 사용자는 **자신의 Google OAuth 클라이언트**를 사용합니다. 클라이언트 ID/시크릿, 토큰, 키는 기기를 떠나지 않고 **이중 암호화**되며 **6자리 PIN**으로 보호됩니다.

## 개인화 · 데이터 주권 · 분산

- 데이터 주권: 데이터는 내 드라이브에 있고 중간 사업자가 없습니다. 이 프로젝트의 어떤 서버도 저장·열람·변경할 수 없습니다.
- 개인화: 누가 보고, 누가 댓글을 달고, 어떤 글에 비밀번호를 걸거나 링크로 공개할지 직접 정합니다.
- 분산: 개방형 데이터 형식으로 여러 웹사이트와 앱이 하나의 개인 데이터 원본을 공유할 수 있습니다.

## 기능

- 글: 작성·수정·삭제, 사진(리사이즈, EXIF/GPS 제거), 확대·회전이 되는 슬라이드 뷰어.
- 공유: `@이메일` 멘션, “보기”/“댓글” 권한, 언제든 취소.
- 공개 링크: “링크가 있는 누구나”는 글의 파일만 열며 폴더는 절대 열지 않습니다.
- 비밀번호로 보호된 글은 브라우저에서 암호화(AES-256-GCM)됩니다.
- 댓글 모드: 모두 / 공유한 사람만 / 잠금 — Drive에서 강제됩니다. 좋아요는 글을 볼 수 있는 사람을 따릅니다.
- 암호화된 로컬 캐시를 쓰는 빠른 개인 색인(index.json).
- 이중 암호화 로컬 보관함, 6자리 PIN, 자동 잠금, 오입력 누적 시 삭제.
- 14개 언어(RTL 포함), 라이트/다크, 반응형, 설치 가능한 PWA, `#/demo` 데모, 소개/약관/개인정보 페이지.

## 빠른 시작

```bash
npm install
npm run dev            # http://localhost:5173
```

실제 사용에는 자신의 Google OAuth 클라이언트를 만드세요(약 5분): docs/GOOGLE_SETUP.md. 설정 없이 `#/demo`를 열어 미리 볼 수 있습니다.

## Docker

```bash
cp .env.example .env
docker compose up -d --build   # http://localhost:8088
```

- 위 명령으로 빌드·실행하고, 포트는 `.env`의 `SPECACT_PORT`로 바꿉니다.
- non-root nginx, 읽기 전용 파일시스템, 엄격한 CSP. `.env`를 수정하고 `docker compose up -d`만 하면 되며 재빌드는 필요 없습니다.
- 실제 도메인에는 HTTPS를 쓰세요(Google은 localhost에만 http://를 허용하며 WebCrypto는 보안 컨텍스트가 필요합니다).
- 모든 설정은 `.env.example`에 설명되어 있습니다. Google 클라이언트 시크릿을 `.env`에 넣지 마세요.

## 알려진 제한

- Drive 로직은 실제 Google이 아닌 모의 Drive로 테스트했습니다. 먼저 임시 계정으로 시도하세요.
- Testing 모드에서는 Google 리프레시 토큰이 7일 후 만료됩니다(다시 로그인).
- 댓글 권한자는 기술적으로 Drive를 통해 다른 사람의 댓글을 수정할 수 있고, 동시 쓰기는 드물게 서로 덮어쓸 수 있습니다.
- 접근을 취소해도 이미 본 내용은 지울 수 없습니다. 비밀번호 보호의 강도는 비밀번호에 달려 있습니다.

---

추가 문서(English / Tiếng Việt): [Architecture](docs/ARCHITECTURE.md) · [Security](docs/SECURITY.md) · [Google setup](docs/GOOGLE_SETUP.md) · [Open format](docs/OPEN_FORMAT.md) — [Kiến trúc](docs/ARCHITECTURE.vi.md) · [Bảo mật](docs/SECURITY.vi.md) · [Thiết lập Google](docs/GOOGLE_SETUP.vi.md) · [Định dạng mở](docs/OPEN_FORMAT.vi.md)

🌐 **[specact.com](https://specact.com)** · [GitHub](https://github.com/donghoangthainhatphuong-max/spec-act)

기여자 규칙: CLAUDE.md ([EN](CLAUDE.md) · [VI](CLAUDE.vi.md))

라이선스: MIT.
