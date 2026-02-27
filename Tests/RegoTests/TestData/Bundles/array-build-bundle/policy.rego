package benchmark.array

# Exercises ArrayAppendStmt (building the literal array) and ScanStmt.

matched if {
    values := [
        "__nomatch_1__", "__nomatch_2__", "__nomatch_3__", "__nomatch_4__", "__nomatch_5__",
        "__nomatch_6__", "__nomatch_7__", "__nomatch_8__", "__nomatch_9__", "__nomatch_10__",
    ]
    input.value == values[_]
}
