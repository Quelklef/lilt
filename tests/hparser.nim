
import lilt/private/outer_ast
import lilt/private/parse
import lilt/private/quick

import strutils

template test(code: string, expected: ONode) =
    let parsed = parseProgram(code)
    if not equiv(parsed, expected):
        echo "Failed; expected ast:"
        echo $$expected
        echo "but got:"
        echo $$parsed
        assert false
