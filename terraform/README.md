# terraform

A [Please](https://please.build) plugin for hermetic, per-target [Terraform](https://www.terraform.io/): every module pins its own Terraform version and is validated as part of the build (`terraform_module`), roots are runnable with `plz run` (`terraform_root`) and testable (`terraform_root_test`), providers come from an offline mirror (`terraform_provider`, `terraform_local_provider`), and third-party modules are fetched by the build rather than by `terraform init` (`terraform_registry_module`).

It downloads every Terraform release itself (verified against a GPG-checked checksum mirror), so Terraform doesn't need to be installed - and works with forks like [OpenTofu](https://opentofu.org/) too.

## Contents

- [Usage](#usage)
- [Rules](#rules)
- [How it works](#how-it-works)
- [Custom workflows](#custom-workflows)
- [Providers](#providers)
- [Third-party modules](#third-party-modules)
- [Configuration](#configuration)
- [Checksum mirror](#checksum-mirror)
- [Testing](#testing)
- [Layout](#layout)

## Usage

See the [root README](../README.md#using-a-plugin) for loading it with `plugin_repo` - in `.plzconfig`:

```ini
[Please]
PluginRepo = https://github.com/{owner}/{plugin}/archive/{revision}.zip
PluginRepo = https://github.com/VJftw/please-rules/releases/download/{plugin}-v{revision}/{plugin}-v{revision}.tar

[Plugin "terraform"]
Target = //third_party/plugins:terraform
; Providers every module's offline mirror has.
DefaultProviders = //third_party/terraform:random
```

and in `third_party/plugins/BUILD`:

```python
plugin_repo(
    name = "terraform",
    owner = "VJftw",
    revision = "<version>",
    hashes = ["<sha256 from registry/plugins/terraform/<version>/source.json>"],
)
```

Then:

```python
# third_party/terraform/BUILD
subinclude("///terraform//build_defs:terraform")

terraform_provider(
    name = "random",
    source = "hashicorp/random",
    version = "3.6.0",
    hashes = {"linux_amd64": "...", "darwin_arm64": "..."},
    visibility = ["PUBLIC"],
)

# network/BUILD
terraform_module(
    name = "network",
    srcs = ["main.tf"],
    version = "1.4.0",
    visibility = ["PUBLIC"],
)

# app/BUILD - `module "network" { source = "../network" }` in main.tf.
terraform_root(
    name = "app",
    srcs = ["main.tf"],
    version = "1.6.0",
    deps = {"network": "//network"},
)

terraform_root_test(
    name = "app_plan_test",
    root = ":app",
    sandbox = True,
)
```

```console
$ plz build //...                    # validates every module
$ plz run //app -- plan
$ plz test //app:app_plan_test
```

## Rules

- **`terraform_module`**: a reusable module - its own `srcs` (with `srcs[0]` directly in its directory) plus its `deps`' files, validated on build (`terraform init` against the offline mirror, then `terraform validate`) with its own pinned `version` (any release in the checksum mirror) or `toolchain` (a `terraform_toolchain`, e.g. OpenTofu). Each module's version only pins its own validation: a module on 1.4.0 can be a dep of a root on 1.6.0.

  `deps` are the modules it calls with a local `source = "../..."`, keyed by the module call's name. `registry_modules` are the `terraform_registry_module`s it calls, also keyed by call name. `providers`/`local_providers` add to the offline mirror, on top of the plugin's `DefaultProviders`.

  `dep_sources` gives the exact `source = "..."` string of each `deps` entry that has registry modules anywhere beneath it - Terraform's module manifest has to match it exactly, or `init` re-discovers the module and fetches everything beneath it from the network. Building fails if one's missing.
- **`terraform_root`**: a `terraform_module` that's also runnable: `plz run //path:name -- <terraform args...>`. `env` sets fixed environment variables for it (e.g. `TF_LOG`), winning over the invoking shell's; `env_labels` is the same, but each value is a rule whose output path the variable is set to.
- **`terraform_root_test`**: runs a `terraform_root` with `tf_args` (default `plan -input=false -no-color`) as a test, passing iff it exits 0. With `sandbox = True` (no network), a pass also shows the root is fully hermetic.
- **`terraform_toolchain`**: a Terraform CLI for a version that's not in the checksum mirror, or a fork - see [OpenTofu and other forks](#opentofu-and-other-forks).
- **`terraform_provider`**, **`terraform_local_provider`**: see [Providers](#providers).
- **`terraform_registry_module`**: see [Third-party modules](#third-party-modules).

## How it works

A module's build output holds `tree/` - its own files plus every dep's, at their paths relative to the repository root (so `source = "../network"` resolves), with registry modules under `<module dir>/_registry_modules/<key>/`
- and `module.json`, describing the `.terraform/modules/modules.json` entries Terraform needs for them. Validation runs `init` with only the offline provider mirror (`direct` installation is disabled, so a missing provider fails loudly) and a pre-built module manifest, so it never touches the network.

`plz run` of a `terraform_root` copies that tree into a writable scratch directory (`plz-out/terraform/<label>/` - never the source tree), sets up the provider mirror's CLI config and the module manifest there, then hands off to a script: by default the plugin's own, which runs `init` first for `plan`, `apply`, `destroy`, `validate`, `refresh`, `import`, `console` and `output`, then `terraform` with your arguments. Exit codes pass straight through (e.g. `plan -detailed-exitcode`'s `2`).

Provider plugins talk to Terraform over Unix sockets in `TMPDIR`, whose paths are limited to ~100 characters, so runs and validations use a short `/tmp/plz-terraform-*` `TMPDIR` rather than Please's own (deep) directories.

Built-in steps are Nushell scripts (`scripts/`), run with a Nushell the plugin downloads itself (see `Nushell` below).

## Custom workflows

Set the plugin's `DefaultScript` to an executable target, and every `terraform_root` (and `terraform_root_test`) hands off to it instead of the built-in script - e.g. for an approval gate before `apply`, notifications, or several Terraform commands in one run:

```ini
[Plugin "terraform"]
DefaultScript = //tools:my_workflow
```

It runs in the writable module directory, with everything after `--` as its arguments, and gets:

- `TF_BIN` - the `terraform` (or `tofu`, ...) binary - and a `PATH` starting with a directory where its own name (`terraform`, `tofu`) runs it.
- `TF_MODULE_DIR` - the writable copy of the module (also its working directory).
- `TF_LABEL`, `TF_ROOT_NAME`, `TF_ROOT_PACKAGE` - the root's label, name and package, to tell roots apart.
- `TF_VERSION` - the root's pinned `version`.
- `TF_CLI_CONFIG_FILE` - the offline provider mirror's CLI config (if it has any providers).
- the root's own `env`/`env_labels`.

There's no auto-`init` - the script owns the whole command:

```sh
#!/bin/sh
set -eu
terraform init -input=false -no-color
terraform "$@"
```

## Providers

Every module's `init` installs providers from an offline filesystem mirror made of its `providers`, `local_providers` and the plugin's `DefaultProviders`, and nothing else.

### Third-party providers

`terraform_provider` downloads a provider for the host platform into the mirror layout. HashiCorp-published ones (`hashicorp/<name>`) come from releases.hashicorp.com; anything else needs a `url_template` (with `{namespace}`, `{name}`, `{version}` and `{platform}` placeholders):

```python
terraform_provider(
    name = "cloudflare",
    source = "cloudflare/cloudflare",
    version = "5.24.0",
    url_template = "https://github.com/cloudflare/terraform-provider-cloudflare/releases/download/v{version}/terraform-provider-cloudflare_{version}_{platform}.zip",
    hashes = {"linux_amd64": "...", "linux_arm64": "...", "darwin_amd64": "...", "darwin_arm64": "..."},
)
```

`hashes` is a list, or a dict of platform to sha256 (only the host's is used). There's no checksum mirror for providers.

### In-repo (local) providers

`terraform_local_provider` lays out a provider built in your repository (e.g. a `go_binary`) the same way, with no release, registry or network fetch. With `hostname = "local"` and `source = "myorg/myprovider"`, it's `local/myorg/myprovider` in `required_providers`.

## Third-party modules

`terraform_registry_module` fetches a registry or git module from a concrete archive `url` - not via the registry API, so the build is hermetic:

```python
terraform_registry_module(
    name = "label",
    source = "registry.terraform.io/cloudposse/label/null",
    version = "0.25.0",
    url = "https://github.com/cloudposse/terraform-null-label/archive/488ab91e34a24a86957e397d9f7262ec5925586a.tar.gz",
    strip_prefix = "terraform-null-label-488ab91e34a24a86957e397d9f7262ec5925586a",
    hashes = ["sha256: ..."],
)
```

`source` is exactly what Terraform's manifest records - with the `registry.terraform.io/` prefix, even if your `.tf` omits it. For a registry module, its archive is the `x-terraform-get` header of `curl -sD - https://registry.terraform.io/v1/modules/<namespace>/<name>/<provider>/<version>/download`; for `git::https://github.com/<owner>/<repo>?ref=<ref>`, it's `https://github.com/<owner>/<repo>/archive/<ref>.tar.gz` with `strip_prefix = "<repo>-<ref>"`. A module calling `module "label" { source = "cloudposse/label/null" ... }` lists it as `registry_modules = {"label": "//third_party/terraform:label"}`.

A registry module that itself calls other third-party modules lists them in its own `nested` (keyed by call name inside it), since the plugin never parses `.tf` files.

A module with registry modules beneath it, used through another module's `deps`, needs that module's `dep_sources` too - see `terraform_module` above.

## Configuration

| Key                | Default                       | Description |
| ------------------ | ----------------------------- | ----------- |
| `DefaultProviders` | (none)                        | Provider rules in every module's offline mirror. Repeatable. |
| `DefaultScript`    | (none - the built-in script)  | An executable every `terraform_root` hands off to. See [Custom workflows](#custom-workflows). |
| `Nushell`          | `//third_party/nushell:nu\|nu` | The `nu` the plugin's build steps and runner use. |

The Terraform version is set per rule (`version`/`toolchain`), not here.

## Checksum mirror

`build_defs/versions.build_defs` has the checksums of every Terraform release, verified against HashiCorp's GPG-signed `SHA256SUMS` - so any `version` works without hashes of your own, and the plugin defines a `///terraform//third_party/terraform:terraform_<version>` toolchain for each. See [Checksum mirrors](../README.md#checksum-mirrors) (`cd .github && plz run //scripts/mirrors:terraform`).

### OpenTofu and other forks

The mirror is HashiCorp-specific, so a fork is a `terraform_toolchain` with its own `url_template` (with `{version}` and `{platform}`), `bin_name` and `hashes`, passed as `toolchain` instead of `version`:

```python
terraform_toolchain(
    name = "tofu_1.7.0",
    version = "1.7.0",
    bin_name = "tofu",
    url_template = "https://github.com/opentofu/opentofu/releases/download/v{version}/tofu_{version}_{platform}.zip",
    hashes = {"linux_amd64": "...", "darwin_arm64": "..."},
)

terraform_root(
    name = "opentofu",
    srcs = ["main.tf"],
    toolchain = "//third_party/terraform:tofu_1.7.0",
)
```

## Supported platforms

Linux and macOS, on amd64 and arm64. Windows isn't supported.

## Testing

[`examples/`](./examples) is a separate Please repository that consumes this plugin from this checkout via `subrepo(name = "terraform", path = "..", plugin = True)`. It covers per-target versions (1.4.0 and 1.6.0), HashiCorp and third-party providers, a local provider's layout, a registry module - directly and through a local `deps` chain (with and without `dep_sources`) - and OpenTofu, with sandboxed plan tests:

```console
$ cd examples && plz test //...
$ plz run //new -- plan
```

## Layout

- `.plzconfig` - the plugin definition and its configuration options.
- `VERSION` - the plugin's current version.
- `build_defs/terraform.build_defs` - the rules above.
- `build_defs/versions.build_defs` - the generated checksum mirror.
- `scripts/` - the Nushell build steps (`build_module.nu`, `build_registry_module.nu`) and `plz run` runner (`runner.nu`).
- `third_party/terraform/BUILD` - a toolchain per mirrored Terraform release.
- `third_party/nushell/BUILD` - the default `Nushell`.
- `examples/` - an example repository, used for testing (see above).
