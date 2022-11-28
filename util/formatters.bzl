def _bazelify(value):
    return value.replace(".", "_").replace("-", "_")

def _add_indent(a_str, indent, indentstr = "    "):
    return "\n".join([(indentstr * indent) + a for a in a_str.split("\n")])

def _q(x):
    return "\"%s\"" % x

def _format_dict(x):
    if not x:
        return "{}"
    elif len(x) == 1:
        return "{ %s: %s }" % (_q(x.keys()[0]), x.values()[0])

    return "{\n" + "\n".join([
        "        %s: %s," % (_q(a[0]), _q(a[1]))
        for a in x.items()
    ]) + "    \n}"

def _to_arg(x):
    typeof = type(x)
    if typeof == "dict":
        return _format_dict(x)
    elif typeof == "string":
        return _q(x)

    fail("unknown type: " + typeof)

def _to_kv_pair(x):
    return "%s = %s" % (x[0], _to_arg(x[1]))

def _format_call(rule, args = []):
    if not args:
        return rule + "()"
    elif len(args) == 1:
        return rule + "(%s)" % _to_kv_pair(args.items()[0])

    return rule + "(\n" + "\n".join([
        "    %s," % _to_kv_pair(x)
        for x in args.items()
    ]) + "\n)"

f = struct(
    q = _q,
    bazelify = _bazelify,
    add_indent = _add_indent,
    format_call = _format_call,
)
