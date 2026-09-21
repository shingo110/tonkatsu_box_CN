import 'dart:async';

import 'package:dio/dio.dart';

import '../../shared/constants/platform_features.dart';
import '../../shared/constants/source_catalog.dart';
import 'api_dio.dart';

/// How far a probe got.
enum ReachabilityOutcome {
  /// Any HTTP answer came back. A 401 or a 503 still proves the route exists.
  reached,

  /// The connect attempt or the answer ran out of time.
  timedOut,

  /// DNS, TCP or TLS refused outright.
  unreachable,
}

/// One probe's verdict for one provider.
class SourceReachability {
  const SourceReachability({
    required this.info,
    required this.outcome,
    this.statusCode,
    this.elapsed,
  });

  final SourceInfo info;
  final ReachabilityOutcome outcome;
  final int? statusCode;
  final Duration? elapsed;

  bool get isReachable => outcome == ReachabilityOutcome.reached;
}

/// Probes each provider's API host. A class rather than a function so a test
/// can answer from a canned list without a network.
class SourceReachabilityProbe {
  const SourceReachabilityProbe({this.timeout = const Duration(seconds: 6)});

  final Duration timeout;

  /// Maps a failure onto an outcome. Pure, so the split stays unit-testable
  /// without a socket.
  static ReachabilityOutcome outcomeFor(Object error) {
    if (error is! DioException) return ReachabilityOutcome.unreachable;
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        ReachabilityOutcome.timedOut,
      DioExceptionType.badResponse => ReachabilityOutcome.reached,
      _ => ReachabilityOutcome.unreachable,
    };
  }

  /// Probes every host at once: a fully blocked network then costs one timeout
  /// instead of one per provider.
  ///
  /// The web build is skipped — its requests all leave through the selfhost
  /// server, so a browser-side verdict would describe the server, not the user.
  Future<List<SourceReachability>> run(List<SourceInfo> targets) async {
    if (kIsWebBuild) return const <SourceReachability>[];
    return Future.wait<SourceReachability>(
      targets.map((SourceInfo info) => _probe(info)),
    );
  }

  Future<SourceReachability> _probe(SourceInfo info) async {
    final Dio dio = createApiDio(
      baseUrl: 'https://${info.apiHost}/',
      connectTimeout: timeout,
      receiveTimeout: timeout,
      responseType: ResponseType.plain,
    );
    final Stopwatch watch = Stopwatch()..start();
    try {
      final Response<dynamic> response = await dio.get<dynamic>(
        '/',
        options: Options(
          // A 401/403/404 all prove the route; only silence does not.
          validateStatus: (int? _) => true,
          followRedirects: false,
          headers: <String, String>{
            // This is a reachability probe, not a fetch: ask for nothing.
            'Range': 'bytes=0-0',
            'User-Agent': kAppUserAgent,
          },
        ),
      );
      watch.stop();
      return SourceReachability(
        info: info,
        outcome: ReachabilityOutcome.reached,
        statusCode: response.statusCode,
        elapsed: watch.elapsed,
      );
    } catch (error) {
      watch.stop();
      return SourceReachability(
        info: info,
        outcome: outcomeFor(error),
        elapsed: watch.elapsed,
      );
    }
  }
}
