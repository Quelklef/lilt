
#[
Lilt API
]#

import tables

import lilt/private/base
import lilt/private/parse
import lilt/private/types
import lilt/private/interpret

proc makeParsers*(code: string, consumeAll=true): Table[string, proc(text: string): RuleVal] =
    let ast = parse.parseProgram(code)
    types.preprocess(ast)
    let parsers = interpret.programToContext(ast, consumeAll)

    return parsers
