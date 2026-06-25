# Vista — Architecture & Build Review

**Repo:** https://github.com/immrit/vista-project
**Reviewed:** 2026-06-25 (commit on default branch at clone time)
**Scope:** Static read of the client repo only. No backend, no database, no toolchain, nothing built or run.
**Verdict up front:** The app *works* in the demo sense, but it is a half-migrated, kitchen-sink Flutter monolith with a feed that will not scale gracefully, a build that is slow by construction, and **live cloud credentials committed to a public repo and compiled into the shipped APK.** Fix the secrets today. The rest is debt you can pay down; the secret leak is an incident.

---

## Fix Checklist — Progress: 5/12 fixes done

Implementation order = impact, build-heaviness/slowness first (per refactor plan). Worked on branch `architecture-fixes`. Test baseline before changes: **56 pass / 1 pre-existing fail** (`adaptive_effects_provider_test.dart` — unrelated repo bug, untouched).

**Build-time (do first — cheapest "lighter & faster"):**
- [x] **BF1** — `kotlin.incremental=true` (re-enable incremental Kotlin compile). §5.1
- [x] **BF2** — ABI filters: ship arm64-v8a + armeabi-v7a, drop x86_64 from release. §5.2 / §8
- [x] **BF3** — release `minifyEnabled true` + `shrinkResources true` (R8 shrink). §5.7 / §6 / §8 *(debug-signing change deferred — see flagged note; needs release-build smoke test)*
- [x] **BF4** — `workers.max` 4→8, dropped `HeapDumpOnOutOfMemoryError`, heaps kept (right for 16 GB). §5.5 / §7

**Security (critical — partial in-repo; rotation/history purge need user):**
- [x] **SEC1** — removed S3 master creds from `gradle.properties` (AWS_* + dart-defines) and `.env`; untracked `.env`. Verified no Dart code reads `AWS_*` (dead leak). §6 *(⚠ key rotation + git-history purge still REQUIRED — out-of-band, see MEMORY.md)*

**Perf / architecture (after build):**
- [ ] **P1** — feed row: extract `_ThreadPostItem`, `RepaintBoundary` per row, `const` subtrees, stop per-row global-provider watches, `memCacheWidth` on feed images, `cacheExtent`. §3.1 / §8.2
- [ ] **P2** — non-destructive pagination errors: keep loaded items, inline retry row, never `AsyncValue.error` over populated list. §3.2 / §8.3
- [ ] **P3** — single shared `Dio` client: interceptors for auth (in-memory token, central 401 refresh), retry/backoff; batch analytics POSTs. §3.4 / §8.4
- [ ] **P4** — provider hygiene: `autoDispose` defaults + `keepAlive` only where needed. §3.2 / §8.5
- [ ] **P5** — finish migration + prune redundant deps + dead Supabase code; plan Isar 3 exit. §4.1 / §8.6 *(large — staged)*
- [ ] **P6** — media transcode off UI isolate / server-side; gate + cap resolution. §3.5 / §8.7 *(backend-dependent)*

> Heavy/cross-cutting items (P3/P5/P6) are staged and may land partial with follow-ups noted in `MEMORY.md`. See `MEMORY.md` for global changes + rollback map.

---

## 1. Stack Inventory

