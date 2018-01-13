#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) Petr Baudis <pasky@suse.cz>  2008
# Copyright (C) Kyle J. McKay <mackyle@gmail.com>  2015,2016,2017,2018
# All rights reserved.
# GPLv2

names= # Branch(es) to update
name1= # first name
name2= # second name
namecnt=0 # how many names were seen
all= # Update all branches
pattern= # Branch selection filter for -a
current= # Branch we are currently on
skipms= # skip missing dependencies
stash= # tgstash refs before changes
quiet= # be quieter
basemode= # true if --base active
editmode= # 0, 1 or empty to force none, force edit or default
basemsg= # message for --base merge commit
basefile= # message file for --base merge commit
basenc= # --no-commit on merge
basefrc= # --force non-ff update
setautoupdate=1 # temporarily set rerere.autoUpdate to true

if [ "$(git config --get --bool topgit.autostash 2>/dev/null)" != "false" ]; then
	# topgit.autostash is true (or unset)
	stash=1
fi

## Parse options

USAGE="\
Usage: ${tgname:-tg} [...] update [--[no-]stash] [--skip-missing] ([<name>...] | -a [<pattern>...])
   Or: ${tgname:-tg} [...] update --base [-F <file> | -m <msg>] [--[no-]edit] [-f] <base-branch> <ref>
   Or: ${tgname:-tg} [...] update --continue | -skip | --stop | --abort"

usage()
{
	if [ "${1:-0}" != 0 ]; then
		printf '%s\n' "$USAGE" >&2
	else
		printf '%s\n' "$USAGE"
	fi
	exit ${1:-0}
}

# --base mode comes here with $1 set to <base-branch> and $2 set to <ref>
# and all options already parsed and validated into above-listed flags
# this function should exit after returning to "$current"
do_base_mode()
{
	v_verify_topgit_branch tgbranch "$1"
	depcnt="$(git cat-file blob "refs/heads/$tgbranch:.topdeps" 2>/dev/null | awk 'END {print NR}')"
	if [ $depcnt -gt 0 ]; then
		grammar="dependency"
		[ $depcnt -eq 1 ] || grammar="dependencies"
		die "'$tgbranch' is not a TopGit [BASE] branch (it has $depcnt $grammar)"
	fi
	newrev="$(git rev-parse --verify "$2^0" --)" && [ -n "$newrev" ] ||
		die "not a valid commit-ish: $2"
	baserev="$(ref_exists_rev "refs/$topbases/$tgbranch")" && [ -n "$baserev" ] ||
		die "unable to get current base commit for branch '$tgbranch'"
	if [ "$baserev" = "$newrev" ]; then
		[ -n "$quiet" ] || echo "No change"
		exit 0
	fi
	alreadymerged=
	! contained_by "$newrev" "refs/heads/$tgbranch" || alreadymerged=1
	if [ -z "$basefrc" ] && ! contained_by "$baserev" "$newrev"; then
		die "Refusing non-fast-forward update of base without --force"
	fi

	# check that we can checkout the branch

	[ -n "$alreadymerged" ] || git read-tree -n -u -m "refs/heads/$tgbranch" ||
		die "git checkout \"$branch\" would fail"

	# and make sure everything's clean and we know who we are

	[ -n "$alreadymerged" ] || ensure_clean_tree
	ensure_ident_available

	# always auto stash even if it's just to the anonymous stash TG_STASH

	stashmsg="tgupdate: autostash before --base $tgbranch update"
	if [ -n "$stash" ]; then
		tg tag -q -q -m "$stashmsg" --stash "$tgbranch" &&
		stashhash="$(git rev-parse --quiet --verify refs/tgstash --)" &&
		[ -n "$stashhash" ] &&
		[ "$(git cat-file -t "$stashhash" -- 2>/dev/null)" = "tag" ] ||
		die "requested --stash failed"
	else
		tg tag --anonymous "$tgbranch" &&
		stashhash="$(git rev-parse --quiet --verify TG_STASH --)" &&
		[ -n "$stashhash" ] &&
		[ "$(git cat-file -t "$stashhash" -- 2>/dev/null)" = "tag" ] ||
		die "anonymous --stash failed"
	fi

	# proceed with the update

	git update-ref -m "tg update --base $tgbranch $2" "refs/$topbases/$tgbranch" "$newrev" "$baserev" ||
		die "Unable to update base ref"
	if [ -n "$alreadymerged" ]; then
		[ -n "$quiet" ] || echo "Already contained in branch (base updated)"
		exit 0
	fi
	git checkout -q $iowopt "$tgbranch" || die "git checkout failed"
	msgopt=
	# options validation guarantees that at most one of basemsg or basefile is set
	[ -z "$basemsg" ] || msgopt='-m "$basemsg"'
	if [ -n "$basefile" ]; then
		# git merge does not accept a -F <msgfile> option so we have to fake it
		basefilemsg="$(cat "$basefile")" || die "could not read file '$basefile'"
		msgopt='-m "$basefilemsg"'
	fi
	editopt=
	if [ -n "$editmode" ]; then
		if [ "$editmode" = "0" ]; then
			editopt="--no-edit"
		else
			editopt="--edit"
		fi
	fi
	if [ -z "$basemsg$basefile" ]; then
		[ -n "$editopt" ] || editopt="--edit"
		basemsg="tg update --base $tgbranch $2"
		msgopt='-m "$basemsg"'
	else
		[ -n "$editopt" ] || editopt="--no-edit"
	fi
	ncopt=
	[ -z "$basenc" ] || ncopt="--no-commit"
	eval git merge --no-ff --no-log --no-stat $auhopt $ncopt $editopt "$msgopt" "refs/$topbases/$tgbranch" -- || exit
	[ -n "$basenc" ] || checkout_symref_full "$current"
	exit
}

state_dir="$git_dir/tg-update"
mergeours=
mergetheirs=
mergeresult=
stashhash=
next_no_auto=
merging_topfiles=

