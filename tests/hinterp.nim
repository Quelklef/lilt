
import tables
import strutils
import options

import lilt/private/base
import lilt/private/inner_ast
import lilt

proc test(code: string, ruleName: string, input: string, expected: Node) =
    # Test must expect a node, not a list or code.
    let parsers = lilt.makeParsers(code)
    let res = parsers[ruleName](input).node

    if res != expected:
        echo "Expected:\n$1\n\nBut got:\n$2" % [$$expected, $$res]
        assert false
