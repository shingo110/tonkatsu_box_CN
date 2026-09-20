// A conditional import, not `kIsWeb`: this keeps the literal out of
// main.dart.js by construction, rather than trusting tree-shaking to drop it.
import 'douban_defaults_io.dart'
    if (dart.library.js_interop) 'douban_defaults_web.dart' as platform;

/// Frodo stopped issuing new keys, so there is no signup to send a user to —
/// the app ships the public pair the official client itself carries instead.
/// Neither half is a secret of ours, which is why Douban has no key screen.
abstract final class DoubanDefaults {
  static String get apiKey => platform.apiKey;

  static String get apiSecret => platform.apiSecret;
}