is_active() {
	[ -d "$state_dir" ] || return 1
	[ -s "$state_dir/fullcmd" ] || return 1
	[ -f "$state_dir/remote" ] || return 1
	[ -f "$state_dir/skipms" ] || return 1
	[ -f "$state_dir/all" ] || return 1
	[ -s "$state_dir/current" ] || return 1
	[ -s "$state_dir/stashhash" ] || return 1
	[ -s "$state_dir/name" ] || return 1
	[ -s "$state_dir/names" ] || return 1
	[ -f "$state_dir/processed" ] || return 1
	[ -f "$state_dir/no_auto" ] || return 1
	[ -f "$state_dir/setautoupdate" ] || return 1
	[ -f "$state_dir/merging_topfiles" ] || return 1
	[ -f "$state_dir/mergeours" ] || return 1
	[ -f "$state_dir/mergeours" ] || return 1
	if [ -s "$state_dir/mergeours" ]; then
		[ -s "$state_dir/mergetheirs" ] || return 1
	else
		! [ -s "$state_dir/mergetheirs" ] || return 1
	fi
}

restore_state() {
	is_active || die "programmer error"
	IFS= read -r fullcmd <"$state_dir/fullcmd" && [ -n "$fullcmd" ]
	IFS= read -r base_remote <"$state_dir/remote" || :
	IFS= read -r skipms <"$state_dir/skipms" || :
	IFS= read -r all <"$state_dir/all" || :
	IFS= read -r current <"$state_dir/current" && [ -n "$current" ]
	IFS= read -r stashhash <"$state_dir/stashhash" && [ -n "$stashhash" ]
	IFS= read -r name <"$state_dir/name" && [ -n "$name" ]
	IFS= read -r names <"$state_dir/names" && [ -n "$names" ]
	IFS= read -r processed <"$state_dir/processed" || :
	IFS= read -r next_no_auto <"$state_dir/no_auto" || :
	IFS= read -r setautoupdate <"$state_dir/setautoupdate" || :
	# merging_topfiles is for outside info but not to be restored
	IFS= read -r mergeours <"$state_dir/mergeours" || :
	IFS= read -r mergetheirs <"$state_dir/mergetheirs" || :
	if [ -n "$mergeours" ] && [ -n "$mergetheirs" ]; then
		headhash="$(git rev-parse --quiet --verify HEAD --)" || :
		if [ -n "$headhash" ]; then
			parents="$(git --no-pager log -n 1 --format='format:%P' "$headhash" -- 2>/dev/null)" || :
			if [ "$parents" = "$mergeours $mergetheirs" ]; then
				mergeresult="$headhash"
			fi
		fi
		if [ -z "$mergeresult" ]; then
			mergeours=
			mergetheirs=
		fi
	fi
	restored=1
}

clear_state() {
	! [ -e "$state_dir" ] || rm -rf "$state_dir" >/dev/null 2>&1 || :
}

restarted=
isactive=
! is_active || isactive=1
isactiveopt=
if [ -z "$isactive" ] && [ $# -eq 1 ]; then
	case "$1" in --abort|--stop|--continue|--skip) isactiveopt=1; esac
fi
if [ -n "$isactive" ] || [ -n "$isactiveopt" ]; then
	[ $# -eq 1 ] && [ x"$1" != x"--status" ] || { do_status; exit 0; }
	ensure_work_tree
	if [ -z "$isactive" ]; then
		clear_state
		info "No update is currently active"
		exit 0
	fi
	case "$1" in
	--abort)
		current=
		stashhash=
		IFS= read -r current <"$state_dir/current" || :
		IFS= read -r stashhash <"$state_dir/stashhash" || :
		clear_state
		if [ -n "$stashhash" ]; then
			tg revert -f -q -q --no-stash "$stashhash" >/dev/null 2>&1 || :
		fi
		if [ -n "$current" ]; then
			info "Ok, update aborted, returning to ${current#refs/heads/}"
			checkout_symref_full -f "$current"
		else
			info "Ok, update aborted.  Now, you just need to"
			info "switch back to some sane branch using \`git$gitcdopt checkout\`."
		fi
		! [ -f "$git_dir/TGMERGE_MSG" ] || [ -e "$git_dir/MERGE_MSG" ] ||
			mv -f "$git_dir/TGMERGE_MSG" "$git_dir/MERGE_MSG" || :
		exit 0
		;;
	--stop)
		clear_state
		info "Ok, update stopped.  Now, you just need to"
		info "switch back to some sane branch using \`git$gitcdopt checkout\`."
		! [ -f "$git_dir/TGMERGE_MSG" ] || [ -e "$git_dir/MERGE_MSG" ] ||
			mv -f "$git_dir/TGMERGE_MSG" "$git_dir/MERGE_MSG" || :
		exit 0
		;;
	--continue|--skip)
		restore_state
		if [ "$1" = "--skip" ]; then
			info "Ok, I will try to continue without updating this branch."
			git reset --hard -q
			case " $processed " in *" $name "*);;*)
				processed="${processed:+$processed }$name"
			esac
		fi
		# assume user fixed it
		# we could be left on a detached HEAD if we were resolving
		# a conflict while merging a base in, fix it with a checkout
		git checkout -q $iowopt "$(strip_ref "$name")"
		;;
	*)
		do_status
		exit 1
	esac
fi
clear_state

