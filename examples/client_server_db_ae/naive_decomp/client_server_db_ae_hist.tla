--------------------------- MODULE client_server_db_ae_hist ---------------------------
EXTENDS Naturals, Sequences, FiniteSets, TLC

CONSTANTS Node, Request, Response, DbRequestId

VARIABLES db_request_sent, Fluent9, Fluent8, t, request_sent, response_sent, match, response_received, db_response_sent

vars == <<db_request_sent, Fluent9, Fluent8, t, request_sent, response_sent, match, response_received, db_response_sent>>

CandSep ==
\E var0 \in Node : \A var1 \in Response : (Fluent8[var0]) => (Fluent9[var1])

NoneWithId(i) == (\A n \in Node : (<<i,n>> \notin t))

ResponseMatched(n,p) ==
\E r \in Request :
/\ (<<n,r>> \in request_sent)
/\ (<<r,p>> \in match)

NewRequest(n,r) ==
/\ request_sent' = (request_sent \cup {<<n,r>>})
/\ UNCHANGED <<match,response_sent,response_received,db_request_sent,db_response_sent,t>>
/\ UNCHANGED<<Fluent9, Fluent8>>

ServerProcessRequest(n,r,i) ==
/\ (<<n,r>> \in request_sent)
/\ NoneWithId(i)
/\ t' = (t \cup {<<i,n>>})
/\ db_request_sent' = (db_request_sent \cup {<<i,r>>})
/\ UNCHANGED <<match,request_sent,response_sent,response_received,db_response_sent>>
/\ Fluent8' = [Fluent8 EXCEPT![n] = TRUE]
/\ UNCHANGED<<Fluent9>>

DbProcessRequest(i,r,p) ==
/\ (<<i,r>> \in db_request_sent)
/\ (<<r,p>> \in match)
/\ db_response_sent' = (db_response_sent \cup {<<i,p>>})
/\ UNCHANGED <<match,request_sent,response_sent,response_received,db_request_sent,t>>
/\ UNCHANGED<<Fluent9, Fluent8>>

ServerProcessDbResponse(n,i,p) ==
/\ (<<i,p>> \in db_response_sent)
/\ (<<i,n>> \in t)
/\ response_sent' = (response_sent \cup {<<n,p>>})
/\ UNCHANGED <<match,request_sent,response_received,db_request_sent,db_response_sent,t>>
/\ UNCHANGED<<Fluent9, Fluent8>>

ReceiveResponse(n,p) ==
/\ (<<n,p>> \in response_sent)
/\ response_received' = (response_received \cup {<<n,p>>})
/\ UNCHANGED <<match,request_sent,response_sent,db_request_sent,db_response_sent,t>>
/\ Fluent9' = [Fluent9 EXCEPT![p] = FALSE]
/\ Fluent8' = [Fluent8 EXCEPT![n] = TRUE]
/\ UNCHANGED<<>>

Next ==
\/ (\E n \in Node, r \in Request : NewRequest(n,r))
\/ (\E n \in Node, r \in Request, i \in DbRequestId : ServerProcessRequest(n,r,i))
\/ (\E r \in Request, i \in DbRequestId, p \in Response : DbProcessRequest(i,r,p))
\/ (\E n \in Node, i \in DbRequestId, p \in Response : ServerProcessDbResponse(n,i,p))
\/ (\E n \in Node, p \in Response : ReceiveResponse(n,p))

Init ==
/\ (match \in SUBSET((Request \X Response)))
/\ request_sent = {}
/\ response_sent = {}
/\ response_received = {}
/\ db_request_sent = {}
/\ db_response_sent = {}
/\ t = {}
/\ Fluent9 = [ x0 \in Response |-> TRUE]
/\ Fluent8 = [ x0 \in Node |-> FALSE]

Spec == (Init /\ [][Next]_vars)

TypeOK ==
/\ (match \in SUBSET((Request \X Response)))
/\ (request_sent \in SUBSET((Node \X Request)))
/\ (response_sent \in SUBSET((Node \X Response)))
/\ (response_received \in SUBSET((Node \X Response)))
/\ (db_request_sent \in SUBSET((DbRequestId \X Request)))
/\ (db_response_sent \in SUBSET((DbRequestId \X Response)))
/\ (t \in SUBSET((DbRequestId \X Node)))

Safety == (\A n \in Node, p \in Response : ((<<n,p>> \in response_received) => ResponseMatched(n,p)))
=============================================================================
