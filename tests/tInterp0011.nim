
include hinterp

test(
  """
  someNode1: val="val"
  someNode2: lav="lav"
  token: _ #[someNode1 | someNode2] _
  """,
  "token",
  "     val  ",
  ~~ {
    "kind": "someNode1",
    "val": "val"
  }
)
