---
title: "Light MLS"
abbrev: "lmls"
category: info

docname: draft-kiefer-light-mls-latest
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

This document describes an extension to MLS, light MLS, that introduces light clients
that can efficiently join groups, process group changes, send and receive
application messages, but cannot commit changes to the group. The
reduced complexity results in lower cost and a smaller implementation
for light clients, making them attractive in many scenarios.

--- middle

# Introduction

The design of MLS in {{!RFC9420}} implicitly requires all members to download
and maintain the full MLS tree, validate the credentials and signatures of
all members, and process full commit messages. The size of the MLS tree
is linear in the size of the group, and each commit message can also grow
to be linear in the group size. Consequently, the MLS design results in high
latency and performance bottlenecks at new members seeking to join a large
group, or processing commits in large groups.

This document defines a modified MLS client for the protocol from
{{!RFC9420}} that has significantly lower communication and
computation complexity, logarithmic in the group size. The key idea
behind this optimization is that a light client does not download,
validate, or maintain the full tree. Instead, it only maintains
a tree-slice: the part of tree that it needs to process commits.

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

The rest of the documemt defines the
behavior of light clients, and all required modifications to standard
MLS clients and the MLS infrastructure.

As such the document is structured as follows

* {{mls-groups-with-light-clients}} gives an overview of the changes compared
  to {{!RFC9420}} and introduces terminology and concepts used throughout this document.
* {{light-mls}} defines data structures used for light clients.
* {{full-members}} describes changes to {{!RFC9420}} compliant MLS clients.
* {{deploying-light-mls}} describes requirements on the delivery service and discusses deployment
  considerations.
* {{security-considerations}} discusses security implications for light clients
  and deployments that involve light clients.

# Conventions and Definitions

{::boilerplate bcp14-tagged}

# MLS Groups with Light Clients

An MLS group that supports light clients has two kinds of members:
full clients that can send and receive all MLS messages, and light
clients that cannot send commits but can otherwise participate in
the group normally. If a light client wishes to send a commit,
it can upgrade itself to a full client
({{committing-with-a-light-client}}).

## Terminology
This document introduces the following new concepts

- Tree Slice: A tree slice is the direct path from a leaf node to the root, together with the tree hashes on the co-path.
- Proof of Membership: A proof of membership for leaf A is a tree slice that proves that leaf A is in the tree with the tree hash in the root of the tree slice.
- Partial Commit: A partial commit is a commit that the server stripped down to
  hold only the encrypted path secret for the receiver.
- Light client: A light client is a client that does not know the
  MLS tree but only its own tree slice.
- Full client: A full client is conversely a client that is running the full
  MLS protocol from {{!RFC9420}}.

## Protocol Changes Overview
MLS groups that support light clients must use the `light_clients` extension
({{light-mls-extension}}) in the required capabilities.
When this extension is present in the group context, all messages, except for
application messages, MUST use public messages.

XXX(RLB): I don't love this restriction to public messages, and I don't think
it's necessary.  Clearly it is necessary if the DS is doing the fanout.  But it
seems like you could also envision a scenario where the committer knows which
clients are light (maybe via a LeafNode extension), and generates a light Commit
for each light client.  It puts more burden on the committer, but a group using
PrivateMessage is generally more taxing for committers anyway.  Some technical
details on how to do this below.

XXX(RLB): It might be worth defining a LeafNode extension here to signal that a
client is operating in light mode.  (Note that a client can operate in light
mode even if it gets a full Welcome, but cannot process a full Commit.)

XXX(RLB): It would be worth fleshing out a use case here, since there are some
assumptions on what the committer sends and what the DS does.  Even in the
DS-assisted case, the committer needs to send a fresh GroupInfo.

The changes are primarily on light clients.

When joining a group as a light client, the client downloads the proof of memberships
for the sender (committer) and the receiver (the light client).
The sender's proof of membership can be discarded after being checked such that only
the client's direct path and hashes on the co-path are stored.

Proposals are not processed.
They are only stored to apply when commits use proposals by reference and to know
the proposal sender.

XXX(RLB): Do light clients even need to see proposals?  For anything related to
the tree, they don't care.  They never see the proposal list in the Commit.  The
only possible things are PSK, ReInit, and GroupContextExtensions proposals,
which I'm not sure we handle properly anyway.  We should probably do an audit of
proposals to make sure that a light client gets enough information to react
appropriately to a commit that covers them (maybe throw them into some extension
alongside the tree slice), and also insert some words about future proposal
types.

When processing a commit, the client retrieves

- the partial commit that contains only the path secret encrypted for the client
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

# Light MLS

Light MLS is a variant of MLS run by light clients.

This draft defines two new `MLSMessage` types with `wire_format = 0x0006` and
`wire_format = 0x0007`.

Light welcomes, `wire_format = 0x0006`, are defined as follows.
In particular, the `Welcome` message is extended with the `TreeSlice`.

XXX(RLB): Syntactically, I would be tempted to handle `tree_info` in the same
way as the ratchet tree.  Namely, allow the committer to include it as an
extension in the GroupInfo if they want (possibly for multiple joiners), and if
it's not in the GroupInfo, don't say anything about how the joiner gets it.

~~~tls
struct {
    Welcome welcome;
    TreeSlice tree_info;
} LightWelcome;

