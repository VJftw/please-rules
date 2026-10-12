subinclude("///terraform//build_defs:terraform")

terraform_root(
    name = "thirdparty",
    srcs = ["main.tf"],
    registry_modules = {
        "label": "//third_party/terraform:label",
    },
    version = "1.6.0",
)

terraform_root_test(
    name = "thirdparty_plan_test",
    root = ":thirdparty",
    sandbox = True,
)
