
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

type RuleVal = object of RootObj
    head: int
    kind: RuleReturnType  # But not rrtTypeless

    codeVal: string
    listVal: seq[inner_ast.Node]
    nodeVal: inner_ast.Node

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

type Rule = proc(head: int, code: string): RuleVal
type RuleError = object of Exception

type LiltContext = TableRef[string, Rule]

#[
Extensions need to be able to add items to a node list
instead of returning the items.
]#
type CurrentResult = ref object of RootObj
    list: seq[inner_ast.Node]

proc newCurrentResult(): CurrentResult =
    return CurrentResult(list: @[])

const doDebug = true
when not doDebug:
    template debugWrap(rule: Rule, node: Node): Rule =
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
        proc wrappedRule(head: int, code: string): RuleVal =
            #debugPush("Attempting to match\n$1\nwith:\n$2" % [$node, code[head ..< code.len]])
            debugPush("Attempting to match $1" % $node)
            #discard readLine(stdin)
            try:
                result = rule(head, code)
            except RuleError as e:
                debugPop("Failed: " & e.msg)
                raise e
            debugPop("Success, head now: " & $result.head)
            return result
        return wrappedRule


type WrongTypeError = object of Exception

method translate(node: outer_ast.Node, context: LiltContext, currentResult: CurrentResult): Rule {.base.} =
    raise newException(WrongTypeError, "Cannot translate node $1" % $node)

method translate(re: Reference, context: LiltContext, currentResult: CurrentResult): Rule =
    return context[re.id]

method translate(se: Sequence, context: LiltContext, currentResult: CurrentResult): Rule =
    let isTopLevel = se.parent of outer_ast.Definition

    proc rule(phead: int, code: string): RuleVal =
        var head = phead

        var
            returnCode = ""
            returnNodeNodeProps = initTable[string, inner_ast.Node]()
            returnNodeChildProps = initTable[string, seq[inner_ast.Node]]()
            returnNodeCodeProps = initTable[string, string]()

        for node in se.contents:
            let returnVal = translate(node, context, currentResult)(head, code)
            head = returnVal.head

            if se.returnType == rrtCode:
                returnCode &= returnVal.codeVal

            if node of outer_ast.Extension:
                currentResult.list.add(returnVal.nodeVal)
            elif node of outer_ast.Property:
                let propNode = outer_ast.Property(node)
                if node.returnType == rrtList:
                    returnNodeChildProps[propNode.propName] = returnVal.listVal
                elif node.returnType == rrtNode:
                    returnNodeNodeProps[propNode.propName] = returnVal.nodeVal  # Remember that translate(v of Property, context) returns a Rule which returns a Node, not List nor Code
                elif node.returnType == rrtCode:
                    returnNodeCodeProps[propNode.propName] = returnVal.codeVal
                else:
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

method translate(ch: Choice, context: LiltContext, currentResult: CurrentResult): Rule =
    proc rule(phead: int, code: string): RuleVal =
        for node in ch.contents:
            try:
                return translate(node, context, currentResult)(phead, code)
            except RuleError:
                discard
        raise newException(RuleError, "Didn't match any rule.")

    return debugWrap(rule, ch)

method translate(li: Literal, context: LiltContext, currentResult: CurrentResult): Rule =
    proc rule(phead: int, code: string): RuleVal =
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

method translate(s: Set, context: LiltContext, currentResult: CurrentResult): Rule =
    proc rule(phead: int, code: string): RuleVal =
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
method translate(o: Optional, context: LiltContext, currentResult: CurrentResult): Rule =
    let innerRule = translate(o.inner, context, currentResult)

    proc rule(phead: int, code: string): RuleVal =
        try:
            return innerRule(phead, code)
        except RuleError:
            if o.returnType == rrtList:
                return (phead, newSeq[inner_ast.Node]())
            elif o.returnType == rrtCode:
                return (phead, "")
            elif o.returnType == rrtNode:
                return (phead, nilNode)  # TODO this smells

    return debugWrap(rule, o)

method translate(op: OnePlus, context: LiltContext, currentResult: CurrentResult): Rule =
    let innerRule = translate(op.inner, context, currentResult)

    proc rule(phead: int, code: string): RuleVal =
        var head = phead
        var matchedCount = 0

        var returnNodeList: seq[inner_ast.Node] = @[]
        var returnCode = ""

        while true:
            try:
                let retVal = innerRule(head, code)
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

method translate(g: Guard, context: LiltContext, currentResult: CurrentResult): Rule =
    let innerRule = translate(g.inner, context, currentResult)

    proc rule(head: int, code: string): RuleVal =
        try:
            discard innerRule(head, code):
        except RuleError:
            return (head, "")  # TODO: Returning Code "" is a smell
        raise newException(RuleError, "Code matched guard inner rule.")

    return debugWrap(rule, g)

method translate(p: Property, context: LiltContext, currentResult: CurrentResult): Rule =
    let innerRule = translate(p.inner, context, currentResult)

    proc rule(head: int, code: string): RuleVal =
        return innerRule(head, code)
    
    return debugWrap(rule, p)

method translate(e: Extension, context: LiltContext, currentResult: CurrentResult): Rule =
    let innerRule = translate(e.inner, context, currentResult)
    
    proc rule(head: int, code: string): RuleVal =
        return innerRule(head, code)
    
    return debugWrap(rule, e)

proc addDefinition(def: Definition, context: LiltContext) =
    ## Add a definition to a context
    var currentResult = newCurrentResult()
    context[def.id] = translate(def.body, context, currentResult)

proc merge[K, V](t1, t2: TableRef[K, V]) =
    for key in t2.keys:
        t1[key] = t2[key]

# Builtins


var builtins: LiltContext = newTable[string, Rule]()

#[
builtins["anything"] = proc(head: int, code: string): RuleVal =
    return (head + 1, $code{head})
builtins["whitespace"] = proc(head: int, code: string): RuleVal =
    if code{head} in su.Whitespace:
        return (head + 1, $code{head})
    raise newException(RuleError, "'$1' is not whitespace." % $code{head})

builtins["lower"] = translate(newSet("abcdefghijklmnopqrstuvwxyz"), builtins)
builtins["upper"] = translate(newSet("ABCDEFGHIJKLMNOPQRSTUVWXYZ"), builtins)
builtins["alpha"] = translate(newChoice(@[
    outer_ast.Node(newReference("lower")),
    outer_ast.Node(newReference("upper")),
]), builtins)

builtins["digit"] = translate(newSet("0123456789"), builtins)
builtins["alphanum"] = translate(newChoice(@[
    outer_ast.Node(newReference("alpha")),
    outer_ast.Node(newReference("digit")),
]), builtins)

builtins["_"] = translate(newOptional(newOnePlus(newReference("whitespace"))), builtins)
]#

method translate(prog: Program): LiltContext {.base.} =
    ## Translates a program to a table of definitions
    var context: LiltContext = newTable[string, Rule]()
    context.merge(builtins)
    for definition in prog.definitions:
        addDefinition(Definition(definition), context)
    return context

when isMainModule:
    const code = r"""
    word: val=*<abcdefghijklmnopqrstuvwxyz>
    sentence: &word *[", " &word]
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
    echo res["sentence"](0, json)

