# SPECACT

**S**ecure **P**ersonal **E**cosystem for **C**ontent, **A**ccess, and **C**ontrol **T**rust

*No es una red social: es una red de contenido personal bajo tu control — soberano, propio y controlado.*

[English](README.md) · [Tiếng Việt](README.vi.md) · [中文](README.zh.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Русский](README.ru.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Español](README.es.md) · [ไทย](README.th.md) · [Bahasa Indonesia](README.id.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [Türkçe](README.tr.md)

---

SPECACT es una PWA de Vue 3 para **compartir publicaciones y fotos exactamente con las personas que elijas**. No hay servidor ni base de datos nuestros:

- Todos los datos viven en una **carpeta `SPECACT` de tu propio Google Drive**.
- Quién ve una publicación lo deciden los **permisos de Google Drive**: sin permiso no hay acceso, ni siquiera con el enlace.
- Tras cargar, el navegador **solo habla con Google** (la CSP bloquea cualquier otro destino). El alojamiento web solo sirve archivos estáticos.
- Cada usuario trae **su propio cliente OAuth de Google**; ID/secreto de cliente, tokens y claves nunca salen del dispositivo, están **cifrados dos veces** y protegidos por un **PIN de 6 dígitos**.

## Personal · Soberano · Descentralizado

- Soberanía: tus datos viven en tu Drive, sin proveedor en medio — ningún servidor del proyecto puede almacenarlos, leerlos ni modificarlos.
- Personalización: tú decides quién ve, quién comenta y qué publicaciones llevan contraseña o son públicas por enlace.
- Descentralización: un formato de datos abierto permite que muchos sitios y apps compartan una misma fuente de datos personal.

## Funciones

- Publicaciones: crear, editar, borrar; fotos (redimensionadas, sin EXIF/GPS) con visor de diapositivas (zoom, giro).
- Compartir: menciones `@correo`, roles «puede ver» / «puede comentar», revocación en cualquier momento.
- Enlace público: «cualquiera con el enlace» abre solo los archivos de la publicación, nunca la carpeta.
- Publicaciones con contraseña, cifradas en el navegador (AES-256-GCM).
- Modos de comentarios: abierto / solo personas compartidas / bloqueado — aplicados en Drive. Los «me gusta» siguen a quien puede ver la publicación.
- Índice personal rápido (index.json) con caché local cifrada.
- Bóveda local con doble cifrado, PIN de 6 dígitos, bloqueo automático, borrado tras demasiados intentos fallidos.
- 14 idiomas (con RTL), claro/oscuro, adaptable, PWA instalable, modo demo `#/demo`, páginas Acerca de / Términos / Privacidad.

## Inicio rápido

```bash
npm install
npm run dev            # http://localhost:5173
```

Para uso real, crea tu propio cliente OAuth de Google (unos 5 minutos): docs/GOOGLE_SETUP.md. Abre `#/demo` para una vista previa sin configurar nada.

## Docker

```bash
cp .env.example .env
docker compose up -d --build   # http://localhost:8088
```

- Construye y ejecuta con el comando anterior; cambia el puerto con `SPECACT_PORT` en `.env`.
- nginx sin root, sistema de archivos de solo lectura, CSP estricta. Edita `.env` y ejecuta `docker compose up -d` — sin reconstruir.
- Usa HTTPS en un dominio real (Google solo permite `http://` en localhost; WebCrypto exige contexto seguro).
- Todos los ajustes están documentados en `.env.example`. Nunca pongas un secreto de cliente de Google en `.env`.

## Limitaciones conocidas

- La lógica de Drive se prueba contra un Drive simulado, no contra Google real — prueba primero con una cuenta desechable.
- En modo Testing, los tokens de actualización de Google caducan a los 7 días (vuelve a iniciar sesión).
- Quien comenta puede, técnicamente, editar comentarios ajenos vía Drive; las escrituras simultáneas rara vez se pisan.
- Revocar el acceso no borra lo ya visto; la protección con contraseña vale lo que valga la contraseña.

---

Más documentación (English / Tiếng Việt): [Architecture](docs/ARCHITECTURE.md) · [Security](docs/SECURITY.md) · [Google setup](docs/GOOGLE_SETUP.md) · [Open format](docs/OPEN_FORMAT.md) — [Kiến trúc](docs/ARCHITECTURE.vi.md) · [Bảo mật](docs/SECURITY.vi.md) · [Thiết lập Google](docs/GOOGLE_SETUP.vi.md) · [Định dạng mở](docs/OPEN_FORMAT.vi.md)

Reglas para colaboradores: CLAUDE.md ([EN](CLAUDE.md) · [VI](CLAUDE.vi.md))

Licencia: MIT.
