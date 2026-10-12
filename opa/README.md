# opa

A [Please](https://please.build) plugin for [Open Policy Agent](https://www.openpolicyagent.org/): packaging Rego policies into bundles (`opa_build`), evaluating queries at build time - including as policy gates that fail the build (`opa_eval`) - and running policy tests (`opa_test`).

By default it downloads OPA itself from [GitHub Releases](https://github.com/open-policy-agent/opa/releases) (the fully static Linux builds), so it doesn't need to be installed.

## Usage

See the [root README](../README.md#using-a-plugin) for loading it with `plugin_repo` - in `.plzconfig`:

```ini
[Please]
PluginRepo = https://github.com/{owner}/{plugin}/archive/{revision}.zip
PluginRepo = https://github.com/VJftw/please-rules/releases/download/{plugin}-v{revision}/{plugin}-v{revision}.tar

[Plugin "opa"]
Target = //third_party/plugins:opa
```

and in `third_party/plugins/BUILD`:

```python
plugin_repo(
    name = "opa",
    owner = "VJftw",
    revision = "<version>",
    hashes = ["<sha256 from registry/plugins/opa/<version>/source.json>"],
)
```

Then, in a `BUILD` file next to your policies:

```python
subinclude("///opa//build_defs:opa")

opa_build(
    name = "bundle",
    srcs = ["authz.rego", "authz_test.rego"],
)

# Fails the build unless input.json is allowed.
opa_eval(
    name = "allow_get",
    srcs = ["authz.rego"],
    input = "input.json",
    query = "data.authz.allow = true",
    fail_undefined = True,
)

opa_test(
    name = "authz_test",
    srcs = ["authz.rego", "authz_test.rego"],
)
```

```console
$ plz build //policy:bundle //policy:allow_get
$ plz test //policy:authz_test
```

## Rules

- **`opa_build`**: `opa build -b <dir> --follow-symlinks -o <out>` - a bundle (`<name>.tar.gz`) of every file in `srcs` (`.rego` policies, `data.json`/`data.yaml`, an optional `manifest.yaml`). The bundle's root is the directory `srcs[0]` is directly inside. `revision` is recorded in its `.manifest`. `--follow-symlinks` is always passed, as Please can stage sources as symlinks, which `opa build` otherwise silently skips.
- **`opa_eval`**: `opa eval -d <src>... [--input <input>] --format <format>
  <query>`, with the result written to `<name>.json` (or `out`).
  `fail_undefined` (`--fail`) / `fail_defined` (`--fail-defined`) make it a build-time gate: the build fails if the query is undefined / defined.
- **`opa_test`**: `opa test <srcs...>` as a Please test, passing iff every `test_*` rule passes. `test_args` (default `["-v"]`) are passed through; `timeout`, `flaky`, `size` and `sandbox` work as for any other test.
- **`opa_tool`**: downloads OPA for the host platform (Linux and macOS, amd64 and arm64). Used for the default `Tool`, and can be used directly to provide your own - a different `version`, your own `hashes`, or a `url_template` (with `{version}` and `{asset}` placeholders) for a mirror.

### Writing a gate query

A gate only fails on an *undefined* result, so its query must be undefined whenever the policy says no. `data.authz.allow` on its own is always defined if the policy has `default allow := false`, and so is `data.authz.allow == true` (a comparison's result is `false`, not undefined). Unifying it instead - `data.authz.allow = true` - is only defined when it's actually `true`.

## Configuration

| Key           | Default                 | Description |
| ------------- | ----------------------- | ----------- |
| `Tool`        | `//third_party/opa:opa` | The `opa` executable: a build target, or a command on the host's PATH. |
| `ToolVersion` | `1.20.2`                | The OPA version the default `Tool` downloads. |

Every OPA release's checksums are in the plugin's mirror, `build_defs/versions.build_defs` - see [Checksum mirrors](../README.md#checksum-mirrors) (`cd .github && plz run //scripts/mirrors:opa`).

## Testing

[`examples/`](./examples) is a separate Please repository that consumes this plugin from this checkout via `subrepo(name = "opa", path = "..", plugin = True)`. It builds a bundle and a gate, runs the policy tests (one sandboxed), and checks the outputs:

```console
$ cd examples && plz test //...
```

## Layout

- `.plzconfig` - the plugin definition and its configuration options.
- `VERSION` - the plugin's current version.
- `build_defs/opa.build_defs` - `opa_build`, `opa_eval`, `opa_test` and `opa_tool`.
- `build_defs/versions.build_defs` - the generated checksum mirror.
- `third_party/opa/BUILD` - the default `Tool`: an `opa_tool` at `ToolVersion`.
- `examples/` - an example repository, used for testing (see above).
