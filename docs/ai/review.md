# AI review (solvor-myrion)

_Generated 2026-10-20 by claude-opus-5-5 from a snapshot of tracked sources; verify before acting._

# Code review: solvor-myrion

## Summary
Solvor is a macOS 26 SwiftUI client for a self-hosted "Keep" runtime. It uploads user files, browser-captured emails, clipboard text and Downloads files to the host. The host summarises each one inside a network-less microVM, and the app shows the outbound-connection count as "proof". The client logic sits in a SwiftPM library, `KeepKit`: API client, Keychain token store, Secure Enclave approval signing, secret scan, redactor and parsers. The UI is `Sources/Solvor`, plus XcodeGen config and release tooling.

## Bugs and correctness risks

**Watched folders**
- **Feedback loop from `name.keep.md`.** In `AppState.handleWatched`, the summary is written next to the watched file. If a rule's pattern matches `*.md` or `*`, the summary itself is picked up by `FolderWatcher.scan`. It has new content, so a new hash, so it runs again, indefinitely. `FolderRule.matches` (`FolderRules.swift`) has no exclusion for `*.keep.md`.
- **A file can be marked seen without ever running.** `handleWatched` inserts the hash into `seen` and saves it *before* `run(...)`. `run` can bail out in two ways:
  - It returns early when there is no client.
  - It parks the upload in `pendingSecretWarning` when the secret or size check fires, and the user may cancel.
  
  In both cases the file is never processed again. The save-beside loop then polls for 120 s and can match a *stale* job for the same path (`jobs.first(where: { $0.files == [file] && $0.source == "folder rule" })`), writing an old summary over the new one.
- **`FolderRule.notify` is never read.** The "Notify when a run finishes" toggle in `WatchFoldersView.swift` has no effect. `AppState.finish` uses only the global `notify`.
- **Secret-warning alerts can surface unexpectedly.** A folder-rule run can raise the modal alert at any time. Concurrent files overwrite the single `pendingSecretWarning`, so earlier pending uploads are silently dropped.

**Email reader**
- **The subject is never redacted or scanned.** In `EmailReaderView.send()`, `page.title = subject` is put into the `.eml` unredacted. A subject like "Your login code is 482913" is uploaded verbatim. Only the body goes through `Redactor` and `SecretScan.scan(text:)`.

**Catalogue hints**
- **Joined commands break when pasted.** `tools/gen_catalog.py` `hint()` joins multi-line code blocks with spaces, so inline `#` comments swallow the following commands. Examples in `CatalogData.swift`:
  - `homebrew-audit`: `brew list --versions > brew.txt # what is installed brew outdated …`. Pasted, only the first command runs.
  - `invoice-check` and `inbox-digest` contain deploy instructions, not "how to get the file".
  
  The UI offers these through "Copy command".

**Redactor and router (substring false positives)**
- `Redactor.codeWords` has no word boundaries. `pin` matches "ship**pin**g" and `code` matches "postcode", so order and reference numbers following those words are masked.
- `EmailRouter` rules use `lower.contains`. `cab` matches "vocabulary", `gate` matches "navigate", `claim` matches "disclaimer". Since only 2 hits are required, misrouting is plausible.
- `VoiceCommandParser.matchUseCase` uses the same substring matching.

**Approvals**
- **Silent unsigned decisions.** In `ApprovalsView.decide`, if `approval.sign != nil` but `deviceId` is empty, the decision is sent unsigned without telling the user.
- **Keychain work inside the view body.** `ApprovalsView.body` calls `SecureEnclaveKey.loadOrCreate()` on every render. That is a Keychain read on each render, and *key creation* as a side effect of the first render.
- **No recovery after fingerprint changes.** Because of `.biometryCurrentSet`, the stored key stops signing when the enrolled fingerprints change. `SecureEnclaveKey.delete` exists but nothing in the UI calls it to re-enrol.

**Polling and client**
- **Duplicate notifications on reconnect.** `startPolling` starts with `known = []` on every `connect()`. The first poll therefore posts a notification for every already-pending approval each time the app (re)connects.
- **Keychain read on every access.** `AppState.client` is a computed property that reads the Keychain each time. It is used from views, tasks and the poller.
- **Crash on empty input.** `KeepClient.run` uses `precondition(!files.isEmpty)`. A library API should throw instead of crashing the app.

**Concurrency**
- **Shared clipboard temp file.** `clipboard.txt` is a fixed temp path, shared by `MenuBarView.runClipboard` and `AppState.perform`. Two quick runs can race.
- **NSAppleScript off the main thread.** `BrowserReader.read` runs `NSAppleScript` on a global queue. NSAppleScript's thread-safety is historically documented as main-thread-only. I can't confirm the current status, so treat this as a risk.

**Snapshot-specific breakage**
- `CatalogTests.testEveryExamplePackIsInTheCatalogue` walks up 5 directories, which assumes the fabric layout. In this repo it always skips.
- `gen_catalog.py` and `make_icon.py` (`docs_png = ../../docs/assets/keep/...`) read and write outside the repo.
- `tools/export.sh` copies `../../LICENSE`.

**Minor**
- `Catalog.suggestions` uses a name tiebreak (`lower.contains(idPrefix)`). It is defeated when the id prefix equals the extension: `csv-clean` always "matches" `x.csv`.
- `SeenFiles` grows without bound.
- `AboutView` hard-codes "Version 0.1".

## Security concerns
- **`keep://run?usecase=…&path=…` uploads an arbitrary local path** (`SolvorApp.handle`), with no confirmation beyond the regex secret scan. Any web page or app can trigger it, for example `~/Library/Messages/chat.db` or documents without the scanned patterns. Fix: require explicit user confirmation, or restrict to files the user just dropped or chose.
- **Shortcuts and Siri bypass the safeguards the README promises.**
  - `RunUseCaseIntent.perform` calls `client.run` directly, with no `SecretScan` and no size warning.
  - `SummariseLatestDownloadIntent` and `TellSolvorIntent` go through `AppState.perform`. That path starts the upload immediately when one use case matches. There is no "Do it" confirmation, which only exists in `VoiceView`.
  - The README ("asks before it acts") and the intent description ("shows you which one") overstate this.
- **The intent temp path trusts `file.filename`.** `RunUseCaseIntent` builds it with `appendingPathComponent("intent-…-\(name)")`. A name containing `/` or `..` could escape the temp dir. This is low likelihood but worth sanitising.
- **Plaintext HTTP to non-loopback hosts is accepted.** `KeepClient.init` allows `http` for any host, so the bearer token and the files can travel in cleartext. I can't verify the ATS settings because `Info.plist` is not shown. Warn, or refuse `http` unless the host is loopback.
- **Keychain item details.**
  - `KeychainTokenStore` does not set `kSecUseDataProtectionKeychain`. On macOS the file-based keychain may not honour `kSecAttrAccessible…ThisDeviceOnly`; this is uncertain and worth checking.
  - `save` does a delete then an add, so a failed add loses the existing token.
- **Debug environment-variable credentials.** These are guarded by `#if
