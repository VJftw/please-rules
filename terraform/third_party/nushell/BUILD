# The default value of the plugin's `Nushell` config: the nu its build actions
# and runners (scripts/*.nu) run with - downloaded here, rather than needing
# the nushell plugin too.
_VERSION = "0.116.0"

_PLATFORMS = {
    "linux_amd64": ["x86_64-unknown-linux-musl", "7b91aeef575080f4b90405ba4512f4ccd0c21a6fbcd99f18bde3272c75213f00"],
    "linux_arm64": ["aarch64-unknown-linux-musl", "bc3503d0588caa7c2835d61337825152141c748c126817739cb86519c593416e"],
    "darwin_amd64": ["x86_64-apple-darwin", "c03c8cc16e7a1d616d0dd5992b114ae28d84b622e00b43905118147cc0bccdaf"],
    "darwin_arm64": ["aarch64-apple-darwin", "8d3169054b0e8f04b60b38ac1673acf61cbf66c6d8073ebc732d5bc108b3add6"],
}

_platform = f"{CONFIG.OS}_{CONFIG.ARCH}"

if _platform in _PLATFORMS:
    _triple = _PLATFORMS[_platform][0]
    _sha256 = _PLATFORMS[_platform][1]

    remote_file(
        name = "nu",
        url = f"https://github.com/nushell/nushell/releases/download/{_VERSION}/nu-{_VERSION}-{_triple}.tar.gz",
        hashes = [f"sha256: {_sha256}"],
        extract = True,
        strip_prefix = f"nu-{_VERSION}-{_triple}",
        binary = True,
        entry_points = {"nu": "nu"},
        visibility = ["PUBLIC"],
    )
