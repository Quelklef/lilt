
class StupidDevError(Exception):
    """ For code which should never be reached """
    pass


class Unparsable(Exception):
    pass


def is_blank(string):
    return string.strip() == ''


def get_indentation_level(string, spaces_per_indent=4):
    if is_blank(string):
        return 0

    single_indent = ' ' * spaces_per_indent
    i = 0
    indentation = 0
    while string[i:i+spaces_per_indent] == single_indent:
        i += spaces_per_indent
        indentation += 1
    return indentation


def parse_instruction(context, instr):
    """
    Returns an instruction as a function, given the global context.
    The function accepts some text and returns the number of characters it consumes.
    If it is unable to properly parse the text, it raises Unraisable.
    """
    tag = instr[0]
    body = instr[1:]

    if tag == '@':

        def ret(text):
            print(f"REQUIRE '{body}' with '{text}'")
            return context[body](text)

        return ret

    elif tag == '?':

        def ret(text):
            print(f"ALLOW {body} with '{text}'")
            try:
                return context[body](text)
            except Unparsable:
                return 0

        return ret

    else:  # Literal

        def ret(text):
            print(f"LITERAL '{instr}' with '{text}'")
            if text.startswith(instr):
                return len(instr)
            raise Unparsable(f"'{text}' does not match literal '{instr}'.")

        return ret


def create_rule(instructions):
    print("Create rule:", instructions)
    def rule(code):
        i = 0
        for instruction in instructions:
            i += instruction(code[i:])
            if i >= len(code):
                assert i == len(code)  # If not, something's wrong
                break
        return i
    return rule


def take_while(predicate):
    def rule(code):
        i = 0
        while i < len(code) and predicate(code[i]):
            i += 1
        if i == 0:
            raise Unparsable
        return i
    return rule


builtins = {
    'alpha': take_while(str.isalpha),
    'alphanumeric': take_while(str.isalnum),
    'numeric': take_while(str.isnumeric),
    'ws': take_while(lambda c: c != '\n' and c.isspace()),  # whitespace
}


import sys
sys.setrecursionlimit(200)


def parse(code):
    lines = code.split('\n')

    rules = builtins

    """
    0: Expecting definition
    1: Expecting definition body
    """
    state = 0
    current_definition_name = None
    current_definition_body = []

    line_number = 0  # Lines are, sigh, 1-indexed

    def end_definition():
        # Create rule and add to context
        nonlocal current_definition_body
        rules[current_definition_name] = create_rule(current_definition_body)
        current_definition_body = []

    for line in lines:
        line_number += 1

        if is_blank(line):
            continue

        indentation = get_indentation_level(line)

        if indentation > state:
            raise ValueError(f"Invalid indentation on line {line_number}")
        elif indentation < state:
            # End current thing
            if state == 1:
                end_definition()
            else:  # Make sure to cover all cases!
                raise StupidDevError

            state = indentation

        if state == 0:  # Start making definition
            identifier = line.strip()
            if not identifier.isalnum():
                raise ValueError(f"Invalid identifier '{identifier}' on line {line_number}")
            current_definition_name = identifier
            state += 1
        elif state == 1:  # Add to body of existing definition
            instructions = list(filter(lambda s: not is_blank(s), line.split(' ')))
            print(current_definition_name, instructions)
            for instruction in instructions:
                current_definition_body.append(parse_instruction(rules, instruction))

    end_definition()

    return rules


if __name__ == "__main__":
    with open('syntax.txt') as f:
        parser = parse(f.read())['main']
    with open('code.txt') as f:
        code = f.read()
    print(parser(code))
