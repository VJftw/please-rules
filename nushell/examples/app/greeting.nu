# Writes a greeting to a file, at build time - see nu_genrule in app/BUILD.
use lib/shout.nu

def main [name: string, out: string] {
    shout greet $name | save --force $out
}
