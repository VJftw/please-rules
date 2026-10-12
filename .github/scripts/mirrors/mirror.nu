# Shared helpers for the checksum mirror scripts in this directory - see
# their own header comments, and each plugin's README's Checksum mirror
# section.
#
# Each script maintains a plugin's generated `build_defs/*versions.build_defs`:
# a `<NAME> = {version: ...}` dict (in `plz format`'s own style, so it's
# never reformatted), which that plugin's tool-downloading rule reads the
# default hashes from.
#
# Incremental: versions already in the existing file are carried over as-is,
# never re-fetched or re-verified - only releases published since the last
# refresh are looked up (see `list-new-github-versions`), so a refresh (e.g.
# the nightly workflow's) is cheap when nothing new has shipped.

const USER_AGENT = "please-rules-mirror-script"

# Releases are only looked up until this many in a row are already mirrored -
# see `list-new-github-versions`.
const STOP_AFTER_MIRRORED = 20

# The root of the repository the script was run from.
export def repo-root []: nothing -> string {
    ^git rev-parse --show-toplevel | str trim
}

# HTTP headers for downloads.
export def headers []: nothing -> list<string> {
    [User-Agent $USER_AGENT]
}

# Authenticates to the GitHub API with $GITHUB_TOKEN when it's set (e.g. in
# the nightly workflow) - unauthenticated requests are limited to 60 an hour.
export def github-api-headers []: nothing -> list<string> {
    let token = ($env.GITHUB_TOKEN? | default "")
    if $token == "" {
        headers
    } else {
        headers | append [Authorization $"Bearer ($token)"]
    }
}

export def fetch [url: string]: nothing -> binary {
    http get --raw --headers (headers) $url | into binary
}

# The versions released (in `repo`'s GitHub releases) since `mirrored` were,
# newest first. `release_versions` turns a page of GitHub's release objects into
# the versions in it that this mirror covers.
#
# GitHub lists releases newest (created) first, so this walks that list until
# it's seen STOP_AFTER_MIRRORED releases in a row that are already mirrored -
# which still catches a release for an older line cut after newer ones (e.g. a
# backported patch), or one whose assets were only uploaded after the last
# refresh, but never pages back through old releases that never had anything
# to mirror.
export def list-new-github-versions [repo: string, mirrored: list<string>, release_versions: closure]: nothing -> list<string> {
    generate {|state|
        if $state.done { return {} }
        let releases = (http get --headers (github-api-headers) $"https://api.github.com/repos/($repo)/releases?per_page=100&page=($state.page)")
        if ($releases | is-empty) { return {} }
        mut run = $state.run
        mut new = []
        for version in (do $release_versions $releases) {
            if $version in $mirrored {
                $run += 1
                if $run >= $STOP_AFTER_MIRRORED { break }
            } else {
                $run = 0
                $new = ($new | append $version)
            }
        }
        {out: $new, next: {page: ($state.page + 1), run: $run, done: ($run >= $STOP_AFTER_MIRRORED)}}
    } {page: 1, run: 0, done: false}
    | flatten
}

# The versions already mirrored in `file`'s `<name> = {...}`, if it exists.
# (Nushell's `from json` accepts its trailing commas.)
export def load-existing [file: string, name: string]: nothing -> record {
    if not ($file | path exists) {
        return {}
    }
    let found = (open --raw $file | parse --regex ('(?s)' + $name + '\s*=\s*(?<dict>\{.*\})\s*$'))
    if ($found | is-empty) {
        error make {msg: $"Could not find ($name) = {...} in existing ($file)"}
    }
    $found.0.dict | from json
}

# `value` (a string, or a record of them, nested) as a Please dict literal, in
# `plz format`'s style: four-space indents and trailing commas.
def to-build-literal [indent: int]: any -> string {
    let value = $in
    if ($value | describe | str starts-with "record") {
        if ($value | is-empty) {
            return "{}"
        }
        let pad = ("" | fill --character " " --width (($indent + 1) * 4))
        let entries = ($value | items {|key, v|
            $"($pad)($key | to json): ($v | to-build-literal ($indent + 1)),"
        })
        let close = ("" | fill --character " " --width ($indent * 4))
        $"{\n($entries | str join "\n")\n($close)}"
    } else {
        $value | to json
    }
}

# Writes `entries` to `file` as `<name> = {...}`, after `header` - each of its
# lines a comment.
export def write-mirror [file: string, name: string, header: list<string>, entries: record]: nothing -> nothing {
    let comments = ($header | each {|line| if $line == "" { "#" } else { $"# ($line)" }} | str join "\n")
    $"($comments)\n\n($name) = ($entries | to-build-literal 0)\n" | save --force --raw $file
    print --stderr $"Wrote ($file)"
}
