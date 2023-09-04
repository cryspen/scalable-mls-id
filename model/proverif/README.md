## Running the Model

### Install ProVerif

https://bblanche.gitlabpages.inria.fr/proverif/

### Analyze the Model

Run: proverif scalable.pv

You should see:
```
--------------------------------------------------------------
Verification summary:

Query not event(Created(p_6,ctx_10)) is false.

Query not event(Member(p_6,ctx_10,q_2)) is false.

Query not event(Joined(q_2,ctx_10,p_6)) is false.

Query not event(Updated(q_2,ctx_10,ctx_)) is false.

Query not event(ProcessedUpdate(q_2,ctx_10,ctx_,p_6)) is false.

Query not event(Send(p_6,ctx_10,m_4)) is false.

Query not event(Recv(p_6,ctx_10,m_4)) is false.

Query not event(Compromised(q_2)) is false.

Query not attacker(group_secret(p_6,ctx_10,sec_2)) is false.

Query attacker(group_secret(p_6,ctx_10,sec_2)) ==> event(Member(p_6,ctx_10,q_2)) && event(Compromised(q_2)) is true.

Query event(Joined(q_2,ctx_10,p_6)) ==> event(Member(p_6,ctx_10,q_2)) || event(Compromised(p_6)) || event(Compromised(q_2)) is true.

Query event(Recv(q_2,ctx_10,m_4)) ==> event(Send(p_6,ctx_10,m_4)) is false.

Query event(Recv(q_2,ctx_10,m_4)) ==> event(Send(p_6,ctx_10,m_4)) || event(Compromised(p_6)) || (event(Member(u,ctx_10,v)) && event(Compromised(v))) is true.

Query not attacker(app_message(p_6,ctx_10)) is false.

Query attacker(app_message(p_6,ctx_10)) ==> event(Send(p_6,ctx_10,app_message(p_6,ctx_10))) && (event(Compromised(p_6)) || (event(Member(u,ctx_10,v)) && event(Compromised(v)))) is true.

--------------------------------------------------------------

```
