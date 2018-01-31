
include hparser

test(
    """
     (( Block comment! ))
     / Line comment
    vowel: <aeiou>/This is a comment
    (( nest a comment
    Let's add ()()()((() ) ) some code in the comments:
    code: <code> ))
    """,
    newProgram(@[
        "vowel" := <>"aeiou"
    ])
)
