
import strutils
import tables
import os

### Semantic constructs ###

# Thrown by a Rule when it is passed code which does
# not match it
type DidntMatchError = object of Exception

# A "Rule" is essentially a regex-matcher; it accepts
# some string and either returns an integer, or throws
# an DidntMatchError exception.
# The integer returned should be the number of chars
# in the given string that the Rule matches (0+).
type Rule = proc(code: string): int

# User-definned rules
var definedRules = newTable[string, Rule]()

proc createQuestionRule(optional: Rule): Rule =
    proc questionRule(code: string): int =
        try:
            return optional(code)
        except DidntMatchError:
            return 0  # Instead of failing, succeeds with length 0
    return questionRule

proc createStarRule(repeated: Rule): Rule =
    proc starRule(code: string): int =
        var head = 0
        while true:
            try:
                head += repeated(code[head ..< code.len])
            except DidntMatchError:
                break
        return head
    return starRule

proc createPlusRule(repeated: Rule): Rule =
    var starRule = createStarRule(repeated)
    proc plusRule(code: string): int =
        result = starRule(code)
        if result == 0:
            raise newException(DidntMatchError, "Expected at least one repitition of something.")
    return plusRule

proc createOrRule(optionsParam: openarray[Rule]): Rule =
    var options: seq[Rule] = @optionsParam  # Needed to sidestep some weird error
    proc orRule(code: string): int =
        # Returns first matching
        for ind, rule in options:
            try:
                return rule(code)
            except DidntMatchError:
                discard
        raise newException(DidntMatchError, "Did not match any rules.")
    return orRule

proc createSequenceRule(rulesParam: openarray[Rule]): Rule =
    # Creates a rule which requires code to follow a set of rules in sequence
    var rules: seq[Rule] = @rulesParam
    proc sequenceRule(code: string): int =
        var head = 0
        for rule in rules:
            head += rule(code[head ..< code.len])
        return head
    return sequenceRule

proc createLiteralRule(literal: string): Rule =
    ## Takes a string and returns a Rule which matches
    ## that string exactly.
    proc literalRule(code: string): int =
        if not code.startsWith(literal):
            raise newException(DidntMatchError, "Expected literal '$1' but got '$2'" % [literal, code])
        # Else, succeed
        return literal.len
    return literalRule

### Parsing ###

# Thrown while parsing, rather than by a Rule,
# when parsing did not match
type ParsingError = object of ValueError

# Parsing functions will return a `ParseValue`
# which gives the number of characters consumed
# and the Rule created from it
type ParseValue = tuple[len: int, rule: Rule]

type ParserFunction = proc(code: string): ParseValue

## Debug

var debugDepth = 0

proc debug*(str: string) =
    echo ".\t".repeat(debugDepth) & str

proc pushd*(str: string) =
    debug(str)
    inc(debugDepth)

proc popd*(str: string) =
    dec(debugDepth)
    debug(str)

proc debugWrap(parser: ParserFunction, name: string): ParserFunction =
    proc decorated(code: string): ParseValue =
        pushd("Attemping to parse <$1>" % name)
        var ret: ParseValue
        try:
            ret = parser(code)
        except ParsingError as e:
            popd("<$1> failed: $2" % [name, e.msg])
            raise e
        popd("<$1> succeeded, consumed [$2]" % [name, code[0 ..< ret.len]])
        return ret
    return decorated

## End debug

proc remove(str: string, removed: char): string =
    ## Removes all instances of a character from a string
    result = ""
    for c in str:
        if c != removed:
            result &= c

const
    lowers = "abcdefghijklmnopqrstuvwxyz"
    uppers = lowers.toUpper
    alpha = lowers & uppers
    digits = "1234567890"
    alphanum = alpha & digits
    symbols = "!@#$%^&*()_-+=`~<>,.?/:;\"'[]{}\\|"
    whitespace = " \t\n"

    shortLiteralChars = alphanum & symbols.remove('\'')
    longLiteralChars = alphanum & whitespace & symbols.remove('"')

    identifierChars = alphanum & "_"

proc consumeWhitespace(code: string): int =
    # Returns the first index with non-whitespace
    while code[result] in whitespace:
        inc(result)

proc consumeChar(code: string, c: char): int =
    # Returns 1 if code starts with c, else raises ParsingError
    if code[0] == c:
        return 1
    raise newException(ParsingError, "Expected character '$1'." % $c)

