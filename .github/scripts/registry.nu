# Manages registry/, this repo's index of released plugin versions.
#
# Every change to a plugin's released contents comes with a new version, and
# that version's registry entry, in the same pull request - so registry/ on
# main only ever changes through reviewed pull requests, and nothing ever has
# to push to main directly. The entry's hash is of the plugin's release
# archive, which is built reproducibly (see `build-archive`), so it can be
# computed before the archive is actually published: `release.yml` rebuilds
# the exact same archive after the pull request merges, checks it against the
# entry, and only then publishes it as a GitHub Release.
#
# Consumers download a release with Please's own `plugin_repo` (see the
# README), passing the entry's hash as its `hashes`.
#
# The new version follows from the pull request's title, which must be a
# Conventional Commit (https://www.conventionalcommits.org/) - with squash
# merges, it's the commit message that actually lands on main. It applies to
# every plugin the pull request changes:
#
#   feat(...)!: / fix!: / ...  breaking - a major bump (a minor one while the
#                              plugin's still 0.x, as 0.x makes no
#                              compatibility promises)
#   feat(...): ...             a minor bump
#   fix(...): ... (or any      a patch bump - the plugin's released contents
#   other type)                still changed
#
# Run from anywhere in the repository:
#
#   cd .github && plz run //scripts:registry -- <subcommand> ...
#
# (needs `git` and GNU `tar` on the PATH). The registry's layout:
# registry/plugins/<plugin>/metadata.json (versions list) and
# registry/plugins/<plugin>/<version>/source.json (the release archive's URL
# and sha256).

const REGISTRY_DIR = "registry/plugins"
const GITHUB_REPOSITORY = "VJftw/please-rules"

# Paths (regexes, relative to a plugin's own directory) whose changes don't
# need a new version: the examples/ repository (its own test suite, not
# something a consumer loads), documentation, and the VERSION file itself
# (`bump` sets it). They're still part of the release archive.
const EXEMPT_PATTERNS = ['^examples/' '\.md$' '^VERSION$']

# https://www.conventionalcommits.org/ - the types are @commitlint/config-conventional's.
const CONVENTIONAL_TYPES = [build chore ci docs feat fix perf refactor revert style test]
const CONVENTIONAL_RE = '^(?<type>[a-z]+)(?:\([^()]+\))?(?<breaking>!)?: \S'

def fail [msg: string] {
    error make {msg: $msg}
}

def --wrapped git [...args: string]: nothing -> string {
    let result = (^git ...$args | complete)
    if $result.exit_code != 0 {
        fail $"git ($args | str join ' ') failed: ($result.stderr | str trim)"
    }
    $result.stdout
}

# A file's content at `spec` (e.g. `<ref>:<path>`, or `:<path>` for the index), or null if it doesn't exist.
def git-show [spec: string]: nothing -> any {
    let result = (^git show $spec | complete)
    if $result.exit_code == 0 { $result.stdout } else { null }
}

def nul-split []: string -> list<string> {
    $in | split row (char nul) | where $it != ""
}

def sha256-hex [file: string]: nothing -> string {
    open --raw $file | hash sha256
}

# --- Plugins and versions ----------------------------------------------------

def version-key [version: string]: nothing -> list<int> {
    let parts = ($version | split row ".")
    if ($parts | length) != 3 or ($parts | any {|part| $part !~ '^\d+$'}) {
        fail $"version '($version)' isn't a plain MAJOR.MINOR.PATCH version"
    }
    $parts | into int
}

# A string that sorts the same as the version does.
def version-sort-key [version: string]: nothing -> string {
    version-key $version | each {|n| $n | into string | fill --alignment right --character "0" --width 12} | str join "."
}

