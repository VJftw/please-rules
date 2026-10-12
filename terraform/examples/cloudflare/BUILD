subinclude("///terraform//build_defs:terraform")

terraform_root(
    name = "cloudflare",
    srcs = ["main.tf"],
    version = "1.6.0",
)

terraform_root_test(
    name = "cloudflare_plan_test",
    root = ":cloudflare",
    sandbox = True,
)
