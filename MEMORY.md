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

## Flagged — needs user / out-of-band (NOT done here)

- **S3 key rotation:** the leaked ArvanCloud keys (`ARVAN_*` / `AWS_*`) must be rotated on the provider console — external action, cannot do from repo. Assume compromised.
- **Git history purge:** secrets live in committed history (`.env`, `android/gradle.properties`). Removing from current files does NOT scrub history. Needs `git filter-repo`/BFG + force-push — destructive, requires explicit user go.
