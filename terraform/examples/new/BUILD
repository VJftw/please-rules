subinclude("///terraform//build_defs:terraform")

terraform_root(
    name = "new",
    srcs = ["main.tf"],
    dep_sources = {"network": "../network"},
    version = "1.6.0",
    deps = {"network": "//network"},
)

terraform_root_test(
    name = "new_plan_test",
    root = ":new",
    sandbox = True,
)
