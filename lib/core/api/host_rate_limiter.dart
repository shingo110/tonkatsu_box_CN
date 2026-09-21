import 'dart:async';

import 'package:dio/dio.dart';

/// MusicBrainz allows one request per second per client and silently throttles
/// offenders instead of returning 503 — the gap has headroom on purpose.
const Map<String, Duration> kHostMinRequestGap = <String, Duration>{
  'musicbrainz.org': Duration(milliseconds: 1100),
  // Cover Art Archive tolerates images better than lookups, but a 40-cover
  // burst from a fresh grid still trips it — pace the background refills.
  'coverartarchive.org': Duration(milliseconds: 300),
  // NeoDB is a volunteer-run instance and never refused us, but a single call
  // already costs ~1s, so this only smooths bursts such as paging results.
  'neodb.social': Duration(milliseconds: 250),
  // WeRead answers in ~250ms and never throttled a burst of eight, but its
  // search runs while the user types, so pace the keystrokes' follow-ups.
  'weread.qq.com': Duration(milliseconds: 200),
  // Douban bans after ten back-to-back calls, so the gap is the one lever that
  // also slows a legitimate walk down a list of ISBNs.
  'douban.com': Duration(milliseconds: 800),
  // TapTap answered fifteen back-to-back searches without complaint, and its
  // search runs while the user types, so this only smooths the keystrokes.
  'taptap.cn': Duration(milliseconds: 200),
  // Ximalaya answered twelve in a row; same reason, same light touch.
  'ximalaya.com': Duration(milliseconds: 200),
};

/// A host that answers a burst by banning the caller needs a breaker in front
/// of the gap: spacing alone still walks a list import straight into the ban.
class HostBackoffPolicy {
  const HostBackoffPolicy({required this.maxBurst, required this.cooldown});

  /// Back-to-back requests allowed through before the breaker opens.
  final int maxBurst;

  /// How long the breaker refuses once open. It doubles as the idle period that
  /// ends a burst, so two calls this far apart never accumulate.
  final Duration cooldown;
}

/// Keyed by registrable domain, not by subdomain — Douban counts requests per
/// client, so `frodo` and `book` must spend one budget between them.
const Map<String, HostBackoffPolicy> kHostBackoffPolicy =
    <String, HostBackoffPolicy>{
  // Frodo serves ten back-to-back calls and then 403s for three to five
  // minutes; opening one call early means the ban is never actually earned.
  'douban.com': HostBackoffPolicy(maxBurst: 9, cooldown: Duration(minutes: 5)),
};

/// Raised instead of sending a request while a host's breaker is open. The text
/// reaches the user, so it names the host and the wait, not the mechanism.
class HostCooldownException implements Exception {
  const HostCooldownException(this.host, this.remaining);

  final String host;
  final Duration remaining;

  /// Rounded up, so an open breaker never reports a wait of zero.
  int get remainingSeconds => (remaining.inMilliseconds / 1000).ceil();

  @override
  String toString() => 'HostCooldownException: $host is paused for '
      '${remainingSeconds}s after refusing a burst of requests';
}

/// Serialises requests to one host: starts stay in FIFO order and at least
/// [minGap] apart. Responses are not awaited — only starts are spaced. With a
/// [backoff] policy, a long enough burst opens a cooldown that refuses requests
/// outright instead of merely spacing them.
class HostRateLimiter {
  HostRateLimiter(this.minGap, {this.backoff, this.host = ''});

  final Duration minGap;
  final HostBackoffPolicy? backoff;

  /// Named in [HostCooldownException], so the message can say which host is
  /// refusing.
  final String host;

  Future<void> _tail = Future<void>.value();
  DateTime _nextAllowed = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _lastStart;
  int _burst = 0;
  DateTime? _cooldownUntil;

  Future<void> acquire() {
    final Future<void> slot = _tail.then((_) async {
      _refuseWhileCoolingDown();
      final Duration wait = _nextAllowed.difference(DateTime.now());
      if (wait > Duration.zero) {
        await Future<void>.delayed(wait);
        // A response that landed during the wait may have opened the breaker.
        _refuseWhileCoolingDown();
      }
      final DateTime now = DateTime.now();
      _nextAllowed = now.add(minGap);
      _countTowardsBurst(now);
    });
    // A refused slot must not poison the queue: later callers chain off `_tail`
    // and would inherit this throw instead of running their own cooldown check.
    _tail = slot.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return slot;
  }

