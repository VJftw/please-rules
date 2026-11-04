# Loads the plugin from the local checkout that contains this example repo, as
# `new_local_repository` would, except that doesn't support `plugin = True`.
subrepo(
    name = "hugo",
    path = "..",
    plugin = True,
)

# The plantuml plugin, for the slides example - also from this checkout.
subrepo(
    name = "plantuml",
    path = "../../plantuml",
    plugin = True,
)