if [ -z "$restored" ]; then
	setautoupdate=1
	[ "$(git config --get --bool topgit.setAutoUpdate 2>/dev/null)" != "false" ] ||
	setautoupdate=

	while [ -n "$1" ]; do
		arg="$1"; shift
		case "$arg" in
		-h)
			usage;;
		-a|--all)
			[ -z "$names$pattern" ] || usage 1
			all=1;;
		--skip-missing)
			skipms=1;;
		--stash)
			stash=1;;
		--no-stash)
			stash=;;
		--auto|--auto-update|--set-auto|--set-auto-update)
			setautoupdate=1;;
		--no-auto|--no-auto-update|--no-set-auto|--no-set-auto-update)
			setautoupdate=;;
		--quiet|-q)
			quiet=1;;
		--base)
			basemode=1;;
		--edit|-e)
			editmode=1;;
		--no-edit)
			editmode=0;;
		--no-commit)
			basenc=1;;
		--force|-f)
			basefrc=1;;
		-m|--message)
			[ $# -gt 0 ] && [ -n "$1" ] || die "option $arg requires an argument"
			basemsg="$1"
			shift;;
		-m?*)
			basemsg="${1#-m}";;
		--message=*)
			basemsg="${1#--message=}";;
		-F|--file)
			[ $# -gt 0 ] && [ -n "$1" ] || die "option $arg requires an argument"
			basefile="$1"
			shift;;
		-F?*)
			basefile="${1#-F}";;
		--file=*)
			basefile="${1#--file=}"
			[ -n "$basefile" ] || die "option --file= requires an argument"
			;;
		-?*)
			usage 1;;
		--)
			break;;
		"")
			;;
		*)
			if [ -z "$all" ]; then
				namecnt=$(( $namecnt + 1 ))
				[ "$namecnt" != "1" ] || name1="$arg"
				[ "$namecnt" != "2" ] || name2="$arg"
				names="${names:+$names }$arg"
			else
				pattern="${pattern:+$pattern }refs/$topbases/$(strip_ref "$arg")"
			fi
			;;
		esac
	done
	ensure_work_tree
	while [ $# -gt 0 ]; do
		if [ -z "$all" ]; then
			namecnt=$(( $namecnt + 1 ))
			[ "$namecnt" != "1" ] || name1="$1"
			[ "$namecnt" != "2" ] || name2="$1"
			names="${names:+$names }$*"
		else
			pattern="${pattern:+$pattern }refs/$topbases/$(strip_ref "$1")"
		fi
		shift
	done
	[ -n "$basemode" ] || [ -z "$editmode$basemsg$basefile$basenc$basefrc" ] || usage 1
	[ -z "$basemode" ] || [ -z "$all$skipms" ] || usage 1
	[ -z "$basemode" ] || [ -z "$basemsg" ] || [ -z "$basefile" ] || usage 1
	[ -z "$basemode" ] || [ "$namecnt" -eq 2 ] || usage 1

	current="$(git symbolic-ref -q HEAD)" || :
	if [ -n "$current" ]; then
		[ -n "$(git rev-parse --verify --quiet HEAD --)" ] ||
			die "cannot return to unborn branch; switch to another branch"
	else
		current="$(git rev-parse --verify --quiet HEAD)" ||
			die "cannot return to invalid HEAD; switch to another branch"
	fi

	[ -z "$basemode" ] || do_base_mode "$name1" "$name2"

	origpattern="$pattern"
	[ -z "$pattern" ] && pattern="refs/$topbases"

	processed=
	[ -n "$all$names" ] || names="HEAD"
	if [ -z "$all" ]; then
		clean_names() {
			names=
			while [ $# -gt 0 ]; do
				name="$(verify_topgit_branch "$1")"
				case " $names " in *" $name "*);;*)
					names="${names:+$names }$name"
				esac
				shift
			done
		}
		clean_names $names
		if [ "$namecnt" -eq 1 ]; then
			case "$fullcmd" in *" @"|*" HEAD")
				namecnt=0
				fullcmd="${fullcmd% *}"
			esac
		fi
		[ "$namecnt" -ne 0 ] || fullcmd="$fullcmd $names"
	fi
	ensure_clean_tree
fi

save_state() {
	mkdir -p "$state_dir"
	printf '%s\n' "$fullcmd" >"$state_dir/fullcmd"
	printf '%s\n' "$base_remote" >"$state_dir/remote"
	printf '%s\n' "$skipms" >"$state_dir/skipms"
	printf '%s\n' "$all" >"$state_dir/all"
	printf '%s\n' "$current" >"$state_dir/current"
	printf '%s\n' "$stashhash" >"$state_dir/stashhash"
	printf '%s\n' "$name" >"$state_dir/name"
	printf '%s\n' "$names" >"$state_dir/names"
	printf '%s\n' "$processed" >"$state_dir/processed"
	printf '%s\n' "$no_auto" >"$state_dir/no_auto"
	printf '%s\n' "$setautoupdate" >"$state_dir/setautoupdate"
	# this one is an external flag and needs to be zero length for false
	printf '%s' "$merging_topfiles" >"$state_dir/merging_topfiles"
	printf '%s\n' "$1" >"$state_dir/mergeours"
	printf '%s\n' "$2" >"$state_dir/mergetheirs"
}

stash_now_if_requested() {
	[ -z "$TG_RECURSIVE" ] || return 0
	[ -z "$stashhash" ] || return 0
	ensure_ident_available
	msg="tgupdate: autostash before update"
	if [ -n "$all" ]; then
		msg="$msg --all${origpattern:+ $origpattern}"
	else
		msg="$msg $names"
	fi
	set -- $names
	if [ -n "$stash" ]; then
		tg tag -q -q -m "$msg" --stash "$@"  &&
		stashhash="$(git rev-parse --quiet --verify refs/tgstash --)" &&
		[ -n "$stashhash" ] &&
		[ "$(git cat-file -t "$stashhash" -- 2>/dev/null)" = "tag" ] ||
		die "requested --stash failed"
	else
		tg tag --anonymous "$@" &&
		stashhash="$(git rev-parse --quiet --verify TG_STASH --)" &&
		[ -n "$stashhash" ] &&
		[ "$(git cat-file -t "$stashhash" -- 2>/dev/null)" = "tag" ] ||
		die "anonymous --stash failed"
	fi
	[ -z "$next_no_auto" ] || no_auto="$next_no_auto"
	next_no_auto=
}

recursive_update() {
	_ret=0
	on_base=
	(
		if [ -n "$TG_RECURSIVE" ]; then
			TG_RECURSIVE="==> [$1]${TG_RECURSIVE#==>}"
		else
			TG_RECURSIVE="==> [$1]$lf"
		fi
		update_branch "$1"
	) || _ret=$?
	[ $_ret -eq 3 ] && exit 3
	return $_ret
}

# If HEAD is a symref to "$1" detach it at its current value
detach_symref_head_on_branch() {
	_hsr="$(git symbolic-ref -q HEAD --)" && [ -n "$_hsr" ] || return 0
	_hrv="$(git rev-parse --quiet --verify HEAD --)" && [ -n "$_hrv" ] ||
		die "cannot detach_symref_head_on_branch from unborn branch $_hsr"
	git update-ref --no-deref -m "detaching HEAD from $_hsr to safely update it" HEAD "$_hrv"
}

# git_topmerge will need this even on success and since it might otherwise
# be called many times do it just the once here and now
repotoplvl="$(git rev-parse --show-toplevel)" && [ -n "$repotoplvl" ] && [ -d "$repotoplvl" ] ||
die "git rev-parse --show-toplevel failed"

