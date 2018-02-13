
import lilt/private/outer_ast
import lilt/private/parse
import quick

import strutils

template test(code: string, expected: ONode, skipValidation=false) =
    var parsed: ONode

    if not skipValidation:
        parsed = parseProgram(code)
    else:
        parsed = parseProgramNoValidation(code)

    if not equiv(parsed, expected):
        echo "Failed; expected ast:"
        echo $$expected
        echo "but got:"
        echo $$parsed
        assert false
