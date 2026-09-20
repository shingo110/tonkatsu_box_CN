import 'package:core/api/douban_signature.dart';
import 'package:test/test.dart';

/// Vectors from probe/douban_sig_vectors.py. The app and the selfhost proxy
/// must both agree with that Python reference byte for byte, or Douban reads
/// the request as unsigned and answers 403.
void main() {
  group('doubanSignature', () {
    const String secret = 'bf7dddc7c9cfe6f7';

    test('signs an ISBN path', () {
      expect(
        doubanSignature(secret, '/api/v2/book/isbn/9787536692930', 1700000000),
        'g9+l253xM80riZQoEdnRsPFqgAs=',
      );
    });

    test('signs a different ISBN to a different value', () {
      expect(
        doubanSignature(secret, '/api/v2/book/isbn/7536692935', 1700000000),
        'gjYkb67Stwxdn3uejupfYS+VTj8=',
      );
    });

    test('signs a search path', () {
      expect(
        doubanSignature(secret, '/api/v2/search/book', 1234567890),
        'naFvvDLhJzj2aYRxniGEXYflj4Q=',
      );
    });

    test('signs a movie path', () {
      expect(
        doubanSignature(secret, '/api/v2/movie/35267208', 1699999999),
        'fLzbBcRk0NNCXvLVnZk1xVnyQrQ=',
      );
    });

    test('handles a zero timestamp', () {
      expect(
        doubanSignature(secret, '/api/v2/book/2567698', 0),
        '2pOGAIneQEZUWJg6z17+iN+drUA=',
      );
    });

    test('a different secret changes the signature', () {
      expect(
        doubanSignature('other', '/api/v2/search/book', 1234567890),
        isNot('naFvvDLhJzj2aYRxniGEXYflj4Q='),
      );
    });
  });
}
