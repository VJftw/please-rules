subinclude("///plantuml//build_defs:plantuml")

plantuml_diagram(
    name = "hello_svg",
    src = "hello.puml",
)

plantuml_diagram(
    name = "hello_png",
    src = "hello.puml",
    format = "png",
)

plantuml_diagram(
    name = "hello_pdf",
    src = "hello.puml",
    format = "pdf",
)

plantuml_diagram(
    name = "hello_txt",
    src = "hello.puml",
    format = "txt",
)

# theme depends on theme_colors, demonstrating that a plantuml_library's own
# deps compose transitively - themed_svg below only lists ":theme" and never
# has to know theme_colors.iuml exists.
plantuml_library(
    name = "theme_colors",
    srcs = ["theme_colors.iuml"],
)

plantuml_library(
    name = "theme",
    srcs = ["theme.iuml"],
    deps = [":theme_colors"],
)

plantuml_diagram(
    name = "themed_svg",
    src = "themed.puml",
    deps = [":theme"],
)

gentest(
    name = "hello_svg_test",
    data = [":hello_svg"],
    no_test_output = True,
    test_cmd = "grep -q '<svg' $DATA",
)

gentest(
    name = "hello_png_test",
    data = [":hello_png"],
    no_test_output = True,
    test_cmd = "head -c 8 $DATA | grep -q PNG",
)

gentest(
    name = "hello_pdf_test",
    data = [":hello_pdf"],
    no_test_output = True,
    test_cmd = "head -c 5 $DATA | grep -q '%PDF-'",
)

gentest(
    name = "hello_txt_test",
    data = [":hello_txt"],
    no_test_output = True,
    test_cmd = "grep -q 'Hello' $DATA",
)

# ACCENT_COLOR, from theme_colors.iuml, is only reachable via theme.iuml.
gentest(
    name = "themed_svg_test",
    data = [":themed_svg"],
    no_test_output = True,
    test_cmd = "grep -q '#F60' $DATA",
)

# ELK layout is one of the features the jar supports that PlantUML's native
# build doesn't.
plantuml_diagram(
    name = "elk_svg",
    src = "elk.puml",
)

gentest(
    name = "elk_svg_test",
    data = [":elk_svg"],
    no_test_output = True,
    test_cmd = "grep -q 'Foo' $DATA && ! grep -qi 'error\\|elk.*not' $DATA",
)
