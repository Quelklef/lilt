
#[
Here we define the Lilt interpreter.
Though in the future Lilt may become a compiled language,
an interpreter works for now. I want to get all the features
planned and implemented before writing a compiler.

The interpreter works by representing different Lilt
constructs as Nim constructs. This process is referred to
as translation.
Lilt code is translated into Nim code, and a full Lilt
program is mapped to a Nim procedure on a file.
]#

import tables
import strutils as su
import sequtils

import outer_ast
import inner_ast
import verify
import strfix
import parse
import types

#[
Most Lilt constructs are translated into Rules,
which are functions which take code and either
a) return an integer, the amount of code consumed,
or b) fail. (Sound familiar?)

Failing is done by raising a RuleError.
]#

type RuleVal* = object of RootObj
    head*: int
    kind*: RuleReturnType  # But not rrtUnknown

    codeVal*: string
    listVal*: seq[inner_ast.Node]
    nodeVal*: inner_ast.Node

proc `$`(s: seq[inner_ast.Node]): string =
    result = "@["
    var firstItem = true
    for node in s:
        if not firstItem: result &= ", "
        result &= $node
        firstItem = false
    result &= "]"

proc `$`(rv: RuleVal): string =
    if rv.kind == rrtCode:
        return "head: $1; code: '$2'" % [$rv.head, rv.codeVal]
    elif rv.kind == rrtList:
        return "head: $1; list: $2" % [$rv.head, $rv.listVal]
    elif rv.kind == rrtNode:
        return "head: $1; node: $2" % [$rv.head, $rv.nodeVal]
    else:
        return "head: $1, kind: $2" % [$rv.head, $rv.kind]

# For nodes with no semantic meaning
# Is just a filler; no code should rely on nil-valued nodes being this value
# This just makes sure $ and such play nicely with others
const nilNode = inner_ast.newCode("")

converter toRuleVal(retVal: (int, string)): RuleVal =
    return RuleVal(
            head: retVal[0],
            kind: rrtCode,
            codeVal: retVal[1],
            listVal: @[],
            nodeVal: nilNode,
        )

converter toRuleVal(retVal: (int, seq[inner_ast.Node])): RuleVal =
    return RuleVal(
            head: retVal[0],
            kind: rrtList,
            codeVal: "",
            listVal: retVal[1],
            nodeVal: nilNode,
        )

converter toRuleval(retVal: (int, inner_ast.Node)): RuleVal =
    return RuleVal(
            head: retVal[0],
            kind: rrtNode,
            codeVal: "",
            listVal: @[],
            nodeVal: retVal[1],
        )

#[
Extensions need to be able to add items to a node list
instead of returning the items.
]#
type CurrentResult* = ref object of RootObj
    list: seq[inner_ast.Node]

type Rule* = proc(head: int, code: string, currentResult: CurrentResult): RuleVal
type RuleError = object of Exception

type LiltContext* = TableRef[string, Rule]

proc newCurrentResult*(): CurrentResult =
    return CurrentResult(list: @[])

const doDebug = false
when not doDebug:
    template debugWrap(rule: Rule, node: outer_ast.Node): Rule =
        rule

else:
    var debugDepth = 0

    proc debugEcho(msg: string) =
        echo ".   ".repeat(debugDepth) & msg

    proc debugPush(msg: string) =
        debugEcho(msg)
        inc(debugDepth)

    proc debugPop(msg: string) =
        dec(debugDepth)
        debugEcho(msg)

    proc debugWrap(rule: Rule, node: outer_ast.Node): Rule =
        proc wrappedRule(head: int, code: string, currentResult: CurrentResult): RuleVal =
            #debugPush("Attempting to match\n$1\nwith:\n$2" % [$node, code[head ..< code.len]])
            debugPush("Attempting to match $1" % $node)
            #discard readLine(stdin)
            try:
                result = rule(head, code, currentResult)
            except RuleError as e:
                debugPop("Failed: " & e.msg)
                raise e
            debugPop("Success, head now: " & $result.head)
            return result
        return wrappedRule


