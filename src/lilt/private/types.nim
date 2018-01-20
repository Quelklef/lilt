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

# TODO: Remove this stupid proc
proc realize(node: Node, returnType: RuleReturnType, known: Known) =
    # "realize" the return type of the node
    node.returnType = returnType

#~# Independently typed nodes #~#

method canInfer(prop: Property, known: Known): bool =
    return true
method inferReturnType(prop: Property, known: Known) =
    prop.realize(rrtNone, known)

method canInfer(adj: Adjoinment, known: Known): bool =
    return true
method inferReturnType(adj: Adjoinment, known: Known) =
    adj.realize(rrtNone, known)

method canInfer(ext: Extension, known: Known): bool =
    return true
method inferReturnType(ext: Extension, known: Known) =
    ext.realize(rrtNone, known)

method canInfer(guard: Guard, known: Known): bool =
    return true
method inferReturnType(guard: Guard, known: Known) =
    guard.realize(rrtNone, known)

method canInfer(se: Set, known: Known): bool =
    return true
method inferReturnType(se: Set, known: Known) =
    se.realize(rrtText, known)

method canInfer(lit: Literal, known: Known): bool =
    return true
method inferReturnType(lit: Literal, known: Known) =
    lit.realize(rrtText, known)

method canInfer(se: Sequence, known: Known): bool =
    return true
method inferReturnType(se: Sequence, known: Known) =
    # Note: verify.nim:verify will already have been
    # run on the AST before this is called, so no need
    # to ensure that doesn't contain Extension node and 
    # Property node
    if se.scoped.anyIt(it of Adjoinment or it of Property or it of Extension):
        # Contains statements, so returns nothing
        se.realize(rrtNone, known)
    else:
        se.realize(rrtText, known)

method canInfer(def: Definition, known: Known): bool =
    return true
method inferReturnType(def: Definition, known: Known) =
    def.realize(rrtNone, known)

method canInfer(prog: Program, known: Known): bool =
    return true
method inferReturnType(prog: Program, known: Known) =
    prog.realize(rrtNone, known)

#~# Dependently typed nodes #~#

method canInfer(op: OnePlus, known: Known): bool =
    return op.inner in known
method inferReturnType(op: OnePlus, known: Known) =
    let inner = op.inner

    case inner.returnType:
    of rrtText:
        op.realize(rrtText, known)
    of rrtNode:
        op.realize(rrtList, known)
    of rrtNone:
        # If typeless, execute statement several times and return nothing
        op.realize(rrtNone, known)
    else:
        raise newException(TypeError, "Cannot have OnePlus of rule that returns type '$1'" % $inner.returnType)

method canInfer(opt: Optional, known: Known): bool =
    return opt.inner in known
method inferReturnType(opt: Optional, known: Known) =
    if opt.inner.returnType == rrtNode:
        opt.realize(rrtNone, known)
    else:
        opt.realize(opt.inner.returnType, known)

method canInfer(re: Reference, known: Known): bool =
    return re.ancestors
        .findIt(it of Program)
        .descendants
        .findIt(it of Definition and it.Definition.id == re.id)
        .Definition.body.Lambda in known
method inferReturnType(re: Reference, known: Known) =
    # Ensure that referencing a defined function
    let definitions = re.ancestors
        .findIt(it of Program)
        .descendants
        .filterIt(it of Definition)
        .mapIt(it.Definition)

    if re.id notin definitions.mapIt(it.id):
        raise newException(TypeError, "No rule '$1'." % re.id)

    re.realize(definitions.findIt(it.id == re.id).body.returnType, known)

method canInfer(choice: Choice, known: Known): bool =
    return choice.children.allIt(it in known)
method inferReturnType(choice: Choice, known: Known) =
    let innerTypes = choice.contents.mapIt(it.returnType)

    if not allSame(innerTypes):
        raise newException(TypeError, "Choice must be homogenous. Got types: $2" % $innerTypes)

    let allTypes = innerTypes[0]  # Type of all inner nodes
    if allTypes == rrtNone:
        raise newException(TypeError, "Choice must return non-None type.")

    choice.realize(allTypes, known)

method canInfer(lamb: Lambda, known: Known): bool =
    return (lamb.body of Sequence) or
        (lamb.body of Choice and lamb.body in known)
method inferReturnType(lamb: Lambda, known: Known) =
    if lamb.body of Sequence:
        for node in lamb.scoped:
            if node of Adjoinment:
                lamb.realize(rrtText, known)
                break
            elif node of Property:
                lamb.realize(rrtnode, known)
                break
            elif node of Extension:
                lamb.realize(rrtList, known)
                break

        # TODO: Match conditional to new semantics
        if lamb.returnType == rrtNone:
            lamb.realize(rrtText, known)

    elif lamb.body of Choice:
        lamb.realize(lamb.body.returnType, known)

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
