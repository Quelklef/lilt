
import lilt/private/parse
import lilt/inner_ast
import lilt/private/outer_ast
import lilt/private/interpret
import lilt/private/misc

import tables
import strutils
import sequtils

proc test(code: string, ruleName: string, input: string, expected: inner_ast.Node) =
    # Test must expect a node, not a list or code.
    let ast = parseProgram(code).Program

    # TODO: This 3-liner REALLY needs to go in some proc.
    # In fact, the entire interpreter API needs to be cleaned up
    for lamb in ast.descendants.filterOf(Lambda):
        if lamb.parent of Definition:
            lamb.returnNodeKind = lamb.parent.Definition.id

    let ctx = astToContext(ast)
    let rule = ctx[ruleName]
    let res = rule(0, input, initLambdaState(ast.
        descendants
        .filterOf(Definition)
        .findIt(it.id == ruleName)
        .body
        .returnType.toLiltType))

    var resNode: inner_ast.Node
    case res.kind:
    of rrtNode:
        resNode = res.node
    else:
        echo res.kind
        assert false

    if resNode != expected:
        echo "Expected:\n$1\n\nBut got:\n$2" % [$$expected, $$resNode]
        assert false
