# Proofs with MLS*

## Verifying the proofs

These proofs build on top of MLS\*, available here: https://github.com/Inria-Prosecco/treesync .
Copy the files in `mls-star/fstar/treesync/code`,
and follow the instructions to build it.

## Membership proof

### Correctness

The correctess theorem `compute_membership_proof_correct` states that
verifying a membership proof that was computed with the `compute_membership_proof` will succeed.

### Security

The theorem `membership_proof_to_tree_hash_security` states that:
given a root tree hash and a membership proof that verifies with it (`check_membership_proof`),
for all trees with the same root tree hash,
either the tree height is the same as the membership proof length
and the tree contains the leaf node and parent nodes stored inside the membership proof (`membership_proof_guarantees`),
or we can compute a hash collision (in polynomial time).

In other words, if we find a counter-example to the guarantees offered by membership proof,
then we can derive from it a hash collision.
Hence, breaking the security of membership proof is as hard as computing a hash collision,
which is assumed to be hard.

The theorem also works for subtrees,
in that case it also guarantees the position of the subtree.

Note that the theorem says "for all trees" and not "there exists a tree":
we cannot guarantee the existence of a tree because the sibling tree hashes in the membership
could be garbage, and not correspond to actual tree hashes.
The "for all" then means if there exists a tree with a tree hash equal to `root_tree_hash`,
then that tree has the relation we want with the membership proof.