# "major", "minor" or "patch", from a Conventional Commit `title`.
def bump-level [title: string]: nothing -> string {
    let match = ($title | parse --regex $CONVENTIONAL_RE)
    if ($match | is-empty) or ($match.0.type not-in $CONVENTIONAL_TYPES) {
        fail (
            $"'($title)' isn't a Conventional Commit - it should look like `<type>\(<optional scope>\): <description>`, "
            + $"with `!` before the `:` for a breaking change, where <type> is one of: ($CONVENTIONAL_TYPES | str join ', '). "
            + "See https://www.conventionalcommits.org/"
        )
    }
    if $match.0.breaking == "!" {
        "major"
    } else if $match.0.type == "feat" {
        "minor"
    } else {
        "patch"
    }
}

def bumped [version: any, level: any]: nothing -> string {
    let key = (version-key $version)
    let major = $key.0
    let minor = $key.1
    let patch = $key.2
    if $level == "major" and $major > 0 {
        $"($major + 1).0.0"
    } else if $level in [major minor] { # A breaking change while 0.x is a minor bump.
        $"($major).($minor + 1).0"
    } else {
        $"($major).($minor).($patch + 1)"
    }
}

# Every plugin in this repo: a top-level directory whose staged .plzconfig has
# a [PluginDefinition] (not dot-directories, e.g. .github's own tooling).
def plugin-dirs []: nothing -> list<string> {
    git ls-files -z -- "*/.plzconfig"
    | nul-split
    | each {|path| $path | split row "/"}
    | where {|parts| ($parts | length) == 2 and not ($parts.0 | str starts-with ".")}
    | each {|parts| $parts.0}
    | where {|plugin| (git-show $":($plugin)/.plzconfig" | default "") =~ '(?im)^\[PluginDefinition\]'}
    | uniq
    | sort
}

def version-path [plugin: string]: nothing -> string {
    [$plugin VERSION] | path join
}

# `plugin`'s version in git's index, or at `ref` - or null if it has no VERSION file there.
def plugin-version [plugin: string, ref: string = ""]: nothing -> any {
    let text = (git-show $"($ref):(version-path $plugin)")
    if $text == null { null } else { $text | str trim }
}

def staged-version [plugin: string]: nothing -> string {
    let version = (plugin-version $plugin)
    if $version == null {
        fail $"($plugin)/VERSION isn't staged in git - create it \(e.g. `0.1.0`\) and `git add` it first"
    }
    version-key $version | ignore
    $version
}

def is-exempt [relpath: string]: nothing -> bool {
    $EXEMPT_PATTERNS | any {|pattern| $relpath =~ $pattern}
}

# [{plugin, files}]: each plugin's staged files, other than EXEMPT_PATTERNS, that differ from `merge_base`.
def changed-plugins [merge_base: string]: nothing -> table<plugin: string, files: list<string>> {
    let changed = (git diff --cached --name-only -z $merge_base | nul-split)
    plugin-dirs | each {|plugin|
        let prefix = $"($plugin)/"
        let files = (
            $changed
            | where {|path| $path | str starts-with $prefix}
            | where {|path| not (is-exempt ($path | str substring ($prefix | str length)..))}
        )
        if ($files | is-not-empty) { {plugin: $plugin, files: $files} }
    } | compact
}

def resolve-merge-base [base: string]: nothing -> string {
    try {
        git merge-base $base HEAD | str trim
    } catch {
        fail $"can't find where this branch diverged from '($base)' - is it fetched?"
    }
}

# --- The release archive -----------------------------------------------------

# [{path, mode}]: every staged file in `plugin`, with its full path and git mode.
def staged-entries [plugin: string]: nothing -> table<path: string, mode: string> {
    git ls-files --stage -z -- $plugin | nul-split | each {|line|
        let entry = ($line | parse --regex '(?s)^(?<mode>\d+) (?<blob>[0-9a-f]+) (?<stage>\d)\t(?<path>.*)$' | first)
        if $entry.stage != "0" {
            fail $"($entry.path) has unresolved merge conflicts"
        }
        {path: $entry.path, mode: $entry.mode}
    }
}

def release-tag [plugin: string, version: string]: nothing -> string {
    $"($plugin)-v($version)"
}