struct {
    ProtocolVersion version = mls10;
    WireFormat wire_format;
    select (MLSMessage.wire_format) {
        ...
        case mls_light_welcome:
            LightWelcome light_welcome;
    };
} MLSMessage;
~~~

Similarly, light commits, `wire_format = 0x0007`, are defined as follow.
The commit message is extended with the `TreeSlice`, a `GroupInfo`, and
the `decryption_node_index` for the decryption key of the path secret.

> XXX(RLB): The LightCommit structure here seems unnecessarily verbose.  It seems
> like the commit operation here is actually almost exactly the same as the join
> operation -- the only difference is that you get the `joiner_secret` from the
> last key schedule rather than the Welcome.
> 
> Note also that the function served by `decryption_node_index` here is done by
> finding a common ancestor with the committer in the Welcome case; would be handy
> to re-use that logic here.  
> 
> Given all that, I would be tempted to define a new ContentType (which could go
> in PublicMessage or PrivateMessage) that just has a GroupInfo, and a GroupInfo
> extension for the required HPKECiphertext.  Compared to the struct below:
> * `commit` corresponds to the HPKECiphertext extension
> * `tree_info` is in a TreeSlice extension (or external some unspecified way)
> * `group_info` is the same
> * `decryption_node_index` is computed as the common ancestor with
>   `group_info.sender`, as in the Welcome case.
>
> This doesn't seem like it really changes the analysis, just ships the
> information around differently so that it's a ligher extension (heh) and
> compatible with PrivateMessage.

~~~tls
struct {
    PublicMessage commit;
    TreeSlice tree_info;
    GroupInfo group_info;
    uint32 decryption_node_index;
} LightCommit;

struct {
    ProtocolVersion version = mls10;
    WireFormat wire_format;
    select (MLSMessage.wire_format) {
        ...
        case mls_light_commit:
            LightCommit light_commit;
    };
} MLSMessage;
~~~

Full MLS clients do not need to implement these types.
The delivery service builds these messages instead.

While the `Commit` structure stays as defined in Section 12.4 {{!RFC9420}}, the
content is changed.
To reduce the size of `Commit` messages, especially in large, sparse trees, the
delivery service strips unnecessary parts of member Commits.
See {{deploying-light-mls}} for details on the requirements on the delivery service.

In the `Commit` in a `LightCommit` messages only the relevant `HPKECiphertext`
value in the `encrypted_path_secret`, in the `UpdatePath` that is relevant
for the receiver, is kept.

## Verifying Group Validity
A light client can not do all the checks that a client with the MLS tree can do.
We therefore update the checks performed on tree modifications.
Instead of verifying the MLS tree, light clients verify that they are in a group
with a certain tree hash value.
In particular the validation of commits and welcome packages are modified compared
to {{!RFC9420}}.

### Joining a Group via Light Welcome Message
When a new member joins the group with a Light Welcome message
(Section 12.4.3.1. {{!RFC9420}}) without the ratchet tree extension the checks
are updated as follows.

1. Verify the `GroupInfo`
    1. signature
    2. confirmation tag
    3. tree hash
2. Verify the sender's membership (see {{proof-of-membership}}).
3. Check the own direct path to the root (see {{proof-of-membership}}).
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

1. Verify the sender's membership (see {{proof-of-membership}}) and leaf node (see Section 7.3 {{!RFC9420}}).
2. Verify the own path (see {{proof-of-membership}}).
3. Verify the GroupInfo signature.
4. Check the tree hash in the GroupInfo matches the clients own tree hash.

## Proof of Membership
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

XXX(RLB): While I agree with this, it's not strictly needed with a strict
light/full dichotomy.  Where it's interesting is for "light+" clients -- light
clients that have authenticated some of the rest of the tree.  This seems like a
concept worth defining; even if there is a hard dichotomy between "have the full
tree" / not for purposes of whether you can make a commit, having a partial tree
can let you authenticate some other members.

~~~tls
struct {
  uint32 index;
  opaque tree_hash<V>;
  opaque original_tree_hash<V>; // XXX(RLB) Why do you need the OTH if you don't
                                // have a full tree?
} Hashes;

enum {
  reserved(0),
  xnode(1),
  hashes(2),
  (255)
} XNodeType;

struct {
  optional<Node> node;
  uint32: index; // XXX(RLB) Nit: ":"
} XNode;

struct {
  XNodeType node_type;
  select (XNode.node_typ) { // XXX(RLB): "node_type"
    case xnode:  XNode xnode;
    case hashes: Hashes hashes;
  }
} SliceNode;

struct {
  SliceNode nodes<V>;   // XXX(RLB): Minor: I would probably just make separate
                        //           vectors for nodes and hashes, vs. the
                        //           select above.
  uint32 own_node;      // XXX(RLB): Nit: `leaf_index`
  uint32 num_nodes;     // XXX(RLB): Nit: `n_leaves`
} TreeSlice;
~~~

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

## Committing with a Light Client

A light client *can not commit* because it doesn't know the necessary
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

# Deploying Light MLS
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
clients to MLS.
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
Yet, the exact security of the protocol is not fully understood yet.
To describe the security of light MLS and how it relates to the security of full
MLS we therefore define the following main high-level guarantees of MLS as follows:

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
{: title="MLS Extensio Types Registry" }

--- back

# Acknowledgments
{:numbered="false"}

TODO acknowledge.