proc parseShortLiteral_d(code: string): ParseValue =
    if code[0] != '\'':
        raise newException(ParsingError, "Short literal must start with an apostrophe.")
    if code[1] notin shortLiteralChars:
        raise newException(ParsingError, "Short literal must contain one or more characters. Cannot be sole apostrophe.")

    var resultLiteralChars: seq[char] = @[]
    for c in code[1 ..< code.len]:  # Ignore apostrophe
        if c in shortLiteralChars:
            resultLiteralChars.add(c)
        else:
            break

    var resultLiteral = resultLiteralChars.join("")
    return (resultLiteral.len + 1, createLiteralRule(resultLiteral))  # +1 for apostrophe

var parseShortLiteral = debugWrap(parseShortLiteral_d, "SHORT LITERAL")

proc parseLongLiteral_d(code: string): ParseValue =
    if code[0] != '"':
        raise newException(ParsingError, "Long literal must start with a double quotation mark.")

    var resultLiteralChars: seq[char] = @[]
    for c in code[1 ..< code.len]:
        if c in longLiteralChars:
            resultLiteralChars.add(c)
        else:
            break

    var resultLiteral = resultLiteralChars.join("")
    return (resultLiteral.len + 1, createLiteralRule(resultLiteral))

var parseLongLiteral = debugWrap(parseLongLiteral_d, "LONG LITERAL")

proc parseLiteral_d(code: string): ParseValue =
    try:
        return parseShortLiteral(code)
    except ParsingError: discard

    try:
        return parseLongLiteral(code)
    except ParsingError: discard

    raise newException(ParsingError, "Did not match short nor long literal.")

var parseLiteral = debugWrap(parseLiteral_d, "LITERAL")

var parseExpression: proc(code: string): ParseValue
var parseSimpleExpression: proc(code: string): ParseValue

proc parseIdentifier(code: string): tuple[len: int, val: string] =
    # NOTE: Does not return a rule
    var head = 0
    while code[head] in identifierChars:
        inc(head)
    if head == 0:
        raise newException(ParsingError, "Identifier expected.")

    return (head, code[0 ..< head])

proc parseReference_d(code: string): ParseValue =
    let (head, identifier) = parseIdentifier(code)
    if not definedRules.hasKey(identifier):
        raise newException(ValueError, "No such rule \"$1\"." % identifier)
    return (head, definedRules[identifier])

var parseReference = debugWrap(parseReference_d, "REFERENCE")

proc parseQuestionExpr_d(code: string): ParseValue =
    if code[0] != '?':
        raise newException(ParsingError, "Question expression must begin with question mark.")

    var (innerRuleLen, innerRule) = parseSimpleExpression(code[1 ..< code.len])
    return (innerRuleLen + 1, createQuestionRule(innerRule))

var parseQuestionExpr = debugWrap(parseQuestionExpr_d, "QUESTION EXPRESSION")

proc parsePlusExpr_d(code: string): ParseValue =
    if code[0] != '+':
        raise newException(ParsingError, "Plus expression must begin with plus sign.")

    var (innerRuleLen, innerRule) = parseSimpleExpression(code[1 ..< code.len])
    return (innerRuleLen + 1, createPlusRule(innerRule))

var parsePlusExpr = debugWrap(parsePlusExpr_d, "PLUS EXPRESSION")

proc parseStarExpr_d(code: string): ParseValue =
    if code[0] != '*':
        raise newException(ParsingError, "Star expression must begin with star.")

    var (innerRuleLen, innerRule) = parseSimpleExpression(code[1 ..< code.len])
    return (innerRuleLen + 1, createStarRule(innerRule))

var parseStarExpr = debugWrap(parseStarExpr_d, "STAR EXPRESSION")

proc parseOrExpr_d(code: string): ParseValue =
    var innerRules: seq[Rule] = @[]
    var head = 0
    var isFirst = true
    var passedAtLeastOnePipe = false

    while head < code.len:
        var dHead: int
        var innerRule: Rule

        if not isFirst:
            head += code[head ..< code.len].consumeWhitespace()  # Allow space before pipe
            if code[head] != '|':
                if passedAtLeastOnePipe:
                    break  # End of or expression; return
                else:
                    raise newException(ParsingError, "Expected at least one pipe.")
            passedAtLeastOnePipe = true
            head.inc  # Consume pipe
            head += code[head ..< code.len].consumeWhitespace()  # Allow space after pipe
        else:
            isFirst = false

        try:
            (dHead, innerRule) = parseSimpleExpression(code[head ..< code.len])
        except ParsingError:
            raise newException(ParsingError, "Expected simple expression.")

        head += dHead
        innerRules.add(innerRule)

    return (head, createOrRule(innerRules))

