# Flutter Cleanup Report — 2026-02-05

## Scope
- Flutter only: `lib/`, `test/`, and root Flutter configs.
- Server code unchanged.
- Supabase SQL migrations removed from the repo (assumed already applied on Supabase).

## Baseline (before changes)
- `flutter test`: passed
- `flutter analyze`:
  - Errors: 0
  - Warnings: 1 (`test/cache_test.dart` dead_code)
  - Total issues reported: 1530

## After changes
- `flutter test`: passed
- `flutter analyze`:
  - Errors: 0
  - Warnings: 0
  - Total issues reported: 1466

## Changes applied
### Removed Supabase migrations from repo
- Deleted `supabase/migrations/*` and removed `supabase/` directory.
- Note: the server README still referenced migrations; left untouched since server was out of scope.

### Renamed directories with spaces
- `lib/features/posts/screens/followers and followings/` → `lib/features/posts/screens/followers_and_followings/`
- `lib/widgets/web files/` → `lib/widgets/web_files/`
- Updated affected imports.

### SessionManager: unified on V2
- Updated providers and screens to use `SessionManagerServiceV2`.
- Added `findCurrentSessionId()` and `isSessionStillValid()` to `lib/services/session_manager_service_v2.dart` for compatibility with existing call sites.
- Deleted the old v1 implementation after migrating all usage to V2.

### Posts UI cleanup
- Removed a no-op `ProviderScope(overrides: [])` wrapper in `lib/features/posts/screens/ExploreFeedScreen.dart`.

### Reduced production `print()` usage
- Replaced `print(...)` calls in `lib/services/vista_node_service.dart` with `logDebug/logWarning` from `lib/security/logging_utility.dart`.

### Deleted deprecated stubs
- Removed two explicitly-deprecated/empty stubs:
  - `lib/features/profile/widgets/profile_action_bar.dart`
  - `lib/features/posts/screens/VistaProfileScreen.dart`

### Deleted unused auth screens (legacy flow)
- Removed the unused legacy auth flow screens:
  - `lib/features/auth/screens/auth_screen.dart`
  - `lib/features/auth/screens/biometric_setup_screen.dart`
  - `lib/features/auth/screens/email_username_auth_screen.dart`
  - `lib/features/auth/screens/otp_verification_screen.dart`
  - `lib/features/auth/screens/password_auth_screen.dart`
  - `lib/features/auth/screens/phone_auth_screen.dart`
  - `lib/features/auth/screens/profile_setup_screen.dart`
  - `lib/features/auth/screens/registration_screen.dart`

### Deleted empty unused Dart files
- Removed empty, unreferenced files:
  - `lib/widgets/advanced_voice_visualizer.dart`
  - `lib/widgets/shared_post_message_widget.dart`
  - `lib/services/message_deduplication_service.dart`
  - `lib/utils/date_time_extensions.dart`

### Tests cleanup
- Updated `test/cache_test.dart` to remove a dead-code analyzer warning (battery saver test now exercises both branches via a helper function).

## Follow-ups (optional)
- There are still many `info` lints (e.g. `withOpacity` deprecation) that can be handled in a separate, larger refactor pass.
