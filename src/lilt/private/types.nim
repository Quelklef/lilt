#[
Handles type inference in the outer ast.

Programs are always typeless (none(LiltType))
Definitions are semantically typeless but are a special case; definitions' return types match those
    of their inner rule.

All other nodes' return types have semantic meaning.
]#

import options
import strutils
import sequtils
import tables

import base
import outer_ast
import misc
import builtins

type SemanticError* = object of Exception
type TypeError* = object of SemanticError
type ReferenceError* = object of SemanticError

# TODO: Switch to hashset
type Known = seq[ONode]

proc mutates*(node: ONode): bool

method inferReturnType(node: ONode, known: Known): Option[LiltType] {.base.} =
    raise new(BaseError)

method canBeInferred(node: ONode, known: Known): bool {.base.} =
    raise new(BaseError)

#~# Independently typed nodes #~#
# (Meaning that their return type may be inferred regardless of
# whether or not we know the return types of any other nodes in
# the AST.)

template indTypeImpl(nimType, liltType: untyped): untyped =
  method canBeInferred(node: nimType, known: Known): bool =
    return true
  method inferReturnType(prop: nimType, known: Known): Option[LiltType] =
    return liltType

indTypeImpl(outer_ast.Property  , none(LiltType))
indTypeImpl(outer_ast.Adjoinment, none(LiltType))
indTypeImpl(outer_ast.Extension , none(LiltType))
indTypeImpl(outer_ast.Guard     , none(LiltType))
indTypeImpl(outer_ast.Set       , some(ltText))
indTypeImpl(outer_ast.Literal   , some(ltText))
indTypeImpl(outer_ast.Sequence  , some(ltText))
indTypeImpl(outer_ast.Definition, none(LiltType))
indTypeImpl(outer_ast.Program   , none(LiltType))

#~# Dependently typed nodes #~#

method canBeInferred(res: Result, known: Known): bool =
    return res.inner in known
method inferReturnType(res: Result, known: Known): Option[LiltType] =
    if res.inner.returnType == none(LiltType):
        raise newException(TypeError, "Cannot have result of rule that returns type '$1'" % $res.inner.returnType)
    return none(LiltType)

method canBeInferred(op: OnePlus, known: Known): bool =
    return op.inner in known
method inferReturnType(op: OnePlus, known: Known): Option[LiltType] =
    let inner = op.inner

    if inner.returnType == none(LiltType):
        # If typeless, execute statement several times and return nothing
        return none(LiltType)

    case inner.returnType.get:
    of ltText:
        return some(ltText)
    of ltNode:
        return some(ltList)
    else:
        raise newException(TypeError, "Cannot have OnePlus of rule that returns type '$1'" % $inner.returnType)

method canBeInferred(opt: Optional, known: Known): bool =
    return opt.inner in known
method inferReturnType(opt: Optional, known: Known): Option[LiltType] =
    if opt.inner.returnType == none(LiltType):
        return none(LiltType)
    else:
        return opt.inner.returnType

method canBeInferred(re: Reference, known: Known): bool =
    let definitions = re.ancestors
        .findOf(Program)
        .descendants.filterOf(Definition)

    let inDefinitions = re.id in definitions.mapIt(it.id)
    let inBuiltins = re.id in liltBuiltins

    if (not inDefinitions) and (not inBuiltins):
        raise newException(ReferenceError, "No rule named '$1'." % re.id) 

    if inDefinitions:
        return definitions
            .findIt(it.id == re.id)
            .body in known
    if inBuiltins:
        return true  # Since all builtins' return types are known
method inferReturnType(re: Reference, known: Known): Option[LiltType] =
    let inBuiltins = re.id in liltBuiltins

    if not inBuiltins:
        return re.ancestors
            .findOf(Program)
            .descendants
            .filterOf(Definition)
            .findIt(it.id == re.id)
            .body.returnType
    else:
        return liltBuiltins[re.id].returnType

method canBeInferred(choice: Choice, known: Known): bool =
    return choice.children.allIt(it in known)
method inferReturnType(choice: Choice, known: Known): Option[LiltType] =
    let innerTypes = choice.contents.mapIt(it.returnType)

    if not allSame(innerTypes):
        raise newException(TypeError, "Choice must be homogenous. Node '$1' got types: $2" % [choice.toLilt, $innerTypes])

    let allTypes = innerTypes[0]  # Type of all inner nodes
    if allTypes == none(LiltType):
        raise newException(TypeError, "Choice must return non-None type.")

    return allTypes

method canBeInferred(lamb: Lambda, known: Known): bool =
    let scoped = lamb.scoped
    # TODO: Document why the following line is `lamb.body of X` not `scoped.anyOf(X)`
    # I know there's a reason, but I forget
    if lamb.body of Adjoinment or lamb.body of outer_ast.Property or lamb.body of Extension:
        return true
    if scoped.anyOf(Result):
        return scoped.findOf(Result) in known
    else:
        return lamb.body in known
    return false
proc inferReturnTypeUnsafe(lamb: Lambda, known: Known): Option[LiltType] =
    # Semantically meaningless; helper for inferReturnType
    if lamb.body of Choice:
        return lamb.body.returnType

    for node in lamb.scoped:
        if node of Adjoinment:
            return some(ltText)
        elif node of outer_ast.Property:
            return some(ltNode)
        elif node of Extension:
            return some(ltList)
        elif node of Result:
            return node.Result.inner.returnType

    if lamb.body.returnType == none(LiltType):
        return some(ltText)
    else:
        return lamb.body.returnType
method inferReturnType(lamb: Lambda, known: Known): Option[LiltType] =
    result = inferReturnTypeUnsafe(lamb, known)

    if result == some(ltNode):
        let isTopLevel = lamb.parent of Definition
        if not isTopLevel:
            # Only top-level lambdas may return nodes because there is no way to specify type if not top-level
            raise newException(TypeError, "Only top-level Lambdas may return nodes.")

proc inferReturnTypes(ast: ONode) =
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

    when defined(debug):
        echo "Type inference complete:"
        echo $$ast

proc setLambdaReturnTypes(node: ONode) =
    ## Sets the return kind of all top-level lambdas
    for lamb in node.descendants.filterOf(Lambda):
        if lamb.parent of Definition:
            lamb.returnNodeKind = lamb.parent.Definition.id

proc checkTopLevelLambdas(node: ONode) =
    ## Throws an error if any definitions' body mutates but is not in a lambda
    ## Throws an error if any top-level lambdas are redundant
    for def in node.descendants.filterOf(Definition):
        let mutates = def.body.mutates
        if def.body of Lambda:
            if not mutates:
                raise newException(SemanticError, "Definition '$1' contains a reduntant top-level lambda." % def.id)
        else:
            if mutates:
                raise newException(SemanticError, "Definition '$1' contains mutations but not a top-level lambda." % def.id)

#~# Exposed API #~#

proc mutates*(node: ONode): bool =
    ## Returns whether a node is an adjoinment, property, extension, or result or
    ## contains a scoped adjoinment, property, extension, or result
    ## Be careful! This will return `false` for a definition which mutates.
    result = node.scoped2.anyIt(it of Adjoinment or it of outer_ast.Property or it of Extension or it of Result)

proc preprocess*(ast: ONode) =
    ## Infers the return types of the AST, then sets the return types of all Lambdas
    inferReturnTypes(ast)
    setLambdaReturnTypes(ast)

proc validateSemantics*(ast: ONode) =
    ## Throws an error if any mutating definitions' bodies are not lambdas
    checkTopLevelLambdas(ast)
