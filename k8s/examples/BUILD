subinclude("///k8s//build_defs:k8s")

# Aggregates every rendered manifest in this example repository into one
# directory - `plz build //:manifests` produces all three files, at their
# own paths (two are both named hello_prod.yaml).
k8s_manifests(
    name = "manifests",
    deps = [
        "//chart:hello",
        "//chart_kustomize:hello_prod",
        "//overlay:hello_prod",
    ],
)

# The plugin's own default kubectl (///k8s//third_party/k8s:kubectl) can be
# run directly; this just demonstrates declaring your own, e.g. for a
# different visibility. `plz run //:kubectl -- version --client`.
kubectl_binary(
    name = "kubectl",
)

# Checks the rendered manifests: the overlay's replicas and namespace, the
# chart's release name, and kustomize's transforms applied to the chart.
gentest(
    name = "manifests_test",
    data = [":manifests"],
    no_test_output = True,
    test_cmd = " && ".join([
        "m=manifests",
        "grep -q 'replicas: 3' $m/overlay/hello_prod.yaml",
        "grep -q 'namespace: hello-prod' $m/overlay/hello_prod.yaml",
        "grep -q 'name: hello-example-hello' $m/chart/hello.yaml",
        "grep -q 'namespace: hello-prod' $m/chart_kustomize/hello_prod.yaml",
        "grep -q 'managed-by: please-k8s' $m/chart_kustomize/hello_prod.yaml",
    ]),
)