# Run an in-tree recursive merge but make sure we get the desired version of
# any .topdeps and .topmsg files.  The $auhopt and --no-stat options are
# always implicitly in effect.  If successful, a new commit is performed on HEAD.
#
# The "git merge-recursive" tool (and others) must be run to get the desired
# result.  And --no-ff is always implicitly in effect as well.
#
# NOTE: [optional] arguments MUST appear in the order shown
# [optional] '-v' varname => optional variable to return original HEAD hash in
# [optional] '--merge', '--theirs' or '--remove' to alter .topfile handling
# [optional] '--name' <name-for-ours [--name <name-for-theirs>]
# $1 => '-m' MUST be '-m'
# $2 => commit message
# $3 => commit-ish to merge as "theirs"
git_topmerge()
{
	_ovar=
	[ "$1" != "-v" ] || [ $# -lt 2 ] || [ -z "$2" ] || { _ovar="$2"; shift 2; }
	_mmode=
	case "$1" in --theirs|--remove|--merge) _mmode="${1#--}"; shift; esac
	_nameours=
	_nametheirs=
	if [ "$1" = "--name" ] && [ $# -ge 2 ]; then
		_nameours="$2"
		shift 2
		if [ "$1" = "--name" ] && [ $# -ge 2 ]; then
			_nametheirs="$2"
			shift 2
		fi
	fi
	: "${_nameours:=HEAD}"
	[ "$#" -eq 3 ] && [ "$1" = "-m" ] && [ -n "$2" ] && [ -n "$3" ] ||
		die "programmer error: invalid arguments to git_topmerge: $*"
	_ours="$(git rev-parse --verify HEAD^0)" || die "git rev-parse failed"
	_theirs="$(git rev-parse --verify "$3^0")" || die "git rev-parse failed"
	[ -z "$_ovar" ] || eval "$_ovar="'"$_ours"'
	eval "GITHEAD_$_ours="'"$_nameours"' && eval export "GITHEAD_$_ours"
	if [ -n "$_nametheirs" ]; then
		eval "GITHEAD_$_theirs="'"$_nametheirs"' && eval export "GITHEAD_$_theirs"
	fi
	_mdriver='touch %A'
	if [ "$_mmode" = "merge" ]; then
		TG_L1="$_nameours" && export TG_L1
		TG_L2="merged common ancestors" && export TG_L2
		TG_L3="${_nametheirs:-$3}" && export TG_L3
		_mdriver='git merge-file -L "$TG_L1" -L "$TG_L2" -L "$TG_L3" --marker-size=%L %A %O %B'
	fi
	_msg="$2"
	_mt=
	_mb="$(git merge-base --all "$_ours" "$_theirs")" && [ -n "$_mb" ] ||
	{ _mt=1; _mb="$(git hash-object -w -t tree --stdin < /dev/null)"; }
	# any .topdeps or .topmsg output needs to be stripped from stdout
	tmpstdout="$tg_tmp_dir/stdout.$$"
	_ret=0
	git -c "merge.ours.driver=$_mdriver" merge-recursive \
		$_mb -- "$_ours" "$_theirs" >"$tmpstdout" || _ret=$?
	# success or failure is not relevant until after fixing up the
	# .topdeps and .topmsg files and running rerere unless _ret >= 126
	[ $_ret -lt 126 ] || return $_ret
	if [ "$_mmode" = "merge" ]; then
		cat "$tmpstdout"
	else
		case "$_mmode" in
			theirs) _source="$_theirs";;
			remove) _source="";;
			     *) _source="$_ours";;
		esac
		_newinfo=
		[ -z "$_source" ] ||
		_newinfo="$(git cat-file --batch-check="%(objecttype) %(objectname)$tab%(rest)" <<-EOT |
		$_source:.topdeps .topdeps
		$_source:.topmsg .topmsg
		EOT
		sed -n 's/^blob /100644 /p'
		)"
		[ -z "$_newinfo" ] || _newinfo="$lf$_newinfo"
		git update-index --index-info <<-EOT ||
		0 $nullsha$tab.topdeps
		0 $nullsha$tab.topmsg$_newinfo
		EOT
		die "git update-index failed"
		if [ "$_mmode" = "remove" ] &&
		   { [ -e "$repotoplvl/.topdeps" ] || [ -e "$repotoplvl/.topmsg" ]; }
		then
			rm -r -f "$repotoplvl/.topdeps" "$repotoplvl/.topmsg" >/dev/null 2>&1 || :
		else
			for zapbad in "$repotoplvl/.topdeps" "$repotoplvl/.topmsg"; do
				if [ -e "$zapbad" ] && { [ -L "$zapbad" ] || [ ! -f "$zapbad" ]; }; then
					rm -r -f "$zapbad"
				fi
			done
			(cd "$repotoplvl" && git checkout-index -q -f -u -- .topdeps .topmsg) ||
			die "git checkout-index failed"
		fi
		# dump output without any .topdeps or .topmsg messages
		sed -e '/ \.topdeps/d' -e '/ \.topmsg/d' <"$tmpstdout"
	fi
	# rerere will be a nop unless rerere.enabled is true, but might complete the merge!
	eval git "${setautoupdate:+-c rerere.autoupdate=1}" rerere || :
	git ls-files --unmerged --full-name --abbrev :/ >"$tmpstdout" 2>&1 ||
	die "git ls-files failed"
	if [ -s "$tmpstdout" ]; then
		[ "$_ret" != "0" ] || _ret=1
	else
		_ret=0
	fi
	if [ $_ret -ne 0 ]; then
		# merge failed, spit out message, enter "merge" mode and return
		{
			printf '%s\n\n# Conflicts:\n' "$_msg"
			sed -n "/$tab/s/^[^$tab]*/#/p" <"$tmpstdout" | sort -u
		} >"$git_dir/MERGE_MSG"
		git update-ref MERGE_HEAD "$_theirs" || :
		echo 'Automatic merge failed; fix conflicts and then commit the result.'
		rm -f "$tmpstdout"
		return $_ret
	fi
	# commit time at last!
	thetree="$(git write-tree)" || die "git write-tree failed"
	# avoid an extra "already up-to-date" commit (can't happen if _mt though)
	origtree=
	[ -n "$_mt" ] || origtree="$(git rev-parse --quiet --verify "$_ours^{tree}" --)" &&
		[ -n "$origtree" ] || die "git rev-parse failed"
	if [ "$origtree" != "$thetree" ] || ! contained_by "$_theirs" "$_ours"; then
		thecommit="$(git commit-tree -p "$_ours" -p "$_theirs" -m "$_msg" "$thetree")" &&
		[ -n "$thecommit" ] || die "git commit-tree failed"
		git update-ref -m "$_msg" HEAD "$thecommit" || die "git update-ref failed"
	fi
	# mention how the merge was made
	echo "Merge made by the 'recursive' strategy."
	rm -f "$tmpstdout"
	return 0
}

