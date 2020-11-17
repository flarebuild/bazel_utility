load("//yaml:yaml.bzl", "load_yaml")
load("//repo:repo_utils.bzl", "repo_utils")
load("@bazel_skylib//lib:paths.bzl", "paths")

_LOCAL_REPO_PATTERN = """
    native.local_repository(
        name = "%s",
        path = "%s",
    )
"""

_GIT_REPO_PATTERN = """
    git_repository(
        name = "%s",
        remote = "%s",
        commit = "%s",
    )
"""

_BUILD_PATTERN = """
sh_binary(
    name = "check",
    srcs = ["check.sh"],
    args = [
        "$(location @build_flare_bazel_utility//tool/linked_repos_checker)",
        "%s/%s",
    ],
    data = [
        "@build_flare_bazel_utility//tool/linked_repos_checker",
    ],
    tags = [
        "local",
        "manual",
    ]
)
"""

def _local_linked_repos_impl(repository_ctx):
    config_path = repository_ctx.path(repository_ctx.attr.config)
    config = load_yaml(repository_ctx.read(repository_ctx.attr.config))
    content = [
        """load("@build_flare_bazel_utility//tool:tools_deps.bzl", "tools_deps")""",
        """load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")""",
        "",
        "def init_local_linked():",
        "    tools_deps()",
    ]

    existing_locals = {}

    for dep, info in config.items():
        path = paths.normalize(
            "%s/%s" % (
                config_path.dirname,
                info["maybe_path"]
            )
        )
        if repo_utils.check_exists(repository_ctx, path):
            content.append(_LOCAL_REPO_PATTERN % (dep, path))
            existing_locals[dep] = path
        else:
            content.append(_GIT_REPO_PATTERN % (dep, info["remote"], info["commit"]))

    content.append("")
    content.append("existing_locals = " + str(existing_locals))

    repository_ctx.file("check.sh", "$@")
    config_label = repository_ctx.attr.config
    repository_ctx.file(
        "BUILD.bazel", 
        _BUILD_PATTERN % (
            config_label.package, 
            config_label.name,
        )
    )
    repository_ctx.file(
        "defs.bzl",
        "\n".join(content),
    )

local_linked_repos = repository_rule(
    implementation = _local_linked_repos_impl,
    attrs = {
        "config": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
    },
)