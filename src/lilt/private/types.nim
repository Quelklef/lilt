#[
Handles type inference in the outer ast.

Programs are always typeless (rrtNone)
Definitions are semantically typeless but are a special case; definitions' return types match those
    of their inner rule.

All other nodes' return types have semantic meaning.
]#

import sets
import macros
import hashes

import outer_ast
import sequtils
import strutils
import tables
import misc

type TypeError* = object of Exception
type ReferenceError* = object of Exception

type Known = seq[Node]  # Conceptually a hashset, but use a seq instead

method inferReturnType(node: Node, known: Known): RuleReturnType {.base.} =
    raise new(BaseError)

method canInfer(node: Node, known: Known): bool {.base.} =
    raise new(BaseError)

#~# Independently typed nodes #~#
# (Meaning that their return type may be inferred regardless of
# whether or not we know the return types of any other nodes in
# the AST.)

method canInfer(prop: Property, known: Known): bool =
    return true
method inferReturnType(prop: Property, known: Known): RuleReturnType =
    return rrtNone

method canInfer(adj: Adjoinment, known: Known): bool =
    return true
method inferReturnType(adj: Adjoinment, known: Known): RuleReturnType =
    return rrtNone

method canInfer(ext: Extension, known: Known): bool =
    return true
method inferReturnType(ext: Extension, known: Known): RuleReturnType =
    return rrtNone

method canInfer(guard: Guard, known: Known): bool =
    return true
method inferReturnType(guard: Guard, known: Known): RuleReturnType =
    return rrtNone

method canInfer(se: Set, known: Known): bool =
    return true
method inferReturnType(se: Set, known: Known): RuleReturnType =
    return rrtText

method canInfer(lit: Literal, known: Known): bool =
    return true
method inferReturnType(lit: Literal, known: Known): RuleReturnType =
    return rrtText

method canInfer(se: Sequence, known: Known): bool =
    return true
method inferReturnType(se: Sequence, known: Known): RuleReturnType =
    return rrtText

method canInfer(def: Definition, known: Known): bool =
    return true
method inferReturnType(def: Definition, known: Known): RuleReturnType =
    return rrtNone

method canInfer(prog: Program, known: Known): bool =
    return true
method inferReturnType(prog: Program, known: Known): RuleReturnType =
    return rrtNone

#~# Dependently typed nodes #~#

method canInfer(op: OnePlus, known: Known): bool =
    return op.inner in known
method inferReturnType(op: OnePlus, known: Known): RuleReturnType =
    let inner = op.inner

    case inner.returnType:
    of rrtText:
        return rrtText
    of rrtNode:
        return rrtList
    of rrtNone:
        # If typeless, execute statement several times and return nothing
        return rrtNone
    else:
        raise newException(TypeError, "Cannot have OnePlus of rule that returns type '$1'" % $inner.returnType)

method canInfer(opt: Optional, known: Known): bool =
    return opt.inner in known
method inferReturnType(opt: Optional, known: Known): RuleReturnType =
    if opt.inner.returnType == rrtNode:
        return rrtNone
    else:
        return opt.inner.returnType

method canInfer(re: Reference, known: Known): bool =
    let definitions = re.ancestors
        .findOf(Program)
        .descendants.filterOf(Definition)

    if re.id notin definitions.mapIt(it.id):
        raise newException(ReferenceError, "No rule named '$1'." % re.id) 

    return definitions
        .findIt(it.id == re.id)
        .body.Lambda in known
method inferReturnType(re: Reference, known: Known): RuleReturnType =
    let definitions = re.ancestors
        .findOf(Program)
        .descendants
        .filterOf(Definition)

    if re.id notin definitions.mapIt(it.id):
        raise newException(TypeError, "No rule '$1'." % re.id)

    return definitions.findIt(it.id == re.id).body.returnType

method canInfer(choice: Choice, known: Known): bool =
    return choice.children.allIt(it in known)
method inferReturnType(choice: Choice, known: Known): RuleReturnType =
    let innerTypes = choice.contents.mapIt(it.returnType)

    if not allSame(innerTypes):
        raise newException(TypeError, "Choice must be homogenous. Got types: $2" % $innerTypes)

    let allTypes = innerTypes[0]  # Type of all inner nodes
    if allTypes == rrtNone:
        raise newException(TypeError, "Choice must return non-None type.")

    return allTypes

method canInfer(lamb: Lambda, known: Known): bool =
    let body = lamb.body
    return (body of Sequence) or
        (body of Choice and body in known) or
        (body of Adjoinment or body of Property or body of Extension) or
        (body in known)
proc inferReturnTypeUnsafe(lamb: Lambda, known: Known): RuleReturnType =
    if lamb.body of Sequence:
        for node in lamb.scoped:
            if node of Adjoinment:
                return rrtText
            elif node of Property:
                return rrtNode
            elif node of Extension:
                return rrtList
        return rrtText

    elif lamb.body of Choice:
        return lamb.body.returnType

    elif lamb.body of Adjoinment:
        return rrtText
    elif lamb.body of Property:
        return rrtNode
    elif lamb.body of Extension:
        return rrtList

    else:
        if lamb.body.returnType == rrtNone:
            return rrtText
        else:
            return lamb.body.returnType
method inferReturnType(lamb: Lambda, known: Known): RuleReturnType =
    let rt = inferReturnTypeUnsafe(lamb, known)

    if rt == rrtNode:
        let isTopLevel = lamb.parent of Definition
        if not isTopLevel:
            raise newException(TypeError, "Only top-level Lambdas may return nodes.")

    return rt

proc inferReturnTypes*(ast: Node) =
    # In reverse order because probably adds efficiency
    # for reasons I'm too lazy to explain
    var toInfer = concat(ast.layers.reversed)
    var known: seq[Node] = @[]

    while toInfer.len > 0:
        var inferredCount = 0

        var head = 0
        while head < toInfer.len:
            let node = toInfer[head]
            if node.canInfer(known):
                node.returnType = node.inferReturnType(known)
                inc(inferredCount)
                toInfer.del(head)
                known.add(node)
            else:
                inc(head)

        if inferredCount == 0:
            # Made no progress; we can do nothing more
            break

    if toInfer.len > 0:
        raise newException(TypeError, "Unable to infer all types.")
