# A terraform_root's `plz run`/terraform_root_test entry point, run by its
# launcher (see terraform.build_defs) with the plugin's nu:
#
#   runner.nu <root> <staged|repo> <config> <args...>
#
# `config` (written at build time) says where each of the root's runtime
# files are, both as staged (next to a test, or for `plz run --in_tmp_dir`,
# relative to <root>) and in the repository (for a plain `plz run`, relative
# to the repository root, <root>) - <staged|repo> says which.
#
# Copies the root's module tree into a writable scratch directory, sets up the
# offline provider mirror and `.terraform/modules/modules.json` there, then
# hands off - with the environment below - to the plugin's `DefaultScript` if
# one's set, or else runs `terraform` itself (`init`ing first for any
# subcommand that needs it).
#
# The script gets: TF_BIN (the terraform - or tofu, ... - binary), TF_MODULE_DIR
# (the writable module directory, which is also its working directory),
# TF_LABEL/TF_ROOT_NAME/TF_ROOT_PACKAGE (the root's label, name and package),
# TF_VERSION (its pinned version), the root's own `env`/`env_labels`, and a
# PATH starting with a directory where the binary's own name (`terraform`,
# `tofu`, ...) runs it.

# (The same as build_module.nu's - this is only ever staged on its own.)
# One `filesystem_mirror` block per provider (each its own mirror root), and
# `direct` excluded unconditionally - a provider that isn't in a mirror should
# fail loudly, not silently reach out to the network.
def provider-cli-config [mirror_roots: list<string>]: nothing -> string {
    let blocks = ($mirror_roots | each {|root|
        $"\n  filesystem_mirror {\n    path    = \"($root)\"\n    include = [\"*/*/*\"]\n  }"
    } | str join "\n")
    $"\ndisable_checkpoint = true\n\nprovider_installation {\n($blocks)\n  direct {\n    exclude = [\"*/*/*\"]\n  }\n}\n"
}

# `.terraform/modules/modules.json`, for `entries` (see module.json above)
# beneath a tree at `tree`.
def manifest [entries: list, tree: string]: nothing -> record {
    let modules = ($entries | each {|e|
        let entry = {Key: $e.key, Source: $e.source}
        let entry = if ($e.version | is-not-empty) { $entry | insert Version $e.version } else { $entry }
        $entry | insert Dir ($tree | path join $e.dir)
    })
    {Modules: ([{Key: "", Source: "", Dir: "."}] | append $modules)}
}


const AUTO_INIT_COMMANDS = [plan apply destroy validate refresh import console output]

def is-windows []: nothing -> bool {
    $nu.os-info.name == "windows"
}

# Where a runtime file (a {rt, repo} pair from the config) is.
def locate [root: string, mode: string, paths: record]: nothing -> string {
    let path = if $mode == "staged" { $paths.rt } else { $paths.repo }
    # Please can give a built file's path as an absolute one - relative to
    # the repository root instead, so it still resolves wherever it's staged.
    let path = if ($path | str starts-with "/") and ($path | str contains "/plz-out/") {
        $"plz-out/($path | split row '/plz-out/' | skip 1 | str join '/plz-out/')"
    } else {
        $path
    }
    if ($path | str starts-with "/") { $path } else { $root | path join $path }
}

# A `bin/` directory in `scratch` where `tf_bin`'s own name runs it.
def make-bin-dir [scratch: string, tf_bin: string]: nothing -> string {
    let bin_dir = ($scratch | path join bin)
    mkdir $bin_dir
    let bin_name = ($tf_bin | path parse | get stem)
    ^ln -sf $tf_bin ($bin_dir | path join $bin_name)
    $bin_dir
}

def --wrapped main [root: string, mode: string, config_path: string, ...args] {
    let config = (open $config_path)
    let tf_bin = (locate $root $mode $config.terraform)
    let module = (open ((locate $root $mode $config.module) | path join module.json))
    let tree = ((locate $root $mode $config.module) | path join tree)

    # A writable copy of the module tree, never the source tree or the
    # (read-only) build output - rebuilt from scratch on every run, so `init`
    # is re-run automatically before any subcommand that needs it.
    let label_key = ($config.label | str replace --all --regex '[^A-Za-z0-9_.-]' "_")
    let scratch_root = if $mode == "staged" { $root } else { $root | path join plz-out }
    let scratch = ($scratch_root | path join terraform $label_key)
    rm --recursive --force $scratch
    mkdir ($scratch | path join tree)
    ^cp -RL $"($tree)/." ($scratch | path join tree)
    ^chmod -R u+w $scratch
    let module_dir = ($scratch | path join tree $module.own_relpath)

    # The root's own env/env_labels - fixed config for it, so they win over
    # the invoking shell's own environment.
    load-env $config.env
    load-env ($config.env_labels | items {|var, paths| {var: $var, path: (locate $root $mode $paths)} } | reduce --fold {} {|it, acc| $acc | insert $it.var $it.path })

    if ($config.providers | is-not-empty) {
        let cli_config = ($scratch | path join .terraformrc)
        provider-cli-config ($config.providers | each {|paths| locate $root $mode $paths }) | save --force $cli_config
        $env.TF_CLI_CONFIG_FILE = $cli_config
    }

    if ($module.entries | is-not-empty) {
        let modules_dir = ($module_dir | path join .terraform modules)
        mkdir $modules_dir
        manifest $module.entries ($scratch | path join tree) | to json | save --force ($modules_dir | path join modules.json)
    }

    # Terraform talks to provider plugins over Unix sockets in TMPDIR, whose
    # paths can't be longer than ~100 characters - which Please's own (deep)
    # test/run directories are likely to exceed. One per root (and checkout),
    # cleared on every run like the scratch directory - this hands off with
    # `exec`, so it can't clean up after itself.
    let plugin_tmp = ($"/tmp/plz-terraform-(($scratch | hash md5) | str substring 0..11)")
    rm --recursive --force $plugin_tmp
    mkdir $plugin_tmp
    $env.TMPDIR = $plugin_tmp
    $env.TF_BIN = $tf_bin
    $env.TF_MODULE_DIR = $module_dir
    $env.TF_LABEL = $config.label
    $env.TF_ROOT_NAME = $config.name
    $env.TF_ROOT_PACKAGE = $config.package
    $env.TF_VERSION = $config.version
    $env.PATH = ($env.PATH | split row (char esep) | prepend (make-bin-dir $scratch $tf_bin))
    cd $module_dir

    if $config.script != null {
        # The plugin's DefaultScript, which owns the whole command.
        exec (locate $root $mode $config.script) ...$args
    }

    if ($args | is-not-empty) and ($args.0 in $AUTO_INIT_COMMANDS) {
        ^$tf_bin init -input=false -no-color
    }
    exec $tf_bin ...$args
}
