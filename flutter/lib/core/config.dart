/// Central configuration (compile-time; override with --dart-define=NAME=value).
class Config {
  static const rootFolder = String.fromEnvironment(
    'DRIVE_ROOT_FOLDER',
    defaultValue: 'SPECACT',
  );
  static const postsFolder = String.fromEnvironment(
    'DRIVE_POSTS_FOLDER',
    defaultValue: 'posts',
  );
  static const oauthScope = String.fromEnvironment(
    'OAUTH_SCOPE',
    defaultValue: 'https://www.googleapis.com/auth/drive',
  );
  static const pbkdf2Iterations = int.fromEnvironment(
    'PBKDF2_ITERATIONS',
    defaultValue: 600000,
  );
  static const postKdfIterations = int.fromEnvironment(
    'POST_KDF_ITERATIONS',
    defaultValue: 310000,
  );
  static const pinLength = int.fromEnvironment('PIN_LENGTH', defaultValue: 6);
  static const pinMaxAttempts = int.fromEnvironment(
    'PIN_MAX_ATTEMPTS',
    defaultValue: 10,
  );
  static const autoLockMinutes = int.fromEnvironment(
    'AUTO_LOCK_MINUTES',
    defaultValue: 5,
  );
  static const maxImagesPerPost = int.fromEnvironment(
    'MAX_IMAGES_PER_POST',
    defaultValue: 20,
  );
  static const maxImageSide = int.fromEnvironment(
    'MAX_IMAGE_SIDE',
    defaultValue: 2048,
  );
  static const chatUrl = String.fromEnvironment(
    'CHAT_URL_TEMPLATE',
    defaultValue: 'https://mail.google.com/chat/?authuser={me}#chat/dm/{email}',
  );
}
