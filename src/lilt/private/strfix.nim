
#~# Subtle string changes #~#

import strutils

#[
As per https://github.com/nim-lang/Nim/issues/5596,
Current Nim strings are null-terminated and that terminator is
both accessible and writable; `string[string.len]` is always '\0'.

As per that thread, this behaviour is being deprecated, and
a function with that behaviour will be added to the stdlib.

However, that function has not yet been created, but
we still want that functionality (it's useful for this
parser). So, we define our own future-proof proc here.

Implementation is based on @yglukhov's comment in the github
thread.
]#
proc `{}`*(s: string, i: int): char =
    if i == s.len:
        return '\0'
    if i >= s.len:
        raise newException(IndexError, "$1 is out of bounds." % $i)
    return s[i]

# Additionally, hotfix the expected patches to ensure futureproofness (TM)
proc `[]`*(s: string, i: int): char =
    if i == s.len:
        raise newException(IndexError, "$1 is out of bounds." % $i)
    return s[i]

# Careful using [slice] and [slice]=
