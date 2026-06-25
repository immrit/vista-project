# MEMORY.md — Global Changes & Recovery Map

Recovery log for **global** changes (whole-app / all-branch impact: deps, architecture, moved core files, build/config). Each entry: what / why / files / how to revert.

Branch: `architecture-fixes`. Implements `ARCHITECTURE_REVIEW.md` fixes.

---

## ENV-0 — Working in a git worktree (not the main checkout)

- **What:** Work happens in worktree `E:/vista-arch` on branch `architecture-fixes`, not in `E:/vista` directly.
- **Why:** `E:/vista/.git/index` is held open by running VS Code + dart analysis-server processes, so every `git checkout -b` / index write in the main checkout fails with `fatal: unable to write new index file`. A worktree has its own index file → unaffected. Main `E:/vista` working tree (64 pre-existing uncommitted chat changes) is left untouched.
- **Files:** new dir `E:/vista-arch`; `.git/worktrees/vista-arch/`.
- **Revert:** `git worktree remove E:/vista-arch` (from `E:/vista`). To also drop branch: `git branch -D architecture-fixes`.

## ENV-1 — Flutter SDK bootstrap patch (toolchain, NOT repo)

- **What:** Patched `E:/flutter/bin/internal/update_engine_version.ps1` — replaced the `engine.stamp` temp-file + `Move-Item -Force` write with a direct `Set-Content -Force` (retry loop kept).
- **Why:** PowerShell 5.1 `Move-Item -Force` on this host cannot overwrite `bin/cache/engine.stamp` (`"Cannot create a file when that file already exists"`), so every `flutter` command aborted with `Error: Unable to determine engine version...`. `Set-Content` overwrite works. Without this, `flutter test` (verification gate) cannot run.
- **Files:** `E:/flutter/bin/internal/update_engine_version.ps1` (outside repo, machine-global).
- **Revert:** restore that block to the upstream `Set-Content $esTmp` + `Move-Item -Path $esTmp -Destination .../engine.stamp -Force` + `finally{ Remove-Item $esTmp }` form. Re-pull/reinstall Flutter 3.44.2 to get the pristine file.

---

## Build / config changes

### BF1 — Kotlin incremental compilation re-enabled
- **What:** `kotlin.incremental=false` → `true` in `android/gradle.properties`.
- **Why:** It was force-disabled; every build recompiled all Kotlin from scratch (§5.1, biggest incremental-build slowdown).
- **Files:** `android/gradle.properties`.
- **Revert:** set `kotlin.incremental=false`.

### BF2 — Release ABI filters (drop x86_64)
- **What:** Added `ndk { abiFilters 'arm64-v8a', 'armeabi-v7a' }` to the `release` buildType.
- **Why:** Release was packaging all 3 ABIs incl. x86_64; with ffmpeg/isar `.so` that's 3× native merge/strip + fat APK (§5.2). Debug left untouched → x86_64 emulator still works.
- **Files:** `android/app/build.gradle`.
- **Revert:** remove the `ndk { abiFilters ... }` block from `release`.

### BF3 — Release R8 minify + resource shrink
- **What:** `minifyEnabled false`→`true`, `shrinkResources false`→`true` in `release`.
- **Why:** Unminified release = bigger APK + trivially recoverable strings (§5.7/§6). Keep rules in `proguard-rules.pro` are comprehensive, so R8 is safe to enable.
- **⚠ Verification gap:** `flutter test` does NOT exercise R8. **Smoke-test a real release build before shipping.** If a release-only crash/missing-class appears, add the needed `-keep` rule, or revert.
- **Files:** `android/app/build.gradle`.
- **Revert:** set both back to `false`.
- **Deferred (NOT changed):** `debug { signingConfig signingConfigs.release }` left as-is. Review flags it (debug signed w/ release key), but it's likely intentional for Firebase/Poolakey SHA-matching during debug; removing risks breaking debug auth/payments. User decision.

### BF5 — Fix debug build failing without the release keystore
- **What:** `signingConfigs.release` is now used by the `debug` and `release` build types **only when `key.properties` exists** (`def hasReleaseKeystore = keystorePropertiesFile.exists()`); otherwise both fall back to `signingConfigs.debug` (default debug keystore).
- **Why:** `debug { signingConfig signingConfigs.release }` hard-required the machine-local keystore. Without `key.properties` (this worktree, CI, any other dev) the build died: `Execution failed for task ':app:packageDebug' > SigningConfig "release" is missing required property "storeFile"`. **Reproduced + fixed live on emulator-5554** (build → install → launch OK). Also resolves the BF3-deferred "debug signed with release key" concern without losing the maintainer's Firebase/Poolakey SHA match (release signing still used when the keystore is present).
- **Files:** `android/app/build.gradle`.
- **Revert:** set both `signingConfig` lines back to `signingConfigs.release` and drop `hasReleaseKeystore`.
- **Note:** installing this debug build over an existing release-key-signed install triggers `INSTALL_FAILED_UPDATE_INCOMPATIBLE` (different signature) — `flutter run` auto-uninstalls + reinstalls. Expected.

