
import strutils

import ../src/lilt/private/inner_ast
import json

template test(testName: string, ast: Node, json: JsonNode) =
  echo "Running test '$1'" % testName
  if ast.toJson != json:
    echo "Failed"
    echo "Expected \n$1\nbut got \n$2\n" % [json.pretty, ast.toJson.pretty]
    assert false
  echo "Passed"

test(
  "JSON test 1",
  initNode(
    "sampleRule",
    {
      "name": initProperty("Connor Nguyen"),
      "age": initProperty(initNode(
        "number",
        {"value": "17"}
      ))
    }
  ),
  %* {
    "kind": "sampleRule",
    "name": "Connor Nguyen",
    "age": {
      "kind": "number",
      "value": "17"
    }
  }
)
