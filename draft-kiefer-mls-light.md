---
title: "Light MLS"
abbrev: "Light MLS"
category: info

docname: draft-kiefer-mls-light-latest
submissiontype: IETF  # also: "independent", "IAB", or "IRTF"
number:
date:
consensus: false
v: 3
area: Security
workgroup: Network Working Group
keyword: Internet-Draft
venue:
  group: WG
  type: Working Group
  mail: WG@example.com
  arch: https://example.com/WG
  github: USER/REPO
  latest: https://example.com/LATEST

author:
 -  ins: F. Kiefer
    fullname: Franziskus Kiefer
    organization: Cryspen
    email: franziskuskiefer@gmail.com
 -  ins: K. Bhargavan
    fullname: Karthikeyan Bhargavan
    organization: Cryspen
    email: karthik.bhargavan@gmail.com
 -  ins: R.L. Barnes
    fullname: Richard L. Barnes
    organization: Cisco
    email: rlb@ipv.sx
 -  ins: J. Alwen
    fullname: Joël Alwen
    organization: AWS Wickr
    email: alwenjo@amazon.com
 -  ins: M. Mularczyk
    fullname: Marta Mularczyk
    organization: AWS Wickr
    email: mulmarta@amazon.ch

normative:

informative:


--- abstract

The Messaging Layer Security (MLS) protocol provides efficient asynchronous
group key establishment for large groups with up to thousands of clients. In
MLS, any member can commit a change to the group, and consequently, all members
must download, validate, and maintain the full group state which can incur a
significant communication and computational cost, especially when joining a
group.  The MLS Commit messages that make these changes are unnecessarily
expensive to transmit, as their structure requires each member to receive many
encrypted valees that the member cannot decrypt.

This document defines Light MLS, a collection of MLS extensions that address
these scaling problems.  A "server aided" Commit scheme allows groups to be
updated more efficiently.  We also define mechanisms to support "light clients":
A light client cannot commit changes to the group, and only has partial
authentication information for the other members of the group, but is otherwise
able to participate in the group.  In exchange for these limitations, a light
client can participate in an MLS group with significantly lower requirements in
terms of download, memory, and processing.

--- middle

# Introduction

[[ MLS is scalable; Commit and Initialization scaling limits ]]

[[ Server aided: Restructure Commit so that DS can split it out ]]

[[ Light clients: Annotated Welcome / Commit to provide only required info ]]

# Terminology

{::boilerplate bcp14-tagged}

Full client:
: TODO

Light client:
: TODO

Separable Commit:
: TODO

Per-Member Commit:
: TODO

Membership proof:
: TODO

Sender-authenticated message:
: TODO

Annotated Welcome:
: TODO

Annotated Commit:
: TODO

# Server-Aided Commits

## Protocol Overview

Consider the example ratchet tree from {{Section 7.4 of !RFC9420}}:

~~~ aasvg
      Y
      |
    .-+-.
   /     \
  X       Z[C]
 / \     / \
A   B   C   D

