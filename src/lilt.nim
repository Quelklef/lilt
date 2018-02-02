
#[
Lilt API
]#

import tables

import lilt/private/base
import lilt/private/parse
import lilt/private/types
import lilt/private/interpret

export base.Parser
export base.LiltValue
export base.LiltType
export base.RuleError

proc makeParsers*(code: string): Table[string, Parser] =
    let ast = parse.parseProgram(code)
    types.preprocess(ast)
    let parsers = interpret.programToContext(ast)

    return parsers

export base.initLiltValue
