---
title: "Light Clients for MLS"
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

normative:

informative:


--- abstract

The Messaging Layer Security (MLS) protocol provides efficient
asynchronous group key establishment for large groups with up to
thousands of clients.  In MLS, any member can commit a change to the
group, and consequently, all members must download, validate, and maintain
the full group state which can incur a significant communication and
computational cost, especially when joining a group.

This document defines Light MLS, an extension that allows for "light clients".
A light client cannot commit changes to the group, and only has partial
authentication information for the other members of the group, but is otherwise
able to participate in the group.  In exchange for these limitations, a light
client can participate in an MLS group with significantly lower requirements in
terms of download, memory, and processing.

--- middle

# Introduction

The Messaging Layer Security protocol {{!RFC9420}} enables continuous group
authenticated key exchange among a group of clients.
The design of MLS implicitly requires all members to download
and maintain the full MLS tree, validate the credentials and signatures of
all members, and process full commit messages. The size of the MLS tree
is linear in the size of the group, and each commit message can also grow
to be linear in the group size. Consequently, the MLS design results in high latency and performance bottlenecks at new members seeking to join a large group, or processing commits in large groups.

This document defines an extension to MLS to allow for "light clients" --
clients that do not download, validate, or maintain the entire ratchet tree for
the group.  On the one hand, this "lightness" allows a light client to
participate in the group with much significantly lower communication and
computation complexity (logarithmic in the group size in the worst case).  On
the other hand, without the full ratchet tree, the light client cannot create
Commit messages to put changes to the group into effect.  Light clients also
only have authentication information for the parts of the tree they download,
not the whole group.

We note that this document does not change the structure of the MLS
tree, or the contents of messages sent in the course of an MLS
session.  It only modifies the local state stored at light clients,
and changes how each light client downloads and checks group messages.
The only modifications required for standard clients are related to
the negotiation of an MLS extension, and additional data they need to
send with each commit.
Furthermore, we note that the changes in this
document only affects the component of MLS that manages, synchronizes,
and authenticates the public group state.
It does not affect the TreeKEM
key establishment or the application message sub-protocols.

The rest of the documemt defines the behavior of light clients, and the required
modifications to standard MLS clients and the MLS infrastructure.

# Conventions and Definitions

{::boilerplate bcp14-tagged}

# Terminology

This document introduces the following new concepts

- Tree Slice: A tree slice is the direct path from a leaf node to the root, together with the tree hashes on the co-path.
- Proof of Membership: A proof of membership for leaf A is a tree slice that proves that leaf A is in the tree with the tree hash in the root of the tree slice.
- Light Commit: A light commit is a commit that the server stripped down to
  hold only the encrypted path secret for the receiver.
- Light client: A light client is a client that does not know the
  MLS tree but only its own tree slice.
- Full client: A full client is conversely a client that is running the full
  MLS protocol from {{!RFC9420}}.

# Protocol Overview

~~~ aasvg

 Full           Delivery        Light      Light      Light
Client          Service       Client A   Client B   Client C
  |                |              |          |          |
  | Commit         |              |          |          |
  | GroupInfo      |              |          |          |
  | Welcome        |              |          |          |
  +--------------->| Welcome      |          |          |
  |                +------------->|          |          |
  |                |              |          |          |
  |                | LightCommitB |          |          |
  |                +------------------------>|          |
  |                |              |          |          |
  |                | LightCommitC |          |          |
  |                +----------------------------------->|
  |                |              |          |          |
  |                | TreeSliceB   |          |          |
  |                +------------->|          |          |
  |                |              |          |          |
