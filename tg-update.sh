#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) Petr Baudis <pasky@suse.cz>  2008
# Copyright (C) Kyle J. McKay <mackyle@gmail.com>  2015,2016
# All rights reserved.
# GPLv2

name= # Branch to update
all= # Update all branches
pattern= # Branch selection filter for -a
current= # Branch we are currently on
skip= # skip missing dependencies
stash= # tgstash refs before changes

if [ "$(git config --get --bool topgit.autostash 2>/dev/null)" != "false" ]; then
	# topgit.autostash is true
	stash=1
fi

## Parse options

while [ -n "$1" ]; do
	arg="$1"; shift
	case "$arg" in
	-a|--all)
		all=1;;
	--skip)
		skip=1;;
	--stash)
		stash=1;;
	--no-stash)
		stash=;;
	-*)
		echo "Usage: ${tgname:-tg} [...] update [--[no-]stash] [--skip] ([<name>] | -a [<pattern>...])" >&2
		exit 1;;
	*)
		if [ -z "$all" ]; then
			[ -z "$name" ] || die "name already specified ($name)"
			name="$arg"
		else
			pattern="${pattern:+$pattern }refs/$topbases/$(strip_ref "$arg")"
		fi
		;;
	esac
done
origpattern="$pattern"
[ -z "$pattern" ] && pattern="refs/$topbases"

current="$(strip_ref "$(git symbolic-ref -q HEAD)")" || :
if [ -z "$all" ]; then
	name="$(verify_topgit_branch "${name:-HEAD}")"
else
	[ -n "$current" ] || die "cannot return to detached HEAD; switch to another branch"
	[ -n "$(git rev-parse --verify --quiet HEAD --)" ] ||
		die "cannot return to unborn branch; switch to another branch"
fi

ensure_clean_tree

stash_now_if_requested() {
	[ -z "$TG_RECURSIVE" ] || return 0
	ensure_ident_available
	[ -n "$stash" ] || return 0
	msg="tgupdate: autostash before update"
	if [ -n "$all" ]; then
		msg="$msg --all${origpattern:+ $origpattern}"
		stashb="--all"
	else
		msg="$msg $name"
		stashb="$name"
	fi
	$tg tag -q -q -m "$msg" --stash "$stashb" || die "requested --stash failed"
	stash=
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
# $1 => '' to discard result, 'refs/?*' to update the specified ref or a varname
# $2 => '-m' MUST be '-m'
# $3 => commit message AND, if $1 matches refs/?* the update-ref message
# $4 => commit-ish to merge as "ours"
# $5 => commit-ish to merge as "theirs"
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
	[ "$#" -eq 5 ] && [ "$2" = "-m" ] && [ -n "$3" ] && [ -n "$4" ] && [ -n "$5" ] ||
		die "programmer error: invalid arguments to v_attempt_index_merge: $*"
	_var="$1"
	_msg="$3"
	_head="$4"
	shift 4
	_mmsg=
	newc=
	_nodt=
	_same=
	rh="$(git rev-parse --quiet --verify "$_head^0" --)" && [ -n "$rh" ] || return 1
	if mb="$(git merge-base "$_head" "$1")" && [ -n "$mb" ]; then
		r1="$(git rev-parse --quiet --verify "$1^0" --)" && [ -n "$r1" ] || return 1
		if [ "$rh" = "$mb" ]; then
			_mmsg="Fast-forward (no commit created)"
			newc="$r1"
			_nodt=1
		elif [ "$r1" = "$mb" ]; then
			_mmsg="Already up-to-date!"
			newc="$rh"
			_nodt=1
			_same=1
		fi
	else
		mb="$(git hash-object -w -t tree --stdin < /dev/null)"
	fi
	if [ -z "$newc" ]; then
		inew="$tg_tmp_dir/index.$$"
		itmp="$tg_tmp_dir/output.$$"
		! [ -e "$inew" ] || rm -f "$inew"
		GIT_INDEX_FILE="$inew" git read-tree -m --aggressive -i "$mb" "$_head" "$1" || { rm -f "$inew"; return 1; }
		GIT_INDEX_FILE="$inew" git ls-files --unmerged --full-name --abbrev :/ >"$itmp" 2>&1 || { rm -f "$inew" "$itmp"; return 1; }
		_auto=
		! [ -s "$itmp" ] || {
			if ! GIT_INDEX_FILE="$inew" TG_TMP_DIR="$tg_tmp_dir" git merge-index -q "$TG_INST_CMDDIR/tg--index-merge-one-file" -a >"$itmp" 2>&1; then
				rm -f "$inew" "$itmp"
				return 1
			fi
			if [ -s "$itmp" ]; then
				cat "$itmp"
				_auto=" automatic"
			fi
		}
		rm -f "$itmp"
		newt="$(GIT_INDEX_FILE="$inew" git write-tree)" && [ -n "$newt" ] || { rm -f "$inew"; return 1; }
		rm -f "$inew"
		newc="$(git commit-tree -p "$_head" -p "$1" -m "$_msg" "$newt")" && [ -n "$newc" ] || return 1
		_mmsg="Merge made by the 'trivial aggressive$_auto' strategy."
	fi
	case "$_var" in
	refs/?*)
		if [ -n "$_same" ]; then
			_same=
			if rv="$(git rev-parse --quiet --verify "$_var" --)" && [ "$rv"  = "$newc" ]; then
				_same=1
			fi
		fi
		if [ -z "$_same" ] ; then
			detach_symref_head_on_branch "$_head" || return 1
			# git update-ref returns 0 even on failure :(
			git update-ref -m "$_msg" "$_var" "$newc" || return 1
		fi
		;;
	?*)
		eval "$_var="'"$newc"'
		;;
	esac
	echo "$_mmsg"
	[ -n "$_nodt" ] || git --no-pager diff-tree --shortstat "$rh" "$newc" --
	return 0
}