  /// Opens the breaker the moment the host refuses us, so the cooldown starts
  /// at that refusal rather than at the next burst ceiling.
  void recordRefusal() {
    final HostBackoffPolicy? policy = backoff;
    if (policy == null) return;
    _cooldownUntil = DateTime.now().add(policy.cooldown);
    _burst = 0;
  }

  void _refuseWhileCoolingDown() {
    final DateTime? until = _cooldownUntil;
    if (until == null) return;
    final DateTime now = DateTime.now();
    if (until.isAfter(now)) {
      throw HostCooldownException(host, until.difference(now));
    }
    // The pause is over: the budget starts clean.
    _cooldownUntil = null;
    _burst = 0;
    _lastStart = null;
  }

  void _countTowardsBurst(DateTime now) {
    final HostBackoffPolicy? policy = backoff;
    if (policy == null) return;
    final DateTime? last = _lastStart;
    // Calls further apart than the cooldown are separate bursts, not one run.
    if (last != null && now.difference(last) >= policy.cooldown) _burst = 0;
    _lastStart = now;
    _burst++;
    if (_burst >= policy.maxBurst) {
      _cooldownUntil = now.add(policy.cooldown);
      _burst = 0;
    }
  }
}

// One queue per configured domain per process, shared by every Dio instance —
// per-client queues would multiply the allowed rate by the number of clients.
final Map<String, HostRateLimiter> _limiters = <String, HostRateLimiter>{};

/// Finds [host] in [table], falling back to its parent domains, so a single
/// `douban.com` entry covers every Douban subsite without listing them.
({String key, T value})? _resolve<T>(Map<String, T> table, String host) {
  String candidate = host;
  while (true) {
    final T? value = table[candidate];
    if (value != null) return (key: candidate, value: value);
    final int dot = candidate.indexOf('.');
    if (dot < 0) return null;
    candidate = candidate.substring(dot + 1);
  }
}

HostRateLimiter? limiterForHost(String host) {
  final String key = host.toLowerCase();
  final ({String key, HostBackoffPolicy value})? breaker =
      _resolve(kHostBackoffPolicy, key);
  final ({String key, Duration value})? spacing =
      _resolve(kHostMinRequestGap, key);
  if (breaker == null && spacing == null) return null;
  // Keyed by the matched entry, so all of `*.douban.com` shares one budget.
  final String cacheKey = breaker?.key ?? spacing!.key;
  return _limiters.putIfAbsent(
    cacheKey,
    () => HostRateLimiter(
      spacing?.value ?? Duration.zero,
      backoff: breaker?.value,
      host: cacheKey,
    ),
  );
}

/// Holds a request until its host's queue frees a slot, and opens that host's
/// breaker when the host itself refuses one. Must sit before the web proxy
/// rewrite so it keys on the real upstream host.
class HostRateLimitInterceptor extends Interceptor {
  HostRateLimitInterceptor({HostRateLimiter? Function(String host)? resolve})
      : _resolve = resolve ?? limiterForHost;

  final HostRateLimiter? Function(String host) _resolve;

  // The limiter rides along on the request: on web the proxy rewrite replaces
  // the URI, so the upstream host is unrecognisable by the response phase.
  static const String _limiterKey = 'hostRateLimiter';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final HostRateLimiter? limiter = _resolve(options.uri.host);
    if (limiter == null) {
      handler.next(options);
      return;
    }
    options.extra[_limiterKey] = limiter;
    unawaited(limiter.acquire().then((_) {
      // A throw past this point would otherwise become an unhandled zone
      // error and leave the request permanently unsettled.
      try {
        handler.next(options);
      } on Object catch (e, s) {
        handler.reject(
          DioException(requestOptions: options, error: e, stackTrace: s),
        );
      }
    }, onError: (Object error, StackTrace stack) {
      handler.reject(
        DioException(
          requestOptions: options,
          message: error is HostCooldownException ? error.toString() : null,
          error: error,
          stackTrace: stack,
        ),
      );
    }));
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final int? status = err.response?.statusCode;
    // A refusal is the host's own signal, and the breaker should hold at once.
    if (status == 402 || status == 403 || status == 429) {
      _limiterFor(err.requestOptions)?.recordRefusal();
    }
    handler.next(err);
  }

  HostRateLimiter? _limiterFor(RequestOptions options) {
    final Object? limiter = options.extra[_limiterKey];
    return limiter is HostRateLimiter ? limiter : null;
  }
}
