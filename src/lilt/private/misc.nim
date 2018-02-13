
import sequtils
import strutils
import tables

proc `{}`*[T](s: seq[seq[T]], i: int): seq[T] =
    ## Returns s[i] || @[]
    if i >= s.len:
        return @[]
    return s[i]

type BaseError* = object of Exception
    ## "Unimplemented error" for base methods
    ## Motivation: To use base types as interfaces

proc `>$`*(s: string, indentText = ".     "): string =
    ## Ident a block of text
    return s.split("\n").mapIt(indentText & it).join("\n")

template extend*[T](s1: seq[T], s2: seq[T]) =
    for item in s2:
        s1.add(item)

proc `$$`*[K, V](t: Table[K, V]): string =
    var parts: seq[string] = @[]
    for key in t.keys:
            parts.add("$1: $2" % [$key, $t[key]])
    return "{\n$1\n}" % >$ parts.join("\n")

iterator reversed*[T](s: seq[T]): T =
    for idx in countdown(s.len - 1, 0):
            yield s[idx]

proc reversed*[T](s: seq[T]): seq[T] =
    result = @[]
    for item in s.reversed:
        result.add(item)

template findIt*(sequence, pred: untyped): untyped =
    ## Return first item which matches predicate
    ## ex: 2 == @[1, 2, 3, 4, 5].findIt(it * it == 4)
    ## NOTE: Will fail with IndexError because templates are hard :(
    filterIt(sequence, pred)[0]

proc allSame*[T](s: seq[T]): bool =
    ## Return if all items in seq are the same value
    ## Implemented `==` for T must be transitive, i.e.
    ## A == B && B == C -> A == C
    if s.len == 0:
        return true

    let first = s[0]
    for item in s:
        if item != first:
            return false
    return true

template filterOf*(sequence, kind: untyped): untyped =
    ## Filter a sequence to find all values of a specified type
    ## Additionally, map those values to that type
    sequence.filterIt(it of kind).mapIt(kind(it))

template findOf*(sequence, kind: untyped): untyped =
    ## Find the first item in a sequene of a specified type
    ## Additionally, convert that item to said type
    kind(sequence.findIt(it of kind))

template anyOf*(sequence, kind: untyped): untyped =
    sequence.anyIt(it of kind) 

proc asString*(charset: set[char]): string =
    result = ""
    for c in charset:
        result &= c

proc invert*[N, K, V](t: array[N, (K, V)]): array[N, (V, K)] =
    for idx, tup in t:
        result[idx] = (tup[1], tup[0])

template addAll*[T](s1: var seq[T], s2: seq[T]) =
    for item in s2:
        s1.add(item)
