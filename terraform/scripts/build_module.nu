# Builds a terraform_module's (or terraform_root's) module (a build action),
# from the spec terraform.build_defs writes: stages its tree, works out the
# `.terraform/modules/modules.json` entries Terraform needs for it, and runs
# `terraform init && terraform validate` against it. Its output directory:
#
#   tree/        this module's own files, plus every dep's (at their paths
#                relative to the repository root, so local `source = "../foo"`
#                references resolve), plus each registry module (and any it
#                nests) under `<this module's directory>/_registry_modules/<key>/`
#   module.json  {own_relpath, entries: [{key, kind, source, version, dir}]} -
#                every manifest entry needed beneath this module ("dir" is
#                relative to tree/), for whatever uses it as a dep
#
# A `deps` entry only needs manifest entries of its own if something hermetic
# (a registry module, at any depth) is reachable through it - Terraform finds
# a plain local module itself. But when one does, Terraform must be told its
# EXACT `source = "..."` string (`dep_sources`): an exactly-matching entry
# lets the registry entries nested beneath it survive `init` untouched, while
# a missing or mismatched one makes Terraform re-discover that local module
# itself, silently wiping out everything pre-populated beneath it.

# One `filesystem_mirror` block per provider (each its own mirror root), and
# `direct` excluded unconditionally - a provider that isn't in a mirror should
# fail loudly, not silently reach out to the network.
export def provider-cli-config [mirror_roots: list<string>]: nothing -> string {
    let blocks = ($mirror_roots | each {|root|
        $"\n  filesystem_mirror {\n    path    = \"($root)\"\n    include = [\"*/*/*\"]\n  }"
    } | str join "\n")
    $"\ndisable_checkpoint = true\n\nprovider_installation {\n($blocks)\n  direct {\n    exclude = [\"*/*/*\"]\n  }\n}\n"
}

# `.terraform/modules/modules.json`, for `entries` (see module.json above)
# beneath a tree at `tree`.
export def manifest [entries: list, tree: string]: nothing -> record {
    let modules = ($entries | each {|e|
        let entry = {Key: $e.key, Source: $e.source}
        let entry = if ($e.version | is-not-empty) { $entry | insert Version $e.version } else { $entry }
        $entry | insert Dir ($tree | path join $e.dir)
    })
    {Modules: ([{Key: "", Source: "", Dir: "."}] | append $modules)}
}

# A registry module's entries - its own, plus any it nests, recursively -
# keyed under `key`, at `dir` (relative to tree/) and below.
def registry-entries [module_dir: string, key: string, dir: string]: nothing -> list {
    let meta = (open ($module_dir | path join module.json))
    let own = [{key: $key, kind: registry, source: $meta.source, version: $meta.version, dir: $dir, files: ($module_dir | path join files)}]
    $own | append ($meta.nested | each {|call|
        registry-entries ($module_dir | path join nested $call) $"($key).($call)" $"($dir).($call)"
    } | flatten)
}

def main [spec_path: string, out: string, terraform: string] {
    let spec = (open $spec_path | insert out $out)
    let tree = ($spec.out | path join tree)
    mkdir $tree

    # This module's own files, and every dep's tree (dereferencing any
    # symlinks Please staged the inputs as).
    for src in ($spec.srcs | each {|s| $s | split row " "} | flatten | where $it != "") {
        mkdir ($tree | path join ($src | path dirname))
        ^cp -L $src ($tree | path join $src)
    }
    for key in ($spec.deps | columns | sort) {
        ^cp -RL $"($spec.deps | get $key)/tree/." $tree
    }

    # Registry modules, staged under this module's own directory.
    mut entries = []
    for key in ($spec.registry_modules | columns | sort) {
        for e in (registry-entries ($spec.registry_modules | get $key) $key ([$spec.own_relpath _registry_modules $key] | path join)) {
            mkdir ($tree | path join $e.dir)
            ^cp -RL $"($e.files)/." ($tree | path join $e.dir)
            $entries = ($entries | append ($e | reject files))
        }
    }

    # Deps with registry modules beneath them.
    for key in ($spec.deps | columns | sort) {
        let dep = (open ([($spec.deps | get $key) module.json] | path join))
        if ($dep.entries | is-empty) {
            continue
        }
        if $key not-in $spec.dep_sources {
            error make {msg: (
                $"($spec.label): dep \"($key)\" has hermetic registry_modules nested beneath it, so its exact "
                + $"`source = \"...\"` string \(as written in this module's own .tf `module \"($key)\" { ... }` "
                + $"block\) must be given via `dep_sources = {\"($key)\": \"...\"}`."
            )}
        }
        $entries = ($entries | append {key: $key, kind: local, source: ($spec.dep_sources | get $key), version: "", dir: $dep.own_relpath})
        $entries = ($entries | append ($dep.entries | each {|e| $e | update key $"($key).($e.key)"}))
    }

    {own_relpath: $spec.own_relpath, entries: $entries} | to json | save --force ($spec.out | path join module.json)

    if not $spec.validate {
        return
    }

    # Validate a writable copy - `init` writes into the module directory
    # (e.g. .terraform.lock.hcl), and the output tree should stay exactly what
    # was staged. TF_DATA_DIR is scratch space too. It's under /tmp because
    # Terraform talks to provider plugins over Unix sockets in TMPDIR, whose
    # paths can't be longer than ~100 characters - which Please's own (deep)
    # build directory is likely to exceed.
    let scratch = (mktemp --directory --tmpdir-path /tmp plz-terraform.XXXXXX)
    try {
        let copy = ($scratch | path join tree)
        ^cp -R $tree $copy
        ^chmod -R u+w $copy
        let data_dir = ($scratch | path join data)
        mkdir ($data_dir | path join modules)
        manifest $entries $copy | to json | save --force ($data_dir | path join modules modules.json)

        let plugin_tmp = ($scratch | path join tmp)
        mkdir $plugin_tmp
        mut env_vars = {TF_DATA_DIR: $data_dir, TMPDIR: $plugin_tmp}
        if ($spec.providers | is-not-empty) {
            let cli_config = ($scratch | path join .terraformrc)
            provider-cli-config ($spec.providers | each {|p| $p | path expand}) | save --force $cli_config
            $env_vars = ($env_vars | insert TF_CLI_CONFIG_FILE $cli_config)
        }

        let terraform = ($terraform | path expand)
        let chdir = $"-chdir=($copy | path join $spec.own_relpath)"
        with-env $env_vars {
            ^$terraform $chdir init -input=false -backend=false -no-color
            ^$terraform $chdir validate -no-color
        }
    } finally {
        rm --recursive --force $scratch
    }
}
