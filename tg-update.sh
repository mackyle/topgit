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

if [ "$(git config --get --bool topgit.autostash 2>/dev/null || :)" = "true" ]; then
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
			pattern="${pattern:+$pattern }refs/top-bases/${arg#refs/top-bases/}"
		fi
		;;
	esac
done
origpattern="$pattern"
[ -z "$pattern" ] && pattern=refs/top-bases

current="$(strip_ref "$(git symbolic-ref -q HEAD || :)")"
if [ -z "$all" ]; then
	name="$(verify_topgit_branch "${name:-HEAD}")"
else
	[ -n "$current" ] || die "cannot return to detached tree; switch to another branch"
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
	$tg tag --quiet -m "$msg" --stash "$stashb" || die "requested --stash failed"
	stash=
}

recursive_update() {
	$tg update ${skip:+--skip}
	_ret=$?
	[ $_ret -eq 3 ] && exit 3
	return $_ret
}

# run git merge with the passed in arguments AND --no-stat
# return the exit status of git merge
# if the returned exit status is no error show a shortstat before
# returning assuming the merge was done into the previous HEAD
git_merge() {
	_oldhead="$(git rev-parse --verify HEAD^0)"
	_ret=0
	git merge $auhopt --no-stat "$@" || _ret=$?
	[ "$_ret" != "0" ] || git --no-pager diff --shortstat "$_oldhead" HEAD^0 --
	return $_ret
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
		stash_now_if_requested
		# We need to switch to the base branch
		# ...but only if we aren't there yet (from failed previous merge)
		_HEAD="$(git symbolic-ref -q HEAD || :)"
		if [ "$_HEAD" = "${_HEAD#refs/top-bases/}" ]; then
			switch_to_base "$_update_name"
		fi

		cat "$_depcheck" |
			sed 's/ [^ ]* *$//' | # last is $_update_name
			sed 's/.* \([^ ]*\)$/+\1/' | # only immediate dependencies
			sed 's/^\([^+]\)/-\1/' | # now each line is +branch or -branch (+ == recurse)
			uniq -s 1 | # fold branch lines; + always comes before - and thus wins within uniq
			while read depline; do
				dep="${depline#?}"
				action="${depline%$dep}"
				become_non_cacheable

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
					git checkout -q "$dep"
					(
					TG_RECURSIVE="[$dep] $TG_RECURSIVE"
					PS1="[$dep] $PS1"
					export TG_RECURSIVE
					export PS1
					while ! recursive_update; do
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
					)
					check_exit_code
					switch_to_base "$_update_name"
				fi

				# This will be either a proper topic branch
				# or a remote base.  (branch_needs_update() is called
				# only on the _dependencies_, not our branch itself!)

				info "Updating $_update_name base with $dep changes..."
				case "$dep" in refs/*) fulldep="$dep";; *) fulldep="refs/heads/$dep"; esac
				if ! git_merge -m "tgupdate: merge ${dep#refs/} into top-bases/$_update_name" "$fulldep^0"; then
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
		check_exit_code
	else
		info "The base is up-to-date."
	fi

	# Home, sweet home...
	# (We want to always switch back, in case we were on the base from failed
	# previous merge.)
	git checkout -q "$_update_name"

	merge_with="refs/top-bases/$_update_name"


	## Second, update our head with the remote branch

	plusextra=
	if has_remote "$_update_name"; then
		_rname="refs/remotes/$base_remote/$_update_name"
		if branch_contains "refs/heads/$_update_name" "$_rname"; then
			info "The $_update_name head is up-to-date wrt. its remote branch."
		else
			stash_now_if_requested
			info "Reconciling $_update_name base with remote branch updates..."
			become_non_cacheable
			# *DETACH* our HEAD now!
			git checkout -q --detach "refs/top-bases/$_update_name"
			if ! git_merge -m "tgupdate: merge ${_rname#refs/} onto top-bases/$_update_name" "$_rname^0"; then
				info "Oops, you will need to help me out here a bit."
				info "Please commit merge resolution and call:"
				info "git$gitcdopt checkout $_update_name && git$gitcdopt merge <commitid>"
				info "It is also safe to abort this operation using: git$gitcdopt reset --hard $_update_name"
				exit 4
			fi
			# Go back but remember we want to merge with this, not base
			merge_with="$(git rev-parse --verify HEAD --)"
			plusextra="${_rname#refs/}+"
			git checkout -q "$_update_name"
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
	if ! git_merge -m "tgupdate: merge ${plusextra}top-bases/$_update_name into $_update_name" "$merge_with^0"; then
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
create_ref_cache

[ -z "$all" ] && { update_branch $name; exit; }

while read name && [ -n "$name" ]; do
	info "Proccessing $name..."
	update_branch "$name" || exit
done <<-EOT
	$(non_annihilated_branches $pattern)
EOT

info "Returning to $current..."
git checkout -q "$current"
# vim:noet
