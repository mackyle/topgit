#!/bin/sh
# TopGit merging utility functions
# Copyright (C) 2015,2016,2017,2018,2019,2021 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved
# License GPLv2

# git_topmerge will need this even on success and since it might otherwise
# be called many times do it just the once here and now
ensure_work_tree
v_get_show_toplevel repotoplvl

# If HEAD is a symref to "$1" detach it at its current value
detach_symref_head_on_branch() {
	_hsr="$(git symbolic-ref -q HEAD --)" && [ -n "$_hsr" ] || return 0
	_hrv="$(git rev-parse --quiet --verify HEAD --)" && [ -n "$_hrv" ] ||
		die "cannot detach_symref_head_on_branch from unborn branch $_hsr"
	git update-ref --no-deref -m "detaching HEAD from $_hsr to safely update it" HEAD "$_hrv"
}

# Run an in-tree recursive merge but make sure we get the desired version of
# any .topdeps and .topmsg files.  The $auhopt and --no-stat options are
# always implicitly in effect.  If successful, a new commit is performed on HEAD
# unless the optional --no-commit option has been given.
#
# The "git merge-recursive" tool (and others) must be run to get the desired
# result.  And --no-ff is always implicitly in effect as well.
#
# NOTE: [optional] arguments MUST appear in the order shown
# [optional] '-v' varname => optional variable to return original HEAD hash in
# [optional] '--no-commit' => update worktree and index but do not commit
# [optional] '--merge', '--theirs' or '--remove' to alter .topfile handling
# [optional] '--name' <name-for-ours> [--name <name-for-theirs>]
# $1 => '-m' MUST be '-m'
# $2 => commit message
# $3 => commit-ish to merge as "theirs"
git_topmerge()
{
	_ovar=
	[ "$1" != "-v" ] || [ $# -lt 2 ] || [ -z "$2" ] || { _ovar="$2"; shift 2; }
	_ncmode=
	[ "$1" != "--no-commit" ] || { _ncmode=1; shift; }
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
	{ _mt=1; _mb="$(git mktree < /dev/null)"; }
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
			# Since Git v2.30.1, even with "-q" checkout-index can spuriously fail!
			# It must only be called with the names of files actually in the index to avoid that.
			idxtopfiles="$(git ls-files --full-name -- :/.topdeps :/.topmsg)" || :
			[ -z "$idxtopfiles" ] ||
			(cd "$repotoplvl" && git checkout-index -q -f -u -- $idxtopfiles) ||
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
	if [ -n "$_ncmode" ]; then
		# merge succeeded, but --no-commit requested, enter "merge" mode and return
		printf '%s\n' "$_msg" >"$git_dir/MERGE_MSG"
		git update-ref MERGE_HEAD "$_theirs" || :
		echo 'Automatic merge went well; stopped before committing as requested.'
		rm -f "$tmpstdout"
		return $_ret
	fi
	# commit time at last!
	thetree="$(git write-tree)" || die "git write-tree failed"
	# avoid an extra "already up-to-date" commit (can't happen if _mt though)
	origtree=
	[ -n "$_mt" ] || {
		origtree="$(git rev-parse --quiet --verify "$_ours^{tree}" --)" &&
		[ -n "$origtree" ]
	} || die "git rev-parse failed"
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
	if [ "$1" != "--no-commit" ] && [ "$_ret" = "0" ]; then
		_exclusions=
		[ "$1" = "--merge" ] || _exclusions=":/ :!/.topdeps :!/.topmsg"
		git --no-pager diff-tree --shortstat "$_oldhead" HEAD^0 -- $_exclusions
	fi
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
		mb="$(git mktree < /dev/null)"
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
