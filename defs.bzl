"""
This file demonstrates how to create custom rules that depends on the cc toolchain if needed.
It declares the `relocatable` rule that can merge object files of its dependencies in a relocatable object,
as well as a `link_relocatables` rules that can use them to generate a binary.

The `relocatable` rule does not return a CcInfo provider so it cannot be used in the deps field of a cc_library/binary,
however it reads the CcInfo providers of its `cc_library` dependencies.

If the name of the relocatable target ends in ".so", it seem that we can also trick the cc_binary rule to add it to the linking step.

"""
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")

def _relocatable_impl(ctx):
    """ This rule creates a relocatable object from all the pic objects """
    libraries_to_link = []
    for dep in ctx.attr.deps:
        # The CcInfo providers of the targets from deps contain information related to cc rules.
        # In particular the linking context from which we will recover pic object files.
        # See https://bazel.build/rules/lib/builtins/LinkingContext
        libraries_to_link.extend(dep[CcInfo].linking_context.linker_inputs.to_list())

    pic_objects_to_link = []
    for library_to_link in libraries_to_link:
        for lib in library_to_link.libraries:
            pic_objects_to_link.extend(lib.pic_objects)
    pic_objects_paths = [o.path for o in pic_objects_to_link]

    # We will get the path of the ld executable from the cc toolchain.
    cc_toolchain = find_cpp_toolchain(ctx)

    # We declare the relocatable bazel artifact produced by the linking action 
    output_filename = ctx.label.name
    output = ctx.actions.declare_file(output_filename)

    # We declare the action with its commant, inputs and outputs.
    ctx.actions.run(
        outputs = [output],
        executable = cc_toolchain.ld_executable,
        arguments = ["-o", output.path, "-r"] + pic_objects_paths,
        inputs = pic_objects_to_link,
    )

    # We declare the output relocatable artifact as an output of the rule
    return [DefaultInfo(
        files = depset([output]),
    )]

relocatable = rule(
    attrs = {
        "deps": attr.label_list(),
        "_cc_toolchain": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
    },
    implementation = _relocatable_impl,
    toolchains = [
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    doc = """ Build a relocatable object out of the object files of its direct dependencies """,
)

def _link_relocatables_impl(ctx):
    """ Build a binary while adding the relocatable objects dependencies to the command """

    # We will recover the compiler path and include paths from the cc toolchain
    cc_toolchain = find_cpp_toolchain(ctx)
    toolchain_includes = ["-I{}".format(dir) for dir in cc_toolchain.built_in_include_directories]

    # We recover the paths of the relocatable objects
    relocatable_deps = [dep[DefaultInfo].files for dep in ctx.attr.relocatable_deps]
    relocatable_deps_depset = depset(transitive = relocatable_deps)
    relocatable_deps_paths = [file.path for file in relocatable_deps_depset.to_list()]

    # We recover the paths of the source files
    srcs_depset = depset(transitive = [src[DefaultInfo].files for src in ctx.attr.srcs])
    srcs_paths = [file.path for file in srcs_depset.to_list()]

    # We declare the output binary
    output_filename = ctx.label.name
    output = ctx.actions.declare_file(output_filename)

    ctx.actions.run(
        outputs = [output],
        executable = cc_toolchain.compiler_executable,
        arguments = ["-o", output.path] + srcs_paths + relocatable_deps_paths + toolchain_includes + ctx.attr.linkopts,
        inputs = depset(transitive = [relocatable_deps_depset, srcs_depset]),
    )

    # We declare the generated binary as an output of the rule
    return [DefaultInfo(
        files = depset([output]),
        executable = output,
    )]

link_relocatables = rule(
    attrs = {
        "relocatable_deps": attr.label_list(),
        "srcs": attr.label_list(allow_files = True),
        "linkopts": attr.string_list(),
        "_cc_toolchain": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
    },
    implementation = _link_relocatables_impl,
    toolchains = [
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    executable = True,
    doc = "Example of a custom rule that can build a binary and link againt relocatable dependencie",
)
