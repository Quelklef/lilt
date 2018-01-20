#[
Handles type inference in the outer ast.

Programs are always typeless (rrtNone)
Definitions are semantically typeless but are a special case; definitions' return types match those
    of their inner rule.

All other nodes' return types have semantic meaning.
]#

import outer_ast
import sequtils
import strutils
import tables
import misc

type TypeError* = object of Exception

method inferReturnType(node: Node) {.base.} =
    raise newException(BaseError, "Cannot infer return type for base type Node. Value given: $1" % $node)

method inferReturnType(prop: Property) =
    # Properties return the same type as their contained node
    prop.returnType = rrtNone

method inferReturnType(adj: Adjoinment) =
    adj.returnType = rrtNone

method inferReturnType(ext: Extension) =
    # Properties return the same type as their contained node
    ext.returnType = rrtNone

method inferReturnType(guard: Guard) =
    guard.returnType = rrtNone

method inferReturnType(op: OnePlus) =
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

method inferReturnType(opt: Optional) =
    if opt.inner.returnType == rrtNode:
        opt.returnType = rrtNone
    else:
        opt.returnType = opt.inner.returnType

method inferReturnType(se: Set) =
    se.returnType = rrtText

method inferReturnType(lit: Literal) =
    lit.returnType = rrtText

method inferReturnType(re: Reference) =
    # Ensure that referencing a defined function
    let definitions = re.ancestors
        .findIt(it of Program)
        .descendants
        .filterIt(it of Definition)
        .mapIt(it.Definition)

    if re.id notin definitions.mapIt(it.id):
        raise newException(TypeError, "No rule '$1'." % re.id)

    re.returnType = definitions.findIt(it.id == re.id).returnType

method inferReturnType(choice: Choice) =
    let innerTypes = choice.contents.mapIt(it.returnType)

    if not allSame(innerTypes):
        raise newException(TypeError, "Choice must be homogenous. Got types: $2" % $innerTypes)

    let allTypes = innerTypes[0]  # Type of all inner nodes
    if allTypes == rrtNone:
        raise newException(TypeError, "Choice must return non-None type.")

    choice.returnType = allTypes

method inferReturnType(se: Sequence) =
    # Note: verify.nim:verify will already have been
    # run on the AST before this is called, so no need
    # to ensure that doesn't contain Extension node and 
    # Property node
    if se.scoped.anyIt(it of Adjoinment or it of Property or it of Extension):
        # Contains statements, so returns nothing
        se.returnType = rrtNone
    else:
        se.returnType = rrtText

method inferReturnType(lamb: Lambda) =
    lamb.returnType = rrtNone  # As a semantic 'nil'

    if lamb.body of Sequence:
        for node in lamb.scoped:
            if node of Adjoinment:
                lamb.returnType = rrtText
                break
            elif node of Property:
                lamb.returnType = rrtNode
                break
            elif node of Extension:
                lamb.returnType = rrtList
                break

        if lamb.returnType == rrtNone:
            lamb.returnType = rrtText

    elif lamb.body of Choice:
        lamb.returnType = lamb.body.returnType

    else:
        assert false

method inferReturnType(def: Definition) =
    discard

method inferReturnType(prog: Program) =
    discard

proc inferReturnTypes*(ast: Node) =
    # First, infer all the return types of the lambdas which
    # contain top-level sequences.
    # We do this first because it can be done very, very easily
    # and other more difficult inferences rely on it
    for lamb in ast.descendants.filterIt(it of Lambda):
        if lamb.Lambda.body of Sequence:
            inferReturnType(lamb)

    # Next, set the return types of definitions to their top-level
    # lambda's return type. This is done as a convention.
    let layers = ast.layers
    let definitionLayer = layers{1}.mapIt(it.Definition)
    for definition in definitionLayer:
        definition.returnType = definition.body.Lambda.returnType

    # Using the known return types, we may infer the return types of the rest of the AST.
    # We infer bottom-up, so that inferences may be made using contained nodes.
    for layer in layers.reversed:
        for node in layer:
            # Skip already known nodes
            if not (node of Definition) and not (node of Lambda):
                inferReturnType(node)
