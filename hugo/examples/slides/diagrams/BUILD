subinclude("///plantuml//build_defs:plantuml")

# Every diagram, rendered into this package - hugo.toml mounts it at
# /diagrams/ in the site.
filegroup(
    name = "diagrams",
    srcs = [
        plantuml_diagram(
            name = splitext(src)[0],
            src = src,
        )
        for src in glob(["*.puml"])
    ],
    visibility = ["//slides:all"],
)
