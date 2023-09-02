module MLS.TreeSync.MembershipProof

open Comparse
open MLS.Crypto
open MLS.Tree
open MLS.NetworkTypes
open MLS.TreeSync.NetworkTypes
open MLS.TreeSync.Types
open MLS.TreeSync.TreeHash
open MLS.TreeSync.TreeHash.Proofs

#set-options "--fuel 1 --ifuel 1"

type treesync_and_metadata (bytes:Type0) {|bytes_like bytes|} (tkt:treekem_types bytes) =
  l:nat & treesync bytes tkt l 0

type membership_proof (bytes:Type0) {|crypto_bytes bytes|} (tkt:treekem_types bytes) =
  path (leaf_node_nt bytes tkt) (option (parent_node_nt bytes tkt) & lbytes bytes (hash_length #bytes))

val compute_membership_proof_pre:
  #bytes:Type0 -> {|crypto_bytes bytes|} -> #tkt:treekem_types bytes ->
  #l:nat -> #i:tree_index l ->
  t:treesync bytes tkt l i ->
  li:leaf_index l i{Some? (leaf_at t li)} ->
  bool
let rec compute_membership_proof_pre #bytes #cb #tkt #l #i t li =
  match t with
  | TLeaf (Some ln) -> true
  | TNode opn _ _ -> (
    let (child, sibling) = get_child_sibling t li in
    tree_hash_pre sibling &&
    compute_membership_proof_pre child li
  )

val compute_membership_proof:
  #bytes:Type0 -> {|crypto_bytes bytes|} -> #tkt:treekem_types bytes ->
  #l:nat -> #i:tree_index l ->
  t:treesync bytes tkt l i ->
  li:leaf_index l i{Some? (leaf_at t li) /\ compute_membership_proof_pre t li} ->
  membership_proof bytes tkt l i li
let rec compute_membership_proof #bytes #cb #tkt #l #i t li =
  match t with
  | TLeaf (Some ln) -> PLeaf ln
  | TNode opn _ _ -> (
    let (child, sibling) = get_child_sibling t li in
    let res_next = compute_membership_proof child li in
    let sibling_hash = tree_hash sibling in
    PNode (opn, sibling_hash) res_next
  )

val membership_proof_to_tree_hash_pre:
  #bytes:Type0 -> {|crypto_bytes bytes|} -> #tkt:treekem_types bytes ->
  #l:nat -> #i:tree_index l -> #li:leaf_index l i ->
  membership_proof bytes tkt l i li ->
  bool
let rec membership_proof_to_tree_hash_pre #bytes #cb #tkt #l #i #li mp =
  match mp with
  | PLeaf lp -> (
    tree_hash_pre ((TLeaf (Some lp)) <: treesync bytes tkt l i)
  )
  | PNode (opn, sibling_hash) mp_next ->
    membership_proof_to_tree_hash_pre mp_next &&
    (1 + prefixes_length ((ps_option (ps_parent_node_nt tkt)).serialize opn)) + 2 + hash_length #bytes + 2 + hash_length #bytes < hash_max_input_length #bytes

#push-options "--z3rlimit 15"
val membership_proof_to_tree_hash:
  #bytes:Type0 -> {|crypto_bytes bytes|} -> #tkt:treekem_types bytes ->
  #l:nat -> #i:tree_index l -> #li:leaf_index l i ->
  mp:membership_proof bytes tkt l i li{membership_proof_to_tree_hash_pre mp} ->
  lbytes bytes (hash_length #bytes)
let rec membership_proof_to_tree_hash #bytes #cb #tkt #l #i #li mp =
  match mp with
  | PLeaf lp -> (
    tree_hash ((TLeaf (Some lp)) <: treesync bytes tkt l i)
  )
  | PNode (opn, sibling_hash) mp_next ->
    let child_hash = membership_proof_to_tree_hash mp_next in
    let left_hash = if is_left_leaf li then child_hash else sibling_hash in
    let right_hash = if is_left_leaf li then sibling_hash else child_hash in
    let hash_input: bytes = serialize (tree_hash_input_nt bytes tkt) (ParentTreeHashInput ({
      parent_node = opn;
      left_hash = left_hash;
      right_hash = right_hash;
    })) in
    hash_hash hash_input
#pop-options

val check_membership_proof_pre:
  #bytes:Type0 -> {|crypto_bytes bytes|} -> #tkt:treekem_types bytes ->
  #l:nat -> #i:tree_index l -> #li:leaf_index l i ->
  membership_proof bytes tkt l i li ->
  bool
let check_membership_proof_pre #bytes #cb #tkt #l #i #li mp =
  membership_proof_to_tree_hash_pre mp

val check_membership_proof:
  #bytes:Type0 -> {|crypto_bytes bytes|} -> #tkt:treekem_types bytes ->
  #l:nat -> #i:tree_index l -> #li:leaf_index l i ->
  bytes -> mp:membership_proof bytes tkt l i li{check_membership_proof_pre mp} ->
  bool
let check_membership_proof #bytes #cb #tkt #l #i #li root_tree_hash mp =
  root_tree_hash = membership_proof_to_tree_hash mp

val compute_membership_proof_to_tree_hash:
  #bytes:Type0 -> {|crypto_bytes bytes|} -> #tkt:treekem_types bytes ->
  #l:nat -> #i:tree_index l ->
  t:treesync bytes tkt l i ->
  li:leaf_index l i ->
  Lemma
  (requires
    Some? (leaf_at t li) /\
    compute_membership_proof_pre t li /\
    membership_proof_to_tree_hash_pre (compute_membership_proof t li) /\
    tree_hash_pre t
  )
  (ensures membership_proof_to_tree_hash (compute_membership_proof t li) == tree_hash t)
let rec compute_membership_proof_to_tree_hash #bytes #cb #tkt #l #i t li =
  match t with
  | TLeaf (Some ln) -> ()
  | TNode opn _ _ -> (
    let (child, sibling) = get_child_sibling t li in
    compute_membership_proof_to_tree_hash child li
  )

val compute_membership_proof_correct:
  #bytes:Type0 -> {|crypto_bytes bytes|} -> #tkt:treekem_types bytes ->
  #l:nat -> #i:tree_index l ->
  t:treesync bytes tkt l i ->
  li:leaf_index l i ->
  Lemma
  (requires
    Some? (leaf_at t li) /\
    compute_membership_proof_pre t li /\
    check_membership_proof_pre (compute_membership_proof t li) /\
    tree_hash_pre t
  )
  (ensures check_membership_proof (tree_hash t) (compute_membership_proof t li))
let compute_membership_proof_correct #bytes #cb #tkt #l #i t li =
  compute_membership_proof_to_tree_hash t li

val membership_proof_is_in_the_tree:
  #bytes:Type0 -> {|crypto_bytes bytes|} -> #tkt:treekem_types bytes ->
  #l:nat -> #i:tree_index l -> #li:leaf_index l i ->
  treesync bytes tkt l i -> membership_proof bytes tkt l i li ->
  bool
let rec membership_proof_is_in_the_tree #bytes #cb #tkt #l #i #li t mp =
  match t, mp with
  | TLeaf oln, PLeaf ln ->
    oln = Some ln
  | TNode t_opn _ _, PNode (mp_opn, _) mp_next -> (
    let (child, _) = get_child_sibling t li in
    t_opn = mp_opn &&
    membership_proof_is_in_the_tree child mp_next
  )

val membership_proof_to_hash_input:
  #bytes:Type0 -> {|crypto_bytes bytes|} -> #tkt:treekem_types bytes ->
  #l:nat -> #i:tree_index l -> #li:leaf_index l i ->
  mp:membership_proof bytes tkt l i li{membership_proof_to_tree_hash_pre mp} ->
  tree_hash_input_nt bytes tkt
let membership_proof_to_hash_input #bytes #cb #tkt #l #i #li mp =
  match mp with
  | PLeaf lp -> (
    get_tree_hash_input ((TLeaf (Some lp)) <: treesync bytes tkt l i)
  )
  | PNode (opn, sibling_hash) mp_next ->
    let child_hash = membership_proof_to_tree_hash mp_next in
    let left_hash = if is_left_leaf li then child_hash else sibling_hash in
    let right_hash = if is_left_leaf li then sibling_hash else child_hash in
    ParentTreeHashInput ({
      parent_node = opn;
      left_hash = left_hash;
      right_hash = right_hash;
    })

#push-options "--z3rlimit 50"
val membership_proof_to_tree_hash_security:
  #bytes:Type0 -> {|crypto_bytes bytes|} -> #tkt:treekem_types bytes ->
  #l:nat -> #i:tree_index l -> #li:leaf_index l i ->
  #l':nat -> #i':tree_index l' ->
  t:treesync bytes tkt l' i' ->
  mp:membership_proof bytes tkt l i li ->
  Pure (bytes & bytes)
  (requires
    tree_hash_pre t /\
    membership_proof_to_tree_hash_pre mp /\
    membership_proof_to_tree_hash mp == tree_hash t
  )
  (ensures (fun (b1, b2) ->
    (
      l == l' /\ i == i' /\
      membership_proof_is_in_the_tree t mp
    ) \/ (
      length b1 < hash_max_input_length #bytes /\
      length b2 < hash_max_input_length #bytes /\
      hash_hash b1 == hash_hash b2 /\ ~(b1 == b2)
    )
  ))
let rec membership_proof_to_tree_hash_security #bytes #cb #tkt #l #i #li #l' #i' t mp =
  ( // Don't know why this is useful, bad SMT encoding somewhere?
    match mp with
    | PLeaf lp -> ()
    | PNode (opn, sibling_hash) mp_next -> ()
  );
  let t_hash_input = get_tree_hash_input t in
  let mp_hash_input = membership_proof_to_hash_input mp in
  let serialized_t_hash_input: bytes = serialize _ t_hash_input in
  let serialized_mp_hash_input: bytes = serialize _ mp_hash_input in
  parse_serialize_inv_lemma #bytes _ t_hash_input;
  parse_serialize_inv_lemma #bytes _ mp_hash_input;
  assert(length serialized_t_hash_input < hash_max_input_length #bytes);
  assert(length serialized_mp_hash_input < hash_max_input_length #bytes);
  if l = l' && i = i' && membership_proof_is_in_the_tree t mp then
    (empty, empty)
  else if not (t_hash_input = mp_hash_input) then (
    (serialized_t_hash_input, serialized_mp_hash_input)
  ) else (
    match t, mp with
    | TNode _ left right, PNode _ mp_next -> (
      if is_left_leaf li then (
        membership_proof_to_tree_hash_security left mp_next
      ) else (
        membership_proof_to_tree_hash_security right mp_next
      )
    )
  )
#pop-options

val membership_proof_to_tree_hash_security_aux:
  #bytes:Type0 -> {|crypto_bytes bytes|} -> #tkt:treekem_types bytes ->
  #l:nat -> #i:tree_index l -> #li:leaf_index l i ->
  #l':nat -> #i':tree_index l' ->
  root_tree_hash:bytes ->
  t:treesync bytes tkt l' i' ->
  mp:membership_proof bytes tkt l i li ->
  Pure (bytes & bytes)
  (requires
    tree_hash_pre t /\
    check_membership_proof_pre mp /\
    check_membership_proof root_tree_hash mp /\
    root_tree_hash == tree_hash t
  )
  (ensures (fun (b1, b2) ->
    (
      l == l' /\ i == i' /\
      membership_proof_is_in_the_tree t mp
    ) \/ (
      length b1 < hash_max_input_length #bytes /\
      length b2 < hash_max_input_length #bytes /\
      hash_hash b1 == hash_hash b2 /\ ~(b1 == b2)
    )
  ))
let membership_proof_to_tree_hash_security_aux #bytes #cb #tkt #l #i #li #l' #i' root_tree_hash t mp =
  membership_proof_to_tree_hash_security t mp
