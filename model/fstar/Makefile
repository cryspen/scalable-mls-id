.PHONY: all membership_proof copy_files

TREESYNC_PATH ?= ./treesync

all: membership_proof

treesync:
	git clone --depth 1 https://github.com/Inria-Prosecco/treesync.git

copy_files:
	cp MLS.TreeSync.MembershipProof.fst $(TREESYNC_PATH)/mls-star/fstar/treesync/code/

membership_proof: copy_files
	make -C treesync/mls-star cache/MLS.TreeSync.MembershipProof.fst.checked
