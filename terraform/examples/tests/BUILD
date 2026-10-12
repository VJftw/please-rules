subinclude("///terraform//build_defs:terraform")

# `network` (see //network) has a hermetic `registry_modules` entry beneath
# it, so a `deps` entry referencing it needs `dep_sources` too.
terraform_module(
    name = "ok_dep_sources_fixture",
    srcs = ["fixture.tf"],
    dep_sources = {"network": "../network"},
    version = "1.4.0",
    deps = {"network": "//network"},
)

# Its manifest entries: the local `network` call (with its exact source), and
# the registry module nested beneath it, keyed through it.
gentest(
    name = "ok_dep_sources_test",
    data = [":ok_dep_sources_fixture"],
    no_test_output = True,
    test_cmd = " && ".join([
        "m=tests/ok_dep_sources_fixture/module.json",
        "grep -Eq '\"key\": *\"network\"' $m",
        "grep -Eq '\"source\": *\"../network\"' $m",
        "grep -Eq '\"key\": *\"network.label\"' $m",
    ]),
)

# Without `dep_sources`, building it fails - so this runs the plugin's own
# build script directly (as the same rule would), and checks it fails with an
# error that says so.
gentest(
    name = "missing_dep_sources_test",
    data = ["//network"],
    no_test_output = True,
    test_cmd = " && ".join([
        """printf '{"out":"%s/out","label":"//tests:missing_dep_sources_fixture","own_relpath":"tests","srcs":[],"deps":{"network":"network/network"},"dep_sources":{},"registry_modules":{},"providers":[],"validate":false}' "$TMP_DIR" > "$TMP_DIR/spec.json\"""",
        """! "$TOOLS_NU" --no-config-file "$TOOLS_SCRIPT" "$TMP_DIR/spec.json" unused > "$TMP_DIR/log" 2>&1""",
        "grep -q dep_sources \"$TMP_DIR/log\"",
    ]),
    test_tools = {
        "nu": ["///terraform//third_party/nushell:nu|nu"],
        "script": ["///terraform//scripts:build_module"],
    },
)

# Not a real provider (never executed) - just an executable to lay out.
genrule(
    name = "fake_provider_bin",
    srcs = ["fake_provider.sh"],
    outs = ["fake_provider_bin.sh"],
    binary = True,
    cmd = "cp $SRC $OUT",
)

terraform_local_provider(
    name = "fake_provider",
    binary = ":fake_provider_bin",
    hostname = "local",
    source = "myorg/myprovider",
    version = "0.1.0",
)

# The filesystem-mirror layout terraform init expects for local/myorg/myprovider.
gentest(
    name = "local_provider_layout_test",
    data = [":fake_provider"],
    no_test_output = True,
    test_cmd = "test -x tests/fake_provider/local/myorg/myprovider/0.1.0/$(uname -s | tr A-Z a-z)_*/terraform-provider-myprovider_v0.1.0",
)
