subinclude("///terraform//build_defs:terraform")

terraform_root(
    name = "opentofu",
    srcs = ["main.tf"],
    toolchain = "//third_party/terraform:tofu_1.7.0",
)

terraform_root_test(
    name = "opentofu_plan_test",
    root = ":opentofu",
    sandbox = True,
)
