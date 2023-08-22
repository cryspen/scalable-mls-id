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
title: "Scalable MLS"
abbrev: "smls"
category: info

docname: draft-kiefer-scalable-mls-latest
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

This document describes a scalable variant of the MLS protocol.


--- middle

# Introduction

This draft defines two modifications to the main MLS protocol in {{!RFC9420}}.

First, it defines expandable trees in Section {{expandable-tree}} that allow
retrieving and storing only the minimally required tree information to participate
in an MLS group.
An expandable tree can always be completed to a full MLS tree as described in
Section {{committing-with-an-expandable-tree}}.

Secondly, it defines receiver specific commits in Section {{receiver-specific-commits}}
that reduce the data downloaded by clients for processing commits.


# Conventions and Definitions

{::boilerplate bcp14-tagged}


# MLS Groups with Expandable Trees

MLS groups that support expandable trees must use the `expandable_trees` extension
in the required capabilities.
When this extension is present in the group context all messages, except for
application messages, MUST use public messages.

## Expandable Trees Extension
The `expandable_trees` group context extension is used to signal that the group
supports clients with expandable trees.

~~~tls
enum ExpandableClientType {
  reserved(0),
  no_upgrade(1),
  resync_upgrade(2),
  self_upgrade(3),
  any_upgrade(4),
}

struct {
  ExpandableClientType expandable;
} ExpandableTreesExtension;
~~~

The extension must be present and set in the required capabiblities of a group
when supporting clients with expandable trees.
It defines ways such a client may upgrade to a full client.

- `no_upgrade` does not allow expandable clients to update to full MLS.
- `resync_upgrade` allows clients to upgrade to full MLS by using an external commit.
  The resync removes the old client from the group and adds a new client with full MLS.
- `self_upgrade` allows clients to upgrade to full MLS by retrieving the full tree
  from the server. Together with the signed group info of the current epoch the
  client "silently" upgrades to full MLS with security equivalent to joining a new
  group. The client MUST perform all checks from Section 12.4.3.1 {{!RFC9420}}.
- `any_upgrade` allows clients to use either of the two upgrade mechanisms.

TODO: Add IANA number for the extension.

## Protocol Changes Overview

The changes are primarily for clients that want to use expandable trees.

### Joining a Group with expandable trees
When joining a group as a client with expandable trees, the client downloads
only it's own expandable path and the committer's proof of membership.
The sender's proof of membership is discarded after being checked such that only
the client's direct, expandable path is stored.

### Processing Proposals
Proposals are ignored and not processed at all.

### Processing Commits
When processing a commit, the client retrieves

- the partial commit that contains only the path secret encrypted for the client
- the sender's proof of membership
- the signed group info

The client MUST NOT check the signature on the framed content, but MUST check
the sender's proof of membership, the signed group info, and the confirmation tag.

### Changes for committers

In groups with `expandable_trees` support, committer must send a signed group
info with every commit.

### Server Changes

The server must track the public group state together with the signed group info,
and provide endpoints for clients to retrieve expandable direct paths, the signed
group info, and partial commits.

# Expandable Tree
An expandable tree is a modified ratchet tree as described in {{!RFC9420}}.
An expandable tree stores only the direct path from the member to the root plus
additional information about the co-path.

