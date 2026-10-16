<div dir="rtl">

# SPECACT

**S**ecure **P**ersonal **E**cosystem for **C**ontent, **A**ccess, and **C**ontrol **T**rust

*ليست شبكة اجتماعية — بل شبكة محتوى شخصي تحت سيطرتك: ذات سيادة، مملوكة لك، ومتحكَّم بها.*

[English](README.md) · [Tiếng Việt](README.vi.md) · [中文](README.zh.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Русский](README.ru.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Español](README.es.md) · [ไทย](README.th.md) · [Bahasa Indonesia](README.id.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [Türkçe](README.tr.md)

---

SPECACT تطبيق PWA مبني على Vue 3 **لمشاركة المنشورات والصور مع من تختارهم فقط**. لا يوجد خادم أو قاعدة بيانات تابعة لنا:

- تعيش كل البيانات في **مجلد `SPECACT` داخل Google Drive الخاص بك**.
- من يرى المنشور تحدده **أذونات Google Drive** — بلا إذن لا وصول، حتى مع الرابط.
- بعد التحميل **يتحدث المتصفح مع Google فقط** (تحجب CSP كل وجهة أخرى). المضيف يقدّم ملفات ثابتة فقط.
- يستخدم كل مستخدم **عميل OAuth الخاص به من Google**؛ لا يغادر معرّف العميل/السرّ والرموز والمفاتيح الجهاز، وهي **مشفّرة مرتين** ومحمية برمز **PIN من 6 أرقام**.

## شخصي · سيادي · لامركزي

- سيادة البيانات: بياناتك في Drive الخاص بك دون مزوّد في الوسط — لا يستطيع أي خادم للمشروع تخزينها أو قراءتها أو تعديلها.
- التخصيص: أنت تقرر من يرى ومن يعلّق وأي المنشورات محمية بكلمة مرور أو عامة عبر رابط.
- اللامركزية: صيغة بيانات مفتوحة تتيح لمواقع وتطبيقات كثيرة مشاركة مصدر بياناتك الشخصي نفسه.

## الميزات

- المنشورات: إنشاء وتعديل وحذف؛ صور (تصغير، إزالة EXIF/GPS) مع عارض شرائح (تكبير، تدوير).
- المشاركة: إشارات `@البريد`، أدوار «يمكنه المشاهدة»/«يمكنه التعليق»، وإلغاء في أي وقت.
- الرابط العام: «أي شخص لديه الرابط» يفتح ملفات المنشور فقط، ولا يفتح المجلد أبدًا.
- منشورات محمية بكلمة مرور ومشفّرة في المتصفح (AES-256-GCM).
- أوضاع التعليق: مفتوح / المشارَكون فقط / مقفل — تُطبَّق في Drive. الإعجاب يتبع من يرى المنشور.
- فهرس شخصي سريع (index.json) مع ذاكرة محلية مشفّرة.
- خزنة محلية بتشفير مزدوج، PIN من 6 أرقام، قفل تلقائي، ومسح بعد محاولات خاطئة كثيرة.
- 14 لغة (مع RTL)، فاتح/داكن، متجاوب، PWA قابل للتثبيت، وضع تجريبي `#/demo`، صفحات حول/الشروط/الخصوصية.

## بدء سريع

```bash
npm install
npm run dev            # http://localhost:5173
```

للاستخدام الفعلي أنشئ عميل OAuth خاصًا بك من Google (نحو 5 دقائق): docs/GOOGLE_SETUP.md. افتح `#/demo` لمعاينة دون أي إعداد.

## Docker

```bash
cp .env.example .env
docker compose up -d --build   # http://localhost:8088
```

- ابنِ وشغّل بالأمر أعلاه؛ غيّر المنفذ عبر `SPECACT_PORT` في `.env`.
- nginx بلا صلاحيات root، نظام ملفات للقراءة فقط، CSP صارمة. عدّل `.env` ثم `docker compose up -d` دون إعادة بناء.
- استخدم HTTPS لنطاق حقيقي (تسمح Google بـ `http://` للـ localhost فقط، ويحتاج WebCrypto إلى سياق آمن).
- كل الإعدادات موثّقة في `.env.example`. لا تضع سرّ عميل Google في `.env` أبدًا.

## قيود معروفة

- منطق Drive مُختبَر على Drive محاكى لا على Google الحقيقي — جرّب أولًا بحساب مؤقت.
- في وضع Testing تنتهي صلاحية رموز التحديث من Google بعد 7 أيام (سجّل الدخول مجددًا).
- يستطيع المعلّقون تقنيًا تعديل تعليقات غيرهم عبر Drive، وقد تتداخل الكتابات المتزامنة نادرًا.
- إلغاء الوصول لا يمحو ما رُئي بالفعل؛ وقوة الحماية بكلمة المرور من قوة كلمة المرور.

---

وثائق إضافية (English / Tiếng Việt): [Architecture](docs/ARCHITECTURE.md) · [Security](docs/SECURITY.md) · [Google setup](docs/GOOGLE_SETUP.md) · [Open format](docs/OPEN_FORMAT.md) — [Kiến trúc](docs/ARCHITECTURE.vi.md) · [Bảo mật](docs/SECURITY.vi.md) · [Thiết lập Google](docs/GOOGLE_SETUP.vi.md) · [Định dạng mở](docs/OPEN_FORMAT.vi.md)

🌐 **[specact.com](https://specact.com)** · [GitHub](https://github.com/donghoangthainhatphuong-max/spec-act)

قواعد المساهمين: CLAUDE.md ([EN](CLAUDE.md) · [VI](CLAUDE.vi.md))

الرخصة: MIT.

</div>
