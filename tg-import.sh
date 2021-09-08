#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) 2008 Petr Baudis <pasky@suse.cz>
# Copyright (C) 2008 Aneesh Kumar K.V <aneesh.kumar@linux.vnet.ibm.com>
# Copyright (C) 2015,2017,2018,2021 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved
# GPLv2

branch_prefix=t/
branch_prefix_set=
single=
single_set=
ranges=
rangecnt=0
basedep=
notesflag=
notesref=

USAGE="\
Usage: ${tgname:-tg} [...] import [-d <base-branch>] [<option>...] <range>...
   Or: ${tgname:-tg} [...] import [-d <base-branch>] [<option>...] -s <name> <commit>
Options:
    -p <prefix>         prepend <prefix> to branch names (default is 't/')
    --notes[=<ref>]     import notes ref <ref> to .topmsg --- comment
    --no-notes          do not import any notes ref --- comment (default)"

## Parse options

while [ -n "$1" ]; do
	arg="$1"; shift
	case "$arg" in
	-d)
		basedep="$1"; shift;;
	-p)
		branch_prefix_set=1
		branch_prefix="$1"; shift;;
	-s)
		single_set=1
		single="$1"; shift;;
	--notes*)
		val="${arg#*=}"
		if [ "$val" = "--notes" ]; then
			notesflag=1
			notesref="refs/notes/commits"
		elif [ -n "$val" ] && [ "${val#-}" = "$val" ]; then
			case "$val" in
			refs/notes/*) checknref="$val";;
			notes/*) checknref="refs/$val";;
			*) checknref="refs/notes/$val";;
			esac
			git check-ref-format "$checknref" >/dev/null 2>&1 ||
				die "invalid --notes parameter $arg"
			notesflag=1
			notesref="$checknref"
		else
			die "invalid --notes parameter $arg"
		fi;;
	--no-notes)
		notesflag=0
		notesref=;;
	-*)
		printf '%s\n' "$USAGE" >&2
		exit 1;;
	*)
		ranges="$ranges $arg"; rangecnt=$(( $rangecnt + 1 ));;
	esac
done

[ -z "$single_set" ] || [ -z "$branch_prefix_set" ] ||
	die "-p does not work with single commit (-s <name> <commit>) mode"

if [ -z "$notesflag" ]; then
	if notesflag="$(git config --bool --get topgit.notesimport 2>/dev/null)"; then
		case "$notesflag" in
		true) notesflag=1; notesref="refs/notes/commits";;
		false) notesflag=0; notesref=;;
		esac
	elif
		notesflag="$(git config --get topgit.notesimport 2>/dev/null)" &&
		test -n "$notesflag"
	then
		case "$notesflag" in
		"-"*) checknref="$notesflag";;
		refs/notes/*) checknref="$notesflag";;
		notes/*) checknref="refs/$notesflag";;
		*) checknref="refs/notes/$notesflag";;
		esac
		git check-ref-format "$checknref" >/dev/null 2>&1 ||
			die "invalid topgit.notesImport config setting \"$notesflag\""
		notesflag=1
		notesref="$checknref"
	fi
fi

ensure_work_tree
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
	git --no-pager log -1 --pretty=format:"From: %an <%ae>$headers%nSubject: [PATCH] %s%n%n%b" "$commit"
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
	git --no-pager log -1 --pretty=format:"%s" "$commit" | sed -e "$titleScript"
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
	lastsymref="$(git symbolic-ref --quiet HEAD)" || :
	lasthead="$(git rev-parse --verify --quiet HEAD -- 2>/dev/null)" || :
	nodeps=
	if [ -n "$isfirst" ]; then
		if [ "$basedep" = "" ] || [ "$basedep" = "HEAD" ] || [ "$basedep" = "@" ]; then
			if [ -z "$lastsymref" ] || [ -z "$lasthead" ]; then
				nodeps='--no-deps'
			fi
		fi
	fi
	tg create --quiet --no-edit $nodeps "$branch_name" $basedep || die "tg create failed"
	basedep=
	get_commit_msg "$commit" > .topmsg
	if [ "${notesflag:-0}" = "1" ] && [ -n "$notesref" ]; then
		notesblob="$(git notes --ref="$notesref" list "$commit^0" 2>/dev/null)" || :
		if [ -n "$notesblob" ]; then
			notesdata="$(git cat-file blob "$notesblob" 2>/dev/null |
				git stripspace 2>/dev/null)" || :
			[ -z "$notesdata" ] || printf '\n---\n%s\n' "$notesdata" >>.topmsg
		fi
	fi
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
			git update-ref -d "refs/$topbases/$branch_name" || :
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
		rev1="${revpair%..*}"
		rev2="${revpair##*..}"
		;;
	?*..)
		rev1="${revpair%..}"
		rev2="HEAD"
		;;
	..?*)
		rev1="HEAD"
		rev2="${revpair#..}"
		;;
	?*'^!')
		rev2="${revpair%^!}"
		cnt="$(git rev-list --no-walk --count --min-parents=1 --max-parents=1 "$rev2^0" -- 2>/dev/null)" || :
		if [ "$cnt" = "1" ]; then
			rev1="${revpair%^!}^"
		else
			die "Not a valid single-parent rev $rev2 ($revpair)"
		fi
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
ec=$?
tmpdir_cleanup || :
git gc --auto || :
exit $ec