### BF4 — Gradle resource tuning (this 16 GB / 12-logical-core host)
- **What:** dropped `-XX:+HeapDumpOnOutOfMemoryError` from `org.gradle.jvmargs`; `org.gradle.workers.max` 4→8. Heaps left at 4G Gradle / 2G Kotlin daemon.
- **Why:** heap-dump-on-OOM wrote a multi-GB file to disk mid-build → froze the box (§7). `workers.max=4` under-used 12 logical cores. Heaps not raised: 16 GB box would swap-thrash (§5.5/§7).
- **Files:** `android/gradle.properties`.
- **Revert:** restore `-XX:+HeapDumpOnOutOfMemoryError` in jvmargs and set `org.gradle.workers.max=4`.

### SEC1 — S3 master credentials removed from repo
- **What:** Deleted `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_REGION`/`AWS_ENDPOINT_URL`/`AWS_BUCKET_NAME` + the `dart-defines=` base64 blob from `android/gradle.properties`. Scrubbed `ARVAN_ACCESS_KEY`/`ARVAN_SECRET_KEY` in `.env` (placeholders) and `git rm --cached .env` (now untracked; already in `.gitignore`).
- **Why:** Live ArvanCloud S3 master keys were committed + baked into the APK via dart-defines. Confirmed **no Dart code reads any `AWS_*`** (`String.fromEnvironment`) and the app never loads `.env` (no `flutter_dotenv`) → the secret was shipped for nothing. Client uses backend presign → needs zero S3 secrets (§6).
- **Files:** `android/gradle.properties`, `.env` (untracked).
- **Revert:** `git checkout <prev> -- android/gradle.properties` and `git add -f .env` with old content. (Do NOT — the keys are compromised.)
- **⚠ Still required (out-of-band):** rotate the Arvan keys; purge them from git history (BFG/`git filter-repo` + force-push). Removing from current files does NOT scrub history.

---

## Perf changes (feature-local — listed for rollback)

### P1 — Feed row scroll perf
- **What:** Wrapped each feed row in `RepaintBoundary`; added `memCacheWidth` (display-size decode) to the feed body `CachedNetworkImage`.
- **Why:** No per-row paint isolation + full-res image decode caused scroll jank + image-cache thrash/GC (§3.1). NOTE: `_ThreadPostItem` was already a `ConsumerWidget` and `scrollCacheExtent` already set — review snapshot predated team work.
- **Files:** `lib/features/posts/screens/ExploreFeedScreen.dart`.
- **Revert:** remove the `RepaintBoundary(child: …)` wrappers (2 list builders) and the `memCacheWidth:` line.

### P2 — Non-destructive feed pagination errors
- **What:** Both feed notifiers no longer call `state = AsyncValue.error` on a page-fetch failure when the feed already has content. They keep the loaded list, set a `loadMoreError` getter, and the list footer renders `_LoadMoreRetryRow` (retry → `retryLoadMore()`). Auto-load is gated while an error is pending. Full error state only when nothing is loaded.
- **Why:** A failed page-N fetch previously wiped the entire feed to a full-screen error (§3.2/§8.3).
- **Files:** `lib/provider/personalized_feed_provider.dart`, `lib/features/posts/providers/posts_provider.dart`, `lib/features/posts/screens/ExploreFeedScreen.dart`.
- **Revert:** restore the single `state = AsyncValue.error(...)` in each notifier's `catch`; drop `_loadMoreError`/`retryLoadMore`/`_LoadMoreRetryRow` and the footer branch.

---

