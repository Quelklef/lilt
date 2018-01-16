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
from misc import `{}`, BaseError, reversed, findIt

type TypeError* = object of Exception

# Maps the name of rules to their type
type KnownTypeRules = Table[string, outer_ast.RuleReturnType]

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
        # If typeless, execture statement several times
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
    let programs = re.ancestors
        .findIt(it of Program)
        .Program.descendants
        .filterIt(it of Definition)
        .mapIt(it.Definition)

    if re.id notin programs.mapIt(it.id):
        raise newException(TypeError, "Rule '$1' has unknown type." % re.id)

    re.returnType = programs.findIt(it.id == re.id).returnType

proc allSame[T](s: seq[T]): bool =
    ## Return if all items in seq are the same value
    ## Implemented `==` for T must be transitive, i.e.
    ## A == B && B == C ==> A == C
    if s.len == 0:
        return true

    let first = s[0]
    for item in s:
        if item != first:
            return false
    return true

method inferReturnType(choice: Choice) =
    let innerTypes = choice.contents.mapIt(it.returnType)

    if not allSame(innerTypes):
        raise newException(TypeError, "Choice must be homogenous.")

    let allTypes = innerTypes[0]  # Type of all inner nodes
    choice.returnType = allTypes

method inferReturnType(se: Sequence) =
    # Note: verify.nim:verify will already have been
    # run on the AST before this is called, so no need
    # to ensure that doesn't contain Extension node and 
    # Property node
    let descendants = se.descendants
    let isTopLevel = se.parent of Definition

    if not isTopLevel:
        se.returnType = rrtText
    else:
        var hasProp, hasAdj, hasExt = false

        for node in descendants:
            if node of Property:
                hasProp = true
            elif node of Adjoinment:
                hasAdj = true
            elif node of Extension:
                hasExt = true

            if hasProp and hasAdj and hasExt:
                break  # No more searching needs to be done

        # At most one must be true
        if [hasProp, hasAdj, hasExt].mapIt(if it: 1 else: 0).foldl(a + b) > 1:
            raise newException(TypeError, "Cannot combine properties and ajointments and extensions.")

        if hasProp:
            se.returnType = rrtNode
        elif hasAdj:
            se.returnType = rrtText
        elif hasExt:
            se.returnType = rrtList
        else:
            se.returnType = rrtText

method inferReturnType(def: Definition) =
    discard

method inferReturnType(prog: Program) =
    discard

proc inferDefinitionReturnTypes*(ast: Node) =
    let definitionLayer = ast.layers{1}.mapIt(it.Definition)

    for definition in definitionLayer:
        for node in definition.descendants:
            if node of Adjoinment:
                definition.returnType = rrtText
                break
            elif node of Property:
                definition.returnType = rrtNode
                break
            elif node of Extension:
                definition.returnType = rrtList
                break

        if definition.returnType == rrtNone:
            # If it has none, it returns text
            definition.returnType = rrtText

proc inferReturnTypes*(ast: Node) =
    let layers = ast.layers
    let definitionLayer = layers{1}

    inferDefinitionReturnTypes(ast)

    # Next, infer the types of the rest of the AST
    for definition in definitionLayer:
        let innerLayers = definition.layers
        for layer in innerLayers[1 .. innerLayers.len - 1].reversed:  # [1..~] because we want to exclude the actual definition
            for node in layer:
                inferReturnType(node)
