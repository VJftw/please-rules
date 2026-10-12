# Regenerates k8s/build_defs/kubectl_versions.build_defs: a mirror of kubectl
# 1.x release checksums, used by kubectl_tool as the default hashes for a
# version it isn't given `hashes` for.
#
# kubectl signs its release binaries via sigstore/cosign keyless signing (a
# `.sig`/`.cert` pair alongside each binary), verified here (see
# `verify-and-hash`) - which is over the *binary itself*, so verifying a
# release means downloading it. Being incremental (see mirror.nu) keeps that
# to just the releases published since the last refresh. A release without a
# signature (older releases) falls back to the plain-HTTPS `<binary>.sha256`.
#
# Needs a real `cosign` binary on PATH - see
# https://docs.sigstore.dev/system_config/installation/.
#
#   cd .github && plz run //scripts/mirrors:kubectl

use scripts/mirrors/mirror.nu

const DL_K8S_IO = "https://dl.k8s.io"
const MAJOR = "1"

# The identity Kubernetes' own release automation signs with - found by
# decoding a real release's kubectl.cert and reading its Subject Alternative
# Name / OIDC issuer extension. If Kubernetes rotates it, verification fails
# (safely - a failure is skipped, never silently trusted) for every new
# release until this is updated.
const KREL_IDENTITY = "krel-staging@k8s-releng-prod.iam.gserviceaccount.com"
const KREL_ISSUER = "https://accounts.google.com"

const PLATFORMS = {
    darwin_amd64: [darwin amd64]
    darwin_arm64: [darwin arm64]
    linux_amd64: [linux amd64]
    linux_arm64: [linux arm64]
    windows_amd64: [windows amd64]
}

def kubectl-url [version: string, platform: string, suffix: string = ""]: nothing -> string {
    let os_arch = ($PLATFORMS | get $platform)
    let ext = if $os_arch.0 == "windows" { ".exe" } else { "" }
    $"($DL_K8S_IO)/release/v($version)/bin/($os_arch.0)/($os_arch.1)/kubectl($ext)($suffix)"
}

# Plain-HTTPS fallback for a version/platform with no signature to verify.
def fetch-sha256 [version: string, platform: string]: nothing -> any {
    try {
        mirror fetch (kubectl-url $version $platform ".sha256") | decode utf-8 | split words | first
    } catch {
        print --stderr $"> No sha256 for kubectl ($version) ($platform), skipping"
        null
    }
}

# Downloads, cosign-verifies, and hashes `version`/`platform`'s binary.
# Returns the verified sha256, {unsigned: true} if there's no signature (the
# caller falls back to `fetch-sha256`), or null if it's unverifiable (skipped
# entirely - never falls back to an unverified hash for something that
# claimed to be signed but didn't check out).
def verify-and-hash [version: string, platform: string]: nothing -> any {
    let sig = (try { mirror fetch (kubectl-url $version $platform ".sig") } catch { null })
    if $sig == null {
        return {unsigned: true}
    }
    let cert = (mirror fetch (kubectl-url $version $platform ".cert"))

    print --stderr $"> Downloading kubectl ($version) ($platform) to verify..."
    let binary = (mirror fetch (kubectl-url $version $platform))

    let dir = (mktemp --directory)
    let bin_path = ($dir | path join kubectl)
    let sig_path = ($dir | path join kubectl.sig)
    let cert_path = ($dir | path join kubectl.cert)
    $binary | save --raw $bin_path
    $sig | save --raw $sig_path
    $cert | save --raw $cert_path
    let result = (
        ^cosign verify-blob
            --signature $sig_path
            --certificate $cert_path
            --certificate-identity $KREL_IDENTITY
            --certificate-oidc-issuer $KREL_ISSUER
            $bin_path
        | complete
    )
    rm --recursive --force $dir

    if $result.exit_code != 0 {
        let reason = ($result.stderr | str trim | lines | last 1 | str join)
        print --stderr $"> Could not verify signature for kubectl ($version) ($platform), skipping: ($reason)"
        return null
    }
    $binary | hash sha256
}

def main [] {
    let file = ([(mirror repo-root) k8s build_defs kubectl_versions.build_defs] | path join)
    let existing = (mirror load-existing $file KUBECTL_VERSIONS)
    print --stderr $"($existing | columns | length) versions already mirrored"

    let versions = (mirror list-new-github-versions kubernetes/kubernetes ($existing | columns) {|releases|
        $releases
        | where {|r| not $r.prerelease }
        | get tag_name
        | parse --regex ('^v(?<version>' + $MAJOR + '\.[0-9]+\.[0-9]+)$')
        | get version
    })
    print --stderr $"Found ($versions | length) kubectl ($MAJOR).x release\(s\) not mirrored yet"

    let new_entries = ($versions | reduce --fold {} {|version, acc|
        print --stderr $"Processing kubectl ($version)..."
        let platform_shas = ($PLATFORMS | columns | reduce --fold {} {|platform, shas|
            let verified = (verify-and-hash $version $platform)
            let sha256 = if ($verified | describe | str starts-with "record") {
                fetch-sha256 $version $platform
            } else {
                $verified
            }
            if $sha256 == null { $shas } else { $shas | insert $platform $sha256 }
        })
        if ($platform_shas | is-empty) { $acc } else { $acc | insert $version $platform_shas }
    })

    mirror write-mirror $file KUBECTL_VERSIONS [
        "GENERATED by `cd .github && plz run //scripts/mirrors:kubectl` - see"
        ".github/scripts/mirrors/kubectl.nu."
        ""
        $"kubectl ($MAJOR).x release checksums - cosign-verified against Kubernetes' own"
        "release identity for signed releases, plain-HTTPS-fetched for unsigned ones:"
        "kubectl_tool's default hashes for a version it isn't given `hashes` for."
    ] ($new_entries | merge $existing)
}
