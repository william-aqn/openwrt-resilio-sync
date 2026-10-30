# Installation

## Requirements

- ARM64 OpenWrt with procd and LuCI. The tested target is Flint 2 / GL-MT6000,
  OpenWrt 25.12.5 with apk; see [validation](VALIDATION.md).
- At least 150 MiB free on the internal filesystem during runtime installation.
- An ext4 data disk mounted through `block-mount`/fstab by UUID. This integration
  does not partition, format or mount a disk for you.
- A Resilio Sync 3 license. Personal, non-commercial licenses are available from
  [Resilio](https://www.resilio.com/sync/register/). Activation remains the user's
  responsibility. See the [vendor licensing guide](https://help.resilio.com/hc/en-us/articles/31116248751123-Licensing-in-Resilio-Sync-3-0).

## Build and install native packages

Use a dedicated SDK directory for your OpenWrt release and target. The helper
retains target selection, saves the previous configuration as
`.config.before-resilio`, and disables the SDK's build-everything defaults.
For the validated target:

The Linux build host also needs GNU `bison` and `localedef` (Debian/Ubuntu:
`bison libc-bin locales`). Set `GLIBC_BISON` and `GLIBC_LOCALEDEF` to explicit
executable paths when an SDK supplies relocated wrappers. `BISON_PKGDATADIR`
may be needed for a locally extracted bison installation.
The helper retains or creates a private signing key inside the SDK, following
OpenWrt's APK key format; it never copies the private key into `dist`.

```sh
git clone https://github.com/william-aqn/openwrt-resilio-sync.git
cd openwrt-resilio-sync
sh scripts/build-sdk.sh /path/to/openwrt-sdk-25.12.5-mediatek-filogic_gcc-14.3.0_musl.Linux-x86_64
```

Copy all four package files in `dist/` to `/tmp/` on your router. Check `SHA256SUMS` against
the files you built, then install them:

```sh
apk add --allow-untrusted /tmp/glibc-compat-*.apk /tmp/libxcrypt-glibc-compat-*.apk /tmp/resilio-sync-*.apk /tmp/luci-app-resilio-sync-*.apk
resilio-sync-runtime install
```

`--allow-untrusted` is needed for your locally built package signing key; it is
not a request to disable HTTPS verification. Do not add it to normal official
package installation commands. A public signed binary feed is not published by
this project yet. Do not mix packages from different OpenWrt releases.

For an opkg-based release, build with that release's SDK and install its `.ipk`
files with `opkg install`. This path is not yet validated on hardware.

For a second SDK, set `DIST_DIR` to a separate absolute output directory.
The snapshot validation outputs under `dist/snapshot` are not the packages to
install on the tested 25.12 firmware; use the four files directly under `dist`.

## Configure storage and credentials

Find the filesystem UUID with `block info`. Substitute your actual mount point,
UUID and folder paths:

```sh
uci set resilio-sync.main.storage_mount='/mnt/storage'
uci set resilio-sync.main.storage_uuid='YOUR-EXT4-UUID'
uci set resilio-sync.main.state_dir='/mnt/storage/.resilio-sync'
uci set resilio-sync.main.directory_root='/mnt/storage/data/Resilio'
uci set resilio-sync.main.device_name='Flint 2'
uci commit resilio-sync
resilio-sync-setup
```

Setup prompts for a password, stores a SHA-512 crypt hash, creates a TLS
certificate, and creates the separate state and shared directories. It keeps
existing credentials on subsequent runs. It never recursively changes ownership
of an existing data tree. Passwords and keys are outside UCI, so LuCI cannot
retrieve them through ordinary configuration reads.

By default, the service runs as the package's `rslsync` user. If files must also
be writable by an existing Samba user, set `resilio-sync.main.user` to that
non-root account **before** initial setup. Ensure it owns the new directories.
Do not share the private state directory over Samba or add it to a sync folder.

Changing the user on an established installation requires deliberately migrating
ownership after stopping the service. Setup refuses state owned by another user.

## Enable the service and open the UI

Bind the GUI to your router's LAN address (example: `192.168.8.1`):

```sh
uci set resilio-sync.main.webui_address='192.168.8.1'
uci set resilio-sync.main.enabled='1'
uci commit resilio-sync
/etc/init.d/resilio-sync enable
/etc/init.d/resilio-sync restart
```

Open `https://192.168.8.1:8888/` with username `admin` and your setup password.
The default certificate is self-signed. Its fingerprint can be checked locally:

```sh
openssl x509 -in /etc/resilio-sync/server.crt -noout -fingerprint -sha256
```

The first-run web UI also requires the user to accept the application's terms.
Even a successfully imported license does not complete that step: the API can
return `Need to agree with the user terms` until the user finishes the wizard.
The integration deliberately does not accept terms automatically.

Use **LuCI → Services → Resilio Sync** to change disk paths, bind address, ports,
device name and transfer limits. Use the **Resilio web UI** to activate your
license, create the identity, add folders and connect devices. These are two
different interfaces. Saving LuCI settings reloads the service.

In the Resilio settings, check **Default folder location** and point it to your
shared root on the external disk. For a NAS-like router, set **Default connect
folder mode** to **Synced**, so it keeps complete files. Enable Selective Sync on
receiving computers as needed. The service sets HOME on the data disk for fresh
installations; this does not overwrite a default folder already saved by Resilio.
An old `//Resilio Sync` default indicates an earlier setup without a useful HOME.

Add a new directory below the configured shared root. Leave the router with a
full copy. On a receiving desktop, enable **Selective Sync** when connecting
the folder; it can then fetch individual files on demand. Selective Sync is a
client feature, not an HTTP file browser. For read-only access, share a read-only
key/link. Treat folder keys and device identity files as credentials.

## Networking

No firewall rules, port forwards or VPN routes are added by the package.
Defaults: HTTPS management on TCP 8888, peer traffic on TCP/UDP 55555, UPnP off.
The default GUI bind address is localhost until deliberately changed.

On standard OpenWrt, the LAN zone accepts traffic to the router, so binding to
its LAN IP is usually sufficient. A PC connected to the router's **WAN** network
is a different case: allow only that trusted management PC as needed. Never
expose management port 8888 to the public Internet.

Resilio can discover peers and use relays for file transfers without a VPN.
Inbound port forwarding can improve direct connectivity but is not mandatory
for relay operation. Relay reachability and real Internet transfer performance
must be checked in your network; a working web UI does not establish either.

Management over a VPN is optional. Bind to the VPN address, or to `0.0.0.0` with
explicit firewall restrictions. Some policy-routed VPN servers need separate
return-route exceptions for management traffic; the package does not alter a
remote VPN server. Management and file transfer ports serve different purposes.

## Disk removal and reboot

Startup checks the actual writable ext4 mount and its UUID before using any data
directory. Merely having `/mnt/storage` on the router's internal flash is not
enough. A block hotplug handler stops Sync when its disk is unplugged and retries
startup briefly when a disk is attached. The configured fstab entry must mount
the disk at the expected path. Startup failure is visible in the system log.

Stop the service before deliberately unmounting or removing the disk:

```sh
/etc/init.d/resilio-sync stop
```

Disk health, RAID recovery and backups remain separate concerns. RAID1 does not
protect against deleted files being synchronized to other devices.

## Upgrade, backup and uninstall

Back up `/etc/config/resilio-sync`, `/etc/resilio-sync/` and the private state
directory with the service stopped. The latter includes identity and folder
secrets. Data and state stay on the external disk; generated run files stay in RAM.
The configuration and credentials are marked as package conffiles.

Before upgrading the package, stop the service. Install the new package, run
`resilio-sync-runtime install`, then restart it. Since integration 1.1.0, the
application directory identifies only the Resilio version; libraries are managed
by `glibc-compat` and `libxcrypt-glibc-compat`. Old Debian-based runtime directories
are left intact for rollback but the new wrapper does not load their libraries.
Retain the previous integration and library packages for a
deliberate rollback. Reverting runtime alone may not revert application database
changes; restore the matching state backup when necessary.

On a firmware sysupgrade, reinstall the matching packages and runtime. Do not
rely on the firmware updater preserving downloaded executables.

```sh
/etc/init.d/resilio-sync stop
/etc/init.d/resilio-sync disable
apk del luci-app-resilio-sync resilio-sync
```

Uninstallation does not erase your shared files, identity, credentials or the
separately downloaded runtime. Remove those explicitly only if no longer needed.

To reset the password, stop the service, remove only
`/etc/resilio-sync/webui-password.hash`, run `resilio-sync-setup`, then restart.
To replace the certificate, install a matching `server.crt`/`server.key` under
`/etc/resilio-sync/` with directory mode 700 and private-key mode 600, then restart.

## Diagnostics

```sh
resilio-sync-runtime status
/usr/libexec/resilio-sync-config check
/etc/init.d/resilio-sync status
logread -e resilio-sync
```

Do not post configuration JSON, the state database, private keys, full debug
logs or folder secrets in public issues. Include OpenWrt release, architecture,
package version, mount status and a redacted error instead.
