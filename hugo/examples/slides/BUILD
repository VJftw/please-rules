subinclude("///hugo//build_defs:hugo")

# reveal.js, from its npm package - its dist/ directory (the JS, CSS, themes
# and plugins), at static/reveal/ in this site, so it's served at /reveal/.
remote_file(
    name = "revealjs_package",
    url = "https://registry.npmjs.org/reveal.js/-/reveal.js-6.0.2.tgz",
    hashes = ["sha256: 2f0c20bfb02447a198a1ebe8a8c097a5437d035caa38f2820bf4ba887a3eac91"],
)

genrule(
    name = "revealjs",
    srcs = [":revealjs_package"],
    outs = ["static/reveal"],
    cmd = 'mkdir "$TMP_DIR/_extracted" && tar -xzf "$SRC" -C "$TMP_DIR/_extracted" package/dist && mv "$TMP_DIR/_extracted/package/dist" "$OUT"',
)

# `cd slides && plz run //slides:public_hugo -- server` for a local preview
# (after `plz build //slides:all`, for the diagrams and reveal.js).
hugo_site(
    name = "public",
    srcs = glob([
        "content/**",
        "layouts/**",
    ]) + [
        ":revealjs",
        "//slides/diagrams",
    ],
    config = "hugo.toml",
)

# Checks the deck has its three slides, with both diagrams and reveal.js.
gentest(
    name = "public_test",
    data = [":public"],
    no_test_output = True,
    test_cmd = " && ".join([
        "p=slides/public",
        "test -f $p/reveal/reveal.js",
        "test -f $p/reveal/theme/white.css",
        "test -f $p/diagrams/architecture.svg",
        "test -f $p/diagrams/build.svg",
        "test $(grep -o '<section>' $p/talks/intro/index.html | wc -l) -eq 3",
        "grep -q 'src=\"/diagrams/architecture.svg\"' $p/talks/intro/index.html",
        "grep -q 'src=\"/diagrams/build.svg\"' $p/talks/intro/index.html",
    ]),
)
