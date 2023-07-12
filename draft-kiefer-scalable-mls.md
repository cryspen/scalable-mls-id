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
workgroup: MLSWG
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
  mls-protocol:
    target: https://datatracker.ietf.org/doc/draft-ietf-mls-protocol/
    title: The Messaging Layer Security (MLS) Protocol


--- abstract

This document describes a scalable variant of the MLS protocol.


--- middle

# Introduction

TODO Introduction


# Conventions and Definitions

{::boilerplate bcp14-tagged}

# Expandable Tree
An expandable tree is a modified ratchet tree as described in {{mls-protocol}}.
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

## Verifying Tree Validity
A client that has an expandable tree can not do all the checks that a client with
the full tree can do.
We therefore update the checks performed on tree modifications.
In particular the validation of commits and welcome packages are modified compared
to {{mls-protocol}}.

### Commit
When a new member joins the group with a `Welcome` message
(Section 12.4.3.1. {{mls-protocol}}) without the ratchet tree extension the checks
are updated as follows.

1. Verify the sender's membership (see {{proof-of-membership}}).
2. Check the own direct path to the root.
3. Do *not* verify leaves in the tree.

## Proof of Membership
To verify the group membership of the sender of a commit, the receiver with an
expandable tree checks the sender's leaf signature as well as the correctness of
the tree as described in {{verify-expandable-tree}}.

## Verify Expandable Tree
To verify the correctness of an expandable tree the client checks its tree hash
and parent hashes.
For each direct path from a leaf to the root that the client has, it checks the
parent hash value on each node by using `original_tree_hash` of the co-path nodes.
The tree hash on the root node is computed similarly, using the `tree_hash` values
for all nodes where the client does not have the full nodes.

# Expandable Tree Extension
The `ExpandableTree` is provided by the delivery service to the client on request.
Alternatively, a client can send the `ExpandableTree` as extension in `Commit`
and `Welcome` messages.

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

# Security Considerations

TODO Security


# IANA Considerations

This document has no IANA actions.


--- back

# Acknowledgments
{:numbered="false"}

TODO acknowledge.