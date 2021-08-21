#!/bin/sh

# tg--index-merge-one-file -- auto merge a file without touching working tree
# Copyright (C) 2017,2021 Kyle J. McKay
# All rights reserved
# License GPLv2+

# $TG_TMP_DIR => location to store temporary files
# $tg_index_mergetop_behavior => "" (ours), "theirs", "merge", "remove"
# $1          => stage 1 hash or empty
# $2          => stage 2 hash or empty
# $3          => stage 3 hash or empty
# $4          => full pathname in index
# $5          => stage 1 mode (6 octal digits) or empty
# $6          => stage 2 mode
# $7          => stage 3 mode

tab='	'

if [ "$1" = "-h" ] && [ $# -eq 1 ]; then
	echo "\
usage: ${tgname:-tg} index-merge-one-file [--<mergetop>] <s1_hash> <s2_hash> <s3_hash> <path> <s1_mode> <s2_mode> <s3_mode>"
	exit 0
fi
if [ -z "$tg_index_mergetop_behavior" ]; then case "$1" in
	--merge|--theirs|--remove|--ours)
		tg_index_mergetop_behavior="${1#--}"
		shift
esac; fi

[ $# -eq 7 ] || exit 1

mtblob="$(git hash-object -t blob --stdin </dev/null 2>/dev/null)" || :
nullsha="0000000000000000000000000000000000000000"
test "${#mtblob}" != "64" ||
nullsha="0000000000000000000000000000000000000000000000000000000000000000"

# The read-tree --aggressive option handles three cases that may end up in
# here:
#
#  1. One side removes a file but the other leaves it unchanged (remove)
#  2. Both sides remove a file (remove)
#  3. Both sides add a path identically (use it)
#
# The problem is (1).  When resolving .topdeps and .topmsg files using either
# --ours or --theirs the normal resolution of (1) to remove may be incorrect.
#
# But that means in order to get that case to come to us all three cases must
# be handled properly for non-topfile files since they will therefore end up
# in here as well.

newhash=
newmode="${6:-0}"

if [ "$tg_index_mergetop_behavior" != "merge" ] &&
   { [ "$4" = ".topdeps" ] || [ "$4" = ".topmsg" ]; }
then
	# Handle --ours, --theirs and --remove for .topdeps and .topmsg

	if [ "$tg_index_mergetop_behavior" = "remove" ]; then
		newhash="$nullsha"
	elif [ "$tg_index_mergetop_behavior" = "theirs" ]; then
		newhash="${3:-$nullsha}"
		newmode="${7:-0}"
	else
		# --ours is the default mode
		newhash="${2:-$nullsha}"
	fi

	# .topmsg and .topdeps are never executable
	[ "$newmode" != "100755" ] || newmode="100644"

	if [ "$newmode" != "100644" ] && [ "$newhash" != "$nullsha" ]; then
		# .topmsg and .topdeps are only allowed to be blobs
		newhash="$nullsha"
		newmode="0"
	fi
fi

if [ -z "$newhash" ]; then
	# Check for the "--aggressive" and "--trivial" things:
	#
	# a) all three hashes are the same (handled same as next case)
	# b) $2 and $3 are the same (and their modes)
	# c) $1 and $2 are the same (and their modes)
	# d) $1 and $3 are the same (and their modes)

	if [ "$2" = "$3" ] && [ "$6" = "$7" ] ; then
		newhash="${2:-$nullsha}"
	elif [ "$1" = "$2" ] && [ "$5" = "$6" ]; then
		newhash="${3:-$nullsha}" newmode="${7:-0}"
	elif [ "$1" = "$3" ] && [ "$5" = "$7" ]; then
		newhash="${2:-$nullsha}"
	fi
fi

if [ -z "$newhash" ]; then
	# We only handle auto merging existing files with the same mode
	case "${1:-:}${2:-:}${3:-:}${4:-:}${5:-:}${6:-:}${7:-:}" in *":"*) exit 1; esac
	[ "$5" = "$6" ] && [ "$6" = "$7" ] || exit 1

	# mode must match 100\o\o\o
	case "$6" in 100[0-7][0-7][0-7]);;*) exit 1; esac

	# perform a "simple" 3-way merge
	tg_tmp_dir="${TG_TMP_DIR:-/tmp}"
	basef="$tg_tmp_dir/tgmerge_$$_base"
	oursf="$tg_tmp_dir/tgmerge_$$_ours"
	thrsf="$tg_tmp_dir/tgmerge_$$_thrs"
	trap 'rm -f "$basef" "$oursf" "$thrsf"' EXIT
	trap 'exit' HUP INT QUIT ABRT PIPE TERM
	git cat-file blob "$1" >"$basef" 2>/dev/null || exit 1
	git cat-file blob "$2" >"$oursf" 2>/dev/null || exit 1
	git cat-file blob "$3" >"$thrsf" 2>/dev/null || exit 1
	git merge-file --quiet "$oursf" "$basef" "$thrsf" >/dev/null 2>&1 || exit 1
	printf '%s\n' "Auto-merging $4"
	newhash="$(git hash-object -w --stdin <"$oursf" 2>/dev/null)" || exit 1
fi

[ -n "$newhash" ] && [ -n "$newmode" ] || exit 1
[ "$newhash" != "$nullsha" ] || newmode="0"
git update-index --index-info >/dev/null 2>&1 <<EOT
0 $nullsha$tab$4
$newmode $newhash$tab$4
EOT
