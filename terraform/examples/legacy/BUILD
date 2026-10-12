subinclude("///terraform//build_defs:terraform")

terraform_root(
    name = "legacy",
    srcs = ["main.tf"],
    dep_sources = {"network": "../network"},
    version = "1.4.0",
    deps = {"network": "//network"},
)

terraform_root_test(
    name = "legacy_plan_test",
    root = ":legacy",
    sandbox = True,
)
