subinclude("///terraform//build_defs:terraform")

terraform_provider(
    name = "random",
    hashes = {
        "linux_amd64": "aa57384b85622a9f7bfb5d4512ca88e61f22a9cea9f30febaa4c98c68ff0dc21",
        "linux_arm64": "24a17bba7f6d679538ff51b3a2f378cedadede97af8a1db7dad4fd8d6d50f829",
        "darwin_amd64": "e2699bc9116447f96c53d55f2a00570f982e6f9935038c3810603572693712d0",
        "darwin_arm64": "e747c0fd5d7684e5bfad8aa0ca441903f15ae7a98a737ff6aca24ba223207e2c",
    },
    source = "hashicorp/random",
    version = "3.6.0",
    visibility = ["PUBLIC"],
)

# A genuine third-party (non-HashiCorp) provider - fetched from its own
# GitHub release via url_template, instead of releases.hashicorp.com.
terraform_provider(
    name = "cloudflare",
    hashes = {
        "linux_amd64": "2390fc5df95addfd47d3f638964a1f9f6192a8c84ad3b1eab554ef88e0ac4091",
        "linux_arm64": "3513243e5582836054076a21abeadd8142a8421df6ec1ead53d96dc37a9e6326",
        "darwin_amd64": "99c7b510b100a605b0c80e0c3665d99c2381b0834f52ad6ca767e161c2ffa416",
        "darwin_arm64": "c523d747a2d8457bc2d2cc00967c419ef38a5ebebd12d5091cf18322b7201f04",
    },
    source = "cloudflare/cloudflare",
    url_template = "https://github.com/cloudflare/terraform-provider-cloudflare/releases/download/v{version}/terraform-provider-cloudflare_{version}_{platform}.zip",
    version = "5.24.0",
    visibility = ["PUBLIC"],
)

terraform_registry_module(
    name = "label",
    hashes = ["sha256: b08e1493864c6edc74ee7901445d501c43d88bcd5d3882303eb3809206502777"],
    source = "registry.terraform.io/cloudposse/label/null",
    strip_prefix = "terraform-null-label-488ab91e34a24a86957e397d9f7262ec5925586a",
    url = "https://github.com/cloudposse/terraform-null-label/archive/488ab91e34a24a86957e397d9f7262ec5925586a.tar.gz",
    version = "0.25.0",
    visibility = ["PUBLIC"],
)

# OpenTofu (a Terraform fork), via url_template/bin_name instead of
# HashiCorp's own release - hashes are required here, since the plugin's
# checksum mirror is HashiCorp-specific.
terraform_toolchain(
    name = "tofu_1.7.0",
    bin_name = "tofu",
    hashes = {
        "linux_amd64": "a4d755f86968cc0278c636c044972c43c28825d7d1af167bddd0470b2318c2c2",
        "linux_arm64": "86a6db50a990b35bd53a7d18c7336c80c768998d1ebd6c3c8387bb030cffcbc7",
        "darwin_amd64": "10a7f25b6f89add71c52952126a52355b2235e1cb1d00924be6d925d8658f142",
        "darwin_arm64": "e73bb705e4b33850e99da357914995fcaa6ad5abb6c51064eea08478cc211c3f",
    },
    url_template = "https://github.com/opentofu/opentofu/releases/download/v{version}/tofu_{version}_{platform}.zip",
    version = "1.7.0",
    visibility = ["PUBLIC"],
)
