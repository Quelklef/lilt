#[
Handles type inference in the outer ast.
]#

import outer_ast
import sequtils
import strutils
import tables
from misc import `{}`, BaseError

type TypeError* = object of Exception

# Maps the name of rules to their type
type KnownTypeRules = Table[string, outer_ast.RuleReturnType]

iterator reversed[T](s: seq[T]): T =
    for idx in countdown(s.len - 1, 0):
        yield s[idx]

method inferReturnType(node: Node, knownReturnTypes: KnownTypeRules) {.base.} =
    raise newException(BaseError, "Cannot infer return type for base type Node. Value given: $1" % $node)

method inferReturnType(prop: Property, knownReturnTypes: KnownTypeRules) =
    # Properties return the same type as their contained node
    prop.returnType = rrtTypeless

method inferReturnType(adj: Adjoinment, knownReturnTypes: KnownTypeRules) =
    adj.returnType = rrtTypeless

method inferReturnType(ext: Extension, knownReturnTypes: KnownTypeRules) =
    # Properties return the same type as their contained node
    ext.returnType = rrtTypeless

method inferReturnType(guard: Guard, knownReturnTypes: KnownTypeRules) =
    guard.returnType = rrtTypeless

method inferReturnType(op: OnePlus, knownReturnTypes: KnownTypeRules) =
    let inner = op.inner

    case inner.returnType:
    of rrtText:
        op.returnType = rrtText
    of rrtNode:
        op.returnType = rrtList
    of rrtTypeless:
        # If typeless, execture statement several times
        op.returnType = rrtTypeless
    else:
        raise newException(TypeError, "Cannot have OnePlus of rule that returns type '$1'" % $inner.returnType)

method inferReturnType(opt: Optional, knownReturnTypes: KnownTypeRules) =
    if opt.inner.returnType == rrtNode:
        opt.returnType = rrtTypeless

    opt.returnType = opt.inner.returnType

method inferReturnType(se: Set, knownReturnTypes: KnownTypeRules) =
    se.returnType = rrtText

method inferReturnType(lit: Literal, knownReturnTypes: KnownTypeRules) =
    lit.returnType = rrtText

method inferReturnType(re: Reference, knownReturnTypes: KnownTypeRules) =
    if re.id notin knownReturnTypes:
        raise newException(TypeError, "Rule '$1' has unknown type." % re.id)
    re.returnType = knownReturnTypes[re.id]

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

method inferReturnType(choice: Choice, knownReturnTypes: KnownTypeRules) =
    let innerTypes = choice.contents.mapIt(it.returnType)

    if not allSame(innerTypes):
        raise newException(TypeError, "Choice must be homogenous.")

    let allTypes = innerTypes[0]  # Type of all inner nodes
    choice.returnType = allTypes

method inferReturnType(se: Sequence, knownReturnTypes: KnownTypeRules) =
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

method inferReturnType(def: Definition, knownReturnTypes: KnownTypeRules) =
    def.returnType = rrtTypeless

method inferReturnType(prog: Program, knownReturnTypes: KnownTypeRules) =
    prog.returnType = rrtTypeless

proc inferDefinitionReturnTypes*(ast: Node): Table[string, RuleReturnType] =
    # Infer the return types of all rules in definitions, and return as a table
    # mapping definition.id -> rrt

    let definitionLayer = ast.layers{1}
    result = initTable[string, outer_ast.RuleReturnType]()

    # First, infer types of definitons and add to the table
    for definition in definitionLayer.mapIt(it.Definition):

        # Get top-level nodes. These are the ones contained in SEQUENCE/CHOICE contained in DEFINITON
        var infferedReturnType = rrtTypeless  # rrtTypeless as a substitute for `nil`

        for node in definition.descendants:
            if node of Property:
                infferedReturnType = rrtNode
                break
            elif node of Extension:
                infferedReturnType = rrtList
                break
            elif node of Adjoinment:
                infferedReturnType = rrtText
                break

        if infferedReturnType == rrtTypeless:
            # If it has none, it returns text
            infferedReturnType = rrtText

        result[definition.id] = infferedReturnType

proc inferReturnTypes*(ast: Node) =
    let layers = ast.layers
    let definitionLayer = layers{1}

    let returnTypeTable = inferDefinitionReturnTypes(ast)

    # Next, infer the types of the rest of the AST
    for definition in definitionLayer:
        let innerLayers = definition.layers
        for layer in innerLayers[1 .. innerLayers.len - 1].reversed:  # [1..~] because we want to exclude the actual definition
            for node in layer:
                inferReturnType(node, returnTypeTable)
