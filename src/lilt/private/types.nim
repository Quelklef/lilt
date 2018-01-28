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

type Known = seq[Node]  # Conceptually a hashset, but use a seq instead

method inferReturnType(node: Node, known: Known) {.base.} =
    raise new(BaseError)

method canInfer(node: Node, known: Known): bool {.base.} =
    raise new(BaseError)

#~# Independently typed nodes #~#
# (Meaning that their return type may be inferred regardless of
# whether or not we know the return types of any other nodes in
# the AST.)

method canInfer(prop: Property, known: Known): bool =
    return true
method inferReturnType(prop: Property, known: Known) =
    prop.returnType = rrtNone

method canInfer(adj: Adjoinment, known: Known): bool =
    return true
method inferReturnType(adj: Adjoinment, known: Known) =
    adj.returnType = rrtNone

method canInfer(ext: Extension, known: Known): bool =
    return true
method inferReturnType(ext: Extension, known: Known) =
    ext.returnType = rrtNone

method canInfer(guard: Guard, known: Known): bool =
    return true
method inferReturnType(guard: Guard, known: Known) =
    guard.returnType = rrtNone

method canInfer(se: Set, known: Known): bool =
    return true
method inferReturnType(se: Set, known: Known) =
    se.returnType = rrtText

method canInfer(lit: Literal, known: Known): bool =
    return true
method inferReturnType(lit: Literal, known: Known) =
    lit.returnType = rrtText

method canInfer(se: Sequence, known: Known): bool =
    return true
method inferReturnType(se: Sequence, known: Known) =
    se.returnType = rrtText

method canInfer(def: Definition, known: Known): bool =
    return true
method inferReturnType(def: Definition, known: Known) =
    def.returnType = rrtNone

method canInfer(prog: Program, known: Known): bool =
    return true
method inferReturnType(prog: Program, known: Known) =
    prog.returnType = rrtNone

#~# Dependently typed nodes #~#

method canInfer(op: OnePlus, known: Known): bool =
    return op.inner in known
method inferReturnType(op: OnePlus, known: Known) =
    let inner = op.inner

    case inner.returnType:
    of rrtText:
        op.returnType = rrtText
    of rrtNode:
        op.returnType = rrtList
    of rrtNone:
        # If typeless, execute statement several times and return nothing
        op.returnType = rrtNone
    else:
        raise newException(TypeError, "Cannot have OnePlus of rule that returns type '$1'" % $inner.returnType)

method canInfer(opt: Optional, known: Known): bool =
    return opt.inner in known
method inferReturnType(opt: Optional, known: Known) =
    if opt.inner.returnType == rrtNode:
        opt.returnType = rrtNone
    else:
        opt.returnType = opt.inner.returnType

method canInfer(re: Reference, known: Known): bool =
    return re.ancestors
        .findIt(it of Program)
        .descendants
        .findIt(it of Definition and it.Definition.id == re.id)
        .Definition.body.Lambda in known
method inferReturnType(re: Reference, known: Known) =
    # TODO Will not nicely fail if referencing an undefined rule
    # Ensure that referencing a defined function
    let definitions = re.ancestors
        .findIt(it of Program)
        .descendants
        .filterIt(it of Definition)
        .mapIt(it.Definition)

    if re.id notin definitions.mapIt(it.id):
        raise newException(TypeError, "No rule '$1'." % re.id)

    re.returnType = definitions.findIt(it.id == re.id).body.returnType

method canInfer(choice: Choice, known: Known): bool =
    return choice.children.allIt(it in known)
method inferReturnType(choice: Choice, known: Known) =
    let innerTypes = choice.contents.mapIt(it.returnType)

    if not allSame(innerTypes):
        raise newException(TypeError, "Choice must be homogenous. Got types: $2" % $innerTypes)

    let allTypes = innerTypes[0]  # Type of all inner nodes
    if allTypes == rrtNone:
        raise newException(TypeError, "Choice must return non-None type.")

    choice.returnType = allTypes

method canInfer(lamb: Lambda, known: Known): bool =
    return (lamb.body of Sequence) or
        (lamb.body of Choice and lamb.body in known)
method inferReturnType(lamb: Lambda, known: Known) =
    if lamb.body of Sequence:
        for node in lamb.scoped:
            if node of Adjoinment:
                lamb.returnType = rrtText
                break
            elif node of Property:
                lamb.returnType = rrtnode
                break
            elif node of Extension:
                lamb.returnType = rrtList
                break

        # TODO: Match conditional to new semantics
        if lamb.returnType == rrtNone:
            lamb.returnType = rrtText

    elif lamb.body of Choice:
        lamb.returnType = lamb.body.returnType

    else:
        assert false

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
                node.inferReturnType(known)
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