# run git_topmerge with the passed in arguments (it always does --no-stat)
# then return the exit status of git_topmerge
# if the returned exit status is no error show a shortstat before
# returning assuming the merge was done into the previous HEAD but exclude
# .topdeps and .topmsg info from the stat unless doing a --merge
# if the first argument is --merge or --theirs or --remove handle .topmsg/.topdeps
# as follows:
#   (default)   .topmsg and .topdeps always keep ours
#   --merge     a normal merge takes place
#   --theirs    .topmsg and .topdeps always keep theirs
#   --remove    .topmsg and .topdeps are removed from the result and working tree
# note this function should only be called after attempt_index_merge fails as
# it implicity always does --no-ff (except for --merge which will --ff)
git_merge() {
	_ret=0
	git_topmerge -v _oldhead "$@" || _ret=$?
	_exclusions=
	[ "$1" = "--merge" ] || _exclusions=":/ :!/.topdeps :!/.topmsg"
	[ "$_ret" != "0" ] || git --no-pager diff-tree --shortstat "$_oldhead" HEAD^0 -- $_exclusions
	return $_ret
}

# $1 => .topfile handling ([--]merge, [--]theirs, [--]remove or else do ours)
# $2 => current "HEAD"
# $3 => proposed fast-forward-to "HEAD"
# result is success if fast-forward satisfies $1
topff_ok() {
	case "${1#--}" in
		merge|theirs)
			# merge and theirs will always be correct
			;;
		remove)
			# okay if both blobs are "missing" in $3
			printf '%s\n' "$3:.topdeps" "$3:.topmsg" |
			git cat-file --batch-check="%(objectname) %(objecttype)" |
			{
				read _tdo _tdt &&
				read _tmo _tmt &&
				[ "$_tdt" = "missing" ] &&
				[ "$_tmt" = "missing" ]
			} || return 1
			;;
		*)
			# "ours"
			# okay if both blobs are the same (same hash or missing)
			printf '%s\n' "$2:.topdeps" "$2:.topmsg" "$3:.topdeps" "$3:.topmsg" |
			git cat-file --batch-check="%(objectname) %(objecttype)" |
			{
				read _td1o _td1t &&
				read _tm1o _tm1t &&
				read _td2o _td2t &&
				read _tm2o _tm2t &&
				{ [ "$_td1t" = "$_td2t" ] &&
				  { [ "$_td1o" = "$_td2o" ] ||
				    [ "$_td1t" = "missing" ]; }; } &&
				{ [ "$_tm1t" = "$_tm2t" ] &&
				  { [ "$_tm1o" = "$_tm2o" ] ||
				    [ "$_tm1t" = "missing" ]; }; }
			} || return 1
			;;
	esac
	return 0
}

