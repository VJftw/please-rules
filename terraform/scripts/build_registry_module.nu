# Builds a terraform_registry_module's output directory (a build action):
#
#   files/        the module's own content (already extracted)
#   nested/<call> each `nested` terraform_registry_module's own output, by the
#                 module call's name inside this module's source
#   module.json   {source, version, nested: [<call>...]}
#
# build_module.nu flattens this into `.terraform/modules/modules.json`
# entries for whichever module uses it.

def main [spec_path: string, out: string, files: string] {
    let spec = (open $spec_path | insert out $out | insert files $files)
    mkdir $spec.out
    # Dereferencing any symlinks Please staged the inputs as.
    ^cp -RL $spec.files ($spec.out | path join files)
    for call in ($spec.nested | columns) {
        mkdir ($spec.out | path join nested)
        ^cp -RL ($spec.nested | get $call) ($spec.out | path join nested $call)
    }
    {source: $spec.source, version: $spec.version, nested: ($spec.nested | columns)}
    | to json
    | save --force ($spec.out | path join module.json)
}
