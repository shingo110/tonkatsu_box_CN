import 'dart:convert';

import 'package:crypto/crypto.dart';

/// `base64(hmac-sha1(secret, "GET&<urlencoded path>&<ts>"))`. Douban signs the
/// path with its query string stripped, so the app and the selfhost proxy
/// compute the same value from it alone.
String doubanSignature(String secret, String path, int unixTime) {
  final String raw = 'GET&${Uri.encodeComponent(path)}&$unixTime';
  final Hmac hmac = Hmac(sha1, utf8.encode(secret));
  return base64.encode(hmac.convert(utf8.encode(raw)).bytes);
}
