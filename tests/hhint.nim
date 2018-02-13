
import strutils

include lilt/private/hints
import lilt/private/parse
import lilt

template testSingleHint(code: string, warningType: typedesc) =
    let ast = parseProgram(code)
    let hints = getHints(ast)
    if hints.len != 1:
        raise newException(Exception, "Expected 1 hint.")
    if not (hints[0] of warningType):
        raise newException(Exception, "Hint of wrong type: $1" % $hints[0])
