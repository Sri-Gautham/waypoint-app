/// Unsplash's free API tier is used for Android trip covers (search a
/// photo by destination name) since there's no on-device generative
/// equivalent to iOS's Image Playground yet.
///
/// This is the free "Demo" tier (50 requests/hour) — plenty for testing,
/// but production use with real users needs Unsplash's (also free)
/// "Production" approval first: https://unsplash.com/oauth/applications
/// > this app > Apply.
class UnsplashConfig {
  static const accessKey = '3rafgT3C_GrRDCW2dJxo5RDZ5WvxOt2CFjmTkOmErmk';
}
