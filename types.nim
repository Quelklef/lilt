#[
Handles type inference in the outer ast.
]#

import outer_ast
import sequtils
import strutils
import tables
from misc import `{}`, BaseError

# Used when types are invalid, for instance
# `*rule` is invalid if `rule` returns rrtText,
# since lists of text may not be returned
type InvalidType* = object of Exception

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

method inferReturnType(ext: Extension, knownReturnTypes: KnownTypeRules) =
  # Properties return the same type as their contained node
  ext.returnType = ext.inner.returnType

method inferReturnType(guard: Guard, knownReturnTypes: KnownTypeRules) =
  guard.returnType = rrtTypeless

method inferReturnType(op: OnePlus, knownReturnTypes: KnownTypeRules) =
  let inner = op.inner

  if inner.returnType == rrtText:
    op.returnType = rrtText
  elif inner.returnType == rrtNode:
    op.returnType = rrtList
  else:
    raise newException(InvalidType, "Cannot have OnePlus of rule that returns type '$1'" % $inner.returnType)

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
    raise newException(InvalidType, "Rule '$1' has unknown type." % re.id)  # TODO: Bad exception..?
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
    se.returnType = rrtText
  else:
    if children.mapIt(it of Extension).any(id):
      # Run same algo as outlined in inferReturnType(Program)
      let ext = children.filterIt(it of Extension)[0]
      let inner = Extension(ext).inner

      if inner.returnType == rrtText:
        se.returnType = rrtText
      elif inner.returnType == rrtNode:
        se.returnType = rrtList
    elif children.mapIt(it of Property).any(id):
      se.returnType = rrtNode
    else:
      se.returnType = rrtText

method inferReturnType(def: Definition, knownReturnTypes: KnownTypeRules) =
  def.returnType = rrtTypeless

method inferReturnType(prog: Program, knownReturnTypes: KnownTypeRules) =
  prog.returnType = rrtTypeless

proc inferReturnTypes*(ast: Node) =
  let layers = ast.layers
  let definitionLayer = layers{1}

  var returnTypeTable: KnownTypeRules = initTable[string, outer_ast.RuleReturnType]()

  # First, infer types of definitons and add to the table
  var definitionsToInfer: seq[Definition] = definitionLayer.mapIt(it.Definition)
  while true:
    var inferredAtLeastOneDefiniton = false
    for idx, definition in definitionsToInfer:
      # Get top-level nodes. These are the ones contained in SEQUENCE/CHOICE contained in DEFINITON
      let topLevel = definition.layers{2}
      var infferedReturnType = rrtTypeless  # rrtTypeless as a substitute for `nil`

      var containsNoExtensionsAndNoProperties = true

      for node in topLevel:
        if node of Property:
          infferedReturnType = rrtNode
          containsNoExtensionsAndNoProperties = false
          inferredAtLeastOneDefiniton = true
          break

      if infferedReturnType == rrtTypeless:  # If not yet inferred
        for node in definition.descendants:
          if node of Extension:
            containsNoExtensionsAndNoProperties = false
            # Extensions may be used in a rule that returns List, or Text.
            # This is because Extensions are used to concatenate lists and also
            # to concatenate strings.
            # As such, we can not immediately infer whether the rule's return type
            # is list or text.
            # We do know, however, if one Extension's inner node returns Node, then
            # the rule is rrtList; if one Extension's inner node returns Text, then
            # the rule is rrtText.
            let inner = Extension(node).inner
            # Infer the return type of the inner node as best we can right now
            var inferredInner = false
            try:
              inferReturnType(inner, returnTypeTable)
              inferredInner = true
            except InvalidType:
              discard

            if inferredInner:
              if inner.returnType == rrtText:
                infferedReturnType = rrtText
                inferredAtLeastOneDefiniton = true
              elif inner.returnType == rrtNode:
                infferedReturnType = rrtList
                inferredAtLeastOneDefiniton = true
              else:
                # Unable to infer type
                raise newException(InvalidType, "Cannot infer type for node $1" % $inner)
              break
            else:
              # Perhaps we can infer in the next pass
              discard

      # If not rrtNode or rrtList, rrtText.
      if infferedReturnType == rrtTypeless and containsNoExtensionsAndNoProperties:
        infferedReturnType = rrtText
        inferredAtLeastOneDefiniton = true

      if infferedReturnType != rrtTypeless:
        #echo "Inferred type $1 of $2" % [$infferedReturnType, $definition]
        returnTypeTable[definition.id] = infferedReturnType
        definitionsToInfer.del(idx)

    if not inferredAtLeastOneDefiniton:
      break

  # Next, infer the types of the rest of the AST
  for definition in definitionLayer:
    let innerLayers = definition.layers
    for layer in innerLayers[1 .. innerLayers.len - 1].reversed:  # [1..~] because we want to exclude the actual definition
      for node in layer:
        inferReturnType(node, returnTypeTable)
