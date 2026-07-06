/// Build-time configuration constants.
///
/// Provide values at build time using --dart-define, e.g.:
///   flutter build apk --dart-define=BACKEND_URL=https://api.vista.app
///
/// See BUILD.md for full build instructions.
library;

import 'package:Vista/utils/env_config.dart';

/// Canonical backend base URL. Delegates to [EnvConfig.apiBaseUrl] so the
/// whole app follows ONE source of truth — previously half the code read the
/// `BACKEND_URL` define and the other half `API_BASE_URL`, so a staging build
/// could silently send part of its traffic to production.
String get backendUrl => EnvConfig.apiBaseUrl;

/// Base URL of the Vista web app (Next.js). Used for in-app webview handoffs
/// such as the game SSO flow.
const String webUrl = String.fromEnvironment(
  'WEB_URL',
  defaultValue: 'https://cafevista.ir',
);

/// The distribution flavor of the app (e.g. 'bazaar', 'myket', 'direct', 'googleplay')
const String appFlavor = String.fromEnvironment(
  'FLAVOR',
  defaultValue: 'direct',
);
