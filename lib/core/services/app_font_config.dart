/// The font family the whole UI renders in.
///
/// [AppTypography] reads [current] on every style it hands out, so replacing
/// the value and rebuilding the tree is all it takes to re-font the app —
/// the same shape [AppProxyConfig] uses for the outbound proxy.
class AppFontConfig {
  const AppFontConfig({required this.family, required this.displayName});

  const AppFontConfig.defaults()
      : family = defaultFontFamily,
        displayName = null;

  /// The live selection. Read on every `AppTypography` style.
  static AppFontConfig current = const AppFontConfig.defaults();

  /// Value handed to `TextStyle.fontFamily` — either [defaultFontFamily] or a
  /// registration key produced by [fontRegistrationKey].
  final String family;

  /// Human label for the settings screen; `null` while on the default font.
  final String? displayName;

  bool get isDefault => family == defaultFontFamily;

  @override
  String toString() => 'AppFontConfig($family)';
}

/// The family bundled with every build.
const String defaultFontFamily = 'Inter';

/// Prefix for families registered from disk.
///
/// Registering under a distinct key is the whole point of going through
/// [FontLoader]: the engine then resolves our bytes unambiguously, with no
/// chance of a same-named or localized family on the system intercepting the
/// lookup (which is exactly what the "just use the system family name" route
/// cannot promise).
String fontRegistrationKey(String familyEn) => 'TK:$familyEn';
