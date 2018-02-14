
import logging
import tables
import sequtils
import strutils
import logging

import misc
import outer_ast

type Hint = ref object of RootObj
    text*: string
    blame*: ONode

proc `$`(h: Hint): string =
    return $(h[])

template initHint(warningType: typedesc, ast: ONode, msg: string): untyped =
    var w: warningType
    new(w)
    w.blame = ast
    w.text = msg
    w

var checks: seq[proc(ast: ONode): seq[Hint]] = @[]

#~# Check if set contains duplicate characters #~#

type SetContainsDuplicates = ref object of Hint

proc getDuplicates(s: string): set[char] =
    var counts = initCountTable[char]()
    for c in s:
        counts.inc(c)

    result = {}
    for c in s:
        if counts[c] > 1:
            result.incl(c)

proc setContainsDuplicate(ast: ONode): seq[Hint] =
    result = @[]
    let sets = ast.descendants.filterOf(Set)
    for s in sets:
        let dupes = getDuplicates(s.charset)
        if dupes.card > 0:
            let warning = initHint(
                SetContainsDuplicates,
                s,
                "Set contains duplicates: $1" % dupes.mapIt("\"$1\"" % $it).join(", ")
            )
            result.add(warning)
checks.add(setContainsDuplicate)


proc getHints*(ast: ONode): seq[Hint] =
    result = @[]
    for check in checks:
        result.addAll(check(ast))

proc logHints*(ast: ONode) =
    let hints = getHints(ast)
    for hint in hints:
        warn(hint.text)
