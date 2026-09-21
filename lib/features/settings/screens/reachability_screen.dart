import 'package:flutter/material.dart';

import '../../../core/api/source_reachability.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/constants/platform_features.dart';
import '../../../shared/constants/source_catalog.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/source_logo.dart';
import '../../../shared/widgets/sub_screen_title_bar.dart';

/// Probes every provider once, so a provider that this network cannot reach can
/// be told apart from one that is broken — instead of guessing from the search
/// strip.
class ReachabilityScreen extends StatefulWidget {
  const ReachabilityScreen({
    super.key,
    this.probe = const SourceReachabilityProbe(),
  });

  /// Injectable so tests answer from a canned list.
  final SourceReachabilityProbe probe;

  @override
  State<ReachabilityScreen> createState() => _ReachabilityScreenState();
}

class _ReachabilityScreenState extends State<ReachabilityScreen> {
  List<SourceReachability>? _results;
  bool _running = false;

  Future<void> _run() async {
    setState(() {
      _running = true;
      _results = null;
    });
    final List<SourceReachability> results =
        await widget.probe.run(kDataSourceCatalog);
    if (!mounted) return;
    setState(() {
      _results = results;
      _running = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);

    return Column(
      children: <Widget>[
        SubScreenTitleBar(title: l.settingsReachability),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l.reachabilityIntro,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l.reachabilityNote,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (kIsWebBuild)
                  Text(
                    l.reachabilityWebNote,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  )
                else ...<Widget>[
                  _buildRunButton(l),
                  const SizedBox(height: AppSpacing.md),
                  ..._buildResults(l),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRunButton(S l) {
    if (_running) {
      return Row(
        children: <Widget>[
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(l.reachabilityChecking),
        ],
      );
    }
    return FilledButton.icon(
      onPressed: _run,
      icon: const Icon(Icons.network_check),
      label: Text(_results == null ? l.reachabilityRun : l.reachabilityRerun),
    );
  }

  List<Widget> _buildResults(S l) {
    final List<SourceReachability>? results = _results;
    if (results == null) return const <Widget>[];
    final int reached =
        results.where((SourceReachability r) => r.isReachable).length;

    return <Widget>[
      Text(
        l.reachabilitySummary(reached, results.length),
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      for (final SourceReachability result in results) _resultRow(l, result),
    ];
  }

  Widget _resultRow(S l, SourceReachability result) {
    final Color color = switch (result.outcome) {
      ReachabilityOutcome.reached => AppColors.success,
      ReachabilityOutcome.timedOut => AppColors.warning,
      ReachabilityOutcome.unreachable => AppColors.error,
    };
    final String label = switch (result.outcome) {
      ReachabilityOutcome.reached => l.reachabilityOutcomeReachable,
      ReachabilityOutcome.timedOut => l.reachabilityOutcomeTimeout,
      ReachabilityOutcome.unreachable => l.reachabilityOutcomeFailed,
    };
    final String detail = <String>[
      result.info.apiHost,
      if (result.statusCode != null) 'HTTP ${result.statusCode}',
      if (result.elapsed != null) '${result.elapsed!.inMilliseconds} ms',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          SourceLogo(source: result.info.source, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(result.info.source.label, style: AppTypography.bodySmall),
                Text(
                  detail,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
