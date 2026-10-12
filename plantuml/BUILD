# The java plugin, which provides the rules that download PlantUML and a JDK.
#
# This is defined at the root of this plugin because, when this plugin is
# loaded as a subrepo, Please resolves `///java` via the host repository's
# `[Plugin "java"]` config if it has one, and otherwise falls back to a `java`
# target at the root of this subrepo.
plugin_repo(
    name = "java",
    owner = "please-build",
    plugin = "java-rules",
    revision = "v0.4.5",
)
