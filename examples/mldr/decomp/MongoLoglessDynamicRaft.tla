---- MODULE MongoLoglessDynamicRaft ----
\*
\* Logless protocol for managing configuration state for dynamic reconfiguration
\* in MongoDB replication.
\*

EXTENDS Naturals, Integers, FiniteSets, Sequences

CONSTANT Server

Secondary == "secondary"
Primary == "primary"
Nil == "nil"
InitTerm == 1
FinNat == 0..5

\* The protocol shouldn't care about the specific value of
\* a counter i.e. if we start all counters at 500 instead of 0
\* it shouldn't affect the correctness of the protocol.
\* {1,2,3}
\* {500,501,502}
\* {1,2,3,4}
\* 

\* Abstracting a state based on ordering between values instead
\* of their concrete values

VARIABLE currentTerm \* counter.
VARIABLE state
VARIABLE configVersion \* counter.
VARIABLE configTerm \* counter.
VARIABLE config

vars == <<currentTerm, state, configVersion, configTerm, config>>

\*
\* Helper operators.
\*

\* The set of all quorums of a given set.
Quorums(S) == {i \in SUBSET(S) : Cardinality(i) * 2 > Cardinality(S)}

QuorumsAt(i) == Quorums(config[i])

\* Is a sequence empty.
Empty(s) == Len(s) = 0

\* Is the config of node i considered 'newer' than the config of node j. This is the condition for
\* node j to accept the config of node i.
IsNewerConfig(i, j) ==
    \/ configTerm[i] > configTerm[j]
    \/ /\ configTerm[i] = configTerm[j]
       /\ configVersion[i] > configVersion[j]

IsNewerOrEqualConfig(i, j) ==
    \/ /\ configTerm[i] = configTerm[j]
       /\ configVersion[i] = configVersion[j]
    \/ IsNewerConfig(i, j)

\* Compares two configs given as <<configVersion, configTerm>> tuples.
NewerConfig(ci, cj) ==
    \* Compare configTerm first.
    \/ ci[2] > cj[2] 
    \* Compare configVersion if terms are equal.
    \/ /\ ci[2] = cj[2]
       /\ ci[1] > cj[1]  

\* Compares two configs given as <<configVersion, configTerm>> tuples.
NewerOrEqualConfig(ci, cj) == NewerConfig(ci, cj) \/ ci = cj

\* Can node 'i' currently cast a vote for node 'j' in term 'term'.
CanVoteForConfig(i, j, term) ==
    /\ currentTerm[i] < term
    /\ IsNewerOrEqualConfig(j, i)
    
\* Do all quorums of set x and set y share at least one overlapping node.
QuorumsOverlap(x, y) == \A qx \in Quorums(x), qy \in Quorums(y) : qx \cap qy # {}

\* Is the current config on primary s committed. A config C=(v, t) can be committed on 
\* a primary in term T iff t=T and there are a quorum of nodes in term T that currently
\* have config C.
ConfigIsCommitted(s, term, Q) == 
    /\ state[s] = Primary
    \* Config must be in the term of this primary.
    /\ configTerm[s] = term
    /\ currentTerm[s] = term
    /\ Q \in Quorums(config[s])
    \* Node must have the same config as the primary.
    /\ \A t \in Q : configVersion[s] = configVersion[t]
    /\ \A t \in Q : configTerm[s] = configTerm[t]
    \* Node must be in the same term as the primary (and the config).
    /\ \A t \in Q : currentTerm[t] = currentTerm[s]

-------------------------------------------------------------------------------------------

\*
\* Next state actions.
\*

\* Update terms if node 'i' has a newer term than node 'j' and ensure 'j' reverts to Secondary state.
UpdateTermsExpr(i, j) ==
    /\ currentTerm[i] > currentTerm[j]
    /\ currentTerm' = [currentTerm EXCEPT ![j] = currentTerm[i]]
    /\ state' = [state EXCEPT ![j] = Secondary]

UpdateTerms(i, j) == 
    /\ UpdateTermsExpr(i, j)
    /\ UNCHANGED <<configVersion, configTerm, config>>

BecomeLeader(i, voteQuorum, newTerm) == 
    \* Primaries make decisions based on their current configuration.
    /\ newTerm = currentTerm[i] + 1
    /\ i \in config[i] \* only become a leader if you are a part of your config.
    /\ i \in voteQuorum \* The new leader should vote for itself.
    /\ \A v \in voteQuorum : CanVoteForConfig(v, i, newTerm)
    \* Update the terms of each voter.
    /\ currentTerm' = [s \in Server |-> IF s \in voteQuorum THEN newTerm ELSE currentTerm[s]]
    /\ state' = [s \in Server |->
                    IF s = i THEN Primary
                    ELSE IF s \in voteQuorum THEN Secondary \* All voters should revert to secondary state.
                    ELSE state[s]]
    \* Update config's term on step-up.
    /\ configTerm' = [configTerm EXCEPT ![i] = newTerm]
    /\ UNCHANGED <<config, configVersion>>    

\* A reconfig occurs on node i. The node must currently be a leader.
Reconfig(i, newConfig, term, Q) ==
    /\ state[i] = Primary
    /\ ConfigIsCommitted(i, term, Q)
    /\ QuorumsOverlap(config[i], newConfig)
    /\ i \in newConfig
    /\ configTerm' = [configTerm EXCEPT ![i] = term]
    /\ configVersion' = [configVersion EXCEPT ![i] = configVersion[i] + 1]
    /\ config' = [config EXCEPT ![i] = newConfig]
    /\ UNCHANGED <<currentTerm, state>>

\* Node i sends its current config to node j.
SendConfig(i, j) ==
    /\ state[j] = Secondary
    /\ IsNewerConfig(i, j)
    /\ configVersion' = [configVersion EXCEPT ![j] = configVersion[i]]
    /\ configTerm' = [configTerm EXCEPT ![j] = configTerm[i]]
    /\ config' = [config EXCEPT ![j] = config[i]]
    /\ UNCHANGED <<currentTerm, state>>

Init == 
    /\ currentTerm = [i \in Server |-> InitTerm]
    /\ state       = [i \in Server |-> Secondary]
    /\ configVersion =  [i \in Server |-> 1]
    /\ configTerm    =  [i \in Server |-> InitTerm]
    /\ \E initConfig \in SUBSET Server :
        /\ initConfig # {}
        /\ config = [i \in Server |-> initConfig]

Next ==
    \/ \E s \in Server, newConfig \in SUBSET Server : \E term \in FinNat : \E Q \in SUBSET Server : Reconfig(s, newConfig, term, Q)
    \/ \E s,t \in Server : SendConfig(s, t)
    \/ \E i \in Server : \E Q \in Quorums(config[i]) : \E newTerm \in FinNat : BecomeLeader(i, Q, newTerm)
    \/ \E s,t \in Server : UpdateTerms(s,t)

Spec == Init /\ [][Next]_vars

------------------------------------------

CV(i) == <<configVersion[i], configTerm[i]>>
ConfigDisabled(i) == 
    \A Q \in Quorums(config[i]) : \E n \in Q : NewerConfig(CV(n), CV(i))

OnePrimaryPerTerm ==
    \A s,t \in Server : 
        (/\ state[s] = Primary 
         /\ state[t] = Primary 
         /\ currentTerm[s] = currentTerm[t]) => (s = t)

TypeOK ==
    /\ currentTerm \in [Server -> Nat]
    /\ state \in [Server -> {Secondary, Primary}]
    /\ config \in [Server -> SUBSET Server]
    /\ configVersion \in [Server -> Nat]
    /\ configTerm \in [Server -> Nat]

=============================================================================
