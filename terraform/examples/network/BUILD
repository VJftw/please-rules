subinclude("///terraform//build_defs:terraform")

terraform_module(
    name = "network",
    srcs = ["main.tf"],
    registry_modules = {
        "label": "//third_party/terraform:label",
    },
    version = "1.4.0",
    visibility = ["PUBLIC"],
)

# `network` isn't runnable on its own (it's a plain terraform_module), so
# there's no `plan` to run - this just asserts it builds (validates).
gentest(
    name = "network_build_test",
    data = [":network"],
    no_test_output = True,
    test_cmd = "test -f network/network/module.json",
)
