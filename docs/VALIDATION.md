# Validation record

Dates: 2026-10-29–31. This is an experimental integration, not a claim of official
OpenWrt support or production reliability.

## Environment

- GL.iNet Flint 2 / GL-MT6000, ARM64 Cortex-A53, 1 GiB RAM.
- GL.iNet 4.9.1-op25 / OpenWrt 25.12.5, kernel 6.12.94, apk package manager.
- Matching OpenWrt 25.12.5 mediatek/filogic SDK, GCC 14.3.0.
- External ext4 filesystem mounted by UUID; a USB hardware RAID1 enclosure.
- Resilio Sync 3.1.2 (1076). Initial tests used Debian libraries; on 2026-10-30
  the service migrated to source-built GNU glibc 2.44 and libxcrypt 4.5.2.
- Installed integration: `resilio-sync` 1.1.0-r2 and `luci-app-resilio-sync`
  1.0.0-r3. See [native runtime validation](NATIVE-RUNTIME.md) for migration
  checks and the limits of the new runtime's test coverage.

## Passed

- SDK packaging of the shell/JS integration into native APK files. Runtime
  dependencies resolve from the router's normal feeds and the two new library
  packages. Only the vendor application is fetched by the runtime installer.
- Installation through apk, service account creation, and upgrade from r1 to r2
  preserving UCI settings and external state.
- The initial three runtime downloads verified against their pinned SHA-256 hashes;
  ARM64 executable reports the expected version with the private loader.
- Service starts under an existing non-root storage account and restarts through
  procd. Its device identity remains stable after restart and package upgrade.
- Actual mounted filesystem accepted; incorrect UUID, internal tmpfs, nested
  private/shared paths, root service account, privileged port and an injected
  address rejected by the guard tests.
- Web UI HTTPS certificate verified against the generated local certificate.
  `/gui/` returns 401 without credentials and 200 with the configured password.
  The application reports 3.1.2 (1076) through its authenticated version endpoint.
- Existing personal Pro license imported and recognized by the application.
- After the user accepted the first-run terms, a GUI-managed standard folder
  transferred from the ARM64 router to an isolated x64 Linux client. Three files
  were received: plain text, a mixed Cyrillic/Japanese filename, and a 1 MiB
  random binary. All three SHA-256 hashes matched the router originals.
  This transfer test used the original Debian runtime, before the native-library
  migration; it is not a transfer qualification of the new libraries.
- Test share records, fixtures, processes and temporary license copies were
  removed. The user's separate share was preserved.
- HTTPS management through the user's Amnezia address was verified with
  certificate validation and authenticated HTTP 200. Router firewall rules and
  server policy-routing exceptions were saved persistently.
- At the user's request, Syncthing was subsequently uninstalled. Its 26 GiB data
  folder, private state and file versions were preserved; its startup hooks and
  obsolete firewall/routing rules were removed. Resilio remained running.
- Shell syntax, ShellCheck 0.11, JS syntax, JSON metadata, pinned-input and
  source-secret checks. The associated blog post builds successfully in Jekyll.

## Findings fixed during hardware validation

### LuCI password reset (2026-10-31)

- Both updated integration APKs built with the matching 25.12.5 SDK and
  installed on Flint 2. Existing UCI settings, certificates and network
  configuration were preserved.
- Nine isolated helper tests cover validation, SHA-512 crypt verification,
  mode 0600, stopped/running services, concurrent requests, hash-generation
  failure and restoring the previous hash after a failed reload.
- Nine RPC tests on the router cover invalid types, malformed JSON, short
  values, newline/tab/NUL rejection and literal shell characters over stdin.
  The tests use a disposable helper and never change production credentials.
- An anonymous HTTP RPC request was denied. The installed handler reapplied
  the existing password through SSH stdin; procd replaced the process and
  authenticated HTTPS access returned 200 with the unchanged password.
- Browser validation confirmed the Network tab button, password dialog and
  rejection of an empty password. Actual password values were not entered
  through browser automation. Password changes use a write-only RPC method;
  ordinary UCI reads contain neither plaintext nor the password hash.

### Earlier findings

- The firmware does not include `stat`; setup now uses POSIX `ls -nd` to verify
  state ownership without adding another dependency.
- Windows stdin uses CRLF. Setup now removes the terminal CR when reading a
  password with `--password-stdin`; authentication with the intended password
  was verified after the fix.
- `xz` has an OpenWrt menu dependency on `xz-utils`. The package selects both,
  and the build helper asserts that both integration packages remain selected
  after `make defconfig`.
- OpenWrt's UCI/JSON shell libraries do not support `set -u`; scripts sourcing
  them use explicit validation and `set -e` instead.
- procd supplied no useful HOME, so the application's initial default folder
  became `//Resilio Sync` and showed an incorrect free-space warning. The service
  now sets HOME to the shared root. The existing app's default folder was changed
  to the HDD, after which it reported about 3.9 TB free and no error. Two offline
  records left by CLI activation were hidden using the UI's own setting; the
  active device was preserved. Normal installation uses web UI activation.

## Not yet passed / limitations

- First-run terms still require each installing user to complete the wizard.
  A license alone does not perform that action.
- Selective placeholders and on-demand retrieval are **not yet validated** by
  this port's tests. The completed transfer test used full synchronization.
- Earlier loopback/configuration-mode attempts did not complete; an x64 WSL
  process also crashed while using `shared_folders`. The successful test used
  the GUI-managed path shipped by this integration, without `shared_folders`.
- The password dialog has been checked in the browser. Other LuCI edit flows
  have not received a complete interactive regression test.
- Physical unplug/replug, cold boot, long-duration operation, large libraries,
  Internet relay transfer, throughput and selective placeholders have not been
  validated. The test did not unmount or reformat the user's existing disk.
- No hardware claim is made for other routers, architectures, opkg releases,
  filesystems or OpenWrt master. No public CI run or official feed acceptance
  has occurred.

## Reproduce the non-destructive checks

```sh
sh tests/test_validation.sh
python3 tests/check_sources.py
python3 tests/test_password.py
node --check luci-app-resilio-sync/htdocs/luci-static/resources/view/resilio-sync/settings.js
```

On a router with the package installed and an already mounted test filesystem:

```sh
sh router-guards.sh /mnt/storage YOUR-EXT4-UUID
sh router-password-rpc.sh
/usr/libexec/resilio-sync-config check
resilio-sync-runtime status
```

Do not include license files, passwords, application databases, folder keys or
device identities in a public test report.
