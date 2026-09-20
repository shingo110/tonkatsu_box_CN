/// The same public pair the app ships. Deliberately *not* seeded into
/// ApiCredentials: `/proxy/keys` echoes that map back to the browser, and the
/// point of signing server-side is that no browser ever sees the secret.
const String kDoubanDefaultKey = '0dad551ec0f84ed02907ff5c42e8ec70';

const String kDoubanDefaultSecret = 'bf7dddc7c9cfe6f7';
