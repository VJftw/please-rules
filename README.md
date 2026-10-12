# please-rules

Monorepo of [VJftw](https://github.com/VJftw)'s plugins for the [Please](https://please.build) build system. Each plugin lives in its own top-level directory, and is versioned and released on its own. They're the Please counterparts of [VJftw/bazel-rules](https://github.com/VJftw/bazel-rules)' modules - see each plugin's own README (linked below) for its rules and quickstart.

## Contents

- [Plugins](#plugins)
- [Using a plugin](#using-a-plugin)
- [Layout](#layout)
- [Releasing](#releasing)
- [Checksum mirrors](#checksum-mirrors)
- [Adding a new plugin](#adding-a-new-plugin)

## Plugins

- [`nushell/`](nushell/) - Nushell scripts as binaries (`nu_binary`), tests (`nu_test`) and build actions (`nu_genrule`), with shared modules (`nu_library`).
- [`plantuml/`](plantuml/) - PlantUML diagram rendering (`plantuml_diagram`, `plantuml_library`), with the PlantUML jar on a downloaded JDK.
- [`opa/`](opa/) - Open Policy Agent bundles (`opa_build`), build-time policy evaluation and gates (`opa_eval`) and policy tests (`opa_test`).
- [`hugo/`](hugo/) - Hugo static sites (`hugo_site`), with a runnable `hugo` for local preview.
- [`k8s/`](k8s/) - Kubernetes manifests from kustomize (`kustomize_build`) and Helm (`helm_template`), composable with each other and bundled (`k8s_manifests`), plus a runnable `kubectl` (`kubectl_binary`).
- [`terraform/`](terraform/) - hermetic, per-target Terraform: modules validated in the build (`terraform_module`), runnable roots (`terraform_root`) and plan tests (`terraform_root_test`), an offline provider mirror and pre-fetched registry modules.

Each downloads the tools it needs itself (verified against a checksum mirror - see below), so nothing but Please needs to be installed.

## Using a plugin

Every plugin version is a GitHub Release of this repository, tagged `<plugin>-vX.Y.Z`, with the plugin's archive (`<plugin>-vX.Y.Z.tar`) attached - which Please's own [`plugin_repo`](https://please.build/plugins.html) can download, given a `PluginRepo` URL template for it. In your `.plzconfig`:

```ini
[Please]
; Please's own default, for any other plugins - setting PluginRepo replaces it.
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
    revision = "0.1.0",
    hashes = ["<sha256>"],
)
```

`plugin_repo`'s `name` must be the plugin's own name. Each version's `<sha256>` is in this repo's `registry/plugins/<plugin>/<version>/source.json` (see Releasing below) - e.g. for opa 0.1.0, `registry/plugins/opa/0.1.0/source.json`. `registry/plugins/<plugin>/metadata.json` lists every released version.

Then `subinclude("///opa//build_defs:opa")` in a `BUILD` file to use its rules.

## Layout

```
please-rules/
  <plugin>/             # a Please plugin - its .plzconfig's [PluginDefinition]
    .plzconfig          # names it and declares its config options
    VERSION             # its current version
    build_defs/         # its rules, and its generated checksum mirror(s)
    third_party/        # the tools it downloads by default
    examples/           # a separate Please repository consuming the plugin
                        # from this checkout - its test suite (see its README)
  registry/plugins/     # every released plugin version - see Releasing
    <plugin>/
      metadata.json
      <version>/source.json
  .github/              # itself a Please repository, for this repo's tooling:
    scripts/
      registry.nu       # versions, registry entries and release archives
      mirrors/          # the checksum mirror scripts - see Checksum mirrors
    actions/setup-please/  # installs a pinned Please, for the workflows
    workflows/
      ci.yml            # plz build/test on every plugin's examples/
      registry.yml      # on pull requests: `registry.nu check`
      release.yml       # on every merge to main: releases new versions
      nightly.yml       # refreshes the checksum mirrors
```

## Releasing

Each plugin is versioned and released independently: version `X.Y.Z` of `<plugin>` is the GitHub Release tagged `<plugin>-vX.Y.Z`. There's no separate release step - a pull request that changes a plugin also adds its new version to `registry/`, and merging it releases that version:

1. Give your pull request a [Conventional Commit](https://www.conventionalcommits.org/) title - with squash merges, it's the commit message that lands on `main`, and it decides every changed plugin's new version:

   | Title                                  | Version bump                                         |
   | -------------------------------------- | ---------------------------------------------------- |
   | `feat(opa)!: ...` (any type with `!`)  | major - minor while the plugin's still `0.x`         |
   | `feat(opa): ...`                       | minor                                                |
   | `fix(opa): ...`, or any other type     | patch - the plugin's released contents still changed |

   It applies to every plugin the pull request changes - split it up if they need different bumps.
2. Stage your changes (`git add`), then run:

   ```console
   $ cd .github && plz run //scripts:registry -- bump
   ```

   For every plugin whose released contents changed, that sets its `VERSION` to the version the title implies, writes `registry/plugins/<plugin>/<version>/source.json` (the release archive's URL and sha256) and adds the version to `metadata.json`, and stages all of it - commit it alongside your change. It reads the title from the open pull request (via `gh`), or the branch's only commit if there's no pull request yet - otherwise, pass `--title '...'`. Re-run it whenever you change a plugin again or retitle the pull request; it replaces what it wrote before.

   CI's `version-bumps` job (`registry.nu check`, in `.github/workflows/registry.yml` - which also re-runs when the title is edited) fails the pull request unless the title is a Conventional Commit, and every plugin whose released contents changed has exactly the version it implies and an up-to-date `registry/` entry. Changes to only a plugin's `examples/` or its `*.md` docs don't need a new version.
3. Once it merges, `.github/workflows/release.yml` releases every plugin version in `registry/` that doesn't have a GitHub Release yet: it rebuilds the plugin's archive, checks it matches the registry entry's sha256, and creates the tag and GitHub Release with it attached.

This never pushes to `main`, so it works with branch protection - every change to `registry/` is reviewed in a pull request like any other.

The registry entry's hash can be computed before the archive is published because the archive is built reproducibly - from what's staged in git (not the working tree), with sorted entries and fixed timestamps, ownership and permissions, as an uncompressed `.tar` (a compressor can produce different bytes for the same input on different machines), under a single `<plugin>/` directory (what `plugin_repo` expects) - so the same change always gives byte-for-byte the same archive, wherever it's built.

## Checksum mirrors

Each plugin verifies the tools it downloads against a generated checksum mirror - its `build_defs/*versions.build_defs`, covering every release of the tool (GPG-verified for Terraform and Helm, cosign-verified for kubectl, hashed from the downloads themselves for PlantUML) - so any version of a tool works without supplying hashes yourself.

`.github/scripts/mirrors/` has a script per tool, each run with:

```console
$ cd .github && plz run //scripts/mirrors:<tool>
```

They're incremental - only releases published since the last refresh are looked up - and `.github/workflows/nightly.yml` runs them every night, opening (or updating) a `chore(<plugin>): update version mirrors` pull request per plugin with new versions, with the version bump and registry entry included. See that workflow's own comments for the GitHub App it can open them as, so CI runs on them.

## Adding a new plugin

A new top-level directory with its own `.plzconfig` (with a `[PluginDefinition]`), a `VERSION` file (e.g. `0.1.0`) and an `examples/` Please repository loading it from this checkout - plus an entry in `ci.yml`'s matrix, and in `nightly.yml`'s if it has a checksum mirror. `registry.nu` and `release.yml` handle any plugin directory generically; its first pull request adds its first version, as for any other change.
