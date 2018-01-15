
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
    head: int

    case kind*: RuleReturnType:
    of rrtText:
        text*: string
    of rrtList:
        list*: seq[inner_ast.Node]
    of rrtNode:
        node*: inner_ast.Node
    of rrtTypeless:
        discard
    of rrtUnknown:
        discard  # Technically not allowed, but can't `assert false` here.

proc `$`(s: seq[inner_ast.Node]): string =
    result = "@["
    var firstItem = true
    for node in s:
        if not firstItem: result &= ", "
        result &= $node
        firstItem = false
    result &= "]"

proc `$`(rv: RuleVal): string =
    case rv.kind:
    of rrtText:
        return "head: $1; text: '$2'" % [$rv.head, rv.text]
    of rrtList:
        return "head: $1; list: $2" % [$rv.head, $rv.list]
    of rrtNode:
        return "head: $1; node: $2" % [$rv.head, $rv.node]
    of rrtTypeless, rrtUnknown:
        return "head: $1, kind: $2" % [$rv.head, $rv.kind]

# TODO: Remove
let nilNode = inner_ast.newNode("nil (if you're reading this, that's bad.)")

converter toRuleVal(retVal: (int, string)): RuleVal =
    return RuleVal(
            kind: rrtText,
            head: retVal[0],
            text: retVal[1],
        )

converter toRuleVal(retVal: (int, seq[inner_ast.Node])): RuleVal =
    return RuleVal(
            kind: rrtList,
            head: retVal[0],
            list: retVal[1],
        )

converter toRuleval(retVal: (int, inner_ast.Node)): RuleVal =
    return RuleVal(
            kind: rrtNode,
            head: retVal[0],
            node: retVal[1],
        )

converter toRuleVal(retVal: int): RuleVal =
    return RuleVal(
        kind: rrtTypeless,
        head: retVal,
    )

#[
Each new reference / run of a definiton's rule makes a new CurrentResult.
This CurrentResult is what the statements in the rule modifies.
]#
type CurrentResult* = ref object of RootObj
    case kind*: RuleReturnType  # TODO Shouldn't be rrt
    of rrtText:
        text*: string
    of rrtNode:
        node*: inner_ast.Node
    of rrtList:
        list*: seq[inner_ast.Node]
    else:
        # Shouldn't happen, but.
        discard

proc newCurrentResult*(kind: RuleReturnType): CurrentResult =
    case kind:
    of rrtText:
        result = CurrentResult(kind: rrtText, text: "")
    of rrtList:
        result = CurrentResult(kind: rrtList, list: @[])
    of rrtNode:
        # The kind will be added in the top-leve sequence
        result = CurrentResult(kind: rrtNode, node: inner_ast.newNode(""))
    else:
        assert false

type Rule* = proc(head: int, code: string, currentResult: CurrentResult): RuleVal
type RuleError = object of Exception

type LiltContext* = TableRef[string, Rule]

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
            assert result.kind == node.returnType  # TODO should be in production code ..?
            debugPop("Success, head now: " & $result.head)
            return result
        return wrappedRule


type WrongTypeError = object of Exception

method translate(node: outer_ast.Node, context: LiltContext): Rule {.base.} =
    raise newException(WrongTypeError, "Cannot translate node $1" % $node)

method translate(re: Reference, context: LiltContext): Rule =
    return proc(phead: int, code: string, currentResult: CurrentResult): RuleVal =
        # TODO: make not hacky
        let prog = re.ancestors.filterIt(it of Program)[0]
        let refRt = inferDefinitionReturnTypes(prog)[re.id]

        # Each time a rule is referenced, it relies on its own current result
        return context[re.id](phead, code, newCurrentResult(refRt))

method translate(se: Sequence, context: LiltContext): Rule =
    let isTopLevel = se.parent of Definition
    var rule: proc(phead: int, code: string, currentResult: CurrentResult): RuleVal

    case se.returnType:
    of rrtText:
        # TODO: This should not be handled here.
        # evidently, typing is insufficient
        # Perhaps intents are a good idea
        let hasAdj = se.descendants.filterIt(it of Adjoinment).len > 0

        if hasAdj:
            rule = proc(phead: int, code: string, currentResult: CurrentResult): RuleVal =
                var returnText = ""
                var head = phead

                for node in se.contents:
                    head = translate(node, context)(head, code, currentResult).head

                return (head, currentResult.text)

        else:
            rule = proc(phead: int, code: string, currentResult: CurrentResult): RuleVal =
                var returnText = ""
                var head = phead

                for node in se.contents:
                    let returnVal = translate(node, context)(head, code, currentResult)
                    head = returnVal.head

                    case returnVal.kind:
                    of rrtText:
                        returnText &= returnVal.text
                    of rrtTypeless:
                        discard
                    else:
                        assert false

                return (head, returnText)

    of rrtNode:
        assert isTopLevel
        rule = proc(phead: int, code: string, currentResult: CurrentResult): RuleVal =
            var head = phead

            for node in se.contents:
                let returnVal = translate(node, context)(head, code, currentResult)
                head = returnVal.head

            currentResult.node.kind = se.parent.Definition.id
            return (head, currentResult.node)
    
    of rrtList:
        assert isTopLevel
        rule = proc(phead: int, code: string, currentResult: CurrentResult): RuleVal =
            var head = phead

            for node in se.contents:
                let returnVal = translate(node, context)(head, code, currentResult)
                head = returnVal.head

            return (head, currentResult.list)

    else:
        assert false

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
    var rule: proc(phead: int, code: string, currentResult: CurrentResult): RuleVal

    if o.inner.returnType in [rrtTypeless, rrtNode]:
        rule = proc(phead: int, code: string, currentResult: CurrentResult): RuleVal =
            return innerRule(phead, code, currentResult).head

    else:
        rule = proc(phead: int, code: string, currentResult: CurrentResult): RuleVal =
            try:
                return innerRule(phead, code, currentResult)
            except RuleError:
                if o.returnType == rrtList:
                    return (phead, newSeq[inner_ast.Node]())
                elif o.returnType == rrtText:
                    return (phead, "")

    return debugWrap(rule, o)