def archive-name [plugin: string, version: string]: nothing -> string {
    $"(release-tag $plugin $version).tar"
}

def release-url [plugin: string, version: string]: nothing -> string {
    $"https://github.com/($GITHUB_REPOSITORY)/releases/download/(release-tag $plugin $version)/(archive-name $plugin $version)"
}

def source-json-path [plugin: string, version: string]: nothing -> string {
    [$REGISTRY_DIR $plugin $version source.json] | path join
}

# Builds `plugin`'s release archive from what's staged in git, and returns its
# sha256. With `out`, also writes the archive there; with `verify`, fails
# (before writing anything) unless it matches the registry entry for the
# plugin's current version.
#
# Reproducible - the same staged content always gives byte-for-byte the same
# archive, on any machine - so its hash can be put in the registry before
# it's published:
#
# - Staged content (not the working tree), so untracked/ignored files (e.g.
#   `plz-out`) can't leak in, and a pull request's CI and the release after it
#   see exactly the same files.
# - Sorted entries, with fixed ownership, timestamps and permissions (only
#   git's own executable bit carries over: files are checked out under a
#   fixed umask).
# - An uncompressed .tar, since compressors (e.g. zlib vs zlib-ng) can
#   produce different bytes for the same input.
#
# Its root is a single `<plugin>/` directory - Please's `plugin_repo` expects
# the plugin's .plzconfig one directory down.
def build-archive [plugin: string, --out: string, --verify]: nothing -> string {
    let entries = (staged-entries $plugin)
    if ($entries | is-empty) {
        fail $"no files from ($plugin)/ are staged in git - `git add` them first"
    }

    # Every path, with every directory above it too (including `<plugin>/`
    # itself) - sorted as the archive's entries (directories with a trailing
    # slash).
    let files = ($entries | get path)
    let dirs = (
        $files
        | each {|path|
            let parts = ($path | split row "/" | drop 1)
            $parts | enumerate | each {|part| $parts | first ($part.index + 1) | str join "/"}
        }
        | flatten
        | uniq
        | each {|dir| $"($dir)/"}
    )
    let names = ($dirs | append $files | sort)

    let tmp = (mktemp --directory)
    try {
        # Git applies its own umask-dependent modes when checking out, so pin it.
        $files | each {|path| $"($path)(char nul)"} | str join
        | ^sh -c 'umask 022; exec "$@"' sh git checkout-index -z --stdin $"--prefix=($tmp)/root/"

        let list = ($tmp | path join "names")
        $names | each {|name| $"($name)(char nul)"} | str join | save --raw $list
        let archive = ($tmp | path join "archive.tar")
        ^tar --create --format=ustar --no-recursion --numeric-owner --owner=0 --group=0 --mtime=@0 --directory ($tmp | path join root) --null --files-from $list --file $archive

        let sha256 = (sha256-hex $archive)
        if $verify {
            let source_json = (source-json-path $plugin (staged-version $plugin))
            let expected = (open $source_json | get sha256)
            if $sha256 != $expected {
                fail $"($plugin)'s archive has sha256 ($sha256), but ($source_json) says ($expected)"
            }
        }
        if $out != null {
            cp $archive $out
        }
        $sha256
    } finally {
        rm --recursive --force $tmp
    }
}

# --- Registry entries --------------------------------------------------------

# The version and source.json the registry should have for `plugin`'s staged state.
def expected-entry [plugin: string]: nothing -> record {
    let version = (staged-version $plugin)
    let source = {
        url: (release-url $plugin $version)
        sha256: (build-archive $plugin)
    }
    {version: $version, source: $source}
}

def metadata-path [plugin: string]: nothing -> string {
    [$REGISTRY_DIR $plugin metadata.json] | path join
}

# `plugin`'s versions in registry/ at `ref` ("" for the index).
def registry-versions [plugin: string, ref: string = ""]: nothing -> list<string> {
    let text = (git-show $"($ref):(metadata-path $plugin)")
    if $text == null or $text == "" { [] } else { $text | from json | get versions }
}

