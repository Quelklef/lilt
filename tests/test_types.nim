
import ../outer_ast
import ../types
import ../parse

import strutils

proc test(testName: string, ast: Program, get_node: proc(prog: Program): Node, expected: RuleReturnType) =
  echo "Running test '$1'" % testName
  var ast = ast  # inferReturnTypes requires var Node for some reason
  inferReturnTypes(ast)
  let node = get_node(ast)
  if node.returnType != expected:
    echo $$node
    echo "Failed test '$1'; expected $2 but got $3" % [testName, $expected, $node.returnType]
    assert false
  echo "Passed"


#[
NODE --> word: val=*<abcdefghijklmnopqrstuvwxyz>
]#
test(
  "Type inference 1",
  newProgram(@[
    newDefinition(
      "word",
      newSequence(@[
        newProperty(
          "val",
          newOptional(newOnePlus(
            newSet("abcdefghijklmnopqrstuvwxyz")
          ))
        ).Node
      ])
    ).Node
  ]),
  proc(prog: Program): Node = prog.definitions[0].Definition.body,  # word
  rrtNode
)


#[
CODE --> sentence: *word
word: <abc>
]#
test(
  "Type inference 2",
  newProgram(@[
    newDefinition(
      "sentence",
      newSequence(@[
        newOptional(newOnePlus(newReference("word"))).Node
      ])
    ).Node,
    newDefinition(
      "word",
      newSequence(@[
        newSet("abc").Node
      ])
    )
  ]),
  proc(prog: Program): Node = prog.definitions[0].Definition.body,
  rrtCode
)

template parseAndTest(testName: string, code: string, get_node: proc(prog: Program): Node, expected: RuleReturnType) =
  let parsed = parseProgram(code).Program
  test(testName, parsed, get_node, expected)

parseAndTest(
  "Type inference 3",
  """
  sentence: ?&word *[" " &word]
  word: val=*<abcd>
  """,
  proc(prog: Program): Node = prog.definitions[0].Definition.body,
  rrtList
)