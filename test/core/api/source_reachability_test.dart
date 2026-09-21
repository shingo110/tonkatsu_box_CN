import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/core/api/source_reachability.dart';

DioException _failure(DioExceptionType type) => DioException(
      requestOptions: RequestOptions(path: '/'),
      type: type,
    );

void main() {
  group('SourceReachabilityProbe.outcomeFor', () {
    test('a stalled connect or answer reads as timed out', () {
      expect(
        SourceReachabilityProbe.outcomeFor(
          _failure(DioExceptionType.connectionTimeout),
        ),
        ReachabilityOutcome.timedOut,
      );
      expect(
        SourceReachabilityProbe.outcomeFor(
          _failure(DioExceptionType.receiveTimeout),
        ),
        ReachabilityOutcome.timedOut,
      );
    });

    test('a refused route reads as unreachable', () {
      // What a blocked host actually looks like: DNS, TCP or TLS never lands.
      expect(
        SourceReachabilityProbe.outcomeFor(
          _failure(DioExceptionType.connectionError),
        ),
        ReachabilityOutcome.unreachable,
      );
      expect(
        SourceReachabilityProbe.outcomeFor(
          _failure(DioExceptionType.unknown),
        ),
        ReachabilityOutcome.unreachable,
      );
    });

    test('a plain Dart error reads as unreachable', () {
      expect(
        SourceReachabilityProbe.outcomeFor(StateError('boom')),
        ReachabilityOutcome.unreachable,
      );
    });

    test('an HTTP error answer still reads as reached', () {
      // A 401 or a 503 proves the route; only silence does not. This is what
      // keeps a missing key from being reported as a network fault.
      expect(
        SourceReachabilityProbe.outcomeFor(
          _failure(DioExceptionType.badResponse),
        ),
        ReachabilityOutcome.reached,
      );
    });
  });
}
