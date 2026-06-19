/// Build-time configuration constants.
///
/// Provide values at build time using --dart-define, e.g.:
///   flutter build apk --dart-define=BACKEND_URL=https://api.vista.app
///
/// See BUILD.md for full build instructions.
library;

const String backendUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'https://api.coffevista.ir',
);

/// Base URL of the Vista web app (Next.js). Used for in-app webview handoffs
/// such as the game SSO flow.
const String webUrl = String.fromEnvironment(
  'WEB_URL',
  defaultValue: 'https://cafevista.ir',
);
