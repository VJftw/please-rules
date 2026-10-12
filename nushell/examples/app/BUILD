subinclude("///nushell//build_defs:nushell")

# `plz run //app:hello -- VJ`
nu_binary(
    name = "hello",
    src = "hello.nu",
    deps = ["//lib:shout"],
)

# Runs app/greeting.nu at build time, to write app/greeting.txt.
nu_genrule(
    name = "greeting",
    src = "greeting.nu",
    outs = ["greeting.txt"],
    args = ["BUILD", "$OUTS"],
    deps = ["//lib:shout"],
)

nu_test(
    name = "hello_test",
    src = "hello_test.nu",
    args = ["VJ"],
    data = [
        "name.txt",
        ":greeting",
    ],
    deps = [
        "//lib:greeting",
        "//lib:shout",
    ],
)

# The same test, sandboxed - where only its runtime files are available.
nu_test(
    name = "hello_sandboxed_test",
    src = "hello_test.nu",
    args = ["VJ"],
    data = [
        "name.txt",
        ":greeting",
    ],
    sandbox = True,
    deps = [
        "//lib:greeting",
        "//lib:shout",
    ],
)
