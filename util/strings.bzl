def _find_all(a_str, sub):
    return [i for i in range(len(a_str)) if a_str.startswith(sub, i)]

strings = struct(
    find_all = _find_all,
)