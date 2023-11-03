This repository contains an example of Bazel custom rules that can be used create relocatable objects.

The `relocatable` rule recovers the `.pic.o` files of all its `cc_library` depencies and merges them all in a relocatable object by calling the linker of the current cc toolchain with the `-r` flag.

The `link_relocatable` rule can link against such relocatable objects to create a binary.

The [defs.bzl](defs.bzl) file contains the definitions of these rules, and they are used in the [BUILD](BUILD) file.