--------------------------- MODULE tmp_hist ---------------------------
EXTENDS Naturals, Integers, Sequences, FiniteSets, TLC

CONSTANTS Server, Quorums, FinNat

VARIABLES log, Fluent3, Fluent2, Fluent1, state, Fluent0, config

vars == <<log, Fluent3, Fluent2, Fluent1, state, Fluent0, config>>

CandSep ==
\A var0 \in Server : Fluent3[var0]

Secondary == "secondary"

Primary == "primary"

Nil == "nil"

Empty(s) == Len(s) = 0

LastTerm(xlog) == IF Len(xlog) = 0 THEN 0 ELSE xlog[Len(xlog)]

LastEntry(xlog) == <<Len(xlog),xlog[Len(xlog)]>>

IsPrefix(s,t) == (Len(s) <= Len(t) /\ SubSeq(s,1,Len(s)) = SubSeq(t,1,Len(s)))

UpdateTermsExpr(i,j) ==
/\ state' = [state EXCEPT![j] = Secondary]

ClientRequest(i,curTerm) ==
/\ state[i] = Primary
/\ log' = [log EXCEPT![i] = Append(log[i],curTerm)]
/\ UNCHANGED <<state,config>>
/\ Fluent3' = [Fluent3 EXCEPT ![i] = TRUE]
/\ UNCHANGED<<>>
/\ UNCHANGED<<Fluent2, Fluent1, Fluent0>>

GetEntries(i,j) ==
/\ state[i] = Secondary
/\ UNCHANGED <<log,state,config>>
/\ UNCHANGED<<Fluent3>>
/\ UNCHANGED<<Fluent2, Fluent1, Fluent0>>

RollbackEntries(i,j) ==
/\ state[i] = Secondary
/\ UNCHANGED <<log,state,config>>
/\ UNCHANGED<<Fluent3>>
/\ UNCHANGED<<Fluent2, Fluent1, Fluent0>>

BecomeLeader(i,voteQuorum,newTerm) ==
/\ (voteQuorum \in Quorums)
/\ (i \in voteQuorum)
/\ state' = [s \in Server |-> IF s = i THEN Primary ELSE IF (s \in voteQuorum) THEN Secondary ELSE state[s]]
/\ UNCHANGED <<log,config>>
/\ UNCHANGED<<Fluent3>>
/\ Fluent1' = [Fluent1 EXCEPT ![newTerm] = TRUE]
/\ UNCHANGED<<Fluent2, Fluent0>>

CommitEntry(i,commitQuorum,ind,curTerm) ==
/\ (commitQuorum \in Quorums)
/\ ind > 0
/\ state[i] = Primary
/\ UNCHANGED <<state,log,config>>
/\ Fluent3' = [Fluent3 EXCEPT ![i] = FALSE]
/\ UNCHANGED<<>>
/\ Fluent2' = [Fluent2 EXCEPT ![ind][curTerm] = TRUE]
/\ Fluent0' = [Fluent0 EXCEPT ![curTerm] = TRUE]
/\ UNCHANGED<<Fluent1>>

UpdateTerms(i,j) ==
/\ UpdateTermsExpr(i,j)
/\ UNCHANGED <<log,config>>
/\ UNCHANGED<<Fluent3>>
/\ UNCHANGED<<Fluent2, Fluent1, Fluent0>>

Init ==
/\ state = [i \in Server |-> Secondary]
/\ log = [i \in Server |-> <<>>]
/\ (\E initConfig \in SUBSET(Server) : (initConfig /= {} /\ config = [i \in Server |-> initConfig]))
/\ Fluent3 = [ x0 \in Server |-> TRUE]
/\ Fluent2 = [ x0 \in FinNat |-> [ x1 \in FinNat |-> FALSE]]
/\ Fluent1 = [ x0 \in FinNat |-> FALSE]
/\ Fluent0 = [ x0 \in FinNat |-> FALSE]

Next ==
\/ (\E s \in Server : (\E t \in FinNat : ClientRequest(s,t)))
\/ (\E s,t \in Server : GetEntries(s,t))
\/ (\E s,t \in Server : RollbackEntries(s,t))
\/ (\E s \in Server : (\E Q \in Quorums : (\E newTerm \in FinNat : BecomeLeader(s,Q,newTerm))))
\/ (\E s \in Server : (\E Q \in Quorums : (\E ind \in FinNat : (\E curTerm \in FinNat : CommitEntry(s,Q,ind,curTerm)))))
\/ (\E s,t \in Server : UpdateTerms(s,t))

Spec == (Init /\ [][Next]_vars)
=============================================================================