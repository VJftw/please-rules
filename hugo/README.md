# hugo

A [Please](https://please.build) plugin for building [Hugo](https://gohugo.io/) static sites (`hugo_site`), with a runnable `hugo` for live local previews.

By default it downloads Hugo (the `extended` build, with the Sass/SCSS support most themes expect) from [GitHub Releases](https://github.com/gohugoio/hugo/releases), so it doesn't need to be installed.

## Usage

See the [root README](../README.md#using-a-plugin) for loading it with `plugin_repo` - in `.plzconfig`:

```ini
[Please]
PluginRepo = https://github.com/{owner}/{plugin}/archive/{revision}.zip
PluginRepo = https://github.com/VJftw/please-rules/releases/download/{plugin}-v{revision}/{plugin}-v{revision}.tar

[Plugin "hugo"]
Target = //third_party/plugins:hugo
```

and in `third_party/plugins/BUILD`:

```python
plugin_repo(
    name = "hugo",
    owner = "VJftw",
    revision = "<version>",
    hashes = ["<sha256 from registry/plugins/hugo/<version>/source.json>"],
)
```

Then, in the `BUILD` file next to your site's `hugo.toml`:

```python
subinclude("///hugo//build_defs:hugo")

hugo_site(
    name = "public",
    config = "hugo.toml",
    srcs = glob(["content/**", "layouts/**", "static/**", "assets/**"]),
    minify = True,
)
```

```console
$ plz build //site:public                      # plz-out/gen/site/public/
$ cd site && plz run //site:public_hugo -- server
```

## Rules

- **`hugo_site`**: renders the site into a directory, `<name>/` (or `out`), via `hugo --source <dir of config> --destination <out> --noBuildLock`. `srcs` must list every file the site needs (content, layouts, static, assets, data, i18n, archetypes, themes...). They're copied (dereferencing symlinks, which Hugo's walkers skip) into a scratch directory first. `base_url` (`--baseURL`), `environment` (`--environment`, default `production` - set explicitly, so an ambient `HUGO_ENVIRONMENT` can't change the output), `minify` (`--minify`) and `extra_args` are passed through.

  It also defines **`<name>_hugo`**, which runs the plugin's `hugo` from wherever `plz run` is invoked - e.g. `hugo server` for a live-reloading preview, or any other one-off subcommand.
- **`hugo_tool`**: downloads Hugo for the host platform (Linux amd64/arm64, and macOS's universal `.pkg`, unpacked with `pkgutil`). Used for the default `Tool`, and can be used directly to provide your own - a different `version`/`variant`, your own `hashes`, or a `url_template` (with `{version}` and `{asset}` placeholders) for a mirror.

## Configuration

| Key           | Default                   | Description |
| ------------- | ------------------------- | ----------- |
| `Tool`        | `//third_party/hugo:hugo` | The `hugo` executable: a build target, or a command on the host's PATH. |
| `ToolVersion` | `0.166.0`                 | The Hugo version the default `Tool` downloads. |
| `ToolVariant` | `extended`                | Which build the default `Tool` downloads: `extended`, `hugo`, `extended_withdeploy` or `withdeploy`. |

The `extended` build's checksums for every Hugo release are in the plugin's mirror, `build_defs/versions.build_defs` - see [Checksum mirrors](../README.md#checksum-mirrors) (`cd .github && plz run //scripts/mirrors:hugo`). Other variants are downloaded unverified unless you give `hugo_tool` `hashes`.

## Testing

[`examples/`](./examples) is a separate Please repository that consumes this plugin from this checkout via `subrepo(name = "hugo", path = "..", plugin = True)`. It renders a small site and checks its pages:

```console
$ cd examples && plz test //...
```

## Layout

- `.plzconfig` - the plugin definition and its configuration options.
- `VERSION` - the plugin's current version.
- `build_defs/hugo.build_defs` - `hugo_site` and `hugo_tool`.
- `build_defs/versions.build_defs` - the generated checksum mirror.
- `third_party/hugo/BUILD` - the default `Tool`: a `hugo_tool` at `ToolVersion`/`ToolVariant`.
- `examples/` - an example repository, used for testing (see above).
