
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

#~# Undocumented, unofficially part of the API #~#

proc codeToParser(code: string, returnType: LiltType): Parser =
    let ast = parse.parseBody(code)
    types.preprocess(ast)
    let parser = bodyToParser(ast)
    return parser

proc `$~`*(spec, text: string): string =
    return codeToParser(spec, ltText)(text).text

proc `%~`*(spec, text: string): Node =
    return codeToParser(spec, ltNode)(text).node

proc `&~`*(spec, text: string): seq[Node] =
    return codeToParser(spec, ltList)(text).list
