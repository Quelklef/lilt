
import strutils
import tables
import options

import outer_ast
import strfix
import inner_ast
import interpret
import misc
import sequtils
import types

import parser_ast
types.preprocess(liltParserAst)
let parsers: Table[string, Parser] = programToContext(liltParserAst)

proc toOuterAst(node: inner_ast.Node): ONode

proc parseProgramNoValidation*(code: string): Program =
    ## Super ugly naming because it's used once in the entire codebase
    return parsers["program"](code).node.toOuterAst.Program

proc parseProgram*(code: string): Program =
    result = parseProgramNoValidation(code)
    validateSemantics(result)

proc parseBody*(code: string): ONode =
    return parsers["body"](code).node.toOuterAst

const escapeChar = '\\'
const staticEscapes = {
    '\\': "\\",
    '\'': "'",
    '"': "\"",
    '>': ">",
    't': "\t",
    'r': "\r",
    'c': "\c",
    'l': "\l",
    'a': "\a",
    'b': "\b",
    'e': "\e",
}
let staticEscapesTable = staticEscapes.toTable

proc liltUnescape(s: string): string =
    result = ""
    var head = 0
    while head < s.len:
        if s{head} == escapeChar:
            let next = s{head + 1}
            if next in staticEscapesTable:
                result &= staticEscapesTable[next]
                inc(head, 2)
            else:
                if next == 'x':
                    let hex1 = s{head + 2}
                    if hex1 == '\0':
                        raise newException(ValueError, "\xHH requires 2 digits, got 0.")
                    let hex2 = s{head + 3}
                    if hex2 == '\0':
                        raise newException(ValueError, "\xHH requires 2 digits, got 1.")

                    let value = unescape(s[head .. head + 3], prefix="", suffix="")
                    result &= value
                    inc(head, 4)
                else:
                    raise newException(ValueError, "Invalid escape '$1'" % s[head .. head + 1])
        else:
            result &= s{head}
            inc(head)

proc toOuterAst(node: inner_ast.Node): ONode =
    case node.kind:
    of "program":
        return newProgram(node["definitions"].list.mapIt(it.toOuterAst))
    of "definition":
        var body = node["body"].node.toOuterAst
        # TODO: This logic should be elsewhere
        # Wrap body in lambda if it's needed (iff it mutates)
        if body.mutates:
            body = newLambda(body)
        return newDefinition(node["id"].text, body)
    of "sequence":
        return newSequence(node["contents"].list.mapIt(it.toOuterAst))
    of "choice":
        return newChoice(node["contents"].list.mapIt(it.toOuterAst))
    of "reference":
        return newReference(node["id"].text)
    of "literal":
        return newLiteral(node["text"].text.liltUnescape)
    of "set":
        return newSet(node["charset"].text.liltUnescape)
    of "optional":
        return newOptional(node["inner"].node.toOuterAst)
    of "oneplus":
        return newOnePlus(node["inner"].node.toOuterAst)
    of "zeroplus":
        return newOptional(newOnePlus(node["inner"].node.toOuterAst))
    of "guard":
        return newGuard(node["inner"].node.toOuterAst)
    of "result":
        return newResult(node["inner"].node.toOuterAst)
    of "adjoinment":
        return newAdjoinment(node["inner"].node.toOuterAst)
    of "property":
        return newProperty(node["name"].text, node["inner"].node.toOuterAst)
    of "extension":
        return newExtension(node["inner"].node.toOuterAst)
    of "brackets":
        return node["body"].node.toOuterAst
    of "lambda":
        return newLambda(node["body"].node.toOuterAst)
    else:
        assert false
