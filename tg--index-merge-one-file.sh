#!/bin/sh

# tg--index-merge-one-file -- auto merge a file without touching working tree
# Copyright (C) 2017 Kyle J. McKay
# All rights reserved.
# License GPLv2+

# $TG_TMP_DIR => location to store temporary files
# $1          => stage 1 hash or empty
# $2          => stage 2 hash or empty
# $3          => stage 3 hash or empty
# $4          => full pathname in index
# $5          => stage 1 mode (6 octal digits) or empty
# $6          => stage 2 mode
# $7          => stage 3 mode

if [ "$1" = "-h" ] && [ $# -eq 1 ]; then
	echo "\
usage: ${tgname:-tg} index-merge-one-file <s1_hash> <s2_hash> <s3_hash> <path> <s1_mode> <s2_mode> <s3_mode>"
	exit 0
fi

[ $# -eq 7 ] || exit 1

# We only handle auto merging existing files with the same mode

case "${1:-:}${2:-:}${3:-:}${4:-:}${5:-:}${6:-:}${7:-:}" in *":"*) exit 1; esac
[ "$5" = "$6" ] && [ "$6" = "$7" ] || exit 1

# Check for "just-in-case" things that shouldn't get in here:
#
# a) all three hashes are the same (handled same as next case)
# b) $2 and $3 are the same
# c) $1 and $2 are the same
# d) $1 and $3 are the same

# For the "just-in-case"s it doesn't actually matter what the mode is
newhash=
if [ "$2" = "$3" ]; then
	newhash="$2"
elif [ "$1" = "$2" ]; then
	newhash="$3"
elif [ "$1" = "$3" ]; then
	newhash="$2"
fi

if [ -z "$newhash" ]; then
	# mode must match 100\o\o\o
	case "$6" in 100[0-7][0-7][0-7]);;*) exit 1; esac
	if [ "$4" = ".topdeps" ] || [ "$4" = ".topmsg" ]; then
		# resolution for these two is always silently "ours" never a merge
		newhash="$2"
	else
		tg_tmp_dir="${TG_TMP_DIR:-/tmp}"
		basef="$tg_tmp_dir/tgmerge_$$_base"
		oursf="$tg_tmp_dir/tgmerge_$$_ours"
		thrsf="$tg_tmp_dir/tgmerge_$$_thrs"
		trap 'rm -f "$basef" "$oursf" "$thrsf"' EXIT
		trap 'exit 129' HUP
		trap 'exit 130' INT
		trap 'exit 131' QUIT
		trap 'exit 134' ABRT
		trap 'exit 141' PIPE
		trap 'exit 143' TERM
		git cat-file blob "$1" >"$basef" || exit 1
		git cat-file blob "$2" >"$oursf" || exit 1
		git cat-file blob "$3" >"$thrsf" || exit 1
		git merge-file --quiet "$oursf" "$basef" "$thrsf" >/dev/null 2>&1 || exit 1
		printf '%s\n' "Auto-merging $4"
		newhash="$(git hash-object -w --stdin <"$oursf" 2>/dev/null)"
	fi
fi

[ -n "$newhash" ] || exit 1
git update-index --cacheinfo "$6" "$newhash" "$4"
