#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) Petr Baudis <pasky@suse.cz>  2008
# Copyright (C) Kyle J. McKay <mackyle@gmail.com>  2015,2016,2017
# All rights reserved.
# GPLv2

deps= # List of dependent branches
merge= # List of branches to be merged; subset of $deps
name=
rname= # Remote branch to base this one on
remote=
force=
msg=
msgfile=
topmsg=
topmsgfile=
noedit=
nocommit=
nodeps=
topmsg=
warntop=
quiet=
branchtype=PATCH
branchdesc=patch

USAGE="Usage: ${tgname:-tg} [... -r remote] create [-q] [-m <msg> | -F <file>] [--topmsg <msg> | --topmsg-file <file>] [-n] [--no-commit] [--base] [<name> [<dep>...|-r [<rname>]] ]"

usage()
{
	if [ "${1:-0}" != 0 ]; then
		printf '%s\n' "$USAGE" >&2
	else
		printf '%s\n' "$USAGE"
	fi
	exit ${1:-0}
}

quiet_info()
{
	[ -n "$quiet" ] || info "$@"
}

## Parse options

while [ $# -gt 0 ]; do case "$1" in
	-h|--help)
		usage
		;;
	--quiet|-q)
		quiet=1
		;;
	--force|-f)
		force=1
		;;
	--no-commit)
		nocommit=1
		;;
	-n|--no-edit)
		noedit=1
		nocommit=1
		;;
	--no-deps|--base)
		nodeps=1
		branchtype=BASE
		branchdesc=base
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
	--tm|--tm=*|--topmsg|--topmsg=*)
		case "$1" in
		--tm=*)
			x="$1"
			shift
			set -- --tm "${x#--tm=}" "$@";;
		--topmsg=*)
			x="$1"
			shift
			set -- --topmsg "${x#--topmsg=}" "$@";;
		esac
		if [ $# -lt 2 ]; then
			echo "The $1 option requires an argument" >&2
			usage 1
		fi
		shift
		topmsg="$1"
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
	--tF|--tF=*|--topmsg-file|--topmsg-file=*)
		case "$1" in
		 --tF=*)
			x="$1"
			shift
			set -- --tF "${x#--tF=}" "$@";;
		 --topmsg-file=*)
			x="$1"
			shift
			set -- --topmsg-file "${x#--topmsg-file=}" "$@";;
		esac
		if [ $# -lt 2 ]; then
			echo "The $1 option requires an argument" >&2
			usage 1
		fi
		shift
		topmsgfile="$1"
		;;
	-r)
		remote=1
		rname="$2"; [ $# -eq 0 ] || shift
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
if [ $# -gt 0 ]; then
	name="$1"
	shift
	if [ -z "$remote" -a "$1" = "-r" ]; then
		remote=1
		shift;
		rname="$1"
		[ $# -eq 0 ] || shift
	fi
fi
[ -n "$name" ] || { err "no branch name given"; usage 1; }
[ -z "$remote" -o -n "$rname" ] || rname="$name"
[ -z "$remote" -o -z "$msg$msgfile$topmsg$topmsgfile$nocommit$nodeps" ] || { err "-r may not be combined with other options"; usage 1; }
[ $# -eq 0 -o -z "$remote" ] || { err "deps not allowed with -r"; usage 1; }
[ $# -le 1 -o -z "$nodeps" ] || { err "--base (aka --no-deps) allows at most one <dep>"; usage 1; }
[ -z "$msg" -o -z "$msgfile" ] || die "only one -F or -m option is allowed"
[ "$msgfile" != "-" -o "$topmsgfile" != "-" ] || { err "--message-file and --topmsg-file may not both be '-'"; usage 1; }

## Fast-track creating branches based on remote ones

if [ -n "$rname" ]; then
	[ -n "$name" ] || die "no branch name given"
	! ref_exists "refs/heads/$name" || die "branch '$name' already exists"
	! ref_exists "refs/$topbases/$name" || die "'$topbases/$name' already exists"
	if [ -z "$base_remote" ]; then
		die "no remote location given. Either use -r remote argument or set topgit.remote"
	fi
	has_remote "$rname" || die "no branch $rname in remote $base_remote"
	init_reflog "refs/$topases/$name"
	msg="tgcreate: $name -r $rname"
	tbrv="$(ref_exists_rev "refs/remotes/$base_remote/${topbases#heads/}/$rname")" ||
	tbrv="$(ref_exists_rev "refs/remotes/$base_remote/${oldbases#heads/}/$rname")" ||
	die "no branch $rname in remote $base_remote"
	git update-ref -m "$msg" "refs/$topbases/$name" "$tbrv" ""
	git update-ref -m "$msg" "refs/heads/$name" "refs/remotes/$base_remote/$rname" ""
	quiet_info "Topic branch $name based on $base_remote : $rname set up."
	exit 0
fi

## Auto-guess dependencies

deps="$*"
[ "$deps" != "@" ] || deps="HEAD"
if [ -z "$deps" ]; then
	# The common case
	[ -z "$name" ] && die "no branch name given"
	if [ -n "$nodeps" ]; then
		deps="HEAD"
	else
		head="$(git symbolic-ref --quiet HEAD)" || :
		[ -z "$head" ] || git rev-parse --verify --quiet "$head" -- ||
			die "refusing to auto-depend on unborn branch (use --base aka --no-deps)"
		deps="${head#refs/heads/}"
		[ "$deps" != "$head" ] || die "refusing to auto-depend on non-branch ref (${head:-detached HEAD})"
		quiet_info "automatically marking dependency on $deps"
	fi
fi

unborn=
if [ -n "$nodeps" ]; then
	# there can be only one dep and it need only be a committish
	# however, if it's HEAD and HEAD is an unborn branch that's okay too
	if [ "$deps" = "HEAD" ] && unborn="$(git symbolic-ref --quiet HEAD --)" && ! git rev-parse --verify --quiet HEAD -- >/dev/null; then
		branchtype=ROOT
		branchdesc=root
	else
		unborn=
		git rev-parse --quiet --verify "$deps^0" -- >/dev/null ||
			die "unknown committish \"$deps\""
	fi
fi

# Non-remote branch set up requires a clean tree unless the single dep is the same tree as HEAD

[ "$deps" = "HEAD" ] || {
	prefix=refs/heads/
	[ -z "$nodeps" ] || prefix=
	[ $# -eq 1 -a "$(git rev-parse --quiet --verify "$prefix$deps^{tree}" --)" = "$(git rev-parse --quiet --verify HEAD^{tree} --)" ] ||
		(ensure_clean_tree) || {
			[ $# -ne 1 ] || info "use \`git checkout $deps\` first and then try again"
			exit 1
		}
}

[ -n "$merge" ] || merge="$deps "

if [ -z "$nodeps" ]; then
	olddeps="$deps"
	deps=
	while read d && [ -n "$d" ]; do
		[ "$d" != "@" ] || d="HEAD"
		if [ "$d" = "HEAD" ]; then
			sr="$(git symbolic-ref --quiet HEAD)" || :
			[ -z "$sr" ] || git rev-parse --verify --quiet "$sr" -- ||
				die "refusing to depend on unborn branch (use --base aka --no-deps)"
			[ -n "$sr" ] || die "cannot depend on a detached HEAD"
			case "$sr" in refs/heads/*);;*)
				die "HEAD is a symref to other than refs/heads/..."
			esac
			d="${sr#refs/heads/}"
		else
			ref_exists "refs/heads/$d" || die "unknown branch dependency '$d'"
		fi
		case " $deps " in
			*" $d "*)
				warn "ignoring duplicate depedency $d"
				;;
			*)
				deps="${deps:+$deps }$d"
				;;
		esac
	done <<-EOT
	$(sed 'y/ /\n/' <<-LIST
	$olddeps
	LIST
	)
	EOT
	unset olddeps
fi
if test="$(git symbolic-ref --quiet "$name" --)"; then case "$test" in
	refs/"$topbases"/*)
		name="${test#refs/$topbases/}"
		break;;
	refs/heads/*)
		name="${test#refs/heads/}"
		break;;
esac; fi
! ref_exists "refs/heads/$name" ||
	die "branch '$name' already exists"
! ref_exists "refs/$topbases/$name" ||
	die "'$topbases/$name' already exists"
[ -n "$force" ] || ! ref_exists "refs/tags/$name" ||
	die "refusing to create branch with same name as existing tag '$name' without --force"

# Barf now rather than later if missing ident
ensure_ident_available

if [ -n "$merge" ] && [ -z "$unborn" ]; then
	# make sure the checkout won't fail
	branch="${merge%% *}"
	prefix=refs/heads/
	[ -z "$nodeps" ] || prefix=
	git rev-parse --quiet --verify "$prefix$branch^0" >/dev/null ||
		die "invalid dependency: $branch"
	git read-tree -n -u -m "$prefix$branch^0" ||
		die "git checkout \"$branch\" would fail"
fi

# Get messages

tab="$(printf '\t.')" && tab="${tab%?}"
get_subject()
{
	sed -n '1,/^$/p' |
	grep -i "^Subject[ $tab]*:" |
	sed -n "s/^[^: $tab][^: $tab]*[ $tab]*:[ $tab]*//; s/[ $tab][ $tab]*\$//; 1p" ||
	:
}

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

>"$git_dir/TG_EDITMSG"
if [ -n "$topmsgfile" ]; then
	if [ "$topmsgfile" = "-" ]; then
		git stripspace >"$git_dir/TG_EDITMSG"
	else
		git stripspace <"$topmsgfile" >"$git_dir/TG_EDITMSG"
	fi
elif [ -n "$topmsg" ]; then
	printf '%s\n' "$topmsg" | git stripspace >"$git_dir/TG_EDITMSG"
fi
if [ -s "$git_dir/TG_EDITMSG" ]; then
	noedit=1
else
	author="$(git var GIT_AUTHOR_IDENT)"
	author_addr="${author%> *}>"
	{
		echo "From: $author_addr"
		! header="$(git config topgit.to)" || echo "To: $header"
		! header="$(git config topgit.cc)" || echo "Cc: $header"
		! header="$(git config topgit.bcc)" || echo "Bcc: $header"
		! subject_prefix="$(git config topgit.subjectprefix)" || subject_prefix="$subject_prefix "
		echo "Subject: [${subject_prefix}$branchtype] $name"
		echo
		echo "<$branchdesc description>"
		echo
		echo "Signed-off-by: $author_addr"
		[ "$(git config --bool format.signoff)" = true ] && echo "Signed-off-by: $author_addr"
	} | git stripspace >"$git_dir/TG_EDITMSG"
fi
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
# tg create ${nodeps:+--base }$name $deps
EOT
	run_editor "$git_dir/TG_EDITMSG" ||
	die "there was a problem with the editor '$tg_editor'"
	git stripspace -s <"$git_dir/TG_EDITMSG" >"$git_dir/TG_EDITMSG"+
	mv -f "$git_dir/TG_EDITMSG"+ "$git_dir/TG_EDITMSG"
	[ -s "$git_dir/TG_EDITMSG" ] || die "nothing to do"
fi
subj="$(get_subject <"$git_dir/TG_EDITMSG")"
if [ -z "$subj" ]; then
	subj="$(sed -n "s/^[ $tab][ $tab]*//; 1p" <"$git_dir/TG_EDITMSG")";
	case "$subj" in "["*);;*) subj="[$branchtype] $subj"; esac
	printf '%s\n' "Subject: $subj" "" >"$git_dir/TG_EDITMSG"+
	sed -n '2,$p' <"$git_dir/TG_EDITMSG" | git stripspace >>"$git_dir/TG_EDITMSG"+
	mv -f "$git_dir/TG_EDITMSG"+ "$git_dir/TG_EDITMSG"
	warntop=1
fi
topmsg="$(cat "$git_dir/TG_EDITMSG")"
rm -f "$git_dir/TG_EDITMSG"

## Find starting commit to create the base

if [ -n "$merge" ]; then
	# Unshift the first item from the to-merge list
	branch="${merge%% *}"
	merge="${merge#* }"
	# We create a detached head so that we can abort this operation
	prefix=refs/heads/
	[ -z "$nodeps" ] || prefix=
	if [ -n "$unborn" ]; then
		quiet_info "creating $name base with empty tree..."
	else
		quiet_info "creating $name base from $branch..."
		git checkout -q $iowopt "$(git rev-parse --verify "$prefix$branch^0" --)"
	fi
fi

## Set up the topic branch

init_reflog "refs/$topbases/$name"
if [ -n "$unborn" ]; then
	mttree="$(git mktree </dev/null)"
	emsg="tg create empty $topbases/$name"
	[ "refs/heads/$name" = "$unborn" ] || emsg="Initial empty commit"
	mtcommit="$(git commit-tree  -m "$emsg" "$mttree")" || die "git commit-tree failed"
	git update-ref -m "tgcreate: create ${unborn#refs/heads/}" "HEAD" "$mtcommit" ""
	[ "refs/heads/$name" = "$unborn" ] || warn "branch ${unborn#refs/heads/} created with empty commit"
	git update-ref -m "tgcreate: set $topbases/$name base" "refs/$topbases/$name" "HEAD" ""
	[ "refs/heads/$name" = "$unborn" ] || git checkout $iowopt -b "$name"
else
	basetree="$(git rev-parse --verify "HEAD^{tree}" --)" && [ -n "$basetree" ] || die "HEAD disappeared"
	baseptree="$(pretty_tree "HEAD" -r)" || die "pretty_tree HEAD -r (via git mktree) failed"
	if [ "$basetree" != "$baseptree" ]; then
		bmsg="tg create $topbases/$name base"
		basecommit="$(git commit-tree -p "HEAD" -m "$bmsg" "$baseptree")" || die "git commit-tree failed"
	else
		basecommit="HEAD"
	fi
	git update-ref -m "tgcreate: set $topbases/$name base" "refs/$topbases/$name" "$basecommit" ""
	git checkout $iowopt -b "$name"
fi

if [ -n "$nodeps" ] || [ -z "$deps" ]; then
	>"$root_dir/.topdeps"
else
	sed 'y/ /\n/' <<-EOT >"$root_dir/.topdeps"
	$deps
	EOT
fi
git add -f "$root_dir/.topdeps"
printf '%s\n' "$topmsg" >"$root_dir/.topmsg"
git add -f "$root_dir/.topmsg"
rm -f "$git_dir/TGMERGE_MSG"

[ -z "$warntop" ] || warn ".topmsg content was reformatted into patch header"
if [ -n "$nocommit" ]; then
	printf '%s\n' "$msg" >"$git_dir/MERGE_MSG"
	quiet_info "Topic branch $name set up."
	if [ -n "$noedit" ]; then
		quiet_info "Please fill in .topmsg now and make the initial commit."
	else
		quiet_info "Please make the initial commit."
	fi
	quiet_info "Remember to run $tgdisplay update afterwards."
	quiet_info "To abort:"
	quiet_info "  git$gitcdopt rm -f .top* && git$gitcdopt checkout ${deps%% *} && $tgdisplay delete $name"
	exit 0
fi

git commit -m "$msg" "$root_dir/.topdeps" "$root_dir/.topmsg" || die "git commit failed"
rawsubj="$(get_subject <"$root_dir/.topmsg")"
nommsg=1
case "$rawsubj" in *"["[Pp][Aa][Tt][Cc][Hh]"]"*)
	nommsg=
	subj="$(sed "s/^[^]]*]//; s/^[ $tab][ $tab]*//; s/[ $tab][ $tab]*\$//" <<-EOT
		$rawsubj
	EOT
	)"
	{
		[ -z "$subj" ] || printf '%s\n' "$subj" ""
		sed -e '1,/^$/d' <"$root_dir/.topmsg"
	} >"$git_dir/MERGE_MSG"
esac
quiet_info "Topic branch $name created."
[ -n "$merge" ] || exit 0
## Merge other dependencies into the base
quiet_info "Running $tgname update to merge in dependencies."
[ -n "$nommsg" ] || ! [ -f "$git_dir/MERGE_MSG" ] || mv -f "$git_dir/MERGE_MSG" "$git_dir/TGMERGE_MSG" || :
set -- "$name"
. "$TG_INST_CMDDIR"/tg-update
