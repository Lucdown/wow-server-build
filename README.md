# wow-server-build

Builds a custom `mangosd.exe` for my SPP Classics V2 (TBC) server with GitHub Actions.

* `.github/workflows/build-tbc.yml` - the build recipe. Uses the exact source versions SPP's January 2026 server was built from.
* `patches/core`, `patches/playerbots`, `patches/modules/<module>` - changes applied on top before building.

Every push starts a build (about 1 hour). The result is published as the release called **latest**;
`C:\WoWServers\Custom\Install_Cloud_Build.bat` downloads and installs it.
