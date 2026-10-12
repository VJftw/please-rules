subinclude("//build_defs:k8s")

# The default values of the plugin's `Kustomize`, `Helm` and `Kubectl`
# configs: each tool for the host platform, at the plugin's configured
# version. `plz run ///k8s//third_party/k8s:kubectl -- <args>` runs the
# pinned kubectl directly.
kustomize_tool(
    name = "kustomize",
    version = CONFIG.K8S.KUSTOMIZE_VERSION,
    visibility = ["PUBLIC"],
)

helm_tool(
    name = "helm",
    version = CONFIG.K8S.HELM_VERSION,
    visibility = ["PUBLIC"],
)

kubectl_tool(
    name = "kubectl",
    version = CONFIG.K8S.KUBECTL_VERSION,
    visibility = ["PUBLIC"],
)
