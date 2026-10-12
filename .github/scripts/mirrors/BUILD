subinclude("///nushell//build_defs:nushell")

# Checksum mirror scripts - one per tool, each maintaining a plugin's
# generated `build_defs/*versions.build_defs`. See mirror.nu, and the nightly
# workflow, which runs them all.

nu_library(
    name = "mirror",
    srcs = ["mirror.nu"],
)

[nu_binary(
    name = tool,
    src = f"{tool}.nu",
    deps = [":mirror"],
) for tool in ["nushell", "plantuml", "opa", "hugo", "kustomize", "helm", "kubectl", "terraform"]]
