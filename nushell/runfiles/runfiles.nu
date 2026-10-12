# Finds a nu_binary's/nu_test's runtime files - e.g. its `data` - wherever
# Please has put them. Every nu_binary/nu_test's launcher puts this module on
# the include path, so a script can:
#
#     use runfiles.nu
#     open (runfiles rlocation app/name.txt)
#
# A path is relative to the repository root, whether the file is a source
# file or another rule's output - the same path Please stages it at for a
# test (or `plz run --in_tmp_dir`), which is where it's looked for first.
# For a plain `plz run`, nothing is staged, so it's looked for in the
# repository itself and then its plz-out directories instead. The launcher
# passes those roots in $PLZ_NU_RUNFILES_ROOTS.

# Resolves `path`, relative to the repository root (e.g. `app/name.txt`), to
# where the file actually is.
export def rlocation [path: string] {
    let roots = ($env.PLZ_NU_RUNFILES_ROOTS? | default "" | split row (char record_sep) | where $it != "")
    for root in $roots {
        let candidate = ($root | path join $path)
        if ($candidate | path exists) {
            return $candidate
        }
    }
    error make {msg: $"($path) not found in any of: ($roots | str join ', ')"}
}
