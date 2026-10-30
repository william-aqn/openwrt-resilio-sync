# Resilio Sync for OpenWrt

An independent OpenWrt integration for Resilio Sync 3: native package metadata,
UCI configuration, a procd service, external-disk checks, and a LuCI settings page.

**Status:** development. ARM64 only. This is a community feed, not an official
OpenWrt package or a Resilio product. See [validation](docs/VALIDATION.md) for
what has actually been tested.

Resilio is proprietary. The runtime installer downloads only the unmodified
application directly from its publisher. GNU glibc and libxcrypt are built from
pinned upstream sources as separate OpenWrt packages. No Debian runtime packages
are downloaded. The isolated libraries do not replace OpenWrt's musl.
Installing the integration does not accept a Resilio license or activate Sync.

## Packages

| Package | Purpose |
| --- | --- |
| `resilio-sync` | Service, UCI configuration, runtime installer and setup tool |
| `luci-app-resilio-sync` | Services → Resilio Sync settings and service status |
| `glibc-compat` | GNU libc 2.44, C.UTF-8 locale and conversion modules |
| `libxcrypt-glibc-compat` | libxcrypt 4.5.2 built against the private glibc |

The router keeps a complete copy of each folder added in the Resilio web UI.
Use Selective Sync on the receiving computer to download individual files.
Do not point Syncthing and Resilio at the same live folder.

## Install

Build the packages with an OpenWrt SDK, or use packages from a release that
matches your OpenWrt version and architecture. See [installation](docs/INSTALL.md).

```sh
# OpenWrt 25.12 (local packages built with the matching SDK):
apk add --allow-untrusted ./glibc-compat-*.apk ./libxcrypt-glibc-compat-*.apk ./resilio-sync-*.apk ./luci-app-resilio-sync-*.apk

# Fetch the pinned ARM64 application:
resilio-sync-runtime install

# Configure your mounted ext4 disk, then create credentials and a certificate:
uci set resilio-sync.main.storage_mount='/mnt/storage'
uci set resilio-sync.main.storage_uuid='YOUR-EXT4-UUID'
uci set resilio-sync.main.state_dir='/mnt/storage/.resilio-sync'
uci set resilio-sync.main.directory_root='/mnt/storage/data/Resilio'
uci commit resilio-sync
resilio-sync-setup
```

The service is disabled by default and the UI initially binds to localhost.
Setup requires an already mounted disk, refuses to run as root, creates a
hashed password and a self-signed TLS certificate, and prints the next steps.
It does not open firewall ports. Follow the installation guide to enable LAN
access and start the service.

## Build the feed

Inside a matching OpenWrt SDK:

```sh
echo 'src-git resilio https://github.com/william-aqn/openwrt-resilio-sync.git' >> feeds.conf.default
./scripts/feeds update -a
./scripts/feeds install resilio-sync luci-app-resilio-sync
make defconfig
make package/resilio-sync/compile package/luci-app-resilio-sync/compile V=s
```

For a local checkout and the tested SDK, use [scripts/build-sdk.sh](scripts/build-sdk.sh).
The feed currently targets ARM64 Linux only. Other architectures are deliberately
not advertised as supported.

## Documentation

- [Installation, networking, upgrade and removal](docs/INSTALL.md)
- [Design, pinned inputs and licensing](docs/DESIGN.md)
- [Validation on a real Flint 2](docs/VALIDATION.md)
- [Path toward the official OpenWrt packages feed](docs/UPSTREAM.md)
- [Native library build and compatibility tests](docs/NATIVE-RUNTIME.md)

## License

Integration code: [MIT](LICENSE). Resilio Sync retains its proprietary license.
GNU glibc and libxcrypt retain their upstream licenses; license notices ship in
their packages. Corresponding source archives and build recipes must accompany
any public distribution as required by those licenses. No vendor executable, shared library,
credential, device identity or shared-folder key belongs in this Git repository.
