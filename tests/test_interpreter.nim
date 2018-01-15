
import ../parse
import ../verify
import ../types
import ../inner_ast
import ../outer_ast
import ../interpret

import tables
import strutils

proc test(testName: string, code: string, rule: string, input: string, expected: inner_ast.Node) =
  # Test must expect a node, not a list or code.
  echo "Running test '$1'" % testName
  let ast = parseProgram(code).Program
  let res: RuleVal = interpret(code, rule, input)

  var resNode: inner_ast.Node
  case res.kind:
  of rrtNode:
    resNode = res.node
  else:
    assert false

  if resNode != expected:
    echo "Failed"
    echo "Expected:\n$1\n\nBut got:\n$2" % [$$expected, $$resNode]
    assert false
  echo "Passed"

# The following procs exist only to reduce syntactic bulk and
# increase readibility of the following code.
# When reading, they may be safely ignored.
proc `~`(text: string): inner_ast.Property = 
  return newProperty(text)

proc `~`(node: inner_ast.Node): inner_ast.Property =
  return newProperty(node)

proc `~`(list: seq[inner_ast.Node]): inner_ast.Property =
  return newProperty(list)

test(
  "Interpreter test 1",
  """
  sentenceNode: sentence=sentence
  sentence: &word *[", " &word]
  word: val=*<abcdefghijklmnopqrstuvwxyz>
  """,
  "sentenceNode",
  "several, words, in, a, sentence",
  newNode(
    "sentenceNode",
    {
      "sentence": @[
        newNode("word", {"val": "several"}),
        newNode("word", {"val": "words"}),
        newNode("word", {"val": "in"}),
        newNode("word", {"val": "a"}),
        newNode("word", {"val": "sentence"}),
      ]
    }
  )
)

test(
  "Guard test 1",
  """
  alpha: <abcdefghijklmnopqrstuvwxyz>
  consonant: !<aeiou> $alpha
  consoWord: letters=*consonant
  """,
  "consoWord",
  "bhjdsjkeaklj",
  newNode(
    "consoWord",
    {"letters": "bhjdsjk"}
  )
)

test(
  "String extension 1",
  """
  vowel: <aeiou>
  vowels: *$vowel
  nVowels: val=vowels
  """,
  "nVowels",
  "aeeoouuiaobbbbboisoso",
  newNode(
    "nVowels",
    {"val": "aeeoouuiao"}
  )
)

test(
  "Ex: Function definition",
  """
  tIdentif: +<abcdefghijklmnopqrstuvwxyz>
  nArg: id=tIdentif
  lArgs: ?&nArg *[", " &nArg]
  nFuncdef: "function " id=tIdentif "(" args=lArgs ");"
  """,
  "nFuncdef",
  "function multiply(argone, argtwo, argthree);",
  newNode(
    "nFuncdef",
    {
      "args": ~ @[
        newNode("nArg", {"id": "argone"}),
        newNode("nArg", {"id": "argtwo"}),
        newNode("nArg", {"id": "argthree"})
      ],
      "id": ~"multiply",
    }
  )
)