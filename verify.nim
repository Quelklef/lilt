
#[
File for verifying a legitimate (outer) AST
before actually working with it
]#

import outer_ast
import sequtils
import strutils

type InvalidError = object of Exception

proc `{}`[T](s: seq[seq[T]], i: int): seq[T] =
  ## Returns s[i] || @[]
  if i >= s.len:
    return @[]
  return s[i]

proc verify*(ast: outer_ast.Node) =
  ## Verifies a bunch of things about the ast
  ## Fails with InvalidError or silently succeeds
  
  let layers = ast.layers

  block:
    # Firstly, we assert that all Property nodes are top-level in their respective definitions
    # layers[0] will be PROGRAM, [1] will be DEFINITIONs, [2] will be SEQs and CHOICEs, [3] will be top-level nodes
    let topLevelNodes = layers{3}
    # The pooled descendants of the top level nodes ...
    let descendants = topLevelNodes.mapIt(it.descendants).foldl(concat(a, b))
    # ... must not be of type Property
    if descendants.anyIt(it of outer_ast.Property):
      raise newException(InvalidError, "Contains Property node which is not top-level.")

  block:
    # Next, we assert that Property nodes and Extension nodes may not be in the same definition
    let definitions = layers{1}
    for def in definitions:
      let desc = def.descendants
      var
        containsProperty = desc.anyIt(it of outer_ast.Property)
        containsExtension = desc.anyIt(it of outer_ast.Extension)
      if containsProperty and containsExtension:
        raise newException(InvalidError, "Definition of '$1' contains both Property and Extension." % cast[Definition](def).id)