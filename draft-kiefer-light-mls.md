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
* {{passive-clients}} details the operation of passive clients
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

TODO: Do we want to strip welcome messages as well?

# Conventions and Definitions

{::boilerplate bcp14-tagged}

# MLS Groups with Passive Clients

MLS groups with passive clients allow light clients to achieve logarithmic computation
and communication complexity by not using the MLS tree and partial commits.
In turn, these clients can only commit after upgrading to full clients
({{committing-with-a-passive-client}}).

## Terminology
This document introduces the following new concepts

- Proof of Membership: A proof of membership for leaf A is a direct path from a
  leaf node to the root with full nodes along the path, and parent and tree
  hashes on the co-path.
- Partial Commit: A partial commit is a commit that the server stripped down to
  hold only the encrypted path secret for the receiver.
- Passive client: A passive, or light, client is a client that does not know the
  MLS tree but only its own path.
- Active client: An active client is conversely a client that is running the full
  MLS protocol from {{!RFC9420}}.

## Protocol Changes Overview
MLS groups that support passive clients must use the `light_clients` extension
({{passive-clients-extension}}) in the required capabilities.
When this extension is present in the group context, all messages, except for
application messages, MUST use public messages.

The changes are primarily on light clients.

### Joining a Group with a light client
When joining a group as a light client, the client downloads proof of memberships
for the sender (committer) and the receiver (the light client).
The sender's proof of membership is discarded after being checked such that only
the client's direct path and hashes on the co-path are stored.

### Processing Proposals
Proposals are not processed.
They are only stored to apply when commits use proposals by reference and to know
the proposal sender.

### Processing Commits
When processing a commit, the client retrieves

- the partial commit that contains only the path secret encrypted for the client
- the sender's proof of membership
- the signed group info

The client MUST NOT check the signature and membership tag on the framed content,
but MUST check the sender's proof of membership, the signed group info, and the
confirmation tag.

### Changes for committers

In groups with `light_clients` support, committers MUST send a signed group
info with every commit.

### Server Changes

The server MUST track the public group state together with the signed group info,
and provide endpoints for clients to retrieve light commits and light welcomes.
Further, it SHOULD provide an API to retrieve proof of memberships for arbitrary
leaves, and an API to retrieve the full tree.

# Light MLS

## New MLSMessage Types
This draft defines two new `MLSMessage` types with `wire_format = 0x0006` and
`wire_format = 0x0007`.

Light welcomes, `wire_format = 0x0006`, are defined as follows.
In particular, the `Welcome` message is extended with the `TreeSlice`.

~~~tls
struct {
    ProtocolVersion version = mls10;
    WireFormat wire_format;
    select (MLSMessage.wire_format) {
        ...
        case mls_light_welcome:
            Welcome welcome;
            TreeSlice tree_info;
    };
} MLSMessage;
~~~

Similarly, light commits, `wire_format = 0x0007`, are defined as follow.
The commit message is extended with the `TreeSlice`, a `GroupInfo`, and
the `decryption_node_index` for the decryption key of the path secret.

~~~tls
struct {
    ProtocolVersion version = mls10;
    WireFormat wire_format;
    select (MLSMessage.wire_format) {
        ...
        case mls_light_commit:
            PublicMessage commit;
            TreeSlice tree_info;
            GroupInfo group_info;
            uint32 decryption_node_index;
    };
} MLSMessage;
~~~

## Verifying Tree Validity
A light client can not do all the checks that a client with the full tree can do.
We therefore update the checks performed on tree modifications.
In particular the validation of commits and welcome packages are modified compared
to {{!RFC9420}}.

### Joining a Group via Welcome Message
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

### Commit

To reduce the size of `Commit` messages, especially in large, sparse trees, the
delivery service strips unnecessary parts of member Commits.
See {{deploying-light-mls}} for details on the requirements on the delivery service.

The structure of the message stays the same but the server removes all `HPKECiphertext`
from the `encrypted_path_secret` in the commit's `UpdatePath` that is relevant
for the receiver.

This breaks the signature and membership tag on the `FramedContent` such that
these MUST NOT be checked by the receiver of a Light Commit.

