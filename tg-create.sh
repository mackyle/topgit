#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) Petr Baudis <pasky@suse.cz>  2008
# Copyright (C) Kyle J. McKay <mackyle@gmail.com>  2015
# All rights reserved.
# GPLv2

deps= # List of dependent branches
restarted= # Set to 1 if we are picking up in the middle of base setup
merge= # List of branches to be merged; subset of $deps
name=
rname= # Remote branch to base this one on
remote=
msg=
msgfile=
noedit=
nocommit=
nodeps=
continue=
topmsg=

USAGE="Usage: ${tgname:-tg} [... -r remote] create [-m <msg> | -F <file>] [-n] [--no-commit] [--no-deps] [<name> [<dep>...|-r [<rname>]] ]"

usage()
{
	if [ "${1:-0}" != 0 ]; then
		printf '%s\n' "$USAGE" >&2
	else
		printf '%s\n' "$USAGE"
	fi
	exit ${1:-0}
}

is_active()
{
	[ -d "$git_dir/tg-create" ] || return 1
	[ -s "$git_dir/tg-create/name" ] || return 1
	[ -s "$git_dir/tg-create/deps" ] || return 1
	[ -s "$git_dir/tg-create/merge" ] || return 1
	[ -s "$git_dir/tg-create/msg" ] || return 1
	[ -s "$git_dir/tg-create/topmsg" ] || return 1
	[ -f "$git_dir/tg-create/nocommit" ] || return 1
	[ -f "$git_dir/tg-create/noedit" ] || return 1
	return 0
}

## Parse options

while [ $# -gt 0 ]; do case "$1" in
	-h|--help)
		usage
		;;
	--no-commit)
		nocommit=1
		;;
	-n|--no-edit)
		noedit=1
		nocommit=1
		;;
	--no-deps)
		nodeps=1
		;;
	--continue)
		continue=1
		;;
	-m|--message|--message=*)
		case "$1" in --message=*)
			x="$1"
			shift
			set -- --message "${x#--message=}" "$@"
		esac
		if [ $# -lt 2 ]; then
			echo "The $1 option requires an argument" >&2
			usage 1
		fi
		shift
		msg="$1"
		;;
	-F|--file|--file=*)
		case "$1" in --file=*)
			x="$1"
			shift
			set -- --file "${x#--file=}" "$@"
		esac
		if [ $# -lt 2 ]; then
			echo "The $1 option requires an argument" >&2
			usage 1
		fi
		shift
		msgfile="$1"
		;;
	-r)
		remote=1
		rname="$1"; [ $# -eq 0 ] || shift
		;;
	--)
		shift
		break
		;;
	-?*)
		echo "Unknown option: $1" >&2
		usage 1
		;;
	*)
		break
		;;
