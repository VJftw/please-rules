subinclude("///opa//build_defs:opa")

opa_build(
    name = "bundle",
    srcs = [
        "authz.rego",
        "authz_test.rego",
    ],
)

# A build-time policy gate: building this fails unless input.json is allowed.
# `data.authz.allow` alone is always defined (it defaults to false), as is
# `data.authz.allow == true` (a comparison's result is a value, even false) -
# but unifying it with true has no result unless it's true, so this query's
# only defined, and so only passes `fail_undefined`, when the input's allowed.
opa_eval(
    name = "allow_get",
    srcs = ["authz.rego"],
    fail_undefined = True,
    input = "input.json",
    query = "data.authz.allow = true",
)

opa_test(
    name = "authz_test",
    srcs = [
        "authz.rego",
        "authz_test.rego",
    ],
)

opa_test(
    name = "authz_sandboxed_test",
    srcs = [
        "authz.rego",
        "authz_test.rego",
    ],
    sandbox = True,
)

# Checks the bundle has the policy in it, and the gate's result.
gentest(
    name = "outputs_test",
    data = [
        ":allow_get",
        ":bundle",
    ],
    no_test_output = True,
    test_cmd = "tar tzf policy/bundle.tar.gz | grep -q authz.rego && grep -q true policy/allow_get.json",
)
