# SPECACT

**S**ecure **P**ersonal **E**cosystem for **C**ontent, **A**ccess, and **C**ontrol **T**rust

*Sosyal ağ değil — kontrolün sizde olduğu kişisel içerik ağı: egemen, size ait ve denetimli.*

[English](README.md) · [Tiếng Việt](README.vi.md) · [中文](README.zh.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Русский](README.ru.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Español](README.es.md) · [ไทย](README.th.md) · [Bahasa Indonesia](README.id.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [Türkçe](README.tr.md)

---

SPECACT, gönderileri ve fotoğrafları **yalnızca seçtiğiniz kişilerle** paylaşmak için bir Vue 3 PWA'sıdır. Bizim sunucumuz ya da veritabanımız yoktur:

- Tüm veriler **kendi Google Drive'ınızdaki `SPECACT` klasöründe** durur.
- Bir gönderiyi kimin göreceğine **Google Drive izinleri** karar verir — izin yoksa erişim yok, bağlantı olsa bile.
- Yüklendikten sonra tarayıcı **yalnızca Google ile konuşur** (CSP diğer tüm hedefleri engeller). Web sunucusu yalnızca statik dosya sunar.
- Her kullanıcı **kendi Google OAuth istemcisini** getirir; istemci kimliği/gizli anahtarı, belirteçler ve anahtarlar cihazdan çıkmaz, **iki kez şifrelenir** ve **6 haneli PIN** ile korunur.

## Kişisel · Egemen · Merkeziyetsiz

- Veri egemenliği: verileriniz Drive'ınızda, arada sağlayıcı yok — projenin hiçbir sunucusu onları saklayamaz, okuyamaz veya değiştiremez.
- Kişiselleştirme: kimin göreceğine, kimin yorum yapacağına, hangi gönderilerin parolalı ya da bağlantıyla herkese açık olacağına siz karar verirsiniz.
- Merkeziyetsizlik: açık veri biçimi, birçok sitenin ve uygulamanın aynı kişisel veri kaynağınızı paylaşmasını sağlar.

## Özellikler

- Gönderiler: oluştur, düzenle, sil; fotoğraflar (yeniden boyutlandırma, EXIF/GPS temizleme) ve slayt görüntüleyici (yakınlaştırma, döndürme).
- Paylaşım: `@e-posta` anmaları, “görebilir”/“yorum yapabilir” rolleri, istediğiniz an geri alma.
- Herkese açık bağlantı: “bağlantıya sahip herkes” yalnızca gönderinin dosyalarını açar, klasörü asla.
- Parolalı gönderiler tarayıcıda şifrelenir (AES-256-GCM).
- Yorum modları: açık / yalnızca paylaşılanlar / kilitli — Drive'da uygulanır. Beğeniler gönderiyi görebilenleri izler.
- Şifreli yerel önbellekli hızlı kişisel dizin (index.json).
- İki katmanlı şifreli yerel kasa, 6 haneli PIN, otomatik kilit, çok fazla yanlışta silme.
- 14 dil (RTL dahil), açık/koyu, duyarlı, kurulabilir PWA, `#/demo` demo modu, Hakkında/Koşullar/Gizlilik sayfaları.

## Hızlı başlangıç

```bash
npm install
npm run dev            # http://localhost:5173
```

Gerçek kullanım için kendi Google OAuth istemcinizi oluşturun (yaklaşık 5 dakika): docs/GOOGLE_SETUP.md. Kurulumsuz önizleme için `#/demo` açın.

## Docker

```bash
cp .env.example .env
docker compose up -d --build   # http://localhost:8088
```

- Yukarıdaki komutla derleyip çalıştırın; portu `.env` içindeki `SPECACT_PORT` ile değiştirin.
- Root olmayan nginx, salt okunur dosya sistemi, sıkı CSP. `.env` dosyasını düzenleyip `docker compose up -d` çalıştırın — yeniden derleme gerekmez.
- Gerçek bir alan adı için HTTPS kullanın (Google `http://` yalnızca localhost için izin verir; WebCrypto güvenli bağlam ister).
- Tüm ayarlar `.env.example` içinde belgelenmiştir. Google istemci gizli anahtarını asla `.env` içine koymayın.

## Bilinen sınırlamalar

- Drive mantığı gerçek Google'a değil, simüle edilmiş bir Drive'a karşı test edilir — önce atılabilir bir hesapla deneyin.
- Testing modunda Google yenileme belirteçleri 7 günde dolar (yeniden giriş yapın).
- Yorumcular teknik olarak Drive üzerinden başkalarının yorumlarını düzenleyebilir; eşzamanlı yazmalar nadiren birbirinin üzerine yazabilir.
- Erişimi geri almak zaten görülenleri geri almaz; parola korumasının gücü parolanın gücü kadardır.

---

Daha fazla belge (English / Tiếng Việt): [Architecture](docs/ARCHITECTURE.md) · [Security](docs/SECURITY.md) · [Google setup](docs/GOOGLE_SETUP.md) · [Open format](docs/OPEN_FORMAT.md) — [Kiến trúc](docs/ARCHITECTURE.vi.md) · [Bảo mật](docs/SECURITY.vi.md) · [Thiết lập Google](docs/GOOGLE_SETUP.vi.md) · [Định dạng mở](docs/OPEN_FORMAT.vi.md)

Katkıda bulunanlar için kurallar: CLAUDE.md ([EN](CLAUDE.md) · [VI](CLAUDE.vi.md))

Lisans: MIT.
