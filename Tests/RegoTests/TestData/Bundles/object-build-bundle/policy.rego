package benchmark.object

# Exercises ObjectInsertStmt by building a 10-field literal object.

matched if {
    obj := {
        "k1": "__nomatch_1__", "k2": "__nomatch_2__", "k3": "__nomatch_3__",
        "k4": "__nomatch_4__", "k5": "__nomatch_5__", "k6": "__nomatch_6__",
        "k7": "__nomatch_7__", "k8": "__nomatch_8__", "k9": "__nomatch_9__",
        "k10": "__nomatch_10__",
    }
    input.value == obj[_]
}