### Client
- **Framework:** Flutter, Dart SDK constraint `^3.5.4` (`pubspec.yaml`). That implies a Flutter ~3.24–3.29 toolchain.
- **Size:** ~457 Dart files, **~182,000 LOC** under `lib/` (a large chunk is generated `*.g.dart` from Isar, but the hand-written surface is still enormous — a single chat screen is **7,852 lines**: `lib/features/chat/screens/modern_chat_screen.dart`).
- **State management:** `flutter_riverpod` ^2.6.1 + `riverpod_annotation`/`riverpod_generator`. **~400 provider declarations, only ~30 `autoDispose`.** 743 `setState` call sites coexist with Riverpod — two paradigms mixed.
- **Local DB / cache:** `isar` 3.1.0 (+ `isar_flutter_libs`, `isar_generator`). Note: **Isar 3 is effectively unmaintained.** Comments in `pubspec.yaml` show this project already churned through Drift → Sembast → Isar. There is also `flutter_cache_manager`, `shared_preferences`, and a hand-rolled `HighPerformanceCacheSystem`.
- **Networking:** `dio` ^5.4 *and* `http` ^1.3 (both). **43 raw `Dio(...)` instantiations across `lib/`** — no shared client. A `lib/services/http_client_factory.dart` with interceptors exists but the feed/posts repository does not use it.
- **Realtime:** WebSocket, single shared connection to `/v1/chat/ws` with exponential-backoff reconnect (`lib/features/chat/services/sse_manager.dart` — misnamed "SSE", actually WS). This part is sound.
- **Backend:** A custom **Go backend** at `https://api.coffevista.ir` (hardcoded in `lib/utils/env_config.dart`). The codebase is mid-migration **off Supabase** — dead Supabase query code is still commented into `posts_provider.dart`, and `supabaseUrl`/`supabaseAnonKey` defaults linger in `env_config.dart`.
- **Object storage:** ArvanCloud S3 (Iran), via **backend-issued presigned URLs** (`lib/services/backend_upload_service.dart` → `/uploads/presign`). Good pattern — the app does not sign S3 itself at runtime. (But see §6 — the secret is still shipped.)
- **Push:** Firebase Core + Firebase Messaging + `flutter_local_notifications`.
- **Payments:** Cafebazaar Poolakey (`flutter_poolakey`) + Zibal — Iran market (not Google Play).
- **Auth:** Custom JWT (access + refresh) in `flutter_secure_storage` (`TokenStorage` in `lib/features/auth/providers/auth_controller.dart`). E2EE for chat via `cryptography` (X25519/ChaCha-style shared-secret).
- **Analytics/attribution:** AdTrace SDK (Android), Install Referrer.

### The dependency list is a red flag by itself
~120 packages. Heavy/native ones that each carry a real cost: `ffmpeg_kit_flutter_min_gpl`, `video_compress`, `video_editor`, `video_trimmer`, `video_player`, `get_thumbnail_video`, `just_audio` (+background +platform_interface), `audio_waveforms`, `record`, `camera`, `mobile_scanner`, `isar_flutter_libs`, `pro_image_editor`, `image_editor_plus`, `photo_manager`, `geolocator`/`geocoding`, `local_auth`, `webview_flutter`, `flutter_contacts`. Three different image-editing stacks (`pro_image_editor`, `image_editor_plus`, `flutter_exif_rotation`+`image`). Two audio editing concerns, four video packages. **This is "every feature someone asked for, glued in" — not a curated stack.**

### Structure smell: two parallel architectures
`lib/` contains **both** an old layout (`lib/screens`, `lib/provider`, `lib/services` [59 files, ~16k LOC], `lib/model`, `lib/widgets`, `lib/middleware`) **and** a new feature-first layout (`lib/features/*` with `data/domain/providers/screens/widgets`, plus `lib/core`). The migration is unfinished: the main feed screen lives in `lib/features/posts` but imports providers from `lib/provider/`. Two competing feed notifiers exist with **duplicated pagination logic** (`PersonalizedFeedNotifier` in `lib/provider/personalized_feed_provider.dart` vs `FollowingPostsNotifier` in `lib/features/posts/providers/posts_provider.dart`).

---

## 2. Inferred Toolchain (to build this)

You cannot build this on a light setup. Minimum:

| Component | Needed | Why / source |
|---|---|---|
| Flutter SDK | ~3.24–3.29 stable | Dart `^3.5.4` constraint |
| Dart SDK | 3.5.4+ | bundled with Flutter |
| JDK | **17** (not 11, not 8) | AGP 8.11.1 + Gradle require JDK 17. `compileOptions` *target* 1.8 is just bytecode level, not the build JDK |
| Android Gradle Plugin | 8.11.1 | `android/build.gradle` |
| Gradle | ~8.9+ | required by AGP 8.11 |
| Kotlin | 2.2.20 | `ext.kotlin_version` |
| Android SDK Platform | **36** (compileSdk) | `android/app/build.gradle` |
| Android NDK | **29.0.13846066** | pinned in `build.gradle`; needed by ffmpeg/isar native libs |
| CMake + ninja | yes | native plugins (record, ffmpeg kit packaging, desktop targets) |
| Android Studio | recommended | SDK/NDK/AVD management |
| Xcode + CocoaPods | for iOS | `ios/` present |
| Visual Studio C++ / clang + CMake | for Windows/Linux/macOS desktop | `windows/ linux/ macos/` present |
| Signing keystore | `android/key.properties` + keystore | release **and debug** both use the release signing config |

