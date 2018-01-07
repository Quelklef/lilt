#[
Handles type inference in the outer ast.
]#

import outer_ast
import sequtils
import strutils
import tables

type BaseError = object of Exception

# Used when types are invalid, for instance
# `*rule` is invalid if `rule` returns rrtCode,
# since lists of code may not be returned
type InvalidType = object of Exception

# Maps the name of rules to their type
type KnownTypeRules = Table[string, outer_ast.RuleReturnType]

iterator reversed[T](s: seq[T]): T =
  for idx in countdown(s.len - 1, 0):
    yield s[idx]

method inferReturnType(node: Node, knownReturnTypes: KnownTypeRules) {.base.} =
  raise newException(BaseError, "Cannot infer return type for base type Node. Value given: $1" % $node)

method inferReturnType(prop: Property, knownReturnTypes: KnownTypeRules) =
  # Properties return the same type as their contained node
  prop.returnType = prop.inner.returnType

method inferReturnType(ext: Extension, knownReturnTypes: KnownTypeRules) =
  # Properties return the same type as their contained node
  ext.returnType = ext.inner.returnType

method inferReturnType(guard: Guard, knownReturnTypes: KnownTypeRules) =
  guard.returnType = rrtCode  # Guards always return ""

method inferReturnType(op: OnePlus, knownReturnTypes: KnownTypeRules) =
  let inner = op.inner

  if inner.returnType == rrtCode:
    op.returnType = rrtCode
  elif inner.returnType == rrtNode:
    op.returnType = rrtList
  else:
    raise newException(InvalidType, "Cannot have OnePlus of rule that returns type '$1'" % $inner.returnType)

method inferReturnType(opt: Optional, knownReturnTypes: KnownTypeRules) =
  # Fails on inner return type List -> returns []
  # Fails on inner return type Code -> returns ""
  let inner = opt.inner

  if inner.returnType in [rrtList, rrtCode]:
    opt.returnType = opt.inner.returnType
  else:
    raise newException(InvalidType, "Cannot have Optional of rule that returns type '$1'" % $inner.returnType)

method inferReturnType(se: Set, knownReturnTypes: KnownTypeRules) =
  se.returnType = rrtCode

method inferReturnType(lit: Literal, knownReturnTypes: KnownTypeRules) =
  lit.returnType = rrtCode

method inferReturnType(re: Reference, knownReturnTypes: KnownTypeRules) =
  if re.id notin knownReturnTypes:
    raise newException(InvalidType, "Rule '$1' has unknown type." % re.id)  # TODO: Bad exception
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
    raise newException(InvalidType, "Choice must be homogenous.")

  let allTypes = innerTypes[0]  # Type of all inner nodes
  choice.returnType = allTypes

proc id[T](v: T): T = v

method inferReturnType(se: Sequence, knownReturnTypes: KnownTypeRules) =
  # Note: verify.nim:verify will already have been
  # run on the AST before this is called, so no need
  # to ensure that doesn't contain Extension node and 
  # Property node
  let children = se.children
  let isTopLevel = se.parent of Definition

  if not isTopLevel:
    se.returnType = rrtCode
  else:
    if children.mapIt(it of Extension).any(id):
      se.returnType = rrtList
    elif children.mapIt(it of Property).any(id):
      se.returnType = rrtNode
    else:
      se.returnType = rrtCode

method inferReturnType(def: Definition, knownReturnTypes: KnownTypeRules) =
  discard  # Keeps rrtTypeless

method inferReturnType(prog: Program, knownReturnTypes: KnownTypeRules) =
  discard  # Keeps rrtTypeless

proc inferReturnTypes*(ast: Node) =
  #[
  To infer return types, we iterate over the ast from deepest to most
  shallow node, building each time on the types of the previous.
  ]#
  let layers = ast.layers
  var returnTypeTable: KnownTypeRules = initTable[string, outer_ast.RuleReturnType]()

  let definitionLayer = layers[1]  # TODO: layers[1] will fail if no definitions
  for definition in definitionLayer:
    let innerLayers = definition.layers
    for layer in innerLayers[1 .. innerLayers.len - 1].reversed:  # [1..~] because we want to exclude the actual definition
      for node in layer:
        inferReturnType(node, returnTypeTable)

    # Record type of defined Rule
    let definitionNode = outer_ast.Definition(definition)
    returnTypeTable[definitionNode.id] = definitionNode.body.returnType