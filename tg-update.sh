#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) Petr Baudis <pasky@suse.cz>  2008
# Copyright (C) Kyle J. McKay <mackyle@gmail.com>  2015,2016,2017,2018,2019
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
   Or: ${tgname:-tg} [...] update --continue | --skip | --stop | --abort"

usage()
{
	if [ "${1:-0}" != 0 ]; then
		printf '%s\n' "$USAGE" >&2
	else
		printf '%s\n' "$USAGE"
	fi
	exit ${1:-0}
}

# Remove any currently untracked files that also appear in
# $1's tree AND have an identical blob hash.  Never fail, but
# instead simply ignore any operations with problems.
clear_matching_untracked() {
	_cmutree="$(git rev-parse --verify "$1^{tree}" 2>/dev/null)" &&
	[ -n "$_cmutree" ] || return 0
	_idxtree="$(git write-tree 2>/dev/null)" &&
	[ -n "$_idxtree" ] || return 0
	v_get_show_toplevel _tplvl
	# Save the list of untracked files in a temp file, then feed the
	# "A" file lines from diff-tree index to the tree to an awk script
	# along with the list of untracked files and let it spit out
	# a list of blob matches which includes the file mode of the match
	# and then remove any untracked files with a matching hash and mode.
	# Due to limitations of awk, files with '\n' in their names are skipped.
	_utfl="$(get_temp untracked)" || return 0
	_hvrl=1
	command -v readlink >/dev/null 2>&1 || _hvrl=
	git status --porcelain -z | tr '\n\000' '\177\n' | awk '!/^\?\? ./||/\177/{next}{print}' >"$_utfl" || :
	saveIFS="$IFS"
	IFS=" "
	git diff-tree --raw --ignore-submodules=all --no-renames -r -z --diff-filter=A "$_idxtree" "$_cmutree" |
	tr '\n\000' '\177\n' | paste - - | awk -v u="$_utfl" '
		BEGIN {x=""}
		function exitnow(c) {x=c;exit x}
		END {if(x!="")exit x}
		function init(e,l) {
			while ((e=(getline l<u))>0) {
				if(l!~/^\?\? ./||l~/\177/)continue
				f[substr(l,4)]=1
			}
			close(u)
		}
		BEGIN {if(u=="")exitnow(2);init()}
		NF<5||/\177/{next}
		{
			if($1!=":000000"||($2!="100644"&&$2!="100755"&&$2!="120000")||
			   $3!~/^0+$/||$4!~/^[0-9a-f][0-9a-f][0-9a-f][0-9a-f]+$/||
			   $5!="A")next
			t=$0;sub(/^[^\t]*\t/,"",t)
			if(t!=""&&f[t])print $4" "$2" "t
		}
	' |
	while read -r _uthsh _utmod _utnam && [ -n "$_utnam" ] && [ -n "$_uthsh" ]; do
		case "$_utmod" in "100644"|"100755"|"120000");;*) continue; esac
		if
			[ -L "$_tplvl/$_utnam" ] ||
			[ -f "$_tplvl/$_utnam" ]
		then
			case "$_utmod" in
			"100644") test ! -L "$_tplvl/$_utnam" &&
				  test ! -x "$_tplvl/$_utnam" || continue;;
			"100755") test ! -L "$_tplvl/$_utnam" &&
				  test -x "$_tplvl/$_utnam" || continue;;
			"120000") test -n "$_hvrl" &&
				  test -L "$_tplvl/$_utnam" || continue;;
			*) ! :;;
			esac &&
			case "$_utmod" in
			"100644"|"100755") _flhsh="$(git hash-object -t blob -- "$_tplvl/$_utnam")";;
			"120000") _flhsh="$(readlink -n "$_tplvl/$_utnam" 2>/dev/null |
					    git hash-object -t blob --stdin)";;
			*) ! :;;
			esac &&
			[ "$_flhsh" = "$_uthsh" ] || continue
			rm -f "$_tplvl/$_utnam" >/dev/null 2>&1 || :
		fi
	done || :
	IFS="$saveIFS"
	return 0
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
	v_ref_exists_rev baserev "refs/$topbases/$tgbranch" && [ -n "$baserev" ] ||
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
		[ "$(git cat-file -t "$stashhash" 2>/dev/null)" = "tag" ] ||
		die "requested --stash failed"
	else
		tg tag --anonymous "$tgbranch" &&
		stashhash="$(git rev-parse --quiet --verify TG_STASH --)" &&
		[ -n "$stashhash" ] &&
		[ "$(git cat-file -t "$stashhash" 2>/dev/null)" = "tag" ] ||
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
	ec=0
	if [ -z "$basenc" ]; then
		clear_matching_untracked "$current"
		checkout_symref_full "$current" || ec=$?
		tmpdir_cleanup || :
		if [ "${ec:-0}" != "0" ]; then
			info "Unable to switch to ${current#refs/heads/}"
			if
				git rev-parse -q --verify HEAD >/dev/null 2>&1 &&
				! git symbolic-ref -q HEAD >/dev/null 2>&1
			then
				info "HEAD is currently detached"
				info "Use 'git checkout ${current#refs/heads/}' to reattach"
			fi
		fi
	fi
	exit ${ec:-0}
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
		v_strip_ref bname "$name"
		git checkout -q $iowopt "$bname"
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
				v_strip_ref arg "$arg"
				pattern="${pattern:+$pattern }refs/$topbases/$arg"
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
			v_strip_ref arg "$1"
			pattern="${pattern:+$pattern }refs/$topbases/$arg"
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
				v_verify_topgit_branch name "$1"
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
		[ "$(git cat-file -t "$stashhash" 2>/dev/null)" = "tag" ] ||
		die "requested --stash failed"
	else
		tg tag --anonymous "$@" &&
		stashhash="$(git rev-parse --quiet --verify TG_STASH --)" &&
		[ -n "$stashhash" ] &&
		[ "$(git cat-file -t "$stashhash" 2>/dev/null)" = "tag" ] ||
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
ec=0
clear_matching_untracked "$current"
checkout_symref_full "$current" || ec=$?
! [ -f "$git_dir/TGMERGE_MSG" ] || [ -e "$git_dir/MERGE_MSG" ] ||
	mv -f "$git_dir/TGMERGE_MSG" "$git_dir/MERGE_MSG" || :
tmpdir_cleanup || :
git gc --auto || :
if [ "${ec:-0}" != "0" ]; then
	info "Unable to switch to ${current#refs/heads/}"
	if
		git rev-parse -q --verify HEAD >/dev/null 2>&1 &&
		! git symbolic-ref -q HEAD >/dev/null 2>&1
	then
		info "HEAD is currently detached"
		info "Use 'git checkout ${current#refs/heads/}' to reattach"
	fi
fi
exit ${ec:-0}
