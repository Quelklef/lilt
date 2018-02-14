
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
