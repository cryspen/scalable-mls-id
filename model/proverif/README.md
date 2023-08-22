## Running the Model

### Install ProVerif

https://bblanche.gitlabpages.inria.fr/proverif/

### Analyze the Model

Run: proverif scalable.pv

You should see:
```
Verification summary:

Query not event(Created(p_5,ctx_3)) is false.

Query not event(Member(p_5,ctx_3,q_1)) is false.

Query not event(Joined(q_1,ctx_3,p_5)) is false.

Query not event(Compromised(q_1)) is false.

Query not attacker(group_secret(p_5,ctx_3,sec_1)) is false.

Query attacker(group_secret(p_5,ctx_3,sec_1)) ==> event(Member(p_5,ctx_3,q_1)) && event(Compromised(q_1)) is true.

Query event(Joined(q_1,ctx_3,p_5)) ==> event(Member(p_5,ctx_3,q_1)) || event(Compromised(p_5)) || event(Compromised(q_1)) is true.

```
