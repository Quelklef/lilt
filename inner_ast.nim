#[
Definiton of the AST _inside_ Lilt;
that is, the AST which is a Lilt construct;
that is, the AST used when _running_ Lilt code.

Lilt nodes are either code (atoms / leaves), which contain only raw code,
or branches, which tonain:
  - A kind*, which is conteptually an enumeration but
    represented as a string
  - A table of properties, from string to Node
  - A sequence of children
]#

import tables

type Node* = object
  isLeaf*: bool
  code*: string  # iff isLeaf

  # iff not isLeaf; is branch:
  kind*: string
  props*: Table[string, Node]
  children*: seq[Node]

template isBranch*(node: Node): bool =
  not node.isLeaf

const noProps = initTable[string, Node]()

proc newCode*(code: string): Node =
  return Node(isLeaf: true, code: code, kind: nil, props: noProps, children: @[])

proc newBranch*(kind: string, props: Table[string, Node], children: seq[Node]): Node =
  return Node(isLeaf: false, code: nil, kind: kind, props: props, children: children)

# Convenience methods

template extend[T](s1: seq[T], s2: seq[T]) =
  for item in s2:
    s1.add(item)

proc descendants*(node: Node): seq[Node] =
  ## Recursively iterates through all descendants of given node.
  
  result = node.children
  var head = 0  # Index of current node we're unpacking

  while head < result.len:
    let current_node = result[head]
    if current_node.isBranch:
      result.extend(current_node.children)
    inc(head)