Proofs with MLS*
================

Verifying the proofs
--------------------

These proofs build on top of MLS\*, available here: https://github.com/Inria-Prosecco/treesync .
Copy the files in `mls-star/fstar/treesync/code`,
and follow the instructions to build it.

Membership proof
----------------

The theorem `membership_proof_to_tree_hash_security` states that:
given a root tree hash and a membership proof that verifies with it (`check_membership_proof`),
for all trees with the same root tree hash,
either the tree height is the same as the membership proof length
and the tree contains the leaf node and parent nodes stored inside the membership proof (`membership_proof_guarantees`),
or we can compute a hash collision (in polynomial time).

The theorem also works for subtrees,
in that case it also guarantees the position of the subtree.