def load-metadata [plugin: string]: nothing -> record {
    let path = (metadata-path $plugin)
    if ($path | path exists) {
        return (open $path)
    }
    {
        homepage: $"https://github.com/($GITHUB_REPOSITORY)/tree/main/($plugin)"
        repository: $"https://github.com/($GITHUB_REPOSITORY)"
        versions: []
    }
}

def write-json [path: string, value: any]: nothing -> nothing {
    $"($value | to json --indent 2)\n" | save --force --raw $path
}

def write-metadata [plugin: string, metadata: record]: nothing -> nothing {
    write-json (metadata-path $plugin) ($metadata | update versions {|m| $m.versions | sort-by {|v| version-sort-key $v}})
}

# Writes and stages the registry entry for `plugin`'s staged state.
def add-entry [plugin: string]: nothing -> nothing {
    let entry = (expected-entry $plugin)
    let version_dir = ([$REGISTRY_DIR $plugin $entry.version] | path join)
    mkdir $version_dir
    write-json ($version_dir | path join source.json) $entry.source

    mut metadata = (load-metadata $plugin)
    if $entry.version not-in $metadata.versions {
        $metadata = ($metadata | update versions {|m| $m.versions | append $entry.version})
    }
    write-metadata $plugin $metadata

    git add -- $version_dir (metadata-path $plugin) | ignore
    print $"($plugin): wrote and staged ($version_dir)/ \(sha256 ($entry.source.sha256)\)"
}

# Removes (and stages removing) `plugin`'s registry entries that this branch added, other than `keep`.
def remove-unreleased [plugin: string, merge_base: string, keep: any]: nothing -> nothing {
    let released = (registry-versions $plugin $merge_base)
    let stale = (registry-versions $plugin | where {|v| $v not-in $released and $v != $keep})
    if ($stale | is-empty) {
        return
    }
    let metadata = (load-metadata $plugin | update versions {|m| $m.versions | where {|v| $v not-in $stale}})
    for version in $stale {
        let version_dir = ([$REGISTRY_DIR $plugin $version] | path join)
        rm --recursive --force $version_dir
        git rm -r --cached --quiet --ignore-unmatch -- $version_dir | ignore
        print $"($plugin): removed ($version_dir)/, which this branch added before"
    }
    if ($metadata.versions | is-not-empty) {
        write-metadata $plugin $metadata
        git add -- (metadata-path $plugin) | ignore
    } else {
        let plugin_dir = (metadata-path $plugin | path dirname)
        rm --recursive --force $plugin_dir
        git rm -r --cached --quiet --ignore-unmatch -- $plugin_dir | ignore
    }
}

# The open pull request's title (via `gh`), or else the branch's only commit's subject.
def default-title [merge_base: string]: nothing -> string {
    if (which gh | is-not-empty) {
        let result = (^gh pr view --json title --jq .title | complete)
        if $result.exit_code == 0 and ($result.stdout | str trim | is-not-empty) {
            return ($result.stdout | str trim)
        }
    }
    let subjects = (git log --format=%s $"($merge_base)..HEAD" | lines)
    if ($subjects | length) == 1 {
        return $subjects.0
    }
    fail (
        "can't tell what the pull request's title will be (there's no open pull request for this branch, and it "
        + $"has ($subjects | length) commits) - pass it with --title, e.g. --title 'feat\(opa\): add opa_fmt_test'"
    )
}

# Sets (and stages) `plugin`'s version in its VERSION file.
def set-version [plugin: string, version: string]: nothing -> nothing {
    $"($version)\n" | save --force --raw (version-path $plugin)
    git add -- (version-path $plugin) | ignore
}

