subinclude("///k8s//build_defs:k8s")

# Templates the Helm chart (//chart:hello), then passes the result into
# kustomize - `rendered.yaml` in kustomization.yaml (in this same directory)
# is what `resources` below makes resolvable at build time. The
# `namespace`/labels transforms declared here apply to the helm-rendered
# Deployment too, since it's a first-class `resources:` entry of this
# kustomization, not just a file sitting alongside it.
kustomize_build(
    name = "hello_prod",
    kustomization = "kustomization.yaml",
    resources = {"rendered.yaml": "//chart:hello"},
    visibility = ["PUBLIC"],
)
