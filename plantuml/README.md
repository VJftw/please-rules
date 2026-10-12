# plantuml

A [Please](https://please.build) plugin for rendering [PlantUML](https://plantuml.com/) diagrams as build targets.

PlantUML runs from its jar (from Maven Central) on a JDK downloaded with the [java plugin](https://github.com/please-build/java-rules)'s `java_toolchain`, so neither Java nor Graphviz needs to be installed. The jar supports features that PlantUML's native builds don't, e.g. `!pragma layout elk`.

## Usage

See the [root README](../README.md#using-a-plugin) for loading it with `plugin_repo` - in `.plzconfig`:

```ini
[Please]
PluginRepo = https://github.com/{owner}/{plugin}/archive/{revision}.zip
PluginRepo = https://github.com/VJftw/please-rules/releases/download/{plugin}-v{revision}/{plugin}-v{revision}.tar

[Plugin "plantuml"]
Target = //third_party/plugins:plantuml
```

and in `third_party/plugins/BUILD`:

```python
plugin_repo(
    name = "plantuml",
    owner = "VJftw",
    revision = "<version>",
    hashes = ["<sha256 from registry/plugins/plantuml/<version>/source.json>"],
)
```

Then, in a `BUILD` file next to your `.puml` files:

```python
subinclude("///plantuml//build_defs:plantuml")

plantuml_diagram(
    name = "architecture_svg",
    src = "architecture.puml",
)
```

```console
$ plz build //:architecture_svg
```

## Rules

- **`plantuml_diagram`**: renders a single `.puml` source into a diagram. `format` is one of `svg` (default, see `DefaultFormat`), `png`, `eps`, `pdf`, `txt` or `utxt`. The output is named after `src` with the format's extension, unless `out` is given. `deps` lists anything `src` `!include`s: plain files, `filegroup`s or `plantuml_library`s. `!include`s are resolved relative to `src`'s own directory, the same as running PlantUML on it directly. `src` is expected to contain a single `@startuml`/`@enduml` diagram, and a diagram with syntax errors fails the build.
- **`plantuml_library`**: a reusable set of PlantUML include files (e.g. shared styling or macros). Its `deps` are exported, so a library that `!include`s another only needs to be listed once by whatever depends on it, rather than every consumer listing the whole chain.

## Configuration

| Key             | Default                             | Description |
| --------------- | ----------------------------------- | ----------- |
| `Java`          | `//third_party/java:toolchain\|java` | The `java` executable: a build target (with an optional `\|entry_point`), or a path/command on the host, e.g. `java`. |
| `Jar`           | `//third_party/java:plantuml`       | The PlantUML jar: a build target or a path on the host. |
| `ToolVersion`   | `1.2026.8`                          | The PlantUML version the default `Jar` downloads. |
| `DefaultFormat` | `svg`                               | The default `format` for `plantuml_diagram`. |

Every PlantUML release's jar checksum is in the plugin's mirror, `build_defs/versions.build_defs` - see [Checksum mirrors](../README.md#checksum-mirrors) (`cd .github && plz run //scripts/mirrors:plantuml`).

The diagram is written to stdout, so the JVM runs with its own logging sent to stderr and its shared performance-data file turned off - otherwise its warnings (e.g. when several renders run at once) would end up in the output.

The default `Java` is a Temurin 25 JDK, available for Linux and macOS on amd64 and arm64. On other platforms, set `Java` to a `java` of your own.

### The java plugin

This plugin uses the java plugin internally, defined as `//:java` in this plugin. When this plugin is loaded as a subrepo, Please resolves `///java` via your repository's `[Plugin "java"]` config if it has one, so if you already use the java plugin, yours is used instead. You don't need to configure it otherwise.

## Testing

[`examples/`](./examples) is a separate Please repository that consumes this plugin the same way an end user would, except it loads it from this local checkout via `subrepo(name = "plantuml", path = "..", plugin = True)` (the equivalent of `new_local_repository`, which doesn't support `plugin = True`). Its `gentest`s check that each diagram renders, including one that relies on a transitive `plantuml_library` include and one laid out with ELK:

```console
$ cd examples && plz test //...
```

## Layout

- `.plzconfig` - the plugin definition and its configuration options.
- `BUILD` - the java plugin (see above).
- `VERSION` - the plugin's current version.
- `build_defs/plantuml.build_defs` - `plantuml_diagram` and `plantuml_library`.
- `build_defs/versions.build_defs` - the generated checksum mirror.
- `third_party/java/BUILD` - the default `Jar` (a `maven_jar` at `ToolVersion`) and `Java` (a `java_toolchain`).
- `examples/` - an example repository, used for testing (see above).
