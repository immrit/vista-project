/// Build-time configuration constants.
///
/// Provide values at build time using --dart-define, e.g.:
///   flutter build apk --dart-define=BACKEND_URL=https://api.vista.app
///
/// See BUILD.md for full build instructions.

const String backendUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'http://10.0.2.2:8080',
);
