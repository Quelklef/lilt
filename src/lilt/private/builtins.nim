
import strutils
import tables
import options

import base
import strfix
import misc

type Builtin = tuple[returnType: Option[LiltType], rule: Rule]

template toSingleRule(charset: set[char]): Builtin =
    block:
        proc rule(head: int, text: string, lambdaState: LiltValue): RuleVal =
            if text{head} in charset:
                return RuleVal(head: head + 1, lambdaState: lambdaState, val: initLiltValue($text{head}).some)
            raise newException(RuleError, "Expected character in '$1'" % charset.asString)
        (returnType: some(ltText), rule: rule.Rule)

proc toMultiRule(charset: set[char], lowerBound=0): Builtin =
    ## Returns a rule which consumes contiguous text in the given charset
    ## Errors if consumed <lowerBound characters
    block:
        proc rule(head: int, text: string, lambdaState: LiltValue): RuleVal =
            var endHead = head

            while text{endHead} in charset:
                inc(endHead)

            if endHead - head < lowerBound:
                raise newException(RuleError, "Did not consume at least $1 characters." % $lowerBound)

            return RuleVal(
                head: endHead,
                lambdaState: lambdaState,
                val: initLiltValue(text[head ..< endHead]).some
            )
        (returnType: some(ltText), rule: rule.Rule)

# Would call it 'builtins' but that was causing me trouble.
# Probably because this file is builtins.nim, so `import builtins` then `builtins[]` is iffy
let liltBuiltins*: TableRef[string, Builtin] = {
    "newline": {'\l', '\c'}.toMultiRule(1),
    "whitespace": strutils.Whitespace.toSingleRule,
    "_": strutils.Whitespace.toMultiRule,
    "any": (strutils.AllChars - {'\0'}).toSingleRule,
    "lower": {'a' .. 'z'}.toSingleRule,
    "upper": {'A' .. 'Z'}.toSingleRule,
    "alpha": strutils.Letters.toSingleRule,
    "digit": strutils.Digits.toSingleRule,
    "alphanum": toSingleRule(strutils.Letters + strutils.Digits),
}.newTable
