subinclude("//build_defs:terraform")

# A toolchain for every Terraform release in the plugin's checksum mirror
# (build_defs/versions.build_defs), each verified against it - what a
# terraform_module/terraform_root's `version` refers to. Only the ones
# actually used are ever downloaded.
[terraform_toolchain(
    name = f"terraform_{version}",
    version = version,
    visibility = ["PUBLIC"],
) for version in TERRAFORM_VERSIONS.keys()]