# similar to git_merge but operates exclusively using a separate index and temp dir
# only trivial aggressive automatic (i.e. simple) merges are supported
#
# [optional] '--no-auto' to suppress "automatic" merging, merge fails instead
# [optional] '--merge', '--theirs' or '--remove' to alter .topfile handling
# $1 => '' to discard result, 'refs/?*' to update the specified ref or a varname
# $2 => '-m' MUST be '-m'
# $3 => commit message AND, if $1 matches refs/?* the update-ref message
# $4 => commit-ish to merge as "ours"
# $5 => commit-ish to merge as "theirs"
# [$6...] => more commit-ishes to merge as "theirs" in octopus
#
# all merging is done in a separate index (or temporary files for simple merges)
# if successful the ref or var is updated with the result
# otherwise everything is left unchanged and a silent failure occurs
# if successful and $1 matches refs/?* it WILL BE UPDATED to a new commit using the
# message and appropriate parents AND HEAD WILL BE DETACHED first if it's a symref
# to the same ref
# otherwise if $1 does not match refs/?* and is not empty the named variable will
# be set to contain the resulting commit from the merge
# the working tree and index ARE LEFT COMPLETELY UNTOUCHED no matter what
v_attempt_index_merge() {
	_noauto=
	if [ "$1" = "--no-auto" ]; then
		_noauto=1
		shift
	fi
	_exclusions=
	[ "$1" = "--merge" ] || _exclusions=":/ :!/.topdeps :!/.topmsg"
	_mstyle=
	if [ "$1" = "--merge" ] || [ "$1" = "--theirs" ] || [ "$1" = "--remove" ]; then
		_mmode="${1#--}"
		shift
		if [ "$_mmode" = "merge" ] || [ "$_mmode" = "theirs" ]; then
			_mstyle="-top$_mmode"
		fi
	fi
	[ "$#" -ge 5 ] && [ "$2" = "-m" ] && [ -n "$3" ] && [ -n "$4" ] && [ -n "$5" ] ||
		die "programmer error: invalid arguments to v_attempt_index_merge: $*"
	_var="$1"
	_msg="$3"
	_head="$4"
	shift 4
	rh="$(git rev-parse --quiet --verify "$_head^0" --)" && [ -n "$rh" ] || return 1
	orh="$rh"
	oth=
	_mmsg=
	newc=
	_nodt=
	_same=
	_mt=
	_octo=
	if [ $# -gt 1 ]; then
		if [ "$_mmode" = "merge" ] || [ "$_mmode" = "theirs" ]; then
			die "programmer error: invalid octopus .topfile strategy to v_attempt_index_merge: --$_mode"
		fi
		ihl="$(git merge-base --independent "$@")" || return 1
		set -- $ihl
		[ $# -ge 1 ] && [ -n "$1" ] || return 1
	fi
	[ $# -eq 1 ] || _octo=1
	mb="$(git merge-base ${_octo:+--octopus} "$rh" "$@")" && [ -n "$mb" ] || {
		mb="$(git hash-object -w -t tree --stdin < /dev/null)"
		_mt=1
	}
	if [ -z "$_mt" ]; then
		if [ -n "$_octo" ]; then
			while [ $# -gt 1 ] && mbh="$(git merge-base "$rh" "$1")" && [ -n "$mbh" ]; do
				if [ "$rh" = "$mbh" ]; then
					if topff_ok "$_mmode" "$rh" "$1"; then
						_mmsg="Fast-forward (no commit created)"
						rh="$1"
						shift
					else
						break
					fi
				elif [ "$1" = "$mbh" ]; then
					shift
				else
					break;
				fi
			done
			if [ $# -eq 1 ]; then
				_octo=
				mb="$(git merge-base "$rh" "$1")" && [ -n "$mb" ] || return 1
			fi
		fi
		if [ -z "$_octo" ]; then
			r1="$(git rev-parse --quiet --verify "$1^0" --)" && [ -n "$r1" ] || return 1
			oth="$r1"
			set -- "$r1"
			if [ "$rh" = "$mb" ]; then
				if topff_ok "$_mmode" "$rh" "$r1"; then
					_mmsg="Fast-forward (no commit created)"
					newc="$r1"
					_nodt=1
					_mstyle=
				fi
			elif [ "$r1" = "$mb" ]; then
				[ -n "$_mmsg" ] || _mmsg="Already up-to-date!"
				newc="$rh"
				_nodt=1
				_same=1
				_mstyle=
			fi
		fi
	fi
	if [ -z "$newc" ]; then
		if [ "$_mmode" = "theirs" ] && [ -z "$oth" ]; then
			oth="$(git rev-parse --quiet --verify "$1^0" --)" && [ -n "$oth" ] || return 1
			set -- "$oth"
		fi
		inew="$tg_tmp_dir/index.$$"
		! [ -e "$inew" ] || rm -f "$inew"
		itmp="$tg_tmp_dir/output.$$"
		imrg="$tg_tmp_dir/auto.$$"
		[ -z "$_octo" ] || >"$imrg"
		_auto=
		_parents=
		_newrh="$rh"
		while :; do
			if [ -n "$_parents" ]; then
				if contained_by "$1" "$_newrh"; then
					shift
					continue
				fi
			fi
			GIT_INDEX_FILE="$inew" git read-tree -m --aggressive -i "$mb" "$rh" "$1" || { rm -f "$inew" "$imrg"; return 1; }
			GIT_INDEX_FILE="$inew" git ls-files --unmerged --full-name --abbrev :/ >"$itmp" 2>&1 || { rm -f "$inew" "$itmp" "$imrg"; return 1; }
			! [ -s "$itmp" ] || {
				if ! GIT_INDEX_FILE="$inew" TG_TMP_DIR="$tg_tmp_dir" git merge-index -q "$TG_INST_CMDDIR/tg--index-merge-one-file$_mstyle" -a >"$itmp" 2>&1; then
					rm -f "$inew" "$itmp" "$imrg"
					return 1
				fi
				if [ -s "$itmp" ]; then
					if [ -n "$_noauto" ]; then
						rm -f "$inew" "$itmp" "$imrg"
						return 1
					fi
					if [ -n "$_octo" ]; then
						cat "$itmp" >>"$imrg"
					else
						cat "$itmp"
					fi
					_auto=" automatic"
				fi
			}
			_mstyle=
			rm -f "$itmp"
			_parents="${_parents:+$_parents }-p $1"
			if [ $# -gt 1 ]; then
				newt="$(GIT_INDEX_FILE="$inew" git write-tree)" && [ -n "$newt" ] || { rm -f "$inew" "$imrg"; return 1; }
				rh="$newt"
				shift
				continue
			fi
			break;
		done
		if [ "$_mmode" != "merge" ]; then
			case "$_mmode" in
				theirs) _source="$oth";;
				remove) _source="";;
				     *) _source="$orh";;
			esac
			_newinfo=
			[ -z "$_source" ] ||
			_newinfo="$(git cat-file --batch-check="%(objecttype) %(objectname)$tab%(rest)" <<-EOT |
			$_source:.topdeps .topdeps
			$_source:.topmsg .topmsg
			EOT
			sed -n 's/^blob /100644 /p'
			)"
			[ -z "$_newinfo" ] || _newinfo="$lf$_newinfo"
			GIT_INDEX_FILE="$inew" git update-index --index-info <<-EOT || { rm -f "$inew" "$imrg"; return 1; }
			0 $nullsha$tab.topdeps
			0 $nullsha$tab.topmsg$_newinfo
			EOT
		fi
		newt="$(GIT_INDEX_FILE="$inew" git write-tree)" && [ -n "$newt" ] || { rm -f "$inew" "$imrg"; return 1; }
		[ -z "$_octo" ] || sort -u <"$imrg"
		rm -f "$inew" "$imrg"
		newc="$(git commit-tree -p "$orh" $_parents -m "$_msg" "$newt")" && [ -n "$newc" ] || return 1
		_mmsg="Merge made by the 'trivial aggressive$_auto${_octo:+ octopus}' strategy."
	fi
	case "$_var" in
	refs/?*)
		if [ -n "$_same" ]; then
			_same=
			if rv="$(git rev-parse --quiet --verify "$_var" --)" && [ "$rv"  = "$newc" ]; then
				_same=1
			fi
		fi
		if [ -z "$_same" ]; then
			detach_symref_head_on_branch "$_var" || return 1
			# git update-ref returns 0 even on failure :(
			git update-ref -m "$_msg" "$_var" "$newc" || return 1
		fi
		;;
	?*)
		eval "$_var="'"$newc"'
		;;
	esac
	echo "$_mmsg"
	[ -n "$_nodt" ] || git --no-pager diff-tree --shortstat "$orh" "$newc" -- $_exclusions
	return 0
}

# shortcut that passes $3 as a preceding argument (which must match refs/?*)
attempt_index_merge() {
	_noauto=
	_mmode=
	if [ "$1" = "--no-auto" ]; then
		_noauto="$1"
		shift
	fi
	if [ "$1" = "--merge" ] || [ "$1" = "--theirs" ] || [ "$1" = "--remove" ]; then
		_mmode="$1"
		shift
	fi
	case "$3" in refs/?*);;*)
		die "programmer error: invalid arguments to attempt_index_merge: $*"
	esac
	v_attempt_index_merge $_noauto $_mmode "$3" "$@"
}

on_base=
do_base_switch() {
	[ -n "$1" ] || return 0
	if
		[ "$1" != "$on_base" ] ||
		[ "$(git symbolic-ref -q HEAD)" != "refs/$topbases/$1" ]
	then
		switch_to_base "$1"
		on_base="$1"
	fi
}