0   1   2   3
~~~
{: #evolution-tree title="A Full Tree with One Unmerged Leaf" }

In a group with a ratchet tree of this form, if member 0 were to commit, they
would compute two updated path secrets X' and Y', and three encrypted versions
of these path secrets:

1. X' encrypted to B
2. Y' encrypted to C
3. Y' encrypted to D

With a normal MLS Commit, all three of these encrypted values are sent to each
other member -- even though each member can only decrypt one of the encrypted
values.  Since the number of encrypted values can grow linearly as the size of
the group, in the worst case, this creates quadratic data to be transmitted.

With server-aided Commits, each member receives only what they decrypt.  The
committer can make individual messages for each member, or they can emit a
single message with all encrypted values, which the DS can use to construct
per-member messages.  We call the per-member messages PerMemberCommits, and the
message carrying all of the encrypted values a SeparableCommit.

~~~ aasvg
A          B          C          D
| E(B; X') |          |          |
+--------->|          |          |
|          |          |          |
| E(C; Y') |          |          |
+-------------------->|          |
|          |          |          |
| E(D; Y') |          |          |
+------------------------------->|
|          |          |          |
~~~
{: #server-aided-direct title="A committer creates per-member commits" }

~~~ aasvg
A          DS         B          C          D
| E(B; X') |          |          |          |
| E(C; Y') |          |          |          |
| E(D; Y') |          |          |          |
+--------->|          |          |          |
|          |          |          |          |
|          | E(B; X') |          |          |
|          +--------->|          |          |
|          |          |          |          |
|          | E(C; Y') |          |          |
|          +-------------------->|          |
|          |          |          |          |
|          | E(D; Y') |          |          |
|          +------------------------------->|
|          |          |          |          |
~~~
{: #server-aided-ds title="The DS creates per-member commits" }

## CommittedProposals

~~~ tls-syntax
struct {
    ProposalOrRef proposals<V>;
} CommittedProposals;
~~~

## SeparableCommit and PerMemberCommit

~~~ tls-syntax
struct {
    // PrivateMessage or PublicMessage
    // content_type = committed_proposals
    MLSMessage committed_proposals;

    optional<UpdatePath> path;
} SeparableCommit;
~~~

~~~ tls-syntax
struct {
    // PrivateMessage or PublicMessage
    // content_type = committed_proposals
    MLSMessage committed_proposals;

    optional<HPKECiphertext> encrypted_path_secret;
} PerMemberCommit;
~~~

[[ Processing: Basically the same as Commit, just get your path information (if
any) from outside the signature boundary.  Transcript hash advances with just
the proposal list, not the path. ]]

# Light Clients

## Protocol Overview

A light client does not receive or validate a full copy of the ratchet tree for
a group, but still possesses the group's secrets, including receiving updated
secrets as the group evolves.  When MLS messages are sent to a light client,
they need dto be accompanied by annotations that provide the light client with
just enough of information about the ratchet tree to process the message.  These
annotations can be computed by any party with knowledge of the group's ratchet
tree, including the committer and sometimes the DS.

[[ TODO protocol diagrams ]]

## Tree Slices and Partial Trees

~~~
struct {
    opaque hash_value;
} CopathHash;

struct {
  uint32 leaf_index;
  uint32 n_leaves;
  optional<Node> direct_path_nodes<V>;
  CopathHash copath_hashes<V>;
} MembershipProof;
~~~

[[ A membership proof is "valid relative to a tree hash" if the tree hash
computed over the membership proof is equal to the given tree hash. ]]

## Sender Authentication

[[ "Sender authenticated message" -- accompanied by a membership proof for the
sender, relative to the tree hash for an epoch, so that signatures can be
validated. ]]

~~~ tls-syntax
struct {
    T message;
    MembershipProof sender_membership_proof;
} SenderAuthenticatedMessage;
~~~

## Annotated Welcome

[[ Sender-authenticated Welcome, plus membership proof for the joiner relative
to the tree head in the Welcome. ]]

~~~ tls-syntax
struct {
    SenderAuthenticated<Welcome> welcome;
    MembershipProof joiner_membership_proof;
} AnnotatedWelcome;
~~~

## Annotated Commit

[[ Sender-authenticated Commit, SeparableCommit, or PerMemberCommit, plus (a) a
proof that the sender is still a member after the commit, and (b) a proof that
the recipient is still a member after the commit. ]]

~~~ tls-syntax
struct {
    // PrivateMessage or PublicMessage
    // content_type = commit
    SenderAuthenticated<MLSMessage> commit;

    // The recipient can compute which entry in the UpdatePath in the Commit
    // it should use based on the sender index in the Commit.  This index tells
    // it which HPKECiphertext in the UpdatePathNode to use.
    uint32 resolution_index;

    MembershipProof sender_membership_proof_after;
    MembershipProof receiver_membership_proof_after;
} AnnotatedCommit;
~~~

~~~ tls-syntax
struct {
    SenderAuthenticated<PerMemberCommit> commit;

    MembershipProof sender_membership_proof_after;
    MembershipProof receiver_membership_proof_after;
} AnnotatedPerMemberCommit;
~~~

[[ Light clients MUST receive any non-tree-modifying proposals that are
committed, e.g., GCE or PSK.  They SHOULD receieve tree-modifying proposals for
completeness.]]

## Negotiation

[[ LeafNode extension to indicate whether a client is a light client ]]

[[ Note that a full client

# Security Consideratiosn

[[ TODO ]]

# IANA Considerations

[[ TODO ]]

--- back

# Acknowledgments
{:numbered="false"}

TODO acknowledge.

