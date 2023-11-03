load("defs.bzl", "relocatable", "link_relocatables")

cc_library(
    name = "lib",
    srcs = ["lib.c"],
    hdrs = ["lib.h"],
)

# We use the custom rule to create a relocatable object based of the object files from lib
relocatable(
    name = "lib_relocatable.so",
    deps = ["lib"],
)


# We build the main binary with a custom rule that uses this relocatable object.
link_relocatables(
    name = "main",
    srcs = ["main.c", "lib.h"],
    relocatable_deps = ["lib_relocatable.so"],
    linkopts = [],
)

# Since the relocatable lib ends in .so, the cc rules can use it as if it was a dynamic library
cc_binary(
    name = "main2",
    srcs = [
        "main.c",
        "lib.h" ,
        "lib_relocatable.so"
    ],
)