Instead, the proof of membership is verified for the sender and the receiver.
Similar to checking proof of memberships ({{proof-of-membership}}) the receiver
of a Light Commit MUST verify the parent hash of the tree by using
`original_tree_hash` of the co-path nodes, and the tree hash of the new tree.
Note that a light client can not verify all points from {{!RFC9420}}.
In particular, the check that "D is in the resolution of C, and the intersection of P's
`unmerged_leaves`` with the subtree under C is equal to the resolution of C with D removed."
can not be performed because the light client can not compute the resolution.
But this property always holds on correctly generated tree, which the light client
has to trust, not knowing the tree.

Taking the confirmed transcript hash from the GroupInfo, a light client can still
check the confirmation tag.
Otherwise, a Light Commit is applied like a regular commit.

When a member receives a Light Commit message (Section 12.4.2. {{!RFC9420}})
the checks are updated as follows.

1. Verify the sender's membership (see {{proof-of-membership}}).
2. Verify the own path (proof of membership).
3. Verify the GroupInfo signature
4. Check the tree hash in the GroupInfo against our own tree

## Proof of Membership
To verify the group membership of the sender of a commit, the light receiver
checks the sender's leaf (see Section 7.3 {{!RFC9420}}), as well as the
correctness of the tree.

To verify the correctness of the tree on a light client, the client checks its
tree hash and parent hashes.
For each direct path from a leaf to the root that the client has, it checks the
parent hash value on each node by using `original_tree_hash` of the co-path nodes.
The tree hash on the root node is computed similarly, using the `tree_hash` values
for all nodes where the client does not have the full nodes.

Check that the encryption keys of all received nodes are unique.

The `TreeSlice` for proof of memberships is provided by the delivery service to
the light client on request.
Further, a client is sent the `TreeSlice` as part of the `LightWelcome`
and `LightCommit` messages.

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
} ExpandableNode;

struct {
  ExpandableNode nodes<V>;
  uint32 own_node;
  uint32 num_nodes;
} TreeSlice;
~~~

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

The passive clients extension ({{passive-clients-extension}}) defines the possible
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
This will cause the client's performance to regress to the performance of regular
MLS, but allows it to commit again without the necessity to download the full
tree again.

If the client does not expect to commit regularly, only the own path should
be kept after a commit.

## Passive Clients Extension
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

TODO: Add IANA number for the extension.

# Active Members

Full RFC members in groups with light clients don't need significant changes, which
can always be built on top of regular MLS clients.
In particular are active MLS clients required to send a `GroupInfo` alongside
every commit message to the delivery service.
Depending on the deployment, the delivery service might also ask the client to
send a ratchet tree for each commit.
But the delivery service can track the tree based on commit messages such that
sending ratchet trees with commits is not recommended.

# Deploying Light MLS

TODO:
- describe server changes
- deployment considerations

## Commit Processing

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

## Tree slices from the Sender

When the delivery service does not provide the necessary endpoints to query the
expandable paths, the sender can include it into the `GroupInfo` extensions in
the `Welcome` message.

### Maintaining state on Light Clients

Light clients can decide to store the tree slices and build up a tree over time
when other members commit.
But client may decide to delete the sender paths it gets after verifying it's
correctness.

# Passive Clients

# Security Considerations

TODO Security

- public keys only used when committing, at this point we have the full tree
- own path secrets
- proposal validation issues
  - can't check double join
- commits are using only the confirmation tag for the security
  - group context is not signed -> but it was only used to bind the signature to an epoch, which is done by the confirmation tag as well
  - other than that the confirmation tag covers everything relevant (except for `WireFormat` and `ProtocolVersion`)
  - proof of membership ({{proof-of-membership}}) ensures that the sender is in the correct subtree

## Comparison with RFC MLS
The main change compared to the protocol as specified in {{!RFC9420}} is that
the receiver of a `Welcome` or `Commit` message, with an expandable tree, can not
perform all checks as mandated in {{!RFC9420}}.

In particular the following checks are omitted.

* Check for uniqueness of all encryption and signature keys.
Because not all keys are known, the check can only be performed on the known keys.
* Check validity of leaf nodes in the tree when joining a group.

When using receiver specific commits the following checks are omitted in addition.

* Check the signature on the `FramedContent`.

# IANA Considerations

This document has no IANA actions.


--- back

# Acknowledgments
{:numbered="false"}

TODO acknowledge.