Practical RAM/CPU floor for a non-miserable build: **16 GB RAM is the floor, 32 GB is comfortable.** Gradle is configured `-Xmx4096m` + Kotlin daemon `-Xmx2048m` (`android/gradle.properties`), and that is *before* the Dart/Flutter kernel compiler, Gradle daemon, and an IDE. On 8 GB you will swap-thrash (see §5).

---

## 3. Social-Platform Fitness

Judged against what an X-style feed actually demands.

### 3.1 Feed / timeline — **weak**
Main feed: `lib/features/posts/screens/ExploreFeedScreen.dart`.

- **Virtualization:** Uses `ListView.builder` (good) but wraps everything in a `NestedScrollView` → `TabBarView` (For-You / Following). `NestedScrollView` with inner scrollables is a known jank/relayout source and fights `AutomaticKeepAlive`. Two heavy lists kept alive simultaneously.
- **The post item is a 930-line `build()` method** (`_ThreadPostItem`, lines ~680–1219). It is a deep `Column/Row/Padding` tree with **no `RepaintBoundary` per item**, no `const` subtrees, and the whole thing rebuilds on any watched change.
- **Per-item over-watching:** every visible post calls `ref.watch(profileProvider)` and `ref.read(currentUserProfileProvider)` inside `_buildPostActions` to decide menu items — i.e. each row re-derives the *current user's* premium/verification state. That belongs computed once at the list level and passed down.
- **`visibility_detector` on every row:** each item is wrapped in `DwellDetector` (view/dwell tracking). `visibility_detector` runs geometry callbacks on scroll for every mounted child — measurable CPU cost on long lists.
- **Analytics amplification:** `trackFeedEvent` fires an **individual HTTP POST** on view, dwell, open, like, comment, save, and share — each via `goPostsRepositoryProvider`. Scrolling a feed = a storm of unbatched analytics requests. No debounce, no batching, no offline queue for these. This hammers both the device radio and the backend.
- **Image memory:** feed images use `CachedNetworkImage` with `BoxConstraints(maxHeight: 280)` but **no `memCacheWidth`/`cacheWidth`**. Full-resolution source images are decoded into the Flutter image cache. The cache is capped at 80 MB / 200 entries (`app_initialization.dart`), which a handful of full-res photos blows through → constant decode/evict churn → GC pauses while scrolling.
- **Pagination correctness:** trigger is a `NotificationListener` at `maxScrollExtent - 480`. The only re-entrancy guard is the notifier's `_isLoading` bool — workable, but fragile across the two duplicate notifiers.

