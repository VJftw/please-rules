subinclude("///k8s//build_defs:k8s")

helm_template(
    name = "hello",
    srcs = glob(["templates/**"]) + ["values.yaml"],
    chart_yaml = "Chart.yaml",
    release_name = "hello-example",
    visibility = ["PUBLIC"],
)
