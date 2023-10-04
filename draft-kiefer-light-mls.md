---
###
# Internet-Draft Markdown Template
#
# Rename this file from draft-todo-yourname-protocol.md to get started.
# Draft name format is "draft-<yourname>-<workgroup>-<name>.md".
#
# For initial setup, you only need to edit the first block of fields.
# Only "title" needs to be changed; delete "abbrev" if your title is short.
# Any other content can be edited, but be careful not to introduce errors.
# Some fields will be set automatically during setup if they are unchanged.
#
# Don't include "-00" or "-latest" in the filename.
# Labels in the form draft-<yourname>-<workgroup>-<name>-latest are used by
# the tools to refer to the current version; see "docname" for example.
#
# This template uses kramdown-rfc: https://github.com/cabo/kramdown-rfc
# You can replace the entire file if you prefer a different format.
# Change the file extension to match the format (.xml for XML, etc...)
#
###
title: "MLS with Lightweight Clients"
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

This document describes a variant of the MLS protocol with lightweight clients
that are passive in the protocol and only send application messages and proposals.

Passive clients are advantageous on resource constrained devices or can be used
to bootstrap clients lazily.
The reduced complexity, which also results in a smaller implementation, makes
light clients attractive for many scenarios.

--- middle

# Introduction

This draft defines passive clients for MLS and required modifications on the
infrastructure and full MLS clients.

As such the document is structured as follows

* {{mls-groups-with-passive-clients}} gives an overview of the changes compared
  to {{!RFC9420}} and introduces terminology and concepts used throughout this document.
* {{light-mls}} defines data structures used for passive clients.
* {{active-members}} describes changes to {{!RFC9420}} compliant MLS clients.
* {{deploying-light-mls}} describes requirements on the delivery service and discusses deployment
  considerations.
<!-- * {{passive-clients}} details the operation of passive clients -->
* {{security-considerations}} discuss security implications for passive clients
  and deployments that involve passive clients.

The design of MLS in {{!RFC9420}} implicitly requires all members to download
and check a significant amount of cryptographic information, resulting in high
latency and performance bottlenecks at new members seeking to join a large group.

This document defines a modified MLS client for the protocol from {{!RFC9420}}
that has logarithmic communication and computation complexity.

This document does not change the structure of the MLS tree, or the contents of
messages sent in the course of an MLS session.
It only specifies the local state stored at light clients, and changes how each
recipient downloads and checks group message.
Furthermore, the changes only affect the component of MLS that manages,
synchronizes, and authenticates public group state.

# Conventions and Definitions

{::boilerplate bcp14-tagged}

# MLS Groups with Passive Clients

MLS groups with passive clients allow light clients to achieve logarithmic computation
and communication complexity by not using the MLS tree.
In turn, these clients can only commit after upgrading to full clients
({{committing-with-a-passive-client}}).

## Terminology
This document introduces the following new concepts

- Proof of Membership: A proof of membership for leaf A is a direct path, or tree
  slice from a leaf node to the root with full nodes along the path, and parent
  and tree hashes on the co-path.
- Partial Commit: A partial commit is a commit that the server stripped down to
  hold only the encrypted path secret for the receiver.
- Passive client: A passive, or light, client is a client that does not know the
  MLS tree but only its own path.
- Active client: An active client is conversely a client that is running the full
  MLS protocol from {{!RFC9420}}.

## Protocol Changes Overview
MLS groups that support passive clients must use the `light_clients` extension
({{light-mls-extension}}) in the required capabilities.
When this extension is present in the group context, all messages, except for
application messages, MUST use public messages.

The changes are primarily on light clients.

When joining a group as a light client, the client downloads proof of memberships
for the sender (committer) and the receiver (the light client).
The sender's proof of membership is discarded after being checked such that only
the client's direct path and hashes on the co-path are stored.

Proposals are not processed.
They are only stored to apply when commits use proposals by reference and to know
the proposal sender.

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

While the `Commit` structure stays as defined in Sec. 12.4 {{!RFC9420}}, the
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
with a certain hash value.
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

Instead, the proof of membership in the `tree_info` is verified for the sender
and the receiver.

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

When a member receives a Light Commit message (Section 12.4.2. {{!RFC9420}})
the checks are updated as follows.

1. Verify the sender's membership (see {{proof-of-membership}}) and leaf node (see Section 7.3 {{!RFC9420}}).
2. Verify the own path (see {{proof-of-membership}}).
3. Verify the GroupInfo signature.
4. Check the tree hash in the GroupInfo matches the clients own tree hash.

## Proof of Membership
Tree slices are used to proof group membership of leaves.
The `tree_info` in light MLS messages always contains the sender's and the receiver's
tree slices to allow the receiver to check the proof of membership.

