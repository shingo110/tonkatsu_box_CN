import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/core/api/host_rate_limiter.dart';

/// Catches whichever way the interceptor settles a request. Overriding the
/// handler means no request ever reaches an adapter.
class _CapturingRequestHandler extends RequestInterceptorHandler {
  _CapturingRequestHandler({this.onNext, this.onReject});

  final void Function(RequestOptions)? onNext;
  final void Function(DioException)? onReject;

  @override
  void next(RequestOptions options) => onNext?.call(options);

  @override
  void reject(
    DioException error, [
    bool callFollowingErrorInterceptor = false,
  ]) =>
      onReject?.call(error);
}

class _CapturingErrorHandler extends ErrorInterceptorHandler {
  _CapturingErrorHandler(this.onNext);

  final void Function(DioException) onNext;

  @override
  void next(DioException error) => onNext(error);
}

/// Returns the refusal instead of failing the test on it.
Future<HostCooldownException> refusalOf(HostRateLimiter limiter) async {
  try {
    await limiter.acquire();
  } on HostCooldownException catch (e) {
    return e;
  }
  fail('expected the limiter to refuse the request');
}

void main() {
  group('HostRateLimiter', () {
    test('spaces acquisitions by at least the gap', () async {
      final HostRateLimiter limiter =
          HostRateLimiter(const Duration(milliseconds: 60));
      final List<DateTime> starts = <DateTime>[];

      await Future.wait(<Future<void>>[
        for (int i = 0; i < 4; i++)
          limiter.acquire().then((_) => starts.add(DateTime.now())),
      ]);

      expect(starts, hasLength(4));
      for (int i = 1; i < starts.length; i++) {
        final Duration gap = starts[i].difference(starts[i - 1]);
        // Timers may fire a hair early; 5ms of slack avoids flakes.
        expect(
          gap,
          greaterThanOrEqualTo(const Duration(milliseconds: 55)),
          reason: 'gap between request ${i - 1} and $i was $gap',
        );
      }
    });

    test('keeps FIFO order under concurrency', () async {
      final HostRateLimiter limiter =
          HostRateLimiter(const Duration(milliseconds: 10));
      final List<int> order = <int>[];

      await Future.wait(<Future<void>>[
        for (int i = 0; i < 6; i++)
          limiter.acquire().then((_) => order.add(i)),
      ]);

      expect(order, <int>[0, 1, 2, 3, 4, 5]);
    });

    test('an idle period does not delay the next request', () async {
      final HostRateLimiter limiter =
          HostRateLimiter(const Duration(milliseconds: 30));

      await limiter.acquire();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final Stopwatch watch = Stopwatch()..start();
      await limiter.acquire();
      watch.stop();

      expect(watch.elapsed, lessThan(const Duration(milliseconds: 20)));
    });
  });

  group('limiterForHost', () {
    test('returns a limiter only for configured hosts', () {
      expect(limiterForHost('musicbrainz.org'), isNotNull);
      expect(limiterForHost('MUSICBRAINZ.ORG'), isNotNull);
      expect(limiterForHost('coverartarchive.org'), isNotNull);
      expect(limiterForHost('api.listenbrainz.org'), isNull);
    });

    test('returns the same shared instance per host', () {
      expect(
        identical(
          limiterForHost('musicbrainz.org'),
          limiterForHost('musicbrainz.org'),
        ),
        isTrue,
      );
    });
  });

  group('HostRateLimiter backoff', () {
    const HostBackoffPolicy policy = HostBackoffPolicy(
      maxBurst: 10,
      cooldown: Duration(milliseconds: 300),
    );

    HostRateLimiter newLimiter() => HostRateLimiter(
          const Duration(milliseconds: 1),
          backoff: policy,
          host: 'douban.com',
        );

    test('lets a burst through and refuses the request after it', () async {
      final HostRateLimiter limiter = newLimiter();

      for (int i = 0; i < 10; i++) {
        await limiter.acquire();
      }

      await expectLater(
        limiter.acquire(),
        throwsA(isA<HostCooldownException>()),
      );
    });

    test('resumes on its own once the cooldown elapses', () async {
      final HostRateLimiter limiter = newLimiter();
      for (int i = 0; i < 10; i++) {
        await limiter.acquire();
      }
      await refusalOf(limiter);

      await Future<void>.delayed(const Duration(milliseconds: 350));

      await expectLater(limiter.acquire(), completes);
    });

    test('recordRefusal opens the breaker without waiting for the ceiling',
        () async {
      final HostRateLimiter limiter = newLimiter();

      limiter.recordRefusal();

      await expectLater(
        limiter.acquire(),
        throwsA(isA<HostCooldownException>()),
      );
    });

    test('a refused slot leaves the queue usable', () async {
      final HostRateLimiter limiter = newLimiter();
      limiter.recordRefusal();

      // The second refusal is the real assertion: if the first had poisoned
      // `_tail`, the queue would rethrow it instead of re-checking the breaker.
      await refusalOf(limiter);
      await refusalOf(limiter);

      await Future<void>.delayed(const Duration(milliseconds: 350));
      await expectLater(limiter.acquire(), completes);
    });

    test('calls spread past the cooldown never accumulate', () async {
      final HostRateLimiter limiter = HostRateLimiter(
        const Duration(milliseconds: 1),
        backoff: const HostBackoffPolicy(
          maxBurst: 3,
          cooldown: Duration(milliseconds: 80),
        ),
      );

      await limiter.acquire();
      await limiter.acquire();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await limiter.acquire();
      await limiter.acquire();

      // Without the idle reset the count would already have reached the ceiling.
      await expectLater(limiter.acquire(), completes);
    });

    test('a host with no policy is never refused', () async {
      final HostRateLimiter limiter =
          HostRateLimiter(const Duration(milliseconds: 1));

      limiter.recordRefusal();
      for (int i = 0; i < 20; i++) {
        await limiter.acquire();
      }
    });

    test('the refusal names the host and the wait', () async {
      final HostRateLimiter limiter = newLimiter();
      limiter.recordRefusal();

      final HostCooldownException error = await refusalOf(limiter);

      expect(error.host, 'douban.com');
      expect(error.remainingSeconds, greaterThan(0));
      expect(error.toString(), contains('douban.com'));
    });
  });

  group('limiterForHost backoff', () {
    test('every Douban subsite shares one budget', () {
      final HostRateLimiter? frodo = limiterForHost('frodo.douban.com');

      expect(frodo, isNotNull);
      // A ban is counted per client, so per-subdomain queues would multiply the
      // calls Douban sees before it pulls the trigger.
      expect(identical(frodo, limiterForHost('book.douban.com')), isTrue);
      expect(identical(frodo, limiterForHost('movie.douban.com')), isTrue);
      expect(identical(frodo, limiterForHost('DOUBAN.COM')), isTrue);
    });

    test('the breaker names the domain it protects', () {
      final HostRateLimiter limiter = limiterForHost('frodo.douban.com')!;

      expect(limiter.host, 'douban.com');
      expect(limiter.backoff?.maxBurst, 9);
      expect(limiter.backoff?.cooldown, const Duration(minutes: 5));
    });

    test('the shipped policy trips before Douban\'s observed ban', () {
      // Ten back-to-back calls earn a 403, so nine has to be the ceiling.
      expect(kHostBackoffPolicy['douban.com']?.maxBurst, 9);
      expect(limiterForHost('api.listenbrainz.org'), isNull);
    });
  });

  group('HostRateLimitInterceptor', () {
    HostRateLimiter newLimiter() => HostRateLimiter(
          const Duration(milliseconds: 1),
          backoff: const HostBackoffPolicy(
            maxBurst: 4,
            cooldown: Duration(milliseconds: 200),
          ),
          host: 'douban.com',
        );

    /// Runs a request through the interceptor and resolves with the refusal.
    Future<DioException> refuse(
      HostRateLimitInterceptor interceptor,
      RequestOptions options,
    ) {
      final Completer<DioException> settled = Completer<DioException>();
      interceptor.onRequest(
        options,
        _CapturingRequestHandler(onReject: settled.complete),
      );
      return settled.future;
    }

    /// Replays a response status through the interceptor's error phase, which
    /// is where the breaker learns that the host said no.
    Future<void> failWith(
      HostRateLimitInterceptor interceptor,
      RequestOptions options,
      int statusCode,
    ) async {
      final Completer<DioException> settled = Completer<DioException>();
      interceptor.onError(
        DioException(
          requestOptions: options,
          response: Response<dynamic>(
            requestOptions: options,
            statusCode: statusCode,
          ),
        ),
        _CapturingErrorHandler(settled.complete),
      );
      await settled.future;
    }

    test('refuses the request outright while the host is cooling down',
        () async {
      final HostRateLimiter rate = newLimiter()..recordRefusal();
      final RequestOptions options =
          RequestOptions(path: 'https://book.douban.com/isbn/9787115428028');

      final DioException error = await refuse(
        HostRateLimitInterceptor(resolve: (String host) => rate),
        options,
      );

      // Nothing reached the network, and the reason survives on the error.
      expect(error.error, isA<HostCooldownException>());
      expect(error.message, contains('douban.com'));
    });

    test('a 403 opens the breaker for the next request', () async {
      final HostRateLimiter rate = newLimiter();
      final HostRateLimitInterceptor interceptor =
          HostRateLimitInterceptor(resolve: (String host) => rate);
      final RequestOptions options =
          RequestOptions(path: 'https://book.douban.com/isbn/9787115428028');

      // The first request has to go through for the limiter to ride along.
      final Completer<RequestOptions> sent = Completer<RequestOptions>();
      interceptor.onRequest(
        options,
        _CapturingRequestHandler(onNext: sent.complete),
      );
      await sent.future;

      await failWith(interceptor, options, 403);

      await expectLater(
        rate.acquire(),
        throwsA(isA<HostCooldownException>()),
      );
    });

    test('a 500 leaves the breaker closed', () async {
      final HostRateLimiter rate = newLimiter();
      final HostRateLimitInterceptor interceptor =
          HostRateLimitInterceptor(resolve: (String host) => rate);
      final RequestOptions options =
          RequestOptions(path: 'https://book.douban.com/isbn/9787115428028');

      final Completer<RequestOptions> sent = Completer<RequestOptions>();
      interceptor.onRequest(
        options,
        _CapturingRequestHandler(onNext: sent.complete),
      );
      await sent.future;

      await failWith(interceptor, options, 500);

      // A server-side fault is not a refusal, so pacing is all it gets.
      await expectLater(rate.acquire(), completes);
    });
  });
}
