load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# skylib
skylib_sha256 = "97e70364e9249702246c0e9444bccdc4b847bed1eb03c5a3ece4f83dfe6abc44"
skylib_version = "1.0.2"

def init_me():
    http_archive(
        name = "bazel_skylib",
        sha256 = skylib_sha256,
        urls = [ x.format(version = skylib_version) for x in [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/{version}/bazel-skylib-{version}.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/releases/download/{version}/bazel-skylib-{version}.tar.gz",
        ]],
    )