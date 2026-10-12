subinclude("//build_defs:plantuml", "///java//build_defs:java")

# The default value of the plugin's `Jar` config: PlantUML at the plugin's
# configured `ToolVersion`, verified against the plugin's checksum mirror
# (build_defs/versions.build_defs). This jar bundles its optional
# dependencies, e.g. ELK for `!pragma layout elk`.
_plantuml_hashes = plantuml_jar_hashes(CONFIG.PLANTUML.TOOL_VERSION)

maven_jar(
    name = "plantuml",
    id = f"net.sourceforge.plantuml:plantuml:{CONFIG.PLANTUML.TOOL_VERSION}",
    hashes = _plantuml_hashes if _plantuml_hashes else None,
    sources = False,
    visibility = ["PUBLIC"],
)

# The default value of the plugin's `Java` config: a Temurin JDK for the host
# platform, so that Java doesn't need to be installed.
_JDK_VERSION = "25.0.4.1_1"

_JDK_PLATFORMS = {
    "linux_amd64": ("x64_linux", "dbb698396d478e7fa2b1e50f4103324b2a99b90569ee27c33f2261f9215cf41e"),
    "linux_arm64": ("aarch64_linux", "69df11a02cfa3ef7d7ca645e03edce6778ec090e100f6ae2b42097865730ac52"),
    "darwin_amd64": ("x64_mac", "e6229d9504f7922053ab31821b9e6bee8761daf7b026a3476d1a027563009880"),
    "darwin_arm64": ("aarch64_mac", "61979887f7506a24a57439ff99adb8b3a7fc89977d9cfe3b8984f58a981b7b9d"),
}

_jdk_platform = f"{CONFIG.OS}_{CONFIG.ARCH}"

if _jdk_platform in _JDK_PLATFORMS:
    _jdk_tag = _JDK_VERSION.replace("_", "%2B")
    _jdk_suffix, _jdk_hash = _JDK_PLATFORMS[_jdk_platform]

    java_toolchain(
        name = "toolchain",
        jdk_url = f"https://github.com/adoptium/temurin25-binaries/releases/download/jdk-{_jdk_tag}/OpenJDK25U-jdk_{_jdk_suffix}_hotspot_{_JDK_VERSION}.tar.gz",
        hashes = [f"sha256: {_jdk_hash}"],
        visibility = ["PUBLIC"],
    )
