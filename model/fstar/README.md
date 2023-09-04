# Proofs with MLS*

## Verifying the proofs

Step 1: obtain the TreeSync artifact, available here: https://github.com/Inria-Prosecco/treesync .
To do that, `make treesync` will clone the repository in this directory.

Step 2: setup the tools.
Install F* and Z3 as recommended in the TreeSync repository.
The easiest option is to use Nix, and run `nix develop` in the TreeSync repository.

Step 3: setup the environment.
If you downloaded the treesync repository manually, point the `TREESYNC_PATH` environment variable to that directory.
If you downloaded it with `make treesync`, nothing is needed.

Step 4: build.
Run `make` in the current directory, it will copy the files in the TreeSync repository,
and check these files along with the corresponding dependencies in the TreeSync repository.

In other words, these commands will verify the proofs:

```bash
    make treesync
    cd treesync
    nix develop
    cd ..
    make
```

With docker, things are more complex because it requires to copy the source files inside the docker image.
Hence, it is easiest to copy the files before generating the docker image, and then verifying all of MLS\* in docker.

The following commands will verify the proofs using docker.
```bash
    make treesync
    make copy_files

    cd treesync
    docker build . -t treesync_artifact
    docker run -it treesync_artifact

    cd mls-star
    make
```

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