method translate(op: OnePlus, context: LiltContext): Rule =
    let innerRule = translate(op.inner, context)

    # TODO Should be several procs rather than one
    proc rule(phead: int, code: string, currentResult: CurrentResult): RuleVal =
        var head = phead
        var matchedCount = 0

        var returnNodeList: seq[inner_ast.Node] = @[]
        var returnText = ""

        while true:
            try:
                let retVal = innerRule(head, code, currentResult)
                head = retVal.head

                case op.returnType:
                of rrtText:
                    returnText &= retVal.text
                of rrtList:
                    returnNodeList.add(retVal.node)
                else:
                    discard

                inc(matchedCount)
            except RuleError:
                break

        if matchedCount == 0:
            raise newException(RuleError, "Expected code to match at least once.")

        if op.returnType == rrtList:
            return (head, returnNodeList)
        elif op.returnType == rrtText:
            return (head, returnText)

    return debugWrap(rule, op)

method translate(g: Guard, context: LiltContext): Rule =
    let innerRule = translate(g.inner, context)

    proc rule(head: int, code: string, currentResult: CurrentResult): RuleVal =
        try:
            # TODO this is gonna get real funky with mutation/statements
            discard innerRule(head, code, currentResult)
        except RuleError:
            return head
        raise newException(RuleError, "Code matched guard inner rule.")

    return debugWrap(rule, g)

method translate(p: outer_ast.Property, context: LiltContext): Rule =
    let innerRule = translate(p.inner, context)

    proc rule(head: int, code: string, currentResult: CurrentResult): RuleVal =
        let returnVal = innerRule(head, code, currentResult)

        var crNode: inner_ast.Node
        case currentResult.kind:
        of rrtNode:
            crNode = currentResult.node
        else:
            assert false

        # TODO: Perhaps a ReturnVal.toProperty proc is in order?
        case returnVal.kind:
        of rrtText:
            crNode.properties[p.propName] = inner_ast.newProperty(returnVal.text)
        of rrtNode:
            crNode.properties[p.propName] = inner_ast.newProperty(returnVal.node)
        of rrtList:
            crNode.properties[p.propName] = inner_ast.newProperty(returnVal.list)
        of rrtTypeless, rrtUnknown:
            assert false

        return returnVal.head
    
    return debugWrap(rule, p)

method translate(adj: Adjoinment, context: LiltContext): Rule =
    let innerRule = translate(adj.inner, context)

    proc rule(phead: int, code: string, currentResult: CurrentResult): RuleVal =
        let returnVal = innerRule(phead, code, currentResult)

        case returnVal.kind:
        of rrtText:
            currentResult.text &= returnVal.text
        else:
            assert false

        return returnVal.head

    return debugWrap(rule, adj)


method translate(e: Extension, context: LiltContext): Rule =
    let innerRule = translate(e.inner, context)
    
    proc rule(head: int, code: string, currentResult: CurrentResult): RuleVal =
        let returnVal = innerRule(head, code, currentResult)

        case returnVal.kind:
        of rrtNode:
            currentResult.list.add(returnVal.node)
        else:
            assert false

        return returnVal.head
   

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

proc interpret*(code: string, ruleName: string, input: string): RuleVal =
    let ast: outer_ast.Node = parse.parseProgram(code)
    verify.verify(ast)
    types.inferReturnTypes(ast)
    let res = translate(Program(ast))
    let rule = res[ruleName]
    # TODO: This will be called once during type inference and once here.
    # while this is a small inefficiency, it is perhaps worth it to change
    let definitionTypes: Table[string, RuleReturnType] = inferDefinitionReturnTypes(ast)
    # TODO: The following line won't ensure that the rule consumes all code
    return rule(0, input, newCurrentResult(definitionTypes[ruleName]))

when isMainModule:
    const code = r"""
    sentence: &word *[", " &word]
    word: val=*<abcdefghijklmnopqrstuvwxyz>
    """

    block:
        let ast = parseProgram(code)
        verify(ast)
        inferReturnTypes(ast)
        echo $$ast

    #echo $$interpret(code, "word", "test").node
    echo $$interpret(code, "sentence", "several, words, in, a, sentence").list
