
import sequtils
import strutils

proc `{}`*[T](s: seq[seq[T]], i: int): seq[T] =
  ## Returns s[i] || @[]
  if i >= s.len:
    return @[]
  return s[i]

type BaseError* = object of Exception
  ## To be raised when calling a base method with no implementation

proc `>$`*(s: string, indentText = "\t"): string =
    ## Ident a block of text
    return s.split("\n").mapIt(indentText & it).join("\n")
