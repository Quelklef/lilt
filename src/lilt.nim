
#[
Lilt API
]#

import lilt/private/inner_ast
export inner_ast

import lilt/private/base
export base

import lilt/private/interpret
import lilt/private/outer_ast
import lilt/private/parse
import lilt/private/types

import tables
import strutils
import lilt/private/misc

proc makeParser*(code: string): proc(text: string): inner_ast.Node =
    ## Parses and inteprets Lilt code, returning the function
    ## correlating to the Rule 'main' (which must return a Node)
    let ast: outer_ast.Node = parse.parseProgram(code)

    types.inferReturnTypes(ast)

    let definitions: TableRef[string, Rule] = translate(Program(ast))

    if not definitions.hasKey("main"):
        raise newException(ValueError, "Must have a rule named 'main'.")

    let mainNode = ast.descendants.findIt(it of Definition and it.Definition.id == "main")
    if mainNode.Definition.body.returnType != rrtNode:
        raise newException(ValueError, "Rule 'main' must return type Node.")

    let rule: Rule = definitions["main"]

    return proc(text: string): inner_ast.Node =    
        let ruleVal = rule(0, text, initLambdaState(
            ast.Program
                .definitions
                .findIt(it.Definition.id == "main")
                .Definition.body.Lambda
                .returnType.toLiltType
        ))

        if ruleVal.head != text.len - 1:  # TODO should be [text.len] or [text.len - 1]?
            raise newException(RuleError, "Unconsumed text left over. (Head ended at $1, text.len=$2)" % [$ruleVal.head, $text.len])

        return ruleVal.node