# shortcut that passes $3 as a preceding argument (which must match refs/?*)
attempt_index_merge() {
	case "$3" in refs/?*);;*)
		die "programmer error: invalid arguments to attempt_index_merge: $*"
	esac
	v_attempt_index_merge "$3" "$@"
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
		if [ -n "$skip" ]; then
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
				while ! recursive_update "$dep"; do
					# The merge got stuck! Let the user fix it up.
					info "You are in a subshell. If you abort the merge,"
					info "use \`exit 1\` to abort the recursive update altogether."
					info "Use \`exit 2\` to skip updating this branch and continue."
					if "${SHELL:-@SHELL_PATH@}" -i </dev/tty; then
						# assume user fixed it
						# we could be left on a detached HEAD if we were resolving
						# a conflict while merging a base in, fix it with a checkout
						git checkout -q "$(strip_ref "$dep")"
						continue
					else
						ret=$?
						if [ $ret -eq 2 ]; then
							info "Ok, I will try to continue without updating this branch."
							break
						else
							info "Ok, you aborted the merge. Now, you just need to"
							info "switch back to some sane branch using \`git$gitcdopt checkout\`."
							exit 3
						fi
					fi
				done
			fi
		done <"$_depcheck.ideps"

		# Create a list of all the fully qualified ref names that need
		# to be merged into $_update_name's base.  This could be done
		# as an octopus merge if there are no conflicts...
		set --
		while read -r dep; do
			dep="${dep#?}"
			case "$dep" in
			"refs"/*)
				set -- "$@" "$dep";;
			*)
				set -- "$@" "refs/heads/$dep";;
			esac
		done <"$_depcheck.ideps"

		# Make sure we end up on the correct base branch
		on_base=

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
				! attempt_index_merge -m "$msg" "refs/$topbases/$_update_name" "$fulldep^0" &&
				! {
					# We need to switch to the base branch
					# ...but only if we aren't there yet (from failed previous merge)
					do_base_switch "$_update_name" || die "do_base_switch failed" &&
					git_merge -m "$msg" "$fulldep^0"
				}
			then
				if [ -z "$TG_RECURSIVE" ]; then
					resume="\`$tgdisplay update${skip:+ --skip} $_update_name\` again"
				else # subshell
					resume='exit'
				fi
				info "Please commit merge resolution and call $resume."
				info "It is also safe to abort this operation using \`git$gitcdopt reset --hard\`,"
				info "but please remember that you are on the base branch now;"
				info "you will want to switch to some normal branch afterwards."
				rm "$_depcheck"
				exit 2
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
			if
				! v_attempt_index_merge "merge_with" -m "$msg" "refs/$topbases/$_update_name" "$_rname^0" &&
				! {
					# *DETACH* our HEAD now!
					git checkout -q --detach "refs/$topbases/$_update_name" || die "git checkout failed" &&
					git_merge -m "$msg" "$_rname^0" &&
					merge_with="$(git rev-parse --verify HEAD --)"
				}
			then
				info "Oops, you will need to help me out here a bit."
				info "Please commit merge resolution and call:"
				info "git$gitcdopt checkout $_update_name && git$gitcdopt merge <commitid>"
				info "It is also safe to abort this operation using: git$gitcdopt reset --hard $_update_name"
				exit 4
			fi
			# Go back but remember we want to merge with this, not base
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
		if [ -z "$TG_RECURSIVE" ]; then
			info "Please commit merge resolution. No need to do anything else"
			info "You can abort this operation using \`git$gitcdopt reset --hard\` now"
			info "and retry this merge later using \`$tgdisplay update${skip:+ --skip}\`."
		else # subshell
			info "Please commit merge resolution and call exit."
			info "You can abort this operation using \`git$gitcdopt reset --hard\`."
		fi
		exit 4
	fi
}

# We are "read-only" and cacheable until the first change
tg_read_only=1
v_create_ref_cache

[ -z "$all" ] && { update_branch "$name" && git checkout -q "$name"; exit; }

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

while read name && [ -n "$name" ]; do
	info "Proccessing $name..."
	update_branch "$name" || exit
done <<-EOT
	$(do_non_annihilated_branches)
EOT

info "Returning to $current..."
git checkout -q "$current"
# vim:noet
