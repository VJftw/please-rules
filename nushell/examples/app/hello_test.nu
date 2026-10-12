use std/assert

# `use`d relative to this file, rather than to the root of this repository.
use ../lib/greeting.nu
use lib/shout.nu
use runfiles.nu

def main [expected_name: string] {
    assert equal (greeting greet "Please") "Hello, Please!"
    assert equal (shout greet "Please") "HELLO, PLEASE!"

    # `data` files are available relative to the test's working directory...
    assert equal (open app/name.txt | str trim) $expected_name
    # ...or wherever they are, via runfiles.nu - including another rule's
    # output (written at build time by a nu_genrule).
    assert equal (open (runfiles rlocation app/name.txt) | str trim) $expected_name
    assert equal (open (runfiles rlocation app/greeting.txt)) "HELLO, BUILD!"

    # The plugin's pinned Nushell version, not whatever `nu` might be on PATH.
    assert equal (version | get version) "0.116.0"
}
