
import ../src/lilt/private/outer_ast
import ../src/lilt/private/parse

import strutils

template test(testName: string, code: string, expected: Program) =
  let parsed = parseProgram(code)
  echo "Running test '$1'" % testName
  if parsed != expected:
    echo "Failed; got ast:"
    echo $$parsed
    assert false
  echo "Passed"


test(
  "Parsing 1",
  """
  char: *<abcdefg>
  string: +char
  """,
  newProgram(@[
    newDefinition(
      "char",
      newLambda(
        newOptional(newOnePlus(newSet("abcdefg"))).Node
      )
    ).Node,
    newDefinition(
      "string",
      newLambda(
        newOnePlus(newReference("char")).Node
      )
    )
  ])
)

test(
  "Extensions 1",
  """
  args: &arg *[" " &arg]
  """,
  newProgram(@[
    newDefinition(
      "args",
      newLambda(newSequence(@[
        newExtension(newReference("arg")),
        newOptional(newOnePlus(
          newSequence(@[
            newLiteral(" "),
            newExtension(newReference("arg"))
          ])
        ))
      ]))
    ).Node
  ])
)

test(
  "Adjoinment 1",
  """
  handleString: "\"" $*char "\""
  """,
  newProgram(@[
    newDefinition(
      "handleString",
      newLambda(newSequence(@[
        newLiteral("\""),
        newAdjoinment(newOptional(newOnePlus(newReference("char")))),
        newLiteral("\"")
      ]))
    ).Node
  ])
)

test(
  "Comments 1",
  """
   /( Block comment! )
   / Line comment
  vowel: <aeiou>/This is a comment
  /(/( nest a comment
  Let's add /() some code in the comments:
  code: <code> ))
  """,
  newProgram(@[
    newDefinition(
      "vowel",
      newLambda(newSet("aeiou"))
    ).Node
  ])
)

test(
  "Lambda 1",
  "lambTest: { <a> }",
  newProgram(@[
    newDefinition(
      "lambTest",
      newLambda(
        newLambda(newSet("a"))
      )
    ).Node
  ])
)
