import 'package:core/api/psn_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/psn_api.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../providers/settings_provider.dart';
import '../widgets/settings_group.dart';
import 'game_name_list_import_content.dart';

/// Sign in to PlayStation Network and import the purchase list.
///
/// PSN publishes no OAuth registration, so "sign in" here means: the user gets
/// an NPSSO from their own browser session, pastes it, and the app trades it for
/// a token. That trade is the only reason this screen exists — once it has the
/// names, it hands them to [GameNameListImportContent], which already knows how
/// to match, review and write them.
class PsnImportContent extends ConsumerStatefulWidget {
  const PsnImportContent({super.key});

  @override
  ConsumerState<PsnImportContent> createState() => _PsnImportContentState();
}

class _PsnImportContentState extends ConsumerState<PsnImportContent> {
  final TextEditingController _npsso = TextEditingController();

  bool _busy = false;
  bool _remember = false;
  String? _error;

  /// Non-null once the library has been read; the review stage takes over from
  /// there.
  List<PsnLibraryTitle>? _titles;

  /// A refresh token left by an earlier session, if the user opted in.
  String? _savedToken;

  int _fetched = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedToken();
  }

  @override
  void dispose() {
    // The NPSSO is password-equivalent; it has no business outliving the
    // screen, and it is never written to disk in the first place.
    _npsso.clear();
    _npsso.dispose();
    super.dispose();
  }

  void _loadSavedToken() {
    final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
    final bool remembered =
        prefs.getBool(SettingsKeys.psnRememberToken) ?? false;
    final String? token = prefs.getString(SettingsKeys.psnRefreshToken);
    if (!remembered || token == null || token.isEmpty) return;
    setState(() {
      _savedToken = token;
      _remember = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<PsnLibraryTitle>? titles = _titles;
    if (titles != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildConnectedBanner(S.of(context), titles.length),
          const SizedBox(height: AppSpacing.md),
          GameNameListImportContent(initialQueries: titles),
        ],
      );
    }
    return _buildSignInStage(context);
  }

  // --- Sign in --------------------------------------------------------------

  Widget _buildSignInStage(BuildContext context) {
    final S l = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingsGroup(
          title: l.psnImportTitle,
          children: <Widget>[
            _paragraph(l.psnImportDescription),
            _paragraph(l.psnImportHowTo, tertiary: true),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _open(kPsnSignInUrl),
                      icon: const Icon(Icons.login, size: 18),
                      label: Text(l.psnImportSignIn),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _open('$kPsnAuthBase$kPsnNpssoPagePath'),
                      icon: const Icon(Icons.key, size: 18),
                      label: Text(l.psnImportOpenNpssoPage),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: TextField(
                controller: _npsso,
                enabled: !_busy,
                maxLines: 1,
                decoration: InputDecoration(
                  labelText: l.psnImportNpssoLabel,
                  hintText: l.psnImportNpssoHint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _connect(),
              ),
            ),
            SwitchListTile(
              value: _remember,
              onChanged: _busy
                  ? null
                  : (bool value) => setState(() => _remember = value),
              title: Text(l.psnImportRemember, style: AppTypography.body),
              subtitle: Text(
                l.psnImportSecurityNote,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              dense: true,
            ),
            if (_busy) _buildProgress(l),
            if (_error case final String message)
              _buildError(message),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: FilledButton.icon(
                onPressed: _busy ? null : _connect,
                icon: const Icon(Icons.download),
                label: Text(l.psnImportConnect),
              ),
            ),
          ],
        ),
        if (_savedToken != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          SettingsGroup(
            title: l.psnImportSavedSession,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: FilledButton.tonalIcon(
                  onPressed: _busy ? null : _reconnect,
                  icon: const Icon(Icons.refresh),
                  label: Text(l.psnImportUseSaved),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _paragraph(String text, {bool tertiary = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Text(
        text,
        style: AppTypography.bodySmall.copyWith(
          color: tertiary ? AppColors.textTertiary : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildProgress(S l) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const LinearProgressIndicator(),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _fetched > 0
                ? l.psnImportFetchingPages(_fetched)
                : l.psnImportSigningIn,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.statusDropped.withAlpha(25),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: AppColors.statusDropped.withAlpha(77)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.error_outline,
                size: 18, color: AppColors.statusDropped),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shown above the review stage, so it is obvious whose library was read and
  /// how to switch accounts.
  Widget _buildConnectedBanner(S l, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.brand.withAlpha(25),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.brand.withAlpha(77)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.check_circle_outline, size: 18, color: AppColors.brand),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              l.psnImportFetched(count),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _titles = null;
                      _fetched = 0;
                      _error = null;
                    }),
            child: Text(l.psnImportChangeAccount),
          ),
        ],
      ),
    );
  }

  // --- Flow -----------------------------------------------------------------

  Future<void> _connect() async {
    final String npsso = _npsso.text.trim();
    if (npsso.isEmpty) {
      setState(() => _error = S.of(context).psnImportNpssoEmpty);
      return;
    }
    await _run((PsnApi api) => api.connect(npsso));
  }

  /// Reuses the stored refresh token, so a remembered session never needs the
  /// NPSSO again until the token itself expires (about two months).
  Future<void> _reconnect() async {
    final String? token = _savedToken;
    if (token == null) return;
    await _run((PsnApi api) => api.refresh(token));
  }

  /// One sign-in attempt: trade the credential for a token, remember it if
  /// asked, then read the library.
  Future<void> _run(Future<PsnAuthTokens> Function(PsnApi api) authorize) async {
    setState(() {
      _busy = true;
      _error = null;
      _fetched = 0;
    });

    final PsnApi api = ref.read(psnApiProvider);
    try {
      final PsnAuthTokens tokens = await authorize(api);
      await _rememberToken(tokens);

      // Both halves of the library, not just the purchases: a title played
      // from the PlayStation Plus catalogue was never bought, and would
      // otherwise never appear here. The rows carry their other spellings too,
      // so a title Sony names in English can still be looked up in Chinese.
      final List<PsnLibraryTitle> titles = await api.fetchLibraryTitles(
        accessToken: tokens.accessToken,
        onPage: (int fetched) {
          if (mounted) setState(() => _fetched = fetched);
        },
      );

      if (!mounted) return;
      if (titles.isEmpty) {
        setState(() {
          _busy = false;
          _error = S.of(context).psnImportEmpty;
        });
        return;
      }

      // The NPSSO has done its job; drop it rather than leave it in a widget.
      _npsso.clear();
      setState(() {
        _busy = false;
        _titles = titles;
      });
    } on PsnApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  /// Persists the *refresh* token only, and only when the user opted in — the
  /// rollover from an old one is what keeps a remembered session alive.
  Future<void> _rememberToken(PsnAuthTokens tokens) async {
    final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
    if (_remember) {
      await prefs.setString(SettingsKeys.psnRefreshToken, tokens.refreshToken);
      await prefs.setBool(SettingsKeys.psnRememberToken, true);
      if (mounted) setState(() => _savedToken = tokens.refreshToken);
    } else {
      await prefs.remove(SettingsKeys.psnRefreshToken);
      await prefs.setBool(SettingsKeys.psnRememberToken, false);
      if (mounted) setState(() => _savedToken = null);
    }
  }

  Future<void> _open(String url) async {
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }
}
