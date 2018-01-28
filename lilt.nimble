
# Package

# Thanks to https://github.com/nim-lang/nimble/blob/master/nimble.nimble#L4

import ospaths
template packageDir: string = instantiationInfo(fullPaths=true).filename.parentDir

when fileExists(packageDir / "src/version.txt"):
    # In the git repository the Nimble sources are in a ``src`` directory.
    version = slurp(packageDir / "src/version.txt")
else:
    # When the package is installed, the ``src`` directory disappears.
    version = slurp(packageDir / "version.txt")

# Verison set above
author        = "Eli Maynard"
description   = "Simple language for writing parsers"
license       = "MIT"

srcDir        = "src"

# Dependencies

requires "nim >= 0.17.2"
