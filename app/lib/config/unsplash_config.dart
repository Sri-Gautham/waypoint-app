/// Unsplash's free API tier is used for Android trip covers (search a
/// photo by destination name) since there's no on-device generative
/// equivalent to iOS's Image Playground yet. Register a free app at
/// https://unsplash.com/oauth/applications to get an Access Key, then
/// paste it below. Cover generation on Android silently falls back to
/// the illustrated presets while this is empty.
class UnsplashConfig {
  static const accessKey = '';
}
