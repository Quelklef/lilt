
import sequtils
import strutils
import tables

proc `{}`*[T](s: seq[seq[T]], i: int): seq[T] =
  ## Returns s[i] || @[]
  if i >= s.len:
    return @[]
  return s[i]

type BaseError* = object of Exception
  ## To be raised when calling a base method with no implementation

proc `>$`*(s: string, indentText = ".   "): string =
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

iterator reversed[T](s: seq[T]): T =
    for idx in countdown(s.len - 1, 0):
        yield s[idx]
