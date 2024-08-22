--------------------------- MODULE D0_hist ---------------------------
EXTENDS Naturals, Sequences, Integers

CONSTANTS RMs

VARIABLES Fluent5, Fluent4, rmState, Fluent3, Fluent2, Fluent1, Fluent0

vars == <<Fluent5, Fluent4, rmState, Fluent3, Fluent2, Fluent1, Fluent0>>

CandSep ==
/\ \A var0 \in RMs : (Fluent0[var0]) => (Fluent1[var0])
/\ \A var0 \in RMs : (Fluent2[var0]) => (\A var1 \in RMs : Fluent3[var1])
/\ \A var0 \in RMs : (Fluent5[var0]) => (\A var1 \in RMs : Fluent4[var1])

Message == ([type : {"Prepared"},theRM : RMs] \cup [type : {"Commit","Abort"}])

Init ==
/\ rmState = [rm \in RMs |-> "working"]
/\ Fluent3 = [ x0 \in RMs |-> TRUE]
/\ Fluent2 = [ x0 \in RMs |-> TRUE]
/\ Fluent1 = [ x0 \in RMs |-> FALSE]
/\ Fluent0 = [ x0 \in RMs |-> FALSE]
/\ Fluent5 = [ x0 \in RMs |-> FALSE]
/\ Fluent4 = [ x0 \in RMs |-> TRUE]

SndPrepare(rm) ==
/\ rmState[rm] = "working"
/\ rmState' = [rmState EXCEPT![rm] = "prepared"]
/\ Fluent2' = [Fluent2 EXCEPT![rm] = FALSE]
/\ Fluent1' = [Fluent1 EXCEPT![rm] = TRUE]
/\ UNCHANGED<<Fluent3, Fluent0, Fluent5, Fluent4>>
/\ CandSep'

RcvCommit(rm) ==
/\ rmState' = [rmState EXCEPT![rm] = "committed"]
/\ Fluent3' = [Fluent3 EXCEPT![rm] = FALSE]
/\ Fluent0' = [Fluent0 EXCEPT![rm] = TRUE]
/\ Fluent5' = [Fluent5 EXCEPT![rm] = TRUE]
/\ UNCHANGED<<Fluent2, Fluent1, Fluent4>>
/\ CandSep'

RcvAbort(rm) ==
/\ rmState' = [rmState EXCEPT![rm] = "aborted"]
/\ Fluent4' = [Fluent4 EXCEPT![rm] = FALSE]
/\ UNCHANGED<<Fluent3, Fluent2, Fluent1, Fluent0, Fluent5>>
/\ CandSep'

SilentAbort(rm) ==
/\ rmState[rm] = "working"
/\ rmState' = [rmState EXCEPT![rm] = "aborted"]
/\ UNCHANGED<<Fluent3, Fluent2, Fluent1, Fluent0, Fluent5, Fluent4>>
/\ CandSep'

Next ==
\E rm \in RMs :
\/ SndPrepare(rm)
\/ RcvCommit(rm)
\/ RcvAbort(rm)
\/ SilentAbort(rm)

Spec == (Init /\ [][Next]_vars)

TypeOK ==
/\ (rmState \in [RMs -> {"working","prepared","committed","aborted"}])

Consistent == (\A rm1,rm2 \in RMs : ~((rmState[rm1] = "aborted" /\ rmState[rm2] = "committed")))
=============================================================================
