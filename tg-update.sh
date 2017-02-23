#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) Petr Baudis <pasky@suse.cz>  2008
# Copyright (C) Kyle J. McKay <mackyle@gmail.com>  2015,2016,2017
# All rights reserved.
# GPLv2

names= # Branch(es) to update
all= # Update all branches
pattern= # Branch selection filter for -a
current= # Branch we are currently on
skipms= # skip missing dependencies
stash= # tgstash refs before changes

if [ "$(git config --get --bool topgit.autostash 2>/dev/null)" != "false" ]; then
	# topgit.autostash is true
	stash=1
fi

## Parse options

USAGE="\
Usage: ${tgname:-tg} [...] update [--[no-]stash] [--skip-missing] ([<name>...] | -a [<pattern>...])
   Or: ${tgname:-tg} --continue | -skip | --stop | --abort"

usage()
{
	if [ "${1:-0}" != 0 ]; then
		printf '%s\n' "$USAGE" >&2
	else
		printf '%s\n' "$USAGE"
	fi
	exit ${1:-0}
}

state_dir="$git_dir/tg-update"
mergeours=
mergetheirs=
mergeresult=
stashhash=

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
if [ -n "$isactive" ] || [ $# -eq 1 -a x"$1" = x"--abort" ]; then
	[ $# -eq 1 ] && [ x"$1" != x"--status" ] || { do_status; exit 0; }
	case "$1" in
	--abort)
		current=
		stashhash=
		if [ -n "$isactive" ]; then
			IFS= read -r current <"$state_dir/current" || :
			IFS= read -r stashhash <"$state_dir/stashhash" || :
		fi
		clear_state
		if [ -n "$isactive" ]; then
			if [ -n "$stashhash" ]; then
				$tg revert -f -q -q --no-stash "$stashhash" >/dev/null 2>&1 || :
			fi
			if [ -n "$current" ]; then
				info "Ok, update aborted, returning to $current"
				git checkout -f -q "$current"
			else
				info "Ok, update aborted.  Now, you just need to"
				info "switch back to some sane branch using \`git$gitcdopt checkout\`."
			fi
			! [ -f "$git_dir/TGMERGE_MSG" ] || [ -e "$git_dir/MERGE_MSG" ] ||
				mv -f "$git_dir/TGMERGE_MSG" "$git_dir/MERGE_MSG" || :
		else
			info "No update was active"
		fi
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
		git checkout -q "$(strip_ref "$name")"
		;;
	*)
		do_status
		exit 1
	esac
fi
clear_state

if [ -z "$restored" ]; then
	while [ -n "$1" ]; do
		arg="$1"; shift
		case "$arg" in
		-a|--all)
			[ -z "$names$pattern" ] || usage 1
			all=1;;
		--skip-missing)
			skipms=1;;
		--stash)
			stash=1;;
		--no-stash)
			stash=;;
		-h)
			usage;;
		-*)
			usage 1;;
		*)
			if [ -z "$all" ]; then
				names="${names:+$names }$arg"
			else
				pattern="${pattern:+$pattern }refs/$topbases/$(strip_ref "$arg")"
			fi
			;;
		esac
	done
	origpattern="$pattern"
	[ -z "$pattern" ] && pattern="refs/$topbases"

	processed=
	current="$(strip_ref "$(git symbolic-ref -q HEAD)")" || :
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
	else
		[ -n "$current" ] || die "cannot return to detached HEAD; switch to another branch"
		[ -n "$(git rev-parse --verify --quiet HEAD --)" ] ||
			die "cannot return to unborn branch; switch to another branch"
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
		$tg tag -q -q -m "$msg" --stash "$@"  &&
		stashhash="$(git rev-parse --quiet --verify refs/tgstash --)" &&
		[ -n "$stashhash" ] &&
		[ "$(git cat-file -t "$stashhash" -- 2>/dev/null)" = "tag" ] ||
		die "requested --stash failed"
	else
		$tg tag --anonymous "$@" &&
		stashhash="$(git rev-parse --quiet --verify TG_STASH --)" &&
		[ -n "$stashhash" ] &&
		[ "$(git cat-file -t "$stashhash" -- 2>/dev/null)" = "tag" ] ||
		die "anonymous --stash failed"
	fi
}