esac; shift; done
[ $# -gt 0 -o -z "$rname" ] || set -- "$rname"
[ $# -gt 0 -o -n "$remote$msgfile$msg$nocommit$nodeps" ] || continue=1
[ -z "$continue" -o "$#$remote$msgfile$msg$nocommit$nodeps" = "0" ] || usage 1
[ -n "$continue" -o $# -eq 0 ] || { name="$1"; shift; }
[ -n "$continue" -o -n "$name" ] || { warn "no branch name given"; usage 1; }
[ -z "$remote" -o -n "$rname" ] || rname="$name"
[ -z "$remote" -o -z "$msg$msgfile$nocommit$nodeps" ] || { warn "-r may not be combined with other options"; usage 1; }
[ $# -eq 0 -o -z "$remote" ] || { warn "deps not allowed with -r"; usage 1; }
[ $# -le 1 -o -z "$nodeps" ] || { warn "--no-deps requires at most one <dep>"; usage 1; }
[ -z "$msg" -o -z "$msgfile" ] || die "only one -F or -m option is allowed"
[ -z "$continue" ] || is_active || die "no tg create is currently active"

## Fast-track creating branches based on remote ones

if [ -n "$rname" ]; then
	[ -n "$name" ] || die "no branch name given"
	! ref_exists "refs/heads/$name" || die "branch '$name' already exists"
	! ref_exists "refs/top-bases/$name" || die "'top-bases/$name' already exists"
	if [ -z "$base_remote" ]; then
		die "no remote location given. Either use -r remote argument or set topgit.remote"
	fi
	has_remote "$rname" || die "no branch $rname in remote $base_remote"

	if [ -n "$logrefupdates" ]; then
		mkdir -p "$git_dir/logs/refs/top-bases/$(dirname "$name")" 2>/dev/null || :
		{ >>"$git_dir/logs/refs/top-bases/$name" || :; } 2>/dev/null
	fi
	msg="tgcreate: $name -r $rname"
	git update-ref -m "$msg" "refs/top-bases/$name" "refs/remotes/$base_remote/top-bases/$rname" ""
	git update-ref -m "$msg" "refs/heads/$name" "refs/remotes/$base_remote/$rname" ""
	info "Topic branch $name based on $base_remote : $rname set up."
	exit 0
fi

## Auto-guess dependencies

deps="$*"
if [ -z "$deps" ]; then
	if [ -z "$name" ] && is_active; then
		# We are setting up the base branch now; resume merge!
		name="$(cat "$git_dir/tg-create/name")"
		deps="$(cat "$git_dir/tg-create/deps")"
		merge="$(cat "$git_dir/tg-create/merge")"
		msg="$(cat "$git_dir/tg-create/msg")"
		topmsg="$(cat "$git_dir/tg-create/topmsg")"
		nocommit="$(cat "$git_dir/tg-create/nocommit")"
		noedit="$(cat "$git_dir/tg-create/noedit")"
		restarted=1
		info "Resuming $name setup..."
	else
		# The common case
		[ -z "$name" ] && die "no branch name given"
		head="$(git symbolic-ref --quiet HEAD || :)"
		deps="${head#refs/heads/}"
		[ "$deps" != "$head" ] || die "refusing to auto-depend on non-branch ref (${head:-detached HEAD})"
		info "Automatically marking dependency on $deps"
	fi
fi

[ -n "$merge" -o -n "$restarted" ] || merge="$deps "

for d in $deps; do
	ref_exists "refs/heads/$d"  ||
		die "unknown branch dependency '$d'"
done
! ref_exists "refs/heads/$name"  ||
	die "branch '$name' already exists"
! ref_exists "refs/top-bases/$name" ||
	die "'top-bases/$name' already exists"

# Clean up any stale stuff
rm -rf "$git_dir/tg-create"


# Get messages
if [ -z "$restarted" ]; then
	>"$git_dir/TG_EDITMSG"
	if [ -n "$msgfile" ]; then
		if [ "$msgfile" = "-" ]; then
			git stripspace >"$git_dir/TG_EDITMSG"
		else
			git stripspace <"$msgfile" >"$git_dir/TG_EDITMSG"
		fi
	elif [ -n "$msg" ]; then
		printf '%s\n' "$msg" | git stripspace >"$git_dir/TG_EDITMSG"
	fi
	if [ ! -s "$git_dir/TG_EDITMSG" ]; then
		printf '%s\n' "tg create $name" | git stripspace >"$git_dir/TG_EDITMSG"
	fi
	msg="$(cat "$git_dir/TG_EDITMSG")"
	rm -f "$git_dir/TG_EDITMSG"

	author="$(git var GIT_AUTHOR_IDENT)"
	author_addr="${author%> *}>"
	{
		echo "From: $author_addr"
		! header="$(git config topgit.to)" || echo "To: $header"
		! header="$(git config topgit.cc)" || echo "Cc: $header"
		! header="$(git config topgit.bcc)" || echo "Bcc: $header"
		! subject_prefix="$(git config topgit.subjectprefix)" || subject_prefix="$subject_prefix "
		echo "Subject: [${subject_prefix}PATCH] $name"
		echo
		echo '<patch description>'
		echo
		echo "Signed-off-by: $author_addr"
		[ "$(git config --bool format.signoff)" = true ] && echo "Signed-off-by: $author_addr"
	} | git stripspace >"$git_dir/TG_EDITMSG"
	if [ -z "$noedit" ]; then
		cat <<EOT >>"$git_dir/TG_EDITMSG"

# Please enter the patch message for the new TopGit branch $name.
# It will be stored in the .topmsg file and used to create the
# patch header when \`tg patch\` is run on branch $name.
# The "Subject:" line will appear in \`tg summary\` and \`tg info\` output.
#
# Lines starting with '#' will be ignored, and an empty patch
# message aborts the \`tg create\` operation entirely.
#
# tg create $name $deps
EOT
		run_editor "$git_dir/TG_EDITMSG" || \
		die "there was a problem with the editor '$tg_editor'"
		git stripspace -s <"$git_dir/TG_EDITMSG" >"$git_dir/TG_EDITMSG"+
		mv -f "$git_dir/TG_EDITMSG"+ "$git_dir/TG_EDITMSG"
		[ -s "$git_dir/TG_EDITMSG" ] || die "nothing to do"
	fi
	topmsg="$(cat "$git_dir/TG_EDITMSG")"
	rm -f "$git_dir/TG_EDITMSG"
fi


## Find starting commit to create the base

if [ -n "$merge" -a -z "$restarted" ]; then
	# Unshift the first item from the to-merge list
	branch="${merge%% *}"
	merge="${merge#* }"
	info "Creating $name base from $branch..."
	# We create a detached head so that we can abort this operation
	git checkout -q "$(git rev-parse --verify "$branch" --)"
fi


## Merge other dependencies into the base

while [ -n "$merge" ]; do
	# Unshift the first item from the to-merge list
	branch="${merge%% *}"
	merge="${merge#* }"
	info "Merging $name base with $branch..."

	if ! git merge "$branch^0"; then
		info "Please commit merge resolution and call: $tgdisplay create"
		info "It is also safe to abort this operation using:"
		info "git$gitcdopt reset --hard some_branch"
		info "(You are on a detached HEAD now.)"
		mkdir -p "$git_dir/tg-create"
		printf '%s\n' "$name" >"$git_dir/tg-create/name"
		printf '%s\n' "$deps" >"$git_dir/tg-create/deps"
		printf '%s\n' "$merge" >"$git_dir/tg-create/merge"
		printf '%s\n' "$msg" >"$git_dir/tg-create/msg"
		printf '%s\n' "$topmsg" >"$git_dir/tg-create/topmsg"
		printf '%s\n' "$nocommit" >"$git_dir/tg-create/nocommit"
		printf '%s\n' "$noedit" >"$git_dir/tg-create/noedit"
		exit 2
	fi
done


## Set up the topic branch

if [ -n "$logrefupdates" ]; then
	mkdir -p "$git_dir/logs/refs/top-bases/$(dirname "$name")" 2>/dev/null || :
	{ >>"$git_dir/logs/refs/top-bases/$name" || :; } 2>/dev/null
fi
git update-ref "refs/top-bases/$name" "HEAD" ""
git checkout -b "$name"

if [ -n "$nodeps" ]; then
	>"$root_dir/.topdeps"
else
	printf '%s\n' $deps >"$root_dir/.topdeps"
fi
git add -f "$root_dir/.topdeps"
printf '%s\n' "$topmsg" >"$root_dir/.topmsg"
git add -f "$root_dir/.topmsg"
printf '%s\n' "$msg" >"$git_dir/MERGE_MSG"

if [ -n "$nocommit" ]; then
	info "Topic branch $name set up."
	if [ -n "$noedit" ]; then
		info "Please fill in .topmsg now and make the initial commit."
	else
		info "Please make the initial commit."
	fi
	info "To abort:"
	info "  git$gitcdopt rm -f .top* && git$gitcdopt checkout ${deps%% *} && $tgdisplay delete $name"
	exit 0
fi

git commit -m "$msg"
subj="$(grep -i '^Subject:' <"$root_dir/.topmsg" | sed -n 1p || :)"
subj="${subj#????????}"
subj="${subj#*]}"
subj="$(printf '%s\n' "$subj" | sed -e 's/^  *//; s/  *$//')"
if [ -n "$subj" ]; then
	printf '%s\n' "$subj" ""
	sed -e '1,/^$/d' <"$root_dir/.topmsg"
else
	cat "$root_dir/.topmsg"
fi >"$git_dir/MERGE_MSG"
info "Topic branch $name created."
exit 0

# vim:noet
