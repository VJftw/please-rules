subinclude("//build_defs:hugo")

# The default value of the plugin's `Tool` config: Hugo for the host
# platform, at the plugin's configured `ToolVersion` and `ToolVariant`.
hugo_tool(
    name = "hugo",
    variant = CONFIG.HUGO.TOOL_VARIANT,
    version = CONFIG.HUGO.TOOL_VERSION,
    visibility = ["PUBLIC"],
)
