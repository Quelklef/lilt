
import ../outer_ast
import ../parse

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
      newSequence(@[
        newOptional(newOnePlus(newSet("abcdefg"))).Node
      ])
    ).Node,
    newDefinition(
      "string",
      newSequence(@[
        newOnePlus(newReference("char")).Node
      ])
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
      newSequence(@[
        newExtension(newReference("arg")),
        newOptional(newOnePlus(
          newSequence(@[
            newLiteral(" "),
            newExtension(newReference("arg"))
          ])
        ))
      ])
    ).Node
  ])
)

#[
test(
  "Comments 1",
  """
  . Block comment!
  .... More dots inside the comment ...... .. . .. . .. . . .
  vowel: <aeiou>.This is a comment
  . . .. more dots b.c why not
  . Let's add some code in the comments:
  . code: <code>
  """,
  newProgram(@[
    newDefinition(
      "vowel",
      newSequence(@[
        newSet("aeiou").Node
      ])
    ).Node
  ])
)
]#