In particular, a list of `Hashes` are stored for the member's co-path, containing
the node's index, it's tree hash as computed on the full tree, and the original
tree hash as computed on the full tree (recall that the original tree hash is the
node's tree hash excluding any unmerged leaves).

~~~tls
struct {
  uint32 index;
  opaque tree_hash<V>;
  opaque original_tree_hash<V>;
} Hashes;
~~~

TODO: Add tree pictures examples for explanation

~~~ ascii-art
          R
         /
        P
      __|__
     /     \
    D       S
   / \     / \
 ... ... ... ...
 /
L
~~~
{: #expandable-tree-figure title="Expandable tree" }

## Verifying Tree Validity
A client that has an expandable tree can not do all the checks that a client with
the full tree can do.
We therefore update the checks performed on tree modifications.
In particular the validation of commits and welcome packages are modified compared
to {{!RFC9420}}.

### Joining a Group via Welcome Message
When a new member joins the group with a `Welcome` message
(Section 12.4.3.1. {{!RFC9420}}) without the ratchet tree extension the checks
are updated as follows.

1. Verify the `GroupInfo`
    1. signature
    2. confirmation tag
    3. tree hash
2. Verify the sender's membership (see {{proof-of-membership}}).
3. Check the own direct path to the root (see {{verifying-expandable-trees}}).
4. Do *not* verify leaves in the tree.

### Commit
When a member receives a `Commit` message (Section 12.4.2. {{!RFC9420}})
the checks are updated as follows.

1. Verify the sender's membership (see {{proof-of-membership}}).
2. If the own path changed, check it.

## Proof of Membership
To verify the group membership of the sender of a commit, the receiver with an
expandable tree checks the sender's leaf (see Section 7.3 {{!RFC9420}}), as
well as the correctness of the tree as described in {{verifying-expandable-trees}}.

## Verifying Expandable Trees
To verify the correctness of an expandable tree the client checks its tree hash
and parent hashes.
For each direct path from a leaf to the root that the client has, it checks the
parent hash value on each node by using `original_tree_hash` of the co-path nodes.
The tree hash on the root node is computed similarly, using the `tree_hash` values
for all nodes where the client does not have the full nodes.

Check that the encryption keys of all received nodes are unique.

## Retrieving Expandable Tree Information
The `ExpandableTree` is provided by the delivery service to the client on request.
Alternatively, a client can send the `ExpandableTree` as extension in `Welcome`
messages.
See {{expandable-tree}} for details on the expandable tree extension.

### Expandable Tree from the Deliver Service

In particular, when joining a group, after receiving a `Welcome` message, the
client queries the delivery service for the expandable tree.
The delivery service must keep track of the group's state (tree) and assemble the
`ExpandableTree` when requested for a given sender and receiver.

When receiving a `Commit` message, the client queries the delivery service for
the sender's direct path to check its membership.

### Expandable Tree from the Sender

When the delivery service does not provide the necessary endpoints to query the
expandable trees, the sender can include it into the `GroupInfo` extensions in
the `Welcome` message.

## Expandable Tree

~~~tls
enum {
  reserved(0),
  xnode(1),
  hashes(2),
  (255)
} XNodeType;

struct {
  uint32: index;
  optional<Node> node;
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
  uint32 num_nodes;
} ExpandableTree;
~~~

## Committing with an expandable Tree

A client with an expandable *can not commit* because it doesn't know the necessary
public keys in the tree to encrypt to.
Therefore, if a client with an expandable tree wants to commit, it first has to
retrieve the full tree from the server.
Because a client with an expandable tree is not able to fully verify incoming
proposals, it MUST NOT commit to proposals it received while not holding a full tree.
A client that is upgrading from expandable trees to a full MLS tree is therefore
considered to be a new client that has no knowledge of proposals before it joined.
Note that this restriction can not be enforced.
However, since each client in {{!RFC9420}} must check the proposals, a misbehaving
client that upgraded from an expandable tree can only successfully commit bogus
proposals when all other clients and the delivery service agree.

A client that is upgrading to the full tree by requesting the full tree of the
current epoch from the server.
In order ensure that the tree is the expanded version of the expandable tree known
to the client, the client MUST perform the following checks:

* Verify that the tree hash of the expandable tree and the full tree are equivalent.
* Verify that all full nodes (`XNode`) in the expandable tree are equivalent to
  the corresponding node in the full tree.
* Perform all checks on the tree as if joining the group with a `Welcome` message
(see Section 12.4.3.1. in {{!RFC9420}}).

To retrieve the full tree, the delivery service must provide an end point,
equivalent to the one used to retrieve the full tree for a new member that wants
to join with a commit.

### Maintaining state

After committing, the client can decide to switch to regular MLS and process the
full tree as described in {{!RFC9420}}.
This will cause the client's performance to regress to the performance of regular
MLS, but allows it to commit again without the necessity to download the full
tree again.

If the client does not expect to commit regularly, only the expandable tree should
be kept after a commit.

# Receiver specific Commits

To reduce the size of `Commit` messages, especially in large, sparse trees, the
delivery service can strip unnecessary parts of the `Commit` when using the public
message type for `MLSMessage` and the sender type is `member`.

The structure of the message stays the same but the server removes all `HPKECiphertext`
from the `encrypted_path_secret` in the commit's `UpdatePath`, if present, where
the `encryption_key` does not match the receiver's encryption key.

This breaks the signature on the `FramedContent` such that this MUST NOT be checked
by the receiver of such a commit.

The delivery service sends an expandable commit `XCommit` message that is defined
as follows.

A new content type `xcommit(4)` is defined for `FramedContent`.

~~~tls
struct {
  ExpandableNode nodes<V>;
} XPath;

struct {
  ProposalOrRef proposal<V>;
  optional<UpdatePath> path;
  optional<XPath> sender_path;
} XCommit;
~~~

Similar to checking expandable trees ({{verifying-expandable-trees}}) the receiver
of an `XCommit` MUST verify the parent hash value on each node by using
`original_tree_hash` of the co-path nodes, and the tree hash of the new tree.

## Applying receiver specific commits

When receiving an `XCommit`, the client applies it like a regular commit.

Additionally, the client checks the membership of the committer as described in
{{proof-of-membership}} using the `sender_path`.

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