def bump [base: any, title: any]: nothing -> nothing {
    let base = if $base == null {
        if (^git rev-parse --verify --quiet origin/main | complete).exit_code == 0 { "origin/main" } else { "main" }
    } else {
        $base
    }
    let merge_base = (resolve-merge-base $base)
    let title = if $title == null { default-title $merge_base } else { $title }
    let level = (bump-level $title)
    let changed = (changed-plugins $merge_base)
    print $"'($title)': a ($level) bump for every changed plugin"

    for plugin in (plugin-dirs) {
        let version = (staged-version $plugin)
        let base_version = (plugin-version $plugin $merge_base)
        let plugin_changed = ($changed | where plugin == $plugin)

        if ($plugin_changed | is-empty) {
            remove-unreleased $plugin $merge_base null
            if $base_version != null and $version != $base_version {
                set-version $plugin $base_version
                print $"($plugin): unchanged, so restored its version to ($base_version)"
            }
            continue
        }

        let unstaged = (git diff --name-only -- $plugin | lines)
        if ($unstaged | is-not-empty) {
            print $"($plugin): warning: ignoring unstaged changes \(`git add` them and re-run): ($unstaged | str join ', ')"
        }

        mut new_version = $version
        if $base_version == null {
            print $"($plugin): a new plugin, keeping its version ($version)"
        } else {
            $new_version = (bumped $base_version $level)
            set-version $plugin $new_version
            print $"($plugin): version ($base_version) -> ($new_version)"
        }

        remove-unreleased $plugin $merge_base $new_version
        add-entry $plugin
    }
}

def check [base: string, title: string]: nothing -> list<string> {
    let merge_base = (resolve-merge-base $base)
    let changed = (changed-plugins $merge_base)
    let fix = "run `plz run //scripts:registry -- bump` in .github (after staging your changes) and commit the result"

    mut errors = []
    mut level: any = null
    if ($changed | is-not-empty) {
        let result = (try { {level: (bump-level $title)} } catch {|e| {error: $e.msg}})
        if ($result | get -o error) != null {
            $errors = ($errors | append $"the pull request's title: ($result.error)")
        } else {
            $level = $result.level
        }
    }

    for plugin in (plugin-dirs) {
        let version = (staged-version $plugin)
        let released = (registry-versions $plugin $merge_base)
        let added = (registry-versions $plugin | where {|v| $v not-in $released})
        let base_version = (plugin-version $plugin $merge_base)
        let plugin_changed = ($changed | where plugin == $plugin)

        if ($plugin_changed | is-empty) {
            if $base_version != null and $base_version != $version {
                $errors = ($errors | append $"($plugin): its version changed, but nothing else about it did - ($fix)")
            }
            if ($added | is-not-empty) {
                $errors = ($errors | append $"($plugin): it hasn't changed, but registry/ has new versions of it \(($added | str join ', ')\) - ($fix)")
            }
            continue
        }

        let plugin_files = $plugin_changed.0.files
        let files = ($plugin_files | str join "\n  ")
        print $"($plugin): ($plugin_files | length) file\(s) changed, version ($base_version | default 'None') -> ($version)"

        if $version in $released {
            $errors = ($errors | append $"($plugin): version ($version) is already released - ($fix), since these files changed:\n  ($files)")
            continue
        }
        if $base_version != null and $level != null {
            let expected = (bumped $base_version $level)
            if $version != $expected {
                $errors = ($errors | append (
                    $"($plugin): should be version ($expected) - a ($level) bump from ($base_version), for the "
                    + $"pull request's title '($title)' - not ($version); ($fix)"
                ))
                continue
            }
        }
        if ($added | where {|v| $v != $version} | is-not-empty) {
            $errors = ($errors | append $"($plugin): registry/ has new versions of it other than ($version): ($added | str join ', ') - ($fix)")
        }

        let entry = (expected-entry $plugin)
        let actual_source = (git-show $":(source-json-path $plugin $version)")
        if $actual_source == null or $version not-in (registry-versions $plugin) {
            $errors = ($errors | append $"($plugin): there's no registry entry for version ($version) - ($fix)")
        } else if ($actual_source | from json | to json --raw) != ($entry.source | to json --raw) {
            $errors = ($errors | append (
                $"($plugin): the registry entry for version ($version) \((source-json-path $plugin $version)\) is out of date "
                + $"with ($plugin)/ \(e.g. it changed after the entry was written, or the base branch changed it too - "
                + $"merge it in first) - ($fix)"
            ))
        }
    }
    $errors
}

