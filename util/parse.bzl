def _find_patterns(content, pos, patterns):
    max = len(content)
    for i in range(pos, max):
        for p in enumerate(patterns):
            if content.startswith(p[1], i):
                return struct(
                    pos = i,
                    pattern = p[0]
                )

    return None

_find_ending_escapes = {
    '(': ')',
    '"': '"',
    "'": "'",
    '{': '}',
}

def _find_ending(content, pos, endch, escapes = _find_ending_escapes):
    max = len(content)
    ending_search_stack = [ endch ]
    for i in range(pos, max):
        ch = content[i]
        if ch == ending_search_stack[0]:
            ending_search_stack.pop(0)
            if not ending_search_stack:
                return i
            continue
        
        for start, end in escapes.items():
            if ch == start:
                ending_search_stack.insert(0, end)
                break

    return None


_whitespace_chars = [ ' ', '\t', '\n' ]

def _is_whitespace(content, pos, end_pos, ws = _whitespace_chars):
    for i in range(pos, end_pos):
        if not content[i] in ws:
            return False
    return True


parse = struct(
    find_patterns = _find_patterns,
    find_ending = _find_ending,
    is_whitespace = _is_whitespace,
)