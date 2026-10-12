subinclude("///k8s//build_defs:k8s")

kustomize_build(
    name = "hello_prod",
    srcs = ["//base:srcs"],
    kustomization = "kustomization.yaml",
    visibility = ["PUBLIC"],
)