recursive_update() {
	_ret=0
	on_base=
	(
		TG_RECURSIVE="[$1] $TG_RECURSIVE"
		PS1="[$1] $PS1"
		export PS1
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

# run git merge with the passed in arguments AND --no-stat
# return the exit status of git merge
# if the returned exit status is no error show a shortstat before
# returning assuming the merge was done into the previous HEAD
git_merge() {
	_oldhead="$(git rev-parse --verify HEAD^0)"
	_ret=0
	git merge $auhopt --no-stat "$@" || _ret=$?
	[ "$_ret" != "0" ] || git --no-pager diff-tree --shortstat "$_oldhead" HEAD^0 --
	return $_ret
}

# similar to git_merge but operates exclusively using a separate index and temp dir
# only trivial aggressive automatic (i.e. simple) merges are supported
#
# [optional] '--no-auto' to suppress "automatic" merging, merge fails instead
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
	[ "$#" -ge 5 ] && [ "$2" = "-m" ] && [ -n "$3" ] && [ -n "$4" ] && [ -n "$5" ] ||
		die "programmer error: invalid arguments to v_attempt_index_merge: $*"
	_var="$1"
	_msg="$3"
	_head="$4"
	shift 4
	rh="$(git rev-parse --quiet --verify "$_head^0" --)" && [ -n "$rh" ] || return 1
	orh="$rh"
	_mmsg=
	newc=
	_nodt=
	_same=
	_mt=
	_octo=
	if [ $# -gt 1 ]; then
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
					_mmsg="Fast-forward (no commit created)"
					rh="$1"
					shift
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
			set -- "$r1"
			if [ "$rh" = "$mb" ]; then
				_mmsg="Fast-forward (no commit created)"
				newc="$r1"
				_nodt=1
			elif [ "$r1" = "$mb" ]; then
				[ -n "$_mmsg" ] || _mmsg="Already up-to-date!"
				newc="$rh"
				_nodt=1
				_same=1
			fi
		fi
	fi
	if [ -z "$newc" ]; then
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
				if [ "$(git rev-list --count --max-count=1 "$1" --not "$_newrh" --)" = "0" ]; then
					shift
					continue
				fi
			fi
			GIT_INDEX_FILE="$inew" git read-tree -m --aggressive -i "$mb" "$rh" "$1" || { rm -f "$inew" "$imrg"; return 1; }
			GIT_INDEX_FILE="$inew" git ls-files --unmerged --full-name --abbrev :/ >"$itmp" 2>&1 || { rm -f "$inew" "$itmp" "$imrg"; return 1; }
			! [ -s "$itmp" ] || {
				if ! GIT_INDEX_FILE="$inew" TG_TMP_DIR="$tg_tmp_dir" git merge-index -q "$TG_INST_CMDDIR/tg--index-merge-one-file" -a >"$itmp" 2>&1; then
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
			rm -f "$itmp"
			newt="$(GIT_INDEX_FILE="$inew" git write-tree)" && [ -n "$newt" ] || { rm -f "$inew" "$imrg"; return 1; }
			_parents="${_parents:+$_parents }-p $1"
			if [ $# -gt 1 ]; then
				rh="$newt"
				shift
				continue
			fi
			break;
		done
		[ -z "$_octo" ] || LC_ALL=C sort -u <"$imrg"
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
	[ -n "$_nodt" ] || git --no-pager diff-tree --shortstat "$orh" "$newc" --
	return 0
}

# shortcut that passes $3 as a preceding argument (which must match refs/?*)
attempt_index_merge() {
	_noauto=
	if [ "$1" = "--no-auto" ]; then
		_noauto="$1"
		shift
	fi
	case "$3" in refs/?*);;*)
		die "programmer error: invalid arguments to attempt_index_merge: $*"
	esac
	v_attempt_index_merge $_noauto "$3" "$@"
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

update_branch() {
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
			return
		fi
	fi
	if [ -s "$_depcheck" ]; then
		<"$_depcheck" \
			sed 's/ [^ ]* *$//' | # last is $_update_name
			sed 's/.* \([^ ]*\)$/+\1/' | # only immediate dependencies
			sed 's/^\([^+]\)/-\1/' | # now each line is +branch or -branch (+ == recurse)
			>"$_depcheck.ideps" \
			uniq -s 1 # fold branch lines; + always comes before - and thus wins within uniq

		stash_now_if_requested

		while read -r depline; do
			dep="${depline#?}"
			action="${depline%$dep}"

			# We do not distinguish between dependencies out-of-date
			# and base/remote out-of-date cases for $dep here,
			# but thanks to needs_update returning : or refs/remotes/<remote>/<name>
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
			"refs"/*)
				set -- "$@" "$dep"
				case "$dep" in
				"refs/heads"/*)
					d="${dep#refs/heads/}"
					deplist="${deplist:+$deplist }$d"
					deplines="$deplines$d$lf"
					;;
				*)
					d="${dep#refs/}"
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
		no_auto=
		if [ $# -ge 2 ]; then
			info "Updating $_update_name base with deps: $deplist"
			become_non_cacheable
			msg="tgupdate: octopus merge $# deps into $topbases/$_update_name$lf$lf$deplines"
			if attempt_index_merge -m "$msg" "refs/$topbases/$_update_name" "$@"; then
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
			msg="tgupdate: merge $dep into $topbases/$_update_name"
			if
				! attempt_index_merge $no_auto -m "$msg" "refs/$topbases/$_update_name" "$fulldep^0" &&
				! {
					# We need to switch to the base branch
					# ...but only if we aren't there yet (from failed previous merge)
					do_base_switch "$_update_name" || die "do_base_switch failed" &&
					git_merge -m "$msg" "$fulldep^0"
				}
			then
				rm "$_depcheck"
				save_state
				info "Please commit merge resolution and call \`$tgdisplay update --continue\`"
				info "(use \`$tgdisplay status\` to see more options)"
				exit 3
			fi
		done
	else
		info "The base is up-to-date."
	fi


	## Second, update our head with the remote branch

	plusextra=
	merge_with="refs/$topbases/$_update_name"
	if has_remote "$_update_name"; then
		_rname="refs/remotes/$base_remote/$_update_name"
		if branch_contains "refs/heads/$_update_name" "$_rname"; then
			info "The $_update_name head is up-to-date wrt. its remote branch."
		else
			stash_now_if_requested
			info "Reconciling $_update_name base with remote branch updates..."
			become_non_cacheable
			msg="tgupdate: merge ${_rname#refs/} onto $topbases/$_update_name"
			checkours=
			checktheirs=
			got_merge_with=
			if [ -n "$mergeresult" ]; then
				checkours="$(git rev-parse --verify --quiet "refs/$topbases/$_update_name^0" --)" || :
				checktheirs="$(git rev-parse --verify --quiet "$_rname^0" --)" || :
				if [ "$mergeours" = "$checkours" ] && [ "$mergetheirs" = "$checktheirs" ]; then
					got_merge_with="$mergeresult"
				fi
			fi
			if
				[ -z "$got_merge_with" ] &&
				! v_attempt_index_merge "merge_with" -m "$msg" "refs/$topbases/$_update_name" "$_rname^0" &&
				! {
					# *DETACH* our HEAD now!
					git checkout -q --detach "refs/$topbases/$_update_name" || die "git checkout failed" &&
					git_merge -m "$msg" "$_rname^0" &&
					merge_with="$(git rev-parse --verify HEAD --)"
				}
			then
				save_state \
					"$(git rev-parse --verify --quiet "refs/$topbases/$_update_name^0" --)" \
					"$(git rev-parse --verify --quiet "$_rname^0" --)"
				info "Please commit merge resolution and call \`$tgdisplay update --continue\`"
				info "(use \`$tgdisplay status\` to see more options)"
				exit 3
			fi
			# Go back but remember we want to merge with this, not base
			[ -z "$got_merge_with" ] || merge_with="$got_merge_with"
			plusextra="${_rname#refs/}+"
		fi
	fi


	## Third, update our head with the base

	if branch_contains "refs/heads/$_update_name" "$merge_with"; then
		info "The $_update_name head is up-to-date wrt. the base."
		return 0
	fi
	stash_now_if_requested
	info "Updating $_update_name against new base..."
	become_non_cacheable
	msg="tgupdate: merge ${plusextra}$topbases/$_update_name into $_update_name"
	if
		! attempt_index_merge -m "$msg" "refs/heads/$_update_name" "$merge_with^0" &&
		! {
			# Home, sweet home...
			# (We want to always switch back, in case we were
			# on the base from failed previous merge.)
			git checkout -q "$_update_name" || die "git checkout failed" &&
			git_merge -m "$msg" "$merge_with^0"
		}
	then
		save_state
		info "Please commit merge resolution and call \`$tgdisplay update --continue\`"
		info "(use \`$tgdisplay status\` to see more options)"
		exit 3
	fi
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
info "Returning to $current..."
git checkout -q "$current"
! [ -f "$git_dir/TGMERGE_MSG" ] || [ -e "$git_dir/MERGE_MSG" ] ||
	mv -f "$git_dir/TGMERGE_MSG" "$git_dir/MERGE_MSG" || :