var parseOrExpr = debugWrap(parseOrExpr_d, "OPTION EXPRESSION")

proc parseSequenceExpr_d(code: string): ParseValue =
    # Parses a sequence of simple expressions
    var rules: seq[Rule] = @[]

    var (head, rule) = parseSimpleExpression(code)
    rules.add(rule)
    while head < code.len:
        head += code[head ..< code.len].consumeWhitespace()
        var dHead: int
        var rule: Rule
        try:
            (dHead, rule) = parseSimpleExpression(code[head ..< code.len])
        except ParsingError:
            break
        head += dHead
        rules.add(rule)

    if rules.len < 1:
        raise newException(ParsingError, "Expected at least one simple expression.")

    return (head, createSequenceRule(rules))

var parseSequenceExpr = debugWrap(parseSequenceExpr_d, "SEQUENCE EXPRESSION")

proc parseBrackets_d(code: string): ParseValue =
    var head = 0
    head += code[head ..< code.len].consumeChar('[')
    head += code[head ..< code.len].consumeWhitespace()  # Space allowed between '[' and expression
    var (innerRuleLen, innerRule) = parseExpression(code[head ..< code.len])
    head += innerRuleLen
    head += code[head ..< code.len].consumeWhitespace()  # Space allowed between expression and ']'
    head += code[head ..< code.len].consumeChar(']')
    return (head, innerRule)

var parseBrackets = debugWrap(parseBrackets_d, "BRACKETS")

proc parseSimpleExpression_d(code: string): ParseValue =
    # A simple expressioin is anything that's an expression,
    # But it may not be an or-expression
    var options: seq[ParserFunction] = @[
        # Ignore the explicit type casting, IDK why it's needed
        ParserFunction(parseLiteral),
        ParserFunction(parseReference),
        ParserFunction(parseQuestionExpr),
        ParserFunction(parsePlusExpr),
        ParserFunction(parseStarExpr),
        ParserFunction(parseBrackets),
    ]

    for option in options:
        try:
            return option(code)
        except ParsingError: discard

    raise newException(ParsingError, "Expected reference, ?-expr, +-expr, *-expr, literal, or brackets. Matched none.")

parseSimpleExpression = debugWrap(parseSimpleExpression_d, "SIMPLE EXPRESSION")

proc parseExpression_d(code: string): ParseValue =
    # An expression is either an or-expr or a sequence-expr
    var options: seq[ParserFunction] = @[
        ParserFunction(parseOrExpr),
        ParserFunction(parseSequenceExpr),
    ]

    for option in options:
        try:
            return option(code)
        except ParsingError: discard

    raise newException(ParsingError, "Expected or-expr or seq-expr.")

parseExpression = debugWrap(parseExpression_d, "EXPRESSION")

proc parseDefinition_d(code: string): ParseValue =
    # Returns only amount consumed
    # Mutated global dict
    var (head, identifier) = parseIdentifier(code)

    head += code[head ..< code.len].consumeChar(':')
    head += code[head ..< code.len].consumeWhitespace()  # Space allowed between ':' and body

    var (dHead, rule) = parseExpression(code[head ..< code.len])
    head += dHead

    definedRules[identifier] = rule
    return (head, nil)

var parseDefinition = debugWrap(parseDefinition_d, "DEFINITION")

proc parseProgram_d(code: string): ParseValue =
    # Returns nothing but modifies global dict
    var head = 0  # Loaction in code
    while head < code.len:
        head += code[head ..< code.len].consumeWhitespace()  # Space allowed between definitions
        if head == code.len: break
        if head > code.len: raise newException(Exception, "Shouldn't happen")
        head += parseDefinition(code[head ..< code.len]).len
    return (head, nil)

var parseProgram = debugWrap(parseProgram_d, "PROGRAM")

var program = r"""
digit: '0 | '1 | '2 | '3 | '4 | '5 | '6 | '7 | '8 | '9
string: '" +digit '"
"""

discard parseProgram(program)
echo definedRules["string"]("\"374829\"")
