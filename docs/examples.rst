
Examples
========

So, you want to see examples of Lilt! Well, you're in luck.


Parsing a Number
----------------

Parsing a number, returning a node::

    digit: <1234567890>
    number: wholes=*digit ?["." decimals=+digit]

Results::

    on "12.3" -> {
        wholes: "12"
        decimals: "3"
    }

    on "." -> Gives an error

    on "45." -> Gives an error

    on ".500" -> {
        wholes: ""
        decimals: "500"
    }