To verify the correctness of the group on a light client, the client checks its
tree hash and parent hashes.
For each direct path from a leaf to the root that the client has (tree slices),
it checks the parent hash value on each node by using `original_tree_hash` of
the co-path nodes.
The tree hash on the root node is computed similarly, using the `tree_hash` values
for all nodes where the client does not have the full nodes.

The `TreeSlice` for proof of memberships can be queried from the delivery service
at any point for any member in the tree.

~~~tls
struct {
  uint32 index;
  opaque tree_hash<V>;
  opaque original_tree_hash<V>;
} Hashes;

enum {
  reserved(0),
  xnode(1),
  hashes(2),
  (255)
} XNodeType;

struct {
  optional<Node> node;
  uint32: index;
} XNode;

struct {
  XNodeType node_type;
  select (XNode.node_typ) {
    case xnode:  XNode xnode;
    case hashes: Hashes hashes;
  }
} SliceNode;

struct {
  SliceNode nodes<V>;
  uint32 own_node;
  uint32 num_nodes;
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
It further defines ways passive clients may upgrade to a full client.

- `no_upgrade` does not allow light clients to upgrade to full MLS.
- `resync_upgrade` allows light clients to upgrade to full MLS by using an external commit.
  The resync removes the old client from the group and adds a new client with full MLS.
- `self_upgrade` allows light clients to upgrade to full MLS by retrieving the full tree
  from the server. Together with the signed group info of the current epoch the
  client "silently" upgrades to full MLS with security equivalent to joining a new
  group. The client MUST perform all checks from Section 12.4.3.1 {{!RFC9420}}.
- `any_upgrade` allows light clients to use either of the two upgrade mechanisms.

## Committing with a Passive Client

A passive client *can not commit* because it doesn't know the necessary
public keys in the tree to encrypt to.
Therefore, if a passive client wants to commit, it first has to upgrade to full MLS.
Because a passive client is not able to fully verify incoming
proposals, it MUST NOT commit to proposals it received while not holding a full tree.
A client that is upgrading to a full MLS tree is therefore
considered to be a new client that has no knowledge of proposals before it joined.
Note that this restriction can not be enforced.
However, since each client in {{!RFC9420}} must check the proposals, a misbehaving
client that upgraded can only successfully commit bogus
proposals when all other clients and the delivery service agree.

The passive clients extension ({{light-mls-extension}}) defines the possible
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

If the client does not expect to commit regularly, only the own path should
be kept after a commit.

# Active Members

Full RFC members in groups with light clients don't need significant changes.
Any changes can always be built on top of regular MLS clients.
In particular, active MLS clients are required to send a `GroupInfo` alongside
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

Light MLS may also be used to on low powered devices that only occasionally upgrade
to full MLS clients to commit to the group, for example when charging.

Light clients can decide to store the tree slices and build up a tree over time
when other members commit.
But client may decide to delete the sender paths it gets after verifying it's
correctness.

## Tree slices from the Sender

When the delivery service does not provide the necessary endpoints to query the
expandable paths, the sender can include it into the `GroupInfo` extensions in
the `Welcome` message.

# Security Considerations

The MLS protocol in {{!RFC9420}} has a number of security analyses attached.
Yet, the exact security of the protocol is fully understood yet.
To describe the security of light MLS and how it relates to the security of full
MLS we therefore define the following main high-level guarantees of MLS are as follows:

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

To verify the security guarantees provided by passive members, a new security analysis is needed. We have analyzed the security of the protocol using two verification tools ProVerif and F*. In the following, we will describe our model and results.

Light MLS preserves these invariants and thereby all the security goals of MLS
continue to hold at active members.
However, a passive member may not know the identities of all other members in the
group, and it may only discover these identities on-demand.
Consequently, the Member Identity Authentication guarantee is weaker than in RFC MLS,
where all member identities are constantly verified by every member of the group.
Furthermore, since passive members do not store the MLS tree, membership agreement
only holds for the hash of the MLS tree:

- **Passive Membership Agreement**: If a passive client B has a local group state
  for group G in epoch N, and it receives (and accepts) an application message
  from a sender A for group G in epoch N, then A must be a member of G in epoch N
  at B, and if A is honest, then A and B agree on the GroupContext of the group G in epoch N.
- **Passive Member Identity Authentication**: If a passive client B has a local
  group state for group G in epoch N, and B has verified A’s membership proof in G,
  and A is linked to a user identity U, then either the signature key of U’s
  credential is compromised, or A belongs to U.
- **Passive Group Key Secrecy**: If a passive client B has a local group state
  for group G in epoch N with group key K (init secret), and if the tree hash at B
  corresponds to a full tree, then K can only be known to members at the leaves
  of this tree. That is, if the attacker knows K, then the signature or decryption
  keys at one of the leaves must have been compromised.

Another technical caveat is that since passive members do not have the full tree,
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
