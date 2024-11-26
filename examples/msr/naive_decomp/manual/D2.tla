--------------------------- MODULE C2 ---------------------------
EXTENDS Naturals, Integers, Sequences, FiniteSets, TLC

VARIABLES currentTerm
VARIABLES FluentCommitIndTerm

CONSTANTS Server, Quorums, FinNat

Secondary == "secondary"

Primary == "primary"

Nil == "nil"

vars == <<currentTerm, FluentCommitIndTerm>>

CandSep ==
TRUE


Empty(s) == Len(s) = 0

InLog(e,i) ==
\E x \in DOMAIN(log[i]) :
/\ x = e[1]
/\ log[i][x] = e[2]

LastTerm(xlog) == IF Len(xlog) = 0 THEN 0 ELSE xlog[Len(xlog)]

LastEntry(xlog) == <<Len(xlog),xlog[Len(xlog)]>>

IsPrefix(s,t) == (Len(s) <= Len(t) /\ SubSeq(s,1,Len(s)) = SubSeq(t,1,Len(s)))

CanRollback(i,j) ==
/\ LastTerm(log[i]) < LastTerm(log[j])
/\ ~(IsPrefix(log[i],log[j]))

\* Can node 'i' currently cast a vote for node 'j' in term 'term'.
CanVoteForOplog(i, j, term) ==
    LET logOk ==
        \/ LastTerm(log[j]) > LastTerm(log[i])
        \/ /\ LastTerm(log[j]) = LastTerm(log[i])
           /\ Len(log[j]) >= Len(log[i]) IN
    /\ currentTerm[i] < term
    /\ logOk

\* Is a log entry 'e'=<<i, t>> immediately committed in term 't' with a quorum 'Q'.
ImmediatelyCommitted(e, Q) == 
    LET eind == e[1] 
        eterm == e[2] IN
    \A s \in Q :
        /\ Len(log[s]) >= eind
        /\ InLog(e, s) \* they have the entry.
        /\ currentTerm[s] = eterm  \* they are in the same term as the log entry. 

UpdateTermsExpr(i,j) ==
/\ currentTerm[i] > currentTerm[j]
/\ currentTerm' = [currentTerm EXCEPT![j] = currentTerm[i]]

ClientRequest(i,curTerm) ==
/\ currentTerm[i] = curTerm
/\ UNCHANGED <<currentTerm>>
/\ UNCHANGED <<FluentCommitIndTerm>>
/\ CandSep'

BecomeLeader(i,voteQuorum,newTerm) ==
/\ newTerm = (currentTerm[i] + 1)
/\ (i \in voteQuorum)
/\ (\A v \in voteQuorum : CanVoteForOplog(v,i,newTerm))
/\ currentTerm' = [s \in Server |-> IF (s \in voteQuorum) THEN newTerm ELSE currentTerm[s]]
/\ UNCHANGED <<FluentCommitIndTerm>>
/\ CandSep'

CommitEntry(i,commitQuorum,ind,curTerm) ==
/\ FluentCommitIndTerm' = [FluentCommitIndTerm EXCEPT![ind][curTerm] = TRUE]
/\ curTerm = currentTerm[i]
/\ ind > 0
/\ UNCHANGED <<currentTerm>>
/\ CandSep'

UpdateTerms(i,j) ==
/\ UpdateTermsExpr(i,j)
/\ UNCHANGED <<FluentCommitIndTerm>>
/\ CandSep'

Init ==
/\ currentTerm = [i \in Server |-> 0]
/\ FluentCommitIndTerm = [ x0 \in FinNat |-> [x1 \in FinNat |-> FALSE]]

Next ==
\/ (\E s \in Server : (\E t \in FinNat : ClientRequest(s,t)))
\/ (\E s \in Server : (\E Q \in Quorums : (\E newTerm \in FinNat : BecomeLeader(s,Q,newTerm))))
\/ (\E s \in Server : (\E Q \in Quorums : (\E ind \in FinNat : (\E curTerm \in FinNat : CommitEntry(s,Q,ind,curTerm)))))
\/ (\E s,t \in Server : UpdateTerms(s,t))

Spec == (Init /\ [][Next]_vars)

Safety ==
/\ \A i \in FinNat : \A t1,t2 \in FinNat : (FluentCommitIndTerm[i][t1] => (FluentCommitIndTerm[i][t2] => t1=t2))
=============================================================================
