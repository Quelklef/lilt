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
import sequtils
import strutils
import tables

import base
import outer_ast
import misc

type TypeError* = object of Exception
type ReferenceError* = object of Exception

# TODO: Switch to hashset
type Known = seq[ONode]

method inferReturnType(node: ONode, known: Known): RuleReturnType {.base.} =
    raise new(BaseError)

method canBeInferred(node: ONode, known: Known): bool {.base.} =
    raise new(BaseError)

#~# Independently typed nodes #~#
# (Meaning that their return type may be inferred regardless of
# whether or not we know the return types of any other nodes in
# the AST.)

method canBeInferred(prop: outer_ast.Property, known: Known): bool =
    return true
method inferReturnType(prop: outer_ast.Property, known: Known): RuleReturnType =
    return rrtNone

method canBeInferred(adj: Adjoinment, known: Known): bool =
    return true
method inferReturnType(adj: Adjoinment, known: Known): RuleReturnType =
    return rrtNone

method canBeInferred(ext: Extension, known: Known): bool =
    return true
method inferReturnType(ext: Extension, known: Known): RuleReturnType =
    return rrtNone

method canBeInferred(guard: Guard, known: Known): bool =
    return true
method inferReturnType(guard: Guard, known: Known): RuleReturnType =
    return rrtNone

method canBeInferred(se: Set, known: Known): bool =
    return true
method inferReturnType(se: Set, known: Known): RuleReturnType =
    return rrtText

method canBeInferred(lit: Literal, known: Known): bool =
    return true
method inferReturnType(lit: Literal, known: Known): RuleReturnType =
    return rrtText

method canBeInferred(se: Sequence, known: Known): bool =
    return true
method inferReturnType(se: Sequence, known: Known): RuleReturnType =
    return rrtText

method canBeInferred(def: Definition, known: Known): bool =
    return true
method inferReturnType(def: Definition, known: Known): RuleReturnType =
    return rrtNone

method canBeInferred(prog: Program, known: Known): bool =
    return true
method inferReturnType(prog: Program, known: Known): RuleReturnType =
    return rrtNone

#~# Dependently typed nodes #~#

method canBeInferred(op: OnePlus, known: Known): bool =
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

method canBeInferred(opt: Optional, known: Known): bool =
    return opt.inner in known
method inferReturnType(opt: Optional, known: Known): RuleReturnType =
    if opt.inner.returnType == rrtNode:
        return rrtNone
    else:
        return opt.inner.returnType

method canBeInferred(re: Reference, known: Known): bool =
    # TODO: Doesn't work with builtins
    let definitions = re.ancestors
        .findOf(Program)
        .descendants.filterOf(Definition)

    if re.id notin definitions.mapIt(it.id):
        raise newException(ReferenceError, "No rule named '$1'." % re.id) 

    return definitions
        .findIt(it.id == re.id)
        .body in known
method inferReturnType(re: Reference, known: Known): RuleReturnType =
    # TODO: Doesn't work with builtins
    return re.ancestors
        .findOf(Program)
        .descendants
        .filterOf(Definition)
        .findIt(it.id == re.id)
        .body.returnType

method canBeInferred(choice: Choice, known: Known): bool =
    return choice.children.allIt(it in known)
method inferReturnType(choice: Choice, known: Known): RuleReturnType =
    let innerTypes = choice.contents.mapIt(it.returnType)

    if not allSame(innerTypes):
        raise newException(TypeError, "Choice must be homogenous. Node '$1' got types: $2" % [$choice, $innerTypes])

    let allTypes = innerTypes[0]  # Type of all inner nodes
    if allTypes == rrtNone:
        raise newException(TypeError, "Choice must return non-None type.")

    return allTypes

method canBeInferred(lamb: Lambda, known: Known): bool =
    let body = lamb.body
    return body of Sequence or
        body of Choice and body in known or
        body of Adjoinment or body of outer_ast.Property or body of Extension or
        body in known
proc inferReturnTypeUnsafe(lamb: Lambda, known: Known): RuleReturnType =
    # Semantically meaningless; helper for inferReturnType
    if lamb.body of Sequence:
        for node in lamb.scoped:
            if node of Adjoinment:
                return rrtText
            elif node of outer_ast.Property:
                return rrtNode
            elif node of Extension:
                return rrtList
        return rrtText

    elif lamb.body of Choice:
        return lamb.body.returnType

    elif lamb.body of Adjoinment:
        return rrtText
    elif lamb.body of outer_ast.Property:
        return rrtNode
    elif lamb.body of Extension:
        return rrtList

    else:
        if lamb.body.returnType == rrtNone:
            return rrtText
        else:
            return lamb.body.returnType
method inferReturnType(lamb: Lambda, known: Known): RuleReturnType =
    result = inferReturnTypeUnsafe(lamb, known)

    if result == rrtNode:
        let isTopLevel = lamb.parent of Definition
        if not isTopLevel:
            raise newException(TypeError, "Only top-level Lambdas may return nodes.")

proc inferReturnTypes*(ast: ONode) =
    var toInfer = concat(ast.layers)
    var known: Known = @[]

    while toInfer.len > 0:
        var inferredCount = 0

        var head = 0
        while head < toInfer.len:
            let node = toInfer[head]
            if node.canBeInferred(known):
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
