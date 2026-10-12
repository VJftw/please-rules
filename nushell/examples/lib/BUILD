subinclude("///nushell//build_defs:nushell")

nu_library(
    name = "greeting",
    srcs = ["greeting.nu"],
    visibility = ["PUBLIC"],
)

# shout depends on greeting, demonstrating a nu_library's own deps composing
# transitively - //app:hello only lists ":shout" and never has to know
# greeting.nu exists.
nu_library(
    name = "shout",
    srcs = ["shout.nu"],
    visibility = ["PUBLIC"],
    deps = [":greeting"],
)
