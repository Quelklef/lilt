
import ../parse
import ../inner_ast
import ../outer_ast
import ../interpret

import tables
import strutils

proc test(testName: string, code: string, rule: string, input: string, expected: inner_ast.Node) =
  # Test must expect a node, not a list or code.
  echo "Running test '$1'" % testName
  let parsed = parseProgram(code).Program
  let ctx: LiltContext = interpretAst(parsed)
  let ruleFunc: Rule = ctx[rule]
  let res: RuleVal = ruleFunc(0, input, newCurrentResult())
  let resNode = res.nodeVal

  if resNode != expected:
    echo "Failed"
    echo "Expected:\n$1\n\nBut got:\n$2" % [$$expected, $$resNode]
    assert false
  echo "Passed"

test(
  "Interpreter test 1",
  """
  sentenceNode: sentence=sentence
  sentence: &word *[", " &word]
  word: val=*<abcdefghijklmnopqrstuvwxyz>
  """,
  "sentenceNode",
  "several, words, in, a, sentence",
  newBranch(
    "sentenceNode",
    {
      "sentence": @[
        newBranch("word", {"val": "several"}.toTable),
        newBranch("word", {"val": "words"}.toTable),
        newBranch("word", {"val": "in"}.toTable),
        newBranch("word", {"val": "a"}.toTable),
        newBranch("word", {"val": "sentence"}.toTable)
      ]
    }.toTable
  )
)

test(
  "Guard test 1",
  """
  alpha: <abcdefghijklmnopqrstuvwxyz>
  consonant: !<aeiou> alpha
  consoWord: letters=*consonant
  """,
  "consoWord",
  "bhjdsjkeaklj",
  newBranch(
    "consoWord",
    {
      "letters": "bhjdsjk"
    }.toTable
  )
)

test(
  "String extension 1",
  """
  vowel: <aeiou>
  vowels: *&vowel
  nVowels: val=vowels
  """,
  "nVowels",
  "aeeoouuiaobbbbboisoso",
  newBranch(
    "nVowels",
    {
      "val": "aeeoouuiao"
    }.toTable
  )
)

test(
  "Ex: Function definition",
  """
  tIdentif: +<abcdefghijklmnopqrstuvwxyz>
  nArg: id=tIdentif
  lArgs: &nArg *[", " &nArg]
  nFuncdef: "function " id=tIdentif "(" args=lArgs ");"
  """,
  "nFuncdef",
  "function multiply(argone, argtwo, argthree);",
  newBranch(
    "nFuncdef",
    initTable[string, inner_ast.Node](),
    {
      "args": @[
        newBranch("nArg", {"id": "argone"}.toTable),
        newBranch("nArg", {"id": "argtwo"}.toTable),
        newBranch("nArg", {"id": "argthree"}.toTable)
      ]
    }.toTable,
    {
      "id": "multiply",
    }.toTable
  )
)