### 3.2 State at scale — **fragile**
- **~400 providers, ~30 `autoDispose`.** ~370 providers live for the whole session. On a feed/chat app where the user roams many screens, that is unbounded retained state and a steady memory climb.
- **Catastrophic error handling in the feed:** both feed notifiers store `AsyncValue<List<Post>>` and on a *pagination* failure do `state = AsyncValue.error(...)`. **A failed page-5 fetch wipes the entire loaded feed and shows a full-screen error.** That is the wrong model — page errors must be local (a retry row at the bottom), never destroy loaded content.
- **Whole-list reallocation:** every page does `state = AsyncValue.data([...current, ...items])` — a new list each time. Fine at 20 items, wasteful at 500.
- **Two state systems:** 743 `setState` sites alongside 400 Riverpod providers. No single source of truth for things like like-state (there's a `likeStateProvider` map *and* per-post `post.isLiked` reconciliation logic inline in the widget).

### 3.3 Realtime — **the best part**
`SseManager` is a proper singleton WebSocket with one shared connection and exponential backoff, broadcast to providers. This is the right shape. Caveats: it is chat-only; likes/follower-counts/feed updates appear to be pull/optimistic, not pushed. Cannot confirm server-side fan-out from the client.

### 3.4 Backend & data layer — **cannot fully judge from client**
- Pagination is offset-based on the client (`_offset += items.length`) with a server that "dedupes via `user_feed_seen`" per the comments. Whether that scales (keyset vs offset, ranking cost) is a **backend question I cannot see**.
- **No shared HTTP client / no central auth-refresh interceptor on the hot path.** `GoPostsRepository` reads the access token from `flutter_secure_storage` **on every request** (`await TokenStorage.getAccessToken()`), then sets `Authorization` manually. Secure-storage reads hit platform keystore crypto each call. 401→refresh→retry is not centralized here.
- Offline: there's Isar + a `RetryQueueService`, but the feed itself has no read-through cache — cold open with no network = error state, not last-known feed.

### 3.5 Media — **heavy, client-side, risky**
- Upload goes through backend presign (good). But compression/transcode is **on-device** via `ffmpeg_kit_flutter_min_gpl` + `video_compress` + `flutter_image_compress`. ffmpeg transcode on a mid-range phone is a CPU/heat/battery sink and a prime ANR source.
- Multiple overlapping editors (`pro_image_editor`, `image_editor_plus`) inflate binary and memory.
- CDN: `ARVAN_PUBLIC_BASE_URL` exists, so a CDN front is intended — good — but the client doesn't request resized/derivative sizes for feed thumbnails (see decode issue above).

### 3.6 Auth & security — **one good call, several bad ones**
- **Good:** tokens in `flutter_secure_storage` with `encryptedSharedPreferences`/Keychain. Chat E2EE present.
- **Bad (critical):** see §6. Live S3 credentials in the repo *and* baked into the APK; release build unminified/unobfuscated; debug signed with the release key.

---

## 4. Architecture Critique (Q1: why is it wrong/fragile for a feed?)

1. **Half-finished migration is the root problem.** Old `lib/provider|services|model|widgets` and new `lib/features` coexist, with the feed straddling both. Two feed notifiers, duplicated pagination, dead Supabase code in comments. Every change risks touching the wrong copy.
2. **The feed row is a god-widget.** A 930-line item with no `RepaintBoundary`, no `const`, and per-row watches of global providers. This is the single biggest scroll-perf liability.
3. **Pagination errors are destructive** — a tail-fetch failure clears the whole feed. Unacceptable for a social timeline.
4. **Provider lifecycle is unmanaged** — ~370 non-disposing providers = monotonic memory growth across a long session.
5. **No HTTP layer.** 43 ad-hoc Dio clients, per-request secure-storage token reads, no central refresh/retry/backoff/dedup. Request volume is further inflated by per-gesture analytics POSTs.
6. **Dependency sprawl.** ~120 packages, several redundant (two HTTP libs, two-to-three image editors, four video packages). Each is build cost, binary size, and a maintenance/CVE surface. Isar 3 is unmaintained.
7. **Mixed state paradigms.** Riverpod + 743 `setState` + inline optimistic reconciliation = no single source of truth for engagement state.

These are concrete and fixable, but they compound: a heavy row × no repaint isolation × visibility detectors × per-scroll network calls × full-res decodes all land on the same frames during scroll.

---

## 5. Build-Time Analysis (Q2: why is the build slow?)

Real bottlenecks, from config:

1. **`kotlin.incremental=false`** (`gradle.properties`) — incremental Kotlin compilation is **explicitly disabled**. Every build recompiles Kotlin from scratch. This is the biggest self-inflicted wound.
2. **No ABI splits / no `abiFilters`.** The release build compiles and packages **every ABI** (arm64-v8a, armeabi-v7a, x86_64). With `ffmpeg_kit_flutter_min_gpl` and Isar native libs, that's 3× the native packaging and a fat APK.
3. **~120 plugins = ~120 Gradle subprojects**, each configured (and an `afterEvaluate` namespace-patch loop runs over all of them). Configuration + native compile time scales with this.
4. **ffmpeg-kit + NDK 29 native stage.** Even though ffmpeg-kit is prebuilt `.so`, the native merge/strip/packaging across all ABIs is slow; other plugins (record, isar) add native work.
5. **`org.gradle.workers.max=4` + `-Xmx4096m`.** On a machine with more cores this under-parallelizes; on a machine with less RAM the 4 GB heap + 2 GB Kotlin daemon + Dart kernel compiler OOM-thrash. Either way it's mistuned to *the* machine.
6. **First build pays Dart kernel compilation of ~182k LOC + 120 packages**, plus Gradle/Pub/CocoaPods dependency resolution.
7. **`minifyEnabled false` + `enableR8=true`** is contradictory — R8 only shrinks when minify is on, so you get neither the shrink benefit nor the (one-time) speed of skipping it cleanly; and unminified release means a bigger artifact to package/sign every time.

Net: clean builds will be many minutes even on strong hardware; incremental builds are far slower than they should be purely because Kotlin incremental is off.

---

## 6. SECURITY — read this first (Q-critical)

**Three committed-secret problems. Treat as an active incident.**

1. **`.env` is committed with live ArvanCloud S3 credentials** — `ARVAN_ACCESS_KEY` and `ARVAN_SECRET_KEY` (full secret) are in the repo and in git history across multiple commits, even though `.gitignore` lists `.env`. The ignore rule was added after the file was already tracked.
2. **`android/gradle.properties` is committed and contains the same keys in plaintext** (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, endpoint, bucket) — and is **not** gitignored at all.
3. **The S3 secret is compiled into the release binary.** That same `gradle.properties` has a `dart-defines=` base64 blob; decoding it yields `AWS_SECRET_ACCESS_KEY=a6b4db27...`. These are injected via `--dart-define`, so the **secret string is embedded in the shipped APK** — and because **`minifyEnabled false` / `shrinkResources false`**, strings are trivially recoverable from the APK with `strings`/`apktool`.

Consequence: anyone with the public repo (or a copy of the APK) has full read/write/delete on the `coffevista` Arvan bucket. The presigned-URL design on the *backend* is correct, but it's undermined by shipping the master credential anyway.

**Immediate actions:**
- **Rotate the Arvan S3 keys now.** Assume compromised.
- Purge `.env` and `android/gradle.properties` secrets from git history (`git filter-repo`/BFG), force-push, and rotate.
- Remove S3 credentials from `dart-defines` entirely — the app must never hold the master key; it already uses backend presign, so the client needs *zero* S3 secrets.
- Turn on `minifyEnabled true` + `shrinkResources true` + R8 for release (also shrinks the APK), and stop signing debug with the release key.

Other security notes: token storage itself is fine; per-request secure-storage reads are a perf wart, not a hole. Chat E2EE exists but I can't audit key exchange against the server from the client alone.

---

## 7. Freeze / Performance Analysis (Q3: why would a PC freeze, or the app stutter?)

**PC freezing during builds** — almost certainly memory pressure:
- Gradle daemon (4 GB) + Kotlin daemon (2 GB) + Dart kernel compiler + Android Studio/VS Code + emulator can exceed **10–12 GB** easily. On an 8–16 GB machine Windows starts swapping to disk; with `HeapDumpOnOutOfMemoryError` set, an OOM dumps a multi-GB heap to disk mid-build, which itself stalls the box. `kotlin.incremental=false` means this heavy stage runs in full on *every* build.
- All-ABI native packaging + 120 subprojects keeps CPU pinned for long stretches.

**App stutter / device freeze at runtime** — feed + init pressure:
- **Startup:** `AppInitialization.initCore()` runs a long synchronous chain before first frame — Firebase, session manager, device id, E2EE registrar — then defers Isar/caches/notifications. Cold start is back-loaded.
- **Scroll:** god-widget rows × no `RepaintBoundary` × `visibility_detector` per row × full-res image decode (cache thrash → GC) × per-gesture analytics POSTs. These all hit the same frames. Expect dropped frames and, on low-end devices, jank that reads as "freezing."
- **Memory:** ~370 non-disposing providers + image cache thrash + on-device ffmpeg transcode (CPU + heat) → low-memory kills/ANRs under sustained use.
- I **cannot** confirm backend latency, feed-ranking cost, or N+1 query behavior — those would also manifest as "the app hangs," and they live on the server.

---

## 8. Recommended Direction (Q4 — with trade-offs)

### Is Flutter the wrong tool? **No — keep Flutter.**
For an X-style feed app targeting the Iranian market (Cafebazaar, not Play; Android-first; one team), Flutter is a defensible, even good, choice: one codebase, strong list virtualization when used correctly, native-speed scroll when the row is cheap. The problems here are **implementation and discipline**, not the framework. Telegram-class smoothness is achievable in Flutter; this code just doesn't follow the rules that get you there. Rewriting in React Native trades these problems for a *different* set (JS-bridge jank on exactly this kind of heavy list) with no net win. Going fully native (Kotlin + Swift) doubles the team for a product that is fundamentally a CRUD-feed + chat — not justified. **The cheapest path to "lighter and faster" is to fix the Flutter you have.**

### If Flutter stays — the high-leverage changes, in order:
1. **Kill the secret leak** (§6). Non-negotiable, do first.
2. **Rebuild the feed row.** Extract `_ThreadPostItem` into a small `StatelessWidget`/`ConsumerWidget`, wrap each row in `RepaintBoundary`, make subtrees `const`, and stop watching global providers per row — pass derived flags down. Add `cacheExtent` tuning and **`memCacheWidth` on every feed image** (request CDN-resized derivatives, decode at display size). This alone fixes most scroll jank and image-memory pressure.
3. **Make pagination errors non-destructive.** Keep loaded items; show an inline retry row. Never `AsyncValue.error` over a populated list.
4. **One HTTP client.** A single `Dio` with interceptors: auth header (token cached in memory, refreshed centrally on 401), retry/backoff, and **batched** analytics (`trackFeedEvent` → buffer + flush, or fold into one events endpoint). Delete the 43 ad-hoc clients.
5. **Provider hygiene.** Default to `autoDispose`/`ref.keepAlive()` only where needed; tie feed/chat providers to screen lifecycle. This bounds memory.
6. **Finish the migration, then prune.** Pick `lib/features`, move the stragglers, delete `lib/provider|services|model|widgets` duplicates and the commented Supabase code. Then cut redundant deps (one HTTP lib, one image editor, consolidate video). Plan an exit from Isar 3 (it's unmaintained) — Drift or `sqlite3` is the conservative target.
7. **Move media transcode server-side** where possible; if it must stay on-device, gate it, cap resolution, and run it off the UI isolate.

### Build-time fixes (independent, do immediately):
- `kotlin.incremental=true`.
- Add `abiFilters`/ABI splits (ship arm64 + armeabi-v7a; drop x86_64 from release APKs).
- `minifyEnabled true` + `shrinkResources true` for release.
- Tune `org.gradle.workers.max` to the build machine's cores; right-size heaps to its RAM.
- Audit the 120 plugins; every removed native plugin is build time + binary back.

**Trade-offs:** minify/shrink adds a one-time R8 step per release build (slower release builds) but smaller, harder-to-reverse APKs and faster *debug* iteration is unaffected. Dropping x86_64 loses some emulator coverage (use an arm64 emulator instead). Finishing the migration is weeks of unglamorous work with no user-visible feature — but it's the precondition for everything else being maintainable.

---

## 9. What Could NOT Be Assessed From the Client Alone

Flagging where to look next, because these are invisible from this repo:
- **Feed ranking & pagination scalability** — offset vs keyset, ranking query cost, `user_feed_seen` dedup behavior, N+1 joins. All server-side.
- **Realtime fan-out** — whether likes/follows/notification counts are actually pushed over the WS or just polled; presence/scaling of the WS layer.
- **Backend auth** — token TTLs, refresh-token rotation/revocation, 401 handling contract, rate limiting.
- **Actual API latency / payload sizes** — a slow or chatty backend would present as "the app hangs" regardless of client quality.
- **S3/CDN config** — bucket ACLs, whether derivative/resized images exist for thumbnails, cache headers, signed-URL TTLs.
- **E2EE correctness** — key exchange and trust model need the server protocol to audit.
- **Push delivery** — FCM topic/token management and the notification backend.
- **DB migrations** — `supabase/migrations/*.sql` are referenced in `.gitignore` rules but the live schema and indexes aren't visible here.

---

### One-line bottom line
Keep Flutter; fix the feed row, the pagination error model, and the HTTP layer; finish the half-done migration; turn Kotlin incremental back on and add ABI splits — but **rotate those leaked S3 keys before you do anything else.**
