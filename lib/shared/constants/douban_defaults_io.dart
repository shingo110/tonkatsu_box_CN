/// The pair Frodo shipped to its own client. Public, not a secret, and the
/// build can still override it with `--dart-define`.
const String apiKey = String.fromEnvironment(
  'DOUBAN_API_KEY',
  defaultValue: '0dad551ec0f84ed02907ff5c42e8ec70',
);

const String apiSecret = String.fromEnvironment(
  'DOUBAN_API_SECRET',
  defaultValue: 'bf7dddc7c9cfe6f7',
);
