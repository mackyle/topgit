#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) Petr Baudis <pasky@suse.cz>  2008
# Copyright (C) Aneesh Kumar K.V <aneesh.kumar@linux.vnet.ibm.com>  2008
# Copyright (C) Kyle J. McKay <mackyle@gmail.com>  2015
# All rights reserved.
# GPLv2

branch_prefix=t/
single=
ranges=
rangecnt=0
basedep=

USAGE="Usage: ${tgname:-tg} [...] import [-d <base-branch>] ([-p <prefix>] <range>... | -s <name> <commit>)"

## Parse options

while [ -n "$1" ]; do
	arg="$1"; shift
	case "$arg" in
	-d)
		basedep="$1"; shift;;
	-p)
		branch_prefix="$1"; shift;;
	-s)
		single="$1"; shift;;
	-*)
		printf '%s\n' "$USAGE" >&2
		exit 1;;
	*)
		ranges="$ranges $arg"; rangecnt=$(( $rangecnt + 1 ));;
	esac
done


ensure_clean_tree
ensure_ident_available

## Perform import

get_commit_msg()
{
	commit="$1"
	headers=""
	! header="$(git config topgit.to)" || headers="$headers%nTo: $header"
	! header="$(git config topgit.cc)" || headers="$headers%nCc: $header"
	! header="$(git config topgit.bcc)" || headers="$headers%nBcc: $header"
	git log -1 --pretty=format:"From: %an <%ae>$headers%nSubject: [PATCH] %s%n%n%b" "$commit"
}

get_branch_name()
{
	# nice sed script from git-format-patch.sh
	commit="$1"
	titleScript='
	s/[^-a-z.A-Z_0-9]/-/g
	s/\.\.\.*/\./g
	s/\.*$//
	s/--*/-/g
	s/^-//
	s/-$//
	q
'
	git log -1 --pretty=format:"%s" "$commit" | sed -e "$titleScript"
}

origbasedep="$basedep"
isfirst=1
lasthead=
lastsymref=

process_commit()
{
	commit="$1"
	branch_name="$2"
	info "---- Importing $commit to $branch_name"
	lastsymref="$(git symbolic-ref --quiet HEAD || :)"
	lasthead="$(git rev-parse --verify --quiet HEAD -- 2>/dev/null || :)"
	$tg create --quiet --no-edit "$branch_name" $basedep || die "tg create failed"
	basedep=
	get_commit_msg "$commit" > .topmsg
	git add -f .topmsg .topdeps || die "git add failed"
	if [ -n "$tgnosequester" ]; then
		info "topgit.sequester is set to false, unadvisedly skipping sequester commit"
	else
		git commit -m "tg import create $branch_name" || die "git commit failed"
	fi
	if ! git cherry-pick --no-commit "$commit"; then
		info "The commit will also finish the import of this patch."
		return 2
	fi
	git -c topgit.sequester=false commit -C "$commit"
	info "++++ Importing $commit finished"
	isfirst=
}

if [ -n "$single" ]; then
	process_commit $ranges "$single"
	exit
fi

handle_pick_failure()
{
	# The import got stuck! Let the user fix it up.
	info "You are in a subshell."
	info "Please commit the cherry-pick resolution and then \`exit\`"
	info "If you want to abort the cherry-pick,"
	info "use \`exit 1\` to abort the tg import process at this point."
	info "Use \`exit 2\` to skip importing this commit and continue."
	if ! "${SHELL:-@SHELL_PATH@}" -i </dev/tty; then
		ret=$?
		if [ $ret -eq 2 ]; then
			info "Ok, I will try to continue without importing this commit."
			if [ -n "$tgnosequester" ]; then
				git reset --hard HEAD
			else
				git reset --hard HEAD^
			fi
			[ -z "$isfirst" ] || basedep="$(origbasedep)"
			[ -z "$lasthead" ] || git update-ref --no-deref HEAD "$lasthead"
			[ -z "$lastsymref" ] || git symbolic-ref HEAD "$lastsymref"
			git update-ref -d "refs/top-bases/$branch_name" || :
			git update-ref -d "refs/heads/$branch_name" || :
			git reset --hard HEAD
			return 0
		else
			info "Ok, you aborted the import operation at this point.  Now, you just need"
			info "to switch back to some sane branch using \`git$gitcdopt checkout\`."
			exit 3
		fi
	fi
}

handle_one_commit()
{
	case "$sign" in
		'-')
			info "Merged already: $comment"
			;;
		*)
			if ! process_commit "$rev" "$branch_prefix$(get_branch_name "$rev")"; then
				ret=$?
				[ -z "$islast" ] || return $ret
				handle_pick_failure
			fi
			;;
	esac
}

# nice arg verification stolen from git-format-patch.sh
rangeidx=0
islast=
for revpair in $ranges; do
	rangeidx=$(( $rangeidx + 1 ))
	case "$revpair" in
	?*..?*)
		rev1=`expr "z$revpair" : 'z\(.*\)\.\.'`
		rev2=`expr "z$revpair" : 'z.*\.\.\(.*\)'`
		;;
	*)
		die "Unknown range spec $revpair"
		;;
	esac
	git rev-parse --verify "$rev1^0" -- >/dev/null 2>&1 ||
		die "Not a valid rev $rev1 ($revpair)"
	git rev-parse --verify "$rev2^0" -- >/dev/null 2>&1 ||
		die "Not a valid rev $rev2 ($revpair)"
	git cherry -v "$rev1" "$rev2" | {
		if read sign rev comment; then
			while read next_sign next_rev next_comment; do
				handle_one_commit
				sign="$next_sign"
				rev="$next_rev"
				comment="$next_comment"
			done
			[ "$rangeidx" != "$rangecnt" ] || islast=1
			handle_one_commit
		fi
	}
	test $? -eq 0
done

# vim:noet
