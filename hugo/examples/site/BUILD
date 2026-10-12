subinclude("///hugo//build_defs:hugo")

# `cd site && plz run //site:public_hugo -- server` for a local preview.
hugo_site(
    name = "public",
    srcs = glob([
        "content/**",
        "layouts/**",
    ]),
    config = "hugo.toml",
    minify = True,
)

# Checks the rendered site has its home page and the post.
gentest(
    name = "public_test",
    data = [":public"],
    no_test_output = True,
    test_cmd = "test -f site/public/index.html && grep -rq 'Hello' site/public/posts/",
)
