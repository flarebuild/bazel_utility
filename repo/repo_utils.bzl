def _check_exists(repository_ctx, path):
    return repository_ctx.execute([
        "ls",
        path,
    ]).return_code == 0

repo_utils = struct(
    check_exists = _check_exists,
)