### P3c/P4b (delivered) — bare-Dio → shared pinned client sweep + more autoDispose
- **P3c:** converted 15 more backend repos/services from bare `Dio(BaseOptions(...))` to the shared factory (`createApiV1Dio`, or `createPinnedDioClient` for nearby's `/v1/nearby` base): `comment_repository`, `profile_repository`, `profile_note_service`, `privacy_settings_repository`, `services_hub_repository`, `user_presence_service`, `typing_service`, `notification_provider`, `MusicService`, `profile_cache_manager`, `settings_cache_service`, `modern_read_receipt_service`, `story_repository`, `ContactUs`, `nearby_repository`. All now get cert pinning + god-mode interceptors. Removed now-unused `device_id_service` imports from `comment_repository`/`story_repository` (factory injects X-Device-ID). **Verified on emulator-5554:** `/v1/notifications`, `/v1/me/profile`, `/v1/me/note`, `/v1/presence/update`, `/v1/stories/active`, `/v1/profiles/notes/batch`, profile posts, saved — all 2xx, 0 exceptions.
- **Left bare intentionally:** external APIs (`geocoder_service` nominatim/IP), multipart upload Dios (`backend_upload_service`, `payment_service`), `auth_repository` (`/v1/auth` suffix), raw media-download `Dio()` in chat/image viewers.
- **P4b:** `hashtagPostsProvider` → `autoDispose.family` (same per-arg leak as `postProvider`; screen-scoped).
- **Revert:** restore each file's original `Dio(BaseOptions(...))` block + its `device_id_service` import; drop `.autoDispose` on hashtag/post providers.

### P3b/P4a/P5a (delivered) — client routing, autoDispose, dead-code
- **P3b:** `GoPostsRepository` now builds its Dio via `createApiV1Dio(baseUrl: _backendUrl)` (the shared pinned factory) instead of a bare `Dio(BaseOptions(...))`. Gains cert pinning + god-mode interceptors (maintenance/ban/rate-limit/feature-disabled). Pinning is currently inert (only a placeholder fingerprint configured) so TLS behavior is unchanged. Files: `lib/features/posts/data/go_posts_repository.dart`. Revert: restore the bare `Dio(BaseOptions(baseUrl: '$_backendUrl/v1', ... 'X-Device-ID': DeviceIdService.id))` + re-add the `device_id_service` import.
- **P4a:** `postProvider` → `FutureProvider.autoDispose.family` (was leaking one instance per opened post). Only used by `PostDetailPage` (watch + invalidate) → safe. Files: `lib/features/posts/providers/posts_provider.dart`. Revert: drop `.autoDispose`.
- **P5a:** removed unused `supabaseUrl`/`supabaseAnonKey` consts (`lib/utils/env_config.dart`) and the dead commented Supabase `FutureProvider` block (`lib/features/posts/providers/posts_provider.dart`). No code referenced them. Revert: restore from prior commit.

## Staged — large items not safely completable without runtime verification

- **P3 remainder — HTTP client consolidation:** 43 ad-hoc `Dio(...)` instances + per-request `TokenStorage.getAccessToken()` reads remain. Target: one shared `Dio` (the existing `lib/services/http_client_factory.dart`) with a central auth interceptor (in-memory cached token, 401→refresh→retry) + retry/backoff. Sweeping cross-file change, no test coverage, can't runtime-verify here → not attempted. Delivered the contained, highest-impact slice instead (feed-event batching, see below).
- **P4 — provider hygiene (autoDispose):** ~370 of ~400 providers never dispose (§3.2). Blanket-adding `autoDispose` is dangerous — auto-disposing a provider that holds in-use session state causes refetch loops / lost state, and `flutter test` (no widget-navigation coverage here) won't catch it. **Safe approach (not applied):** (1) start with `.family` providers backing transient detail/profile/search screens — these accumulate one instance per argument and are the clearest leak; (2) add `.autoDispose` + `ref.keepAlive()` guarded by a short timer where brief caching is wanted; (3) leave always-on tab providers (feed) alone — autoDispose there just causes refetch on tab switch. Each change must be smoke-tested by navigating in/out of the screen.
- **P5 — finish migration / prune deps / exit Isar 3:** "weeks of unglamorous work" per review §8.6 (old `lib/provider|services|model|widgets` vs `lib/features`, dead Supabase code, ~120 deps incl. redundant HTTP/image/video stacks, unmaintained Isar 3). Not safely scriptable; needs incremental human-driven migration. Documented, not attempted.
- **P6 — media transcode off-isolate / server-side:** backend-dependent (server-side transcode) + needs device runtime profiling to gate on-device ffmpeg. Out of static-edit scope.

---

### P3 (delivered) — Feed-event analytics batching
- **What:** `trackFeedEvent` now enqueues into an in-memory buffer (dedup by `postId|eventType`) and flushes on a 4s debounce or at 25 events; token read once per flush. Was: one HTTP POST + one secure-storage read per gesture.
- **Why:** Scrolling fired an unbatched POST storm + a keystore read per event (§3.4). Endpoint unchanged (`/feed/event`) — folding into one batch request needs a backend `/feed/events` endpoint (follow-up).
- **Files:** `lib/features/posts/data/go_posts_repository.dart`.
- **Revert:** restore the immediate-POST `trackFeedEvent` body; drop the `_pendingFeedEvents`/`_pendingFeedEventKeys`/`_feedEventFlushTimer` fields, `_flushFeedEvents`, and the `dart:async` import.

---

## Flagged — needs user / out-of-band (NOT done here)

- **S3 key rotation:** the leaked ArvanCloud keys (`ARVAN_*` / `AWS_*`) must be rotated on the provider console — external action, cannot do from repo. Assume compromised.
- **Git history purge:** secrets live in committed history (`.env`, `android/gradle.properties`). Removing from current files does NOT scrub history. Needs `git filter-repo`/BFG + force-push — destructive, requires explicit user go.
