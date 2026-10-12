# k8s

A [Please](https://please.build) plugin for Kubernetes manifests: rendering kustomizations (`kustomize_build`) and Helm charts (`helm_template`) at build time, composing them with each other, bundling them into one directory (`k8s_manifests`), and running `kubectl` (`kubectl_binary`).

By default it downloads [kustomize](https://github.com/kubernetes-sigs/kustomize/releases), [Helm](https://github.com/helm/helm/releases) (from `get.helm.sh`) and [kubectl](https://kubernetes.io/releases/) (from `dl.k8s.io`) itself, so none of them need to be installed.

## Usage

See the [root README](../README.md#using-a-plugin) for loading it with `plugin_repo` - in `.plzconfig`:

```ini
[Please]
PluginRepo = https://github.com/{owner}/{plugin}/archive/{revision}.zip
PluginRepo = https://github.com/VJftw/please-rules/releases/download/{plugin}-v{revision}/{plugin}-v{revision}.tar

[Plugin "k8s"]
Target = //third_party/plugins:k8s
```

and in `third_party/plugins/BUILD`:

```python
plugin_repo(
    name = "k8s",
    owner = "VJftw",
    revision = "<version>",
    hashes = ["<sha256 from registry/plugins/k8s/<version>/source.json>"],
)
```

Then, e.g.:

```python
# base/BUILD - a kustomize base, for overlays to list in their srcs.
filegroup(
    name = "srcs",
    srcs = glob(["*.yaml"]),
    visibility = ["PUBLIC"],
)

# overlay/BUILD - `resources: [../base]` in its kustomization.yaml.
subinclude("///k8s//build_defs:k8s")

kustomize_build(
    name = "hello_prod",
    kustomization = "kustomization.yaml",
    srcs = ["//base:srcs"],
)

# chart/BUILD
helm_template(
    name = "hello",
    chart_yaml = "Chart.yaml",
    srcs = glob(["templates/**"]) + ["values.yaml"],
    release_name = "hello-example",
    visibility = ["PUBLIC"],
)

# chart_kustomize/BUILD - `resources: [rendered.yaml]` in its
# kustomization.yaml, so its transforms apply to the chart's output.
kustomize_build(
    name = "hello_prod",
    kustomization = "kustomization.yaml",
    resources = {"rendered.yaml": "//chart:hello"},
)

# BUILD
k8s_manifests(
    name = "manifests",
    deps = ["//overlay:hello_prod", "//chart:hello", "//chart_kustomize:hello_prod"],
)

kubectl_binary(name = "kubectl")
```

```console
$ plz build //:manifests
$ plz run //:kubectl -- apply -R -f plz-out/gen/manifests/
```

## Rules

- **`kustomize_build`**: `kustomize build <dir of kustomization> --output
  <out>` - a single manifest, `<name>.yaml` (or `out`). `kustomization` must
  be named `kustomization.yaml`, `kustomization.yml` or `Kustomization`, and `srcs` must list every other file it needs, including any bases' own files (e.g. via a `filegroup` in each base's package).

  `resources` maps a path in `kustomization`'s directory to another rule's (single) output - typically a `helm_template` or another `kustomize_build` - which is copied there before rendering. Declaring that path in the kustomization's `resources:` makes its own transformers (`namespace`, labels, patches...) apply to the rule's output too.

  `load_restrictor` defaults to `LoadRestrictionsNone` rather than kustomize's `RootOnly`, which refuses the symlinks Please stages sources as - Please's own build isolation already does what it's for.
- **`helm_template`**: `helm template <release_name> <dir of chart_yaml>` - a single manifest, `<name>.yaml` (or `out`). `srcs` lists the chart's other files (`values.yaml`, `templates/**`, vendored `charts/**`); `values` are extra values files (`-f`, in order), `set_values` extra `--set` overrides, plus `namespace` and `include_crds` (default `True`). Helm's cache, config and data directories are kept inside the build, so your own Helm setup doesn't affect the output.
- **`k8s_manifests`**: a directory, `<name>/`, of plain manifest files (`srcs`) and other rules' manifests (`deps`), each at its path relative to the repository root - so same-named files from different packages don't collide. Another `k8s_manifests` in `deps` has its contents merged in.
- **`kubectl_binary`**: runs the plugin's `kubectl` with `plz run //path:name -- <args>`, against whatever kubeconfig the invoking environment points at. The plugin's own `///k8s//third_party/k8s:kubectl` is runnable directly too.
- **`kustomize_tool`**, **`helm_tool`**, **`kubectl_tool`**: download each tool for the host platform (Linux and macOS, amd64 and arm64). Used for the defaults, and can be used directly to provide your own - a different `version`, your own `hashes`, a `url_template` for a mirror, or a different `bin_name`.

## Configuration

| Key                | Default                        | Description |
| ------------------ | ------------------------------ | ----------- |
| `Kustomize`        | `//third_party/k8s:kustomize`  | The `kustomize` executable: a build target, or a command on the host's PATH. |
| `KustomizeVersion` | `5.8.1`                        | The version the default `Kustomize` downloads. |
| `Helm`             | `//third_party/k8s:helm`       | The `helm` executable. |
| `HelmVersion`      | `3.22.0`                       | The version the default `Helm` downloads. |
| `Kubectl`          | `//third_party/k8s:kubectl`    | The `kubectl` executable. |
| `KubectlVersion`   | `1.37.1`                       | The version the default `Kubectl` downloads. |

Every release's checksums are in the plugin's mirrors, `build_defs/{kustomize,helm,kubectl}_versions.build_defs` - Helm's verified against its GPG-signed checksums, kubectl's against its cosign signatures. See [Checksum mirrors](../README.md#checksum-mirrors) (`cd .github && plz run //scripts/mirrors:<kustomize|helm|kubectl>`).

## Testing

[`examples/`](./examples) is a separate Please repository that consumes this plugin from this checkout via `subrepo(name = "k8s", path = "..", plugin = True)`. It renders a kustomize base and overlay, a Helm chart, and the chart passed through kustomize, bundles them, and checks the results:

```console
$ cd examples && plz test //...
$ plz run //:kubectl -- version --client
```

## Layout

- `.plzconfig` - the plugin definition and its configuration options.
- `VERSION` - the plugin's current version.
- `build_defs/k8s.build_defs` - the rules above.
- `build_defs/*_versions.build_defs` - the generated checksum mirrors.
- `third_party/k8s/BUILD` - the default `Kustomize`, `Helm` and `Kubectl`.
- `examples/` - an example repository, used for testing (see above).