# --- Releasing ---------------------------------------------------------------

def releasable []: nothing -> list<string> {
    plugin-dirs | each {|plugin|
        let version = (open --raw (version-path $plugin) | str trim)
        if (source-json-path $plugin $version | path exists) {
            $"($plugin) (release-tag $plugin $version)"
        }
    } | compact
}

# --- Entry point -------------------------------------------------------------

# Paths here are all relative to the repository root - `plz run` keeps the
# directory it was run from, so move from there to the root of its repository.
def invocation-dir []: nothing -> string {
    $env.PWD
}

def --env enter-repo-root []: nothing -> nothing {
    cd (invocation-dir)
    cd (git rev-parse --show-toplevel | str trim)
}

# Runs `body`, which returns the errors it found (or nothing), and exits non-zero if there were any.
def run-guarded [body: closure]: nothing -> nothing {
    let errors = (try { do $body | default [] } catch {|e| [$e.msg]})
    for error in $errors {
        if "GITHUB_ACTIONS" in $env {
            # A GitHub annotation - newlines have to be URL-encoded in one.
            print $"::error::($error | str replace --all "\n" '%0A')"
        } else {
            print --stderr $"ERROR: ($error)"
        }
    }
    if ($errors | is-not-empty) {
        exit 1
    }
}

def main []: nothing -> nothing {
    help main
}

# Run in your pull request, after staging your changes: for every plugin whose
# released contents changed since BASE, sets its VERSION to the version TITLE
# implies, writes its registry entry, and stages both. Safe to re-run - e.g.
# after more changes, or a new title - and it replaces the registry entries it
# wrote before.
def "main bump" [
    --title: string # the pull request's (Conventional Commit) title; defaults to the open pull request's title (via `gh`), or else the branch's only commit's subject
    --base: string # git ref being merged into (default: origin/main, or else main)
]: nothing -> nothing {
    run-guarded {
        enter-repo-root
        bump $base $title
        []
    }
}

# What CI runs on every pull request: TITLE must be a Conventional Commit, and
# every plugin whose released contents changed since BASE must have the
# version it implies and an up-to-date registry entry for it.
def "main check" [
    --title: string # the pull request's (Conventional Commit) title
    --base: string # git ref being merged into, e.g. origin/main
]: nothing -> nothing {
    run-guarded {
        if $title == null or $base == null {
            fail "check needs both --title and --base"
        }
        enter-repo-root
        check $base $title
    }
}

# Writes and stages the registry entry for PLUGIN's current version, as-is
# (`bump` does this for you).
def "main add" [plugin: string]: nothing -> nothing {
    run-guarded {
        enter-repo-root
        add-entry $plugin
        []
    }
}

# Lists `<plugin> <tag>` for every plugin whose current version has a
# registry entry - used by release.yml, which releases the ones that aren't
# released yet.
def "main releasable" []: nothing -> nothing {
    run-guarded {
        enter-repo-root
        releasable | each {|line| print $line}
        []
    }
}

# Builds PLUGIN's release archive - used by release.yml.
def "main archive" [
    plugin: string
    --out: string # where to write the archive (relative to where you ran this)
    --verify # fail unless it matches the registry entry for PLUGIN's current version
]: nothing -> nothing {
    run-guarded {
        if $out == null {
            fail "archive needs --out"
        }
        cd (invocation-dir)
        let out = ($out | path expand)
        enter-repo-root
        let sha256 = (if $verify { build-archive $plugin --out $out --verify } else { build-archive $plugin --out $out })
        print $"Wrote ($out) \(sha256 ($sha256)\)"
        []
    }
}