update_branch_internal() {
	# We are cacheable until the first change
	become_cacheable

	_update_name="$1"
	## First, take care of our base

	_depcheck="$(get_temp tg-depcheck)"
	missing_deps=
	needs_update "$_update_name" >"$_depcheck" || :
	if [ -n "$missing_deps" ]; then
		msg="Some dependencies are missing: $missing_deps"
		if [ -n "$skipms" ]; then
			info "$msg; skipping"
		elif [ -z "$all" ]; then
			die "$msg"
		else
			info "$msg; skipping branch $_update_name"
			return 0
		fi
	fi
	# allow automatic simple merges by default until a failure occurs
	no_auto=
	if [ -s "$_depcheck" ]; then
		# (1) last word is $_update_name, remove it
		# (2) keep only immediate dependencies of a chain adding a leading '+'
		# (3) one-level deep dependencies get a '-' prefix instead
		<"$_depcheck" sed \
			-e 's/ [^ ]* *$//;        # (1)' \
			-e 's/.* \([^ ]*\)$/+\1/; # (2)' \
			-e 's/^\([^+]\)/-\1/;     # (3)' |
			# now each line is +branch or -branch (+ == recurse)
			>"$_depcheck.ideps" \
			uniq -s 1 # fold branch lines; + always comes before - and thus wins within uniq

		stash_now_if_requested

		while read -r depline; do
			dep="${depline#?}"
			action="${depline%$dep}"

			# We do not distinguish between dependencies out-of-date
			# and base/remote out-of-date cases for $dep here,
			# but thanks to needs_update returning : or :refs/remotes/...
			# for the latter, we do correctly recurse here
			# in both cases.

			if [ x"$action" = x+ ]; then
				case " $missing_deps " in *" $dep "*)
					info "Skipping recursing to missing dependency: $dep"
					continue
				esac
				info "Recursing to $dep..."
				recursive_update "$dep" || exit 3
			fi
		done <"$_depcheck.ideps"

		# Create a list of all the fully qualified ref names that need
		# to be merged into $_update_name's base.  This will be done
		# as an octopus merge if there are no conflicts.
		deplist=
		deplines=
		set --
		while read -r dep; do
			dep="${dep#?}"
			case "$dep" in
			:*)
				d="${dep#?}"
				set -- "$@" "$d"
				case "$d" in
				"refs/heads"/*)
					d="${d#refs/heads/}"
					deplist="${deplist:+$deplist }$d"
					deplines="$deplines$d$lf"
					;;
				*)
					d="${d#refs/}"
					deplist="${deplist:+$deplist }$d"
					deplines="$deplines$d$lf"
					;;
				esac
				;;
			*)
				set -- "$@" "refs/heads/$dep"
				deplist="${deplist:+$deplist }$dep"
				deplines="$deplines$dep$lf"
				;;
			esac
		done <"$_depcheck.ideps"

		# Make sure we end up on the correct base branch
		on_base=
		if [ $# -ge 2 ]; then
			info "Updating $_update_name base with deps: $deplist"
			become_non_cacheable
			msg="tgupdate: octopus merge $# deps into $_update_name base$lf$lf$deplines"
			if attempt_index_merge --remove -m "$msg" "refs/$topbases/$_update_name" "$@"; then
				set --
			else
				info "Octopus merge failed; falling back to multiple 3-way merges"
				no_auto="--no-auto"
			fi
		fi

		for fulldep in "$@"; do
			# This will be either a proper topic branch
			# or a remote base.  (branch_needs_update() is called
			# only on the _dependencies_, not our branch itself!)

			case "$fulldep" in
			"refs/heads"/*)
				dep="${fulldep#refs/heads/}";;
			"refs"/*)
				dep="${fulldep#refs/}";;
			*)
				dep="$fulldep";; # this should be a programmer error
			esac

			info "Updating $_update_name base with $dep changes..."
			become_non_cacheable
			msg="tgupdate: merge $dep into $_update_name base"
			if
				! attempt_index_merge $no_auto --remove -m "$msg" "refs/$topbases/$_update_name" "$fulldep^0" &&
				! {
					# We need to switch to the base branch
					# ...but only if we aren't there yet (from failed previous merge)
					do_base_switch "$_update_name" || die "do_base_switch failed" &&
					git_merge --remove --name "$_update_name base" --name "$dep" -m "$msg" "$fulldep^0"
				}
			then
				rm "$_depcheck"
				save_state
				unset TG_RECURSIVE
				info "Please commit merge resolution and call \`$tgdisplayac update --continue\`"
				info "(use \`$tgdisplayac status\` to see more options)"
				exit 3
			fi
		done
	else
		info "The base is up-to-date."
	fi


	## Second, update our head with the remote branch

	plusextra=
	merge_with="refs/$topbases/$_update_name"
	brmmode=
	if has_remote "$_update_name"; then
		_rname="refs/remotes/$base_remote/$_update_name"
		if branch_contains "refs/heads/$_update_name" "$_rname"; then
			info "The $_update_name head is up-to-date wrt. its remote branch."
		else
			stash_now_if_requested
			info "Reconciling $_update_name base with remote branch updates..."
			become_non_cacheable
			msg="tgupdate: merge ${_rname#refs/} onto $_update_name base"
			checkours=
			checktheirs=
			got_merge_with=
			brmmode="--merge"
			if [ -n "$mergeresult" ]; then
				checkours="$(git rev-parse --verify --quiet "refs/$topbases/$_update_name^0" --)" || :
				checktheirs="$(git rev-parse --verify --quiet "$_rname^0" --)" || :
				if [ "$mergeours" = "$checkours" ] && [ "$mergetheirs" = "$checktheirs" ]; then
					got_merge_with="$mergeresult"
				fi
			fi
			if
				[ -z "$got_merge_with" ] &&
				! v_attempt_index_merge $no_auto --theirs "merge_with" -m "$msg" "refs/$topbases/$_update_name" "$_rname^0" &&
				! {
					# *DETACH* our HEAD now!
					no_auto="--no-auto"
					git checkout -q --detach $iowopt "refs/$topbases/$_update_name" || die "git checkout failed" &&
					git_merge --theirs --name "$_update_name base content" --name "${_rname#refs/}" -m "$msg" "$_rname^0" &&
					merge_with="$(git rev-parse --verify HEAD --)"
				}
			then
				save_state \
					"$(git rev-parse --verify --quiet "refs/$topbases/$_update_name^0" --)" \
					"$(git rev-parse --verify --quiet "$_rname^0" --)"
				unset TG_RECURSIVE
				info "Please commit merge resolution and call \`$tgdisplayac update --continue\`"
				info "(use \`$tgdisplayac status\` to see more options)"
				exit 3
			fi
			# Go back but remember we want to merge with this, not base
			[ -z "$got_merge_with" ] || merge_with="$got_merge_with"
			plusextra="${_rname#refs/} + "
		fi
	fi


	## Third, update our head with the base

	if branch_contains "refs/heads/$_update_name" "$merge_with"; then
		info "The $_update_name head is up-to-date wrt. the base."
		return 0
	fi
	stash_now_if_requested
	info "Updating $_update_name against ${plusextra}new base..."
	become_non_cacheable
	msg="tgupdate: merge ${plusextra}$_update_name base into $_update_name"
	b4deps=
	if [ -n "$brmmode" ] && [ "$base_remote" ]; then
		b4deps="$(git rev-parse --verify --quiet "refs/heads/$_update_name:.topdeps" --)" && [ -n "$b4deps" ] ||
		b4deps="$(git hash-object -t blob -w --stdin </dev/null)"
	fi
	if
		! attempt_index_merge $no_auto $brmmode -m "$msg" "refs/heads/$_update_name" "$merge_with^0" &&
		! {
			# Home, sweet home...
			# (We want to always switch back, in case we were
			# on the base from failed previous merge.)
			git checkout -q $iowopt "$_update_name" || die "git checkout failed" &&
			git_merge $brmmode --name "$_update_name" --name "${plusextra}$topbases/$_update_name" -m "$msg" "$merge_with^0"
		}
	then
		no_auto=
		merging_topfiles="${brmmode:+1}"
		save_state
		unset TG_RECURSIVE
		info "Please commit merge resolution and call \`$tgdisplayac update --continue\`"
		info "(use \`$tgdisplayac status\` to see more options)"
		exit 3
	fi

	# Fourth, auto create locally any newly depended on branches we got from the remote

	_result=0
	if [ -n "$b4deps" ] &&
	   l8rdeps="$(git rev-parse --verify --quiet "refs/heads/$_update_name:.topdeps" --)" &&
	   [ -n "$l8rdeps" ] && [ "$b4deps" != "$l8rdeps" ]
	then
		_olddeps=
		while read -r newdep; do
			if [ -n "$newdep" ]; then
				if auto_create_local_remote "$newdep"; then
					_result=75
				else
					if ref_exists "refs/heads/$newdep"; then
						# maybe the line just moved around
						[ -n "$_olddeps" ] && [ -f "$_olddeps" ] || {
							_olddeps="$(get_temp b4deps)" &&
							git cat-file blob "$b4deps" >"$_olddeps"
						}
						if awk -v "newdep=$newdep" '$0 == newdep {exit 1}' <"$_olddeps"; then
							# nope, it's a new head already existing locally
							_result=75
						fi
					else
						# helpfully check to see if there's such a remote branch
						_rntgb=
						! ref_exists "refs/remotes/$base_remote/$newdep" || _rntgb=1
						# maybe a blocking local orphan base too
						_blocked=
						if [ -n "$_rntgb" ] &&
						   ref_exists "refs/remotes/$base_remote/${topbases#heads/}/$newdep" &&
						   ref_exists "refs/$topbases/$newdep"
						then
							_blocked=1
						fi
						# spew the flexibly adjustable warning
						warn "-------------------------------------"
						warn "MISSING DEPENDENCY MERGED FROM REMOTE"
						warn "-------------------------------------"
						warn "Local Branch: $_update_name"
						warn " Remote Name: $base_remote"
						warn "  Dependency: $newdep"
						if [ -n "$_blocked" ]; then
							warn "Blocking Ref: refs/$topbases/$newdep"
						elif [ -n "$_rntgb" ]; then
							warn "Existing Ref: refs/remotes/$base_remote/$newdep"
						fi
						warn ""
						if [ -n "$_blocked" ]; then
							warn "There is no local branch by that name, but"
							warn "there IS a remote TopGit branch available by"
							warn "that name, but creation of a local version has"
							warn "been blocked by existence of the ref shown above."
						elif [ -n "$_rntgb" ]; then
							warn "There is no local branch or remote TopGit"
							warn "branch available by that name, but there is an"
							warn "existing non-TopGit remote branch ref shown above."
							warn "Non-TopGit branches are not set up automatically"
							warn "by TopGit and must be maintained manually."
						else
							warn "There is no local branch or remote branch"
							warn "(TopGit or otherwise) available by that name."
						fi
						warn "-------------------------------------"
					fi
				fi
			fi
		done <<-EOT
		$(git diff --ignore-space-at-eol "$b4deps" "$l8rdeps" -- | diff_added_lines)
		EOT
	fi
	return $_result
}

update_branch() {
	_ubicode=0
	_maxdeploop=3
	update_branch_internal "$@" || _ubicode=$?
	while [ "$_maxdeploop" -gt 0 ] && [ "$_ubicode" = "75" ]; do
		_maxdeploop="$(( $maxdeploop - 1 ))"
		info "Updating $1 again with newly added dependencies..."
		_ubicode=0
		update_branch_internal "$@" || _ubicode=$?
	done
	return $_ubicode
}

# We are "read-only" and cacheable until the first change
tg_read_only=1
v_create_ref_cache

do_non_annihilated_branches_patterns() {
	while read -r _pat && [ -n "$_pat" ]; do
		set -- "$@" "$_pat"
	done
	non_annihilated_branches "$@"
}

do_non_annihilated_branches() {
	if [ -z "$pattern" ]; then
		non_annihilated_branches
	else
		do_non_annihilated_branches_patterns <<-EOT
		$(sed 'y/ /\n/' <<-LIST
		$pattern
		LIST
		)
		EOT
	fi
}

if [ -n "$all" ] && [ -z "$restored" ]; then
	names=
	while read name && [ -n "$name" ]; do
		case " $names " in *" $name "*);;*)
			names="${names:+$names }$name"
		esac
	done <<-EOT
		$(do_non_annihilated_branches)
	EOT
fi

for name in $names; do
	case " $processed " in *" $name "*) continue; esac
	[ -z "$all" ] && case "$names" in *" "*) ! :; esac || info "Proccessing $name..."
	update_branch "$name" || exit
	processed="${processed:+$processed }$name"
done

[ -z "$all" ] && case "$names" in *" "*) ! :; esac ||
info "Returning to ${current#refs/heads/}..."
checkout_symref_full "$current"
! [ -f "$git_dir/TGMERGE_MSG" ] || [ -e "$git_dir/MERGE_MSG" ] ||
	mv -f "$git_dir/TGMERGE_MSG" "$git_dir/MERGE_MSG" || :
ec=$?
tmpdir_cleanup || :
git gc --auto || :
exit $ec
