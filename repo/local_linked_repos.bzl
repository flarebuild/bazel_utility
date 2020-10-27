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
    native.git_repository(
        name = "%s",
        remote = "%s",
        commit = "%s",
    )
"""

_LAST_COMMIT_GETTER = """

#!/usr/bin/env bash
set -eu

if [[ ${GIT_INDEX_FILE} && ${GIT_INDEX_FILE-x} ]]; then
    GIT_INDEX_FILE_BAK=${GIT_INDEX_FILE}
    unset GIT_INDEX_FILE
fi

require_clean_work_tree() {
    # Update the index
    /usr/bin/env git -C $1 update-index -q --ignore-submodules --refresh
    err=0

    # Disallow unstaged changes in the working tree
    if ! /usr/bin/env git -C $1 diff-files --quiet --ignore-submodules --
    then
        echo >&2 "you have unstaged changes."
        /usr/bin/env git -C $1 diff-files --name-status -r --ignore-submodules -- >&2
        err=1
    fi

    # Disallow uncommitted changes in the index
    if ! /usr/bin/env git -C $1 diff-index --cached --quiet HEAD --ignore-submodules --
    then
        echo >&2 "your index contains uncommitted changes."
        /usr/bin/env git -C $1 diff-index --cached --name-status -r --ignore-submodules HEAD -- >&2
        err=1
    fi

    if [ $err = 1 ]
    then
        echo >&2 "Please commit or stash them."
        exit 1
    fi
}

require_clean_work_tree $1

/usr/bin/env git -C $1 rev-parse HEAD

if [[ ${GIT_INDEX_FILE_BAK} && ${GIT_INDEX_FILE_BAK-x} ]]; then
    export GIT_INDEX_FILE="$GIT_INDEX_FILE_BAK"
fi

"""

_BUILD_PATTERN = """
sh_binary(
    name = "last_commit_getter",
    srcs = ["last_commit_getter.sh"],
)

sh_binary(
    name = "check",
    srcs = ["check.sh"],
    args = [
        "$(location @build_flare_bazel_utility//tool/linked_repos_checker)",
        "$(location :last_commit_getter)",
        "%s/%s",
    ],
    data = [
        ":last_commit_getter",
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
        "",
        "def init_local_linked():",
        "    tools_deps()",
    ]
    for dep, info in config.items():
        path = paths.normalize(
            "%s/%s" % (
                config_path.dirname,
                info["maybe_path"]
            )
        )
        if repo_utils.check_exists(repository_ctx, path):
            content.append(_LOCAL_REPO_PATTERN % (dep, path))
        else:
            content.append(_GIT_REPO_PATTERN % (dep, info["remote"], info["commit"]))

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
    repository_ctx.file(
        "last_commit_getter.sh",
        _LAST_COMMIT_GETTER
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