~~~
{: #fig-overview title="Overview of Light MLS" }

{{fig-overview}} illustrates the three main changes introduced by Light MLS:

1. Light clients are always added to the group with a "light" Welcome message,
   i.e., one that does not include the `ratchet_tree` extension.
2. The MLS Delivery Service splits each Commit message into a set of LightCommit
   messages, one per light client.
3. Light clients can download "slices" of the tree to authenticate individual
   other users (here, A authenticates B).

MLS groups that support light clients must use the `light_clients` extension
({{light-mls-extension}}) in the required capabilities.
When this extension is present in the group context, all messages, except for
application messages, MUST use public messages.

The changes are primarily on light clients.  When joining a group as a light
client, the client downloads the proof of memberships for the sender (committer)
and the receiver (the light client).  The sender's proof of membership can be
discarded after being checked such that only the client's direct path and hashes
on the co-path are stored.

Light clients do not process proposals that modify the structure of the tree, in
particular Add, Update, or Remove proposals.

When processing a commit, the client retrieves

- the light commit that contains only the path secret encrypted for the client
- the sender's proof of membership
- the signed group info

The client MUST NOT check the signature and membership tag on the framed content,
but MUST check the sender's proof of membership, the signed group info, and the
confirmation tag.

In groups with `light_clients` support, committers MUST send a signed group
info with every commit.

The server MUST track the public group state together with the signed group info,
and provide endpoints for clients to retrieve light commits and light welcomes.
Further, it SHOULD provide an API to retrieve proof of memberships for arbitrary
leaves, and an API to retrieve the full tree.

# Open Questions

**Proposals:** In this document, we have assumed that light clients don't need
to see or validate proposals.  This is clearly true for proposals that just
modify the tree, e.g., Add/Update/Remove, but less clear for proposals such as
PreSharedKey and GroupContextExtensions, and even less clear for custom
proposals.  We may want to define a way that an application could enable light
clients to verify some proposals.  A light client can verify the signature on a
proposal given a tree slice for the signer, but more mechanism might be needed
to allow a light client to verify that a proposal was actually included in a
Commit.

**Slimming Down Further:** We have assumed that LeafNode and GroupInfo messages
are small enough that it's acceptable for light clients to have to download
them.  However, these messages themselves can be large, e.g., due to large
extensions.  It may be desireable to define lighter variants of these structs,
for example:

* Defining a variant of GroupInfo that is intended for members of the group, who
  do not need to receive a copy of the GroupContext extensions.
* Updating the tree hash algorithm for leaf nodes so that a light client could
  receive and verify a subset of a leaf node (e.g. only the signature key and
  credential)

# Tree Slices

A light client does not download or store the whole MLS ratchet tree, but still
needs to download parts of the tree to verify the membership and identity of
specific members.  For example, the client needs to verify that it is in fact a
member of the group, and that the sender of a Welcome adding it to the group is
a member.

A tree slice provides one or more leaf nodes from the tree, together with the
nodes and node hashes that are required to verify that those leaves are included
in a tree with a given tree hash.  A tree slice can thus function as a proof of
membership for the members at the included leaf nodes.

~~~ aasvg
              X = root
              |
        .-----+-----.
       /             \
      X               #
      |
    .-+-.
   /     \
  #       X
         / \
        X   #

0   1   2   3   4   5   6   7
~~~
{: #fig-tree-slice title="Tree slice for leaf 2 in an 8-member tree.  For nodes
with 'X', the full node is included; with '#', only the hash." }

~~~ tls
struct {
  uint32 index;
  opaque tree_hash<V>;
} Hashes;

enum {
  reserved(0),
  xnode(1),
  hashes(2),
  (255)
} XNodeType;

struct {
  optional<Node> node;
  uint32 index;
} XNode;

struct {
  XNodeType node_type;
  select (XNode.node_type) {
    case xnode:  XNode xnode;
    case hashes: Hashes hashes;
  }
} SliceNode;

struct {
  SliceNode nodes<V>;
  uint32 leaf_index;
  uint32 n_leaves;
} TreeSlice;
~~~

Tree slices are used to prove group membership of leaves.
The `tree_info` in light MLS messages always contains the sender's and may contain the receiver's
tree slices to allow the receiver to check the proof of membership.

To verify the correctness of the group on a light client, the client checks its
tree hash and parent hashes.
For each direct path from a leaf to the root that the client has (tree slices),
it checks the parent hash value on each node by using `original_tree_hash` of
the co-path nodes.
The tree hash on the root node is computed similarly, using the `tree_hash` values
for all nodes where the client does not have the full nodes.

The delivery service should allow to query `TreeSlice` for proof of memberships at any point for any member in the tree.

# Light MLS

Light MLS is a variant of MLS run by light clients.

For light welcomes the necessary tree information can be retrieved from the delivery server, or provided
via the `tree_info` GroupInfo extension.

~~~tls
struct {
    TreeSlice tree_info<V>;
} TreeInfo
~~~

Light commit messages are defined as a new content type for the FramedContent.
A light commit contains a GroupInfo with a LightPathSecret extension, which contains
the commit secret for the receiving light client and the corresponding node index.
In addition, the GroupInfo contains a TreeInfo extension with the committer's
direct paths.

~~~tls
enum {
    reserved(0),
    application(1),
    proposal(2),
    commit(3),
    light_commit(4),
    (255)
} ContentType;

struct {
    HPKECiphertext encrypted_path_secret;
    uint32 decryption_node_index;
} LightPathSecret;

struct {
    GroupInfo group_info;
} LightCommit;
~~~

Full MLS clients do not need to implement these types.
The delivery service can build these messages instead.

The committer's new leaf node is not part of the LightCommit message.
Instead, it is part of the `tree_info` extension in the GroupInfo.

## Verifying Group Validity

A light client can not do all the checks that a client with the MLS tree can do.
We therefore update the checks performed on tree modifications.
Instead of verifying the MLS tree, light clients verify that they are in a group
with a certain tree hash value.
In particular the validation of commits and welcome packages are modified compared
to {{!RFC9420}}.

### Joining as a Light Client

When a new member joins the group with a Light Welcome message
(Section 12.4.3.1. {{!RFC9420}}) without the ratchet tree extension the checks
are updated as follows.

1. Verify the `GroupInfo`
    1. signature
    2. confirmation tag
    3. tree hash
2. Verify the sender's membership (see {{tree-slices}}).
3. Check the own direct path to the root (see {{tree-slices}}).
4. Do *not* verify leaves in the tree.

### Processing a Light Commit
Because the the signature and membership tag on the `FramedContent` in Light Commit
messages is broken, these MUST NOT be checked by the receiver.

Instead, the proof of membership in the `tree_info` is verified for the sender.

Note that while a light client can check the parent hashes when verifying the new
group state, it can not verify all points from Sec. 7.9.2 in {{!RFC9420}}.
In particular, the check that "D is in the resolution of C, and the intersection of P's
`unmerged_leaves`` with the subtree under C is equal to the resolution of C with D removed."
can not be performed because the light client can not compute the resolution.
But this property always holds on correctly generated tree, which the light client
has to trust, not knowing the MLS tree.

Taking the confirmed transcript hash from the GroupInfo, a light client checks
the confirmation tag.
Otherwise, a Light Commit is applied like a regular commit.

In summary, when a member receives a Light Commit message the checks are updated as follows.

1. Verify the sender's membership (see {{tree-slices}}) and leaf node (see Section 7.3 {{!RFC9420}}).
2. Verify the own path (see {{tree-slices}}).
3. Verify the GroupInfo signature.
4. Check the tree hash in the GroupInfo matches the clients own tree hash.

## Light MLS Extension
The `light_clients` group context extension is used to signal that the group
supports Light MLS clients.

~~~tls
enum LightClientType {
  reserved(0),
  no_upgrade(1),
  resync_upgrade(2),
  self_upgrade(3),
  any_upgrade(4),
  (255)
}

struct {
  LightClientType upgrade_policy;
} LightMlsExtension;
~~~

The extension must be present and set in the required capabilities of a group
when supporting light clients.
It further defines ways light clients may upgrade to a full client.

- `no_upgrade` does not allow light clients to upgrade to full MLS.
- `resync_upgrade` allows light clients to upgrade to full MLS by using an external commit.
  The resync removes the old client from the group and adds a new client with full MLS.
- `self_upgrade` allows light clients to upgrade to full MLS by retrieving the full tree
  from the server. Together with the signed group info of the current epoch the
  client "silently" upgrades to full MLS with security equivalent to joining a new
  group. The client MUST perform all checks from Section 12.4.3.1 {{!RFC9420}}.
- `any_upgrade` allows light clients to use either of the two upgrade mechanisms.

### Light MLS LeafNode
The `light_client` leaf node extension signals that a leaf node is a light client.
The extension is an empty struct.

~~~tls
struct {

} LightMlsClient;
~~~

## Committing with a Light Client

A light client *cannot commit* because it doesn't know the necessary
public keys in the tree to encrypt to.
Therefore, if a light client wants to commit, it first has to upgrade to full MLS.
Because a light client is not able to fully verify incoming
proposals, it MUST NOT commit to proposals it received while not holding a full tree.
A client that is upgrading to a full MLS tree is therefore
considered to be a new client that has no knowledge of proposals before it joined.
Note that this restriction can not be enforced.
However, since each client in {{!RFC9420}} must check the proposals, a misbehaving
client that upgraded can only successfully commit bogus
proposals when all other clients and the delivery service agree.

The light clients extension ({{light-mls-extension}}) defines the possible
upgrade paths for light clients.

In order to ensure that the tree retrieved from the server contains the tree
slice known to the client, the upgrading client MUST perform the following checks:

* Verify that the tree hash of the tree slice and the full tree are equivalent.
* Verify that all full nodes (`XNode`) in the client's state are equivalent to
  the corresponding nodes in the full tree.
* Perform all checks on the tree as if joining the group with a `Welcome` message
(see Section 12.4.3.1. in {{!RFC9420}}).

Note that the client already checked the signed group info.

To retrieve the full tree, the delivery service must provide an end point,
equivalent to the one used to retrieve the full tree for a new member that wants
to join with a commit.

### Maintaining state

After committing, the client can decide to switch to regular MLS and process the
full tree as described in {{!RFC9420}}.
This will cause the client's performance to degrade to the performance of regular
MLS, but allows it to commit again without the necessity to download the full
tree again.

If the client does not expect to commit regularly, only the own tree slice should
be kept after a commit.

# Full Members

Full MLS members in groups with light clients don't need significant changes.
Any changes can always be built on top of regular MLS clients.
In particular, full MLS clients are required to send a `GroupInfo` alongside
every commit message to the delivery service.
Depending on the deployment, the delivery service might also ask the client to
send a ratchet tree for each commit.
But the delivery service can track the tree based on commit messages such that
sending ratchet trees with commits is not recommended.

# Operational Considerations

The delivery service for MLS groups with light clients must provide additional
endpoints for Light Welcome and Light Commit messages.
In order to provide these endpoints the server must keep track of the public
group state.

## Delivery Service Commit Processing

The delivery service processes Commits for light clients and produces `LightCommit`
messages for them.
To do this, the server creates the sender and receiver proof of memberships (`tree_info`),
adds the `group_info` of the current epoch, and removes all information from the
`Commit` struct that is not needed by the receiver.
In particular, only the required `UpdatePathNode` is kept from the `nodes` vector,
and only the `HPKECiphertext` the receiver can process is kept from the `encrypted_path_secret`
vector.
For the receiver to identify the decryption key for the ciphertext, the server
adds the `decryption_node_index` to the `LightCommit`.

## How to use Light MLS

Bootstrapping large groups can be particularly costly in MLS.
Light MLS can be used to bootstrap large groups before lazily upgrading light
clients to full clients.
This distributes the load on the server and clients.

Light MLS may also be used on low powered devices that only occasionally upgrade
to full MLS clients to commit to the group, for example when charging.

Light clients can decide to store the tree slices and build up a tree over time
when other members commit.
But client may decide to delete the sender paths it gets after verifying it's
correctness.

## Light Messages from the Sender

When the delivery service does not provide the necessary endpoints for light messages, the committer can build and end the light commit and welcome messages directly.

# Security Considerations

The MLS protocol in {{!RFC9420}} has a number of security analyses attached.
To describe the security of light MLS and how it relates to the security of full
MLS we summarize the following main high-level guarantees of MLS as follows:

- **Membership Agreement**: If a client B has a local group state for group G in
  epoch N, and it receives (and accepts) an application message from a sender A
  for group G in epoch N, then A must be a member of G in epoch N at B, and if A
  is honest, then A and B agree on the full membership of the group G in epoch N.
- **Member Identity Authentication**: If a client B has a local group state for
  group G in epoch N, and B believes that A is a member of G in epoch N, and that
  A is linked to a user identity U, then either the signature key of U’s credential
  is compromised, or A belongs to U.
- **Group Key Secrecy**: If B has a local group state for group G in epoch N with
  group key K (init secret), then K can only be known to members of G in epoch N.
  That is, if the attacker knows K, then one of the signature or decryption keys
  corresponding to one of the leaves of the tree stored at B for G in epoch N
  must be compromised.
  To obtain these properties, each member in MLS verifies a number of signatures
  and MACs, and seeks to preserve the TreeKEM Tree Invariants:
- **Public Key Tree Invariant**: At each node of the tree at a member B, the
  public key, if set, was set by one of the members currently underneath that node
- **Path Secret Invariant**: At each node, the path secret stored at a member B,
  if set, was created by one of the members currently underneath that node

As a corollary of Group Key Secrecy, we also obtain authentication and
confidentiality guarantees for application messages sent and received within a group.

To verify the security guarantees provided by light members, a new security analysis is needed. We have analyzed the security of the protocol using two verification tools ProVerif and F*.
The security analysis, and design of the security mechanisms, are inspired by
work from Alwen et al. {{?AHKM22=DOI.10.1145/3548606.3560632}}.

Light MLS preserves the invariants above and thereby all the security goals of MLS
continue to hold at full members.
However, a light member may not know the identities of all other members in the
group, and it may only discover these identities on-demand.
Consequently, the Member Identity Authentication guarantee is weaker on light clients.
Furthermore, since light members do not store the MLS tree, membership agreement
only holds for the hash of the MLS tree:

- **Light Membership Agreement**: If a light client B has a local group state
  for group G in epoch N, and it receives (and accepts) an application message
  from a sender A for group G in epoch N, then A must be a member of G in epoch N
  at B, and if A is honest, then A and B agree on the GroupContext of the group G in epoch N.
- **Light Member Identity Authentication**: If a light client B has a local
  group state for group G in epoch N, and B has verified A’s membership proof in G,
  and A is linked to a user identity U, then either the signature key of U’s
  credential is compromised, or A belongs to U.
- **Light Group Key Secrecy**: If a light client B has a local group state
  for group G in epoch N with group key K (init secret), and if the tree hash at B
  corresponds to a full tree, then K can only be known to members at the leaves
  of this tree. That is, if the attacker knows K, then the signature or decryption
  keys at one of the leaves must have been compromised.

Another technical caveat is that since light members do not have the full tree,
they cannot validate the uniqueness of all HPKE and signature keys in the tree,
as required by RFC MLS.
The exact security implications of removing this uniqueness check is not clear
but is not expected to be significant.

# IANA Considerations

This document defines two new message types for MLS Wire Formats, and a new
MLS Extension Type

## MLS Wire Formats

| Value           | Name                     | R | Ref           |
|:----------------|:-------------------------|:--|:--------------|
| 0x0006          | mls_light_welcome        | - | This Document |
| 0x0007          | mls_light_commit         | - | This Document |
{: title="MLS Wire Formats Registry" }

## MLS Extension Types

| Value           | Name              |  Message(s) | R | Ref           |
|:----------------|:------------------|:------------|:--|:--------------|
| 0x0006          | light_clients     | GC          | - | This Document |
{: title="MLS Extension Types Registry" }

--- back

# Acknowledgments
{:numbered="false"}

TODO acknowledge.
