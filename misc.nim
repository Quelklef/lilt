
import sequtils

proc `{}`*[T](s: seq[seq[T]], i: int): seq[T] =
  ## Returns s[i] || @[]
  if i >= s.len:
    return @[]
  return s[i]

type BaseError* = object of Exception
  ## To be raised when calling a base method with no implementation
