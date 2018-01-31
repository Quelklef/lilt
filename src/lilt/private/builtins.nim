
import strutils
import tables

import base
import strfix

type Builtin = tuple[rrt: RuleReturnType, rule: Rule]

proc joinItems(cs: set[char]): string =
    result = ""
    for c in cs:
        result &= $c

template toSingleRule(charset: set[char]): Builtin =
    block:
        proc rule(head: int, text: string, lambdaState: LambdaState): RuleVal =
            if text{head} in charset:
                return RuleVal(head: head + 1, lambdaState: lambdaState, kind: rrtText, text: $text{head})
            raise newException(RuleError, "Expected character in '$1'" % charset.joinItems)
        (rrt: rrtText, rule: rule.Rule)

proc toMultiRule(charset: set[char], lowerBound=0): Builtin =
    ## Returns a rule which consumes contiguous text in the given charset
    ## Errors if consumed <lowerBound characters
    block:
        proc rule(head: int, text: string, lambdaState: LambdaState): RuleVal =
            var endHead = head

            while text{endHead} in charset:
                inc(endHead)

            if endHead - head < lowerBound:
                raise newException(RuleError, "Did not consume at least $1 characters." % $lowerBound)

            return RuleVal(
                head: endHead,
                lambdaState: lambdaState,
                kind: rrtText,
                text: text[head ..< endHead]
            )
        (rrt: rrtText, rule: rule.Rule)

# Would call it 'builtins' but that was causing me trouble.
# Probably because this file is builtins.nim, so `import builtins` then `builtins[]` is iffy
let liltBuiltins*: TableRef[string, tuple[rrt: RuleReturnType, rule: Rule]] = {
    "newline": {'\l', '\c'}.toMultiRule(1),
    "whitespace": strutils.Whitespace.toSingleRule,
    "_": strutils.Whitespace.toMultiRule,
    "any": strutils.AllChars.toSingleRule,
    "lower": {'a' .. 'z'}.toSingleRule,
    "upper": {'A' .. 'Z'}.toSingleRule,
    "alpha": strutils.Letters.toSingleRule,
    "digit": strutils.Digits.toSingleRule,
    "alphanum": toSingleRule(strutils.Letters + strutils.Digits),
}.newTable