type WrongTypeError = object of Exception

method translate(node: outer_ast.Node, context: LiltContext): Rule {.base.} =
    raise newException(WrongTypeError, "Cannot translate node $1" % $node)

method translate(re: Reference, context: LiltContext): Rule =
    return context[re.id]

method translate(se: Sequence, context: LiltContext): Rule =
    let isTopLevel = se.parent of outer_ast.Definition

    proc rule(phead: int, code: string, currentResult: CurrentResult): RuleVal =
        var head = phead

        var
            returnCode = ""
            returnNodeNodeProps = initTable[string, inner_ast.Node]()
            returnNodeChildProps = initTable[string, seq[inner_ast.Node]]()
            returnNodeCodeProps = initTable[string, string]()

        for node in se.contents:
            let returnVal = translate(node, context)(head, code, currentResult)
            head = returnVal.head

            if se.returnType == rrtCode:
                returnCode &= returnVal.codeVal

            if node of outer_ast.Extension:
                currentResult.list.add(returnVal.nodeVal)
            elif node of outer_ast.Property:
                let propNode = outer_ast.Property(node)
                # Remember that properties return whatever the inner rule returns
                case returnVal.kind:  # TODO Should be handled by predictive types, not runtime types
                of rrtList:
                    returnNodeChildProps[propNode.propName] = returnVal.listVal
                of rrtNode:
                    returnNodeNodeProps[propNode.propName] = returnVal.nodeVal
                of rrtCode:
                    returnNodeCodeProps[propNode.propName] = returnVal.codeVal
                of rrtTypeless:
                    discard
                of rrtUnknown:
                    assert false
            else:
                discard

        if se.returnType == rrtCode:
            return (head, returnCode)
        elif se.returnType == rrtNode:
            let kind = se.ancestors.filterIt(it of Definition)[0].Definition.id
            return (head, inner_ast.newBranch(kind, returnNodeNodeProps, returnNodeChildProps, returnNodeCodeProps))
        elif se.returnType == rrtList:
            assert isTopLevel
            return (head, currentResult.list)

    return debugWrap(rule, se)

method translate(ch: Choice, context: LiltContext): Rule =
    proc rule(phead: int, code: string, currentResult: CurrentResult): RuleVal =
        for node in ch.contents:
            try:
                return translate(node, context)(phead, code, currentResult)
            except RuleError:
                discard
        raise newException(RuleError, "Didn't match any rule.")

    return debugWrap(rule, ch)

method translate(li: Literal, context: LiltContext): Rule =
    proc rule(phead: int, code: string, currentResult: CurrentResult): RuleVal =
        var head = phead
        for ci in 0 ..< li.text.len:
            if li.text[ci] == code{head}:
                inc(head)
            else:
                raise newException(
                    RuleError,
                    "Code didn't match literal at char $1; expected '$2' but got '$3'." % [
                        $head, $li.text[ci], $code{head}
                    ]
                )
        return (head, li.text)

    return debugWrap(rule, li)

method translate(s: Set, context: LiltContext): Rule =
    proc rule(phead: int, code: string, currentResult: CurrentResult): RuleVal =
        let c = code{phead}
        if c in s.charset:
            return (phead + 1, $c)
        raise newException(RuleError, "'$1' not in $2." % [$c, $s])

    return debugWrap(rule, s)

#[
Optional rules have different behaviour based on their inner rule.
Depending on the return type of the inner rule, the optional rule
will default to returning different things if the inner rule fails.
Inner rule return type -> optional return vail on inner rule failure
code -> ""
list -> []
node -> nilNode
]#
method translate(o: Optional, context: LiltContext): Rule =
    let innerRule = translate(o.inner, context)

    proc rule(phead: int, code: string, currentResult: CurrentResult): RuleVal =
        try:
            return innerRule(phead, code, currentResult)
        except RuleError:
            if o.returnType == rrtList:
                return (phead, newSeq[inner_ast.Node]())
            elif o.returnType == rrtCode:
                return (phead, "")
            elif o.returnType == rrtNode:
                return (phead, nilNode)  # TODO this smells

    return debugWrap(rule, o)

method translate(op: OnePlus, context: LiltContext): Rule =
    let innerRule = translate(op.inner, context)

    proc rule(phead: int, code: string, currentResult: CurrentResult): RuleVal =
        var head = phead
        var matchedCount = 0

        var returnNodeList: seq[inner_ast.Node] = @[]
        var returnCode = ""

        while true:
            try:
                let retVal = innerRule(head, code, currentResult)
                head = retVal.head

                if op.returnType == rrtList:
                    returnNodeList.add(retVal.nodeVal)  # No type checking needed since 
                elif op.returnType == rrtCode:
                    returnCode &= retVal.codeVal

                inc(matchedCount)
            except RuleError:
                break

        if matchedCount == 0:
            raise newException(RuleError, "Expected code to match at least once.")

        if op.returnType == rrtList:
            return (head, returnNodeList)
        elif op.returnType == rrtCode:
            return (head, returnCode)

    return debugWrap(rule, op)

method translate(g: Guard, context: LiltContext): Rule =
    let innerRule = translate(g.inner, context)

    proc rule(head: int, code: string, currentResult: CurrentResult): RuleVal =
        try:
            discard innerRule(head, code, currentResult)
        except RuleError:
            return (head, "")  # TODO: Returning Code "" is a smell
        raise newException(RuleError, "Code matched guard inner rule.")

    return debugWrap(rule, g)

method translate(p: Property, context: LiltContext): Rule =
    let innerRule = translate(p.inner, context)

    proc rule(head: int, code: string, currentResult: CurrentResult): RuleVal =
        return innerRule(head, code, currentResult)
    
    return debugWrap(rule, p)

method translate(e: Extension, context: LiltContext): Rule =
    let innerRule = translate(e.inner, context)
    
    proc rule(head: int, code: string, currentResult: CurrentResult): RuleVal =
        return innerRule(head, code, currentResult)
    
    return debugWrap(rule, e)

proc addDefinition(def: Definition, context: LiltContext) =
    ## Add a definition to a context
    context[def.id] = translate(def.body, context)

proc merge[K, V](t1, t2: TableRef[K, V]) =
    for key in t2.keys:
        t1[key] = t2[key]

method translate(prog: Program): LiltContext {.base.} =
    ## Translates a program to a table of definitions
    var context: LiltContext = newTable[string, Rule]()
    for definition in prog.definitions:
        addDefinition(Definition(definition), context)
    return context

proc interpretAst*(ast: outer_ast.Node): LiltContext =
    verify.verify(ast)
    types.inferReturnTypes(ast)
    let res = translate(Program(ast))
    return res

when isMainModule:
    const code = r"""
    sentence: &word *[", " &word]
    word: val=*<abcdefghijklmnopqrstuvwxyz>
    """

    const json = """several, words, in, a, sentence"""

    # Parse program
    let programAst: outer_ast.Node = parse.parseProgram(code)

    # Verify AST
    verify.verify(programAst)

    # Infer types
    types.inferReturnTypes(programAst)

    echo $$programAst

    # Translate to runnable Nim constructs
    let res = translate(Program(programAst))

    # Run program
    echo res["sentence"](0, json, newCurrentResult())

    # Test word
    #echo res["word"](0, "wgorggnw  ", newCurrentResult())

    when true:
        block:
            let code2 = """
            test: *<abc>
            node: val=test
            """
            let ast2 = parse.parseProgram(code2)
            verify.verify(ast2)
            types.inferReturnTypes(ast2)
            let res = translate(Program(ast2))
            let v = res["node"](0, "bcbba", newCurrentResult())
            echo v