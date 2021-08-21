#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) 2008 Petr Baudis <pasky@suse.cz>
# Copyright (C) 2015,2017 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved.
# GPLv2

## Set up all the tg machinery

: "${TG_INST_BINDIR:=@bindir@}"

set -e
tg__include=1
tg_util() {
	. "$TG_INST_BINDIR"/tg
	tg_use_alt_odb=
}
tg_util


## Generally have fun

# Don't do anything on a non-TopGit branch
if head_=$(git symbolic-ref -q HEAD); then
	case "$head_" in
		refs/heads/*)
			head_="${head_#refs/heads/}"
			git rev-parse -q --verify "refs/$topbases/$head_^0" -- >/dev/null || exit 0;;
		*)
			exit 0;;
	esac

else
	exit 0
fi

# status 0 iff HEAD exists and has neither .topdeps nor .topmsg entries
is_bare_branch()
{
	_tbbtree="$(git rev-parse --quiet --verify HEAD^{tree} --)" || return 1
	_tbbls="$(git ls-tree --full-tree "$_tbbtree" .topdeps .topmsg)" || return 1
	test -z "$_tbbls"
}

# Input:
#   $1 => variable name (set to "" for 0 return otherwise message)
#   $2 => tree to inspect
#   $3 => file name to look for
#   $4 => if non-empty allow a zero-length file
# Output:
#   0: specified blob exists and meets $4 condition and eval "$1="
#   1: ls-tree gave no result for that file and eval "$1='some error message'"
#   2: file is of type other than blob and eval "$1='some error message'"
#   3: file is a zero length blob and $4 is empty and eval "$1='error message'"
v_check_topfile()
{
	_var="$1"
	shift
	eval "$_var="
	_tree="$1"
	_file="$2"
	_zerook="$3"

	_ls_line="$(git ls-tree --long --full-tree "$_tree" "$_file")" || {
		eval "$_var="'"cannot ls tree for $_file"'
		return 1
	}

	[ -n "$_ls_line" ] || {
		eval "$_var="'"$_file is missing"'
		return 1
	}

	# check for type and size
	set -- $_ls_line
	_type="$2"
	_size="$4"

	# check file is of type blob (file)
	[ "x$_type" = "xblob" ] || {
		eval "$_var=\"\$_file is not a file (i.e. not a 'blob')\""
		return 2
	}

	# check for positive size
	[ -n "$_zerook" ] || [ "$_size" -gt 0 ] || {
		eval "$_var="'"$_file has empty (i.e. 0) size"'
		return 3
	}

	return 0
}

tree=$(git write-tree) ||
	die "cannot write tree"

ed=0 && v_check_topfile msg1 "$tree" ".topdeps" 1 || ed=$?
em=0 && v_check_topfile msg2 "$tree" ".topmsg"    || em=$?
[ $ed -ne 1 ] || [ $em -ne 1 ] || ! is_bare_branch || exit 0
[ -z "$msg1" ] || fatal "$msg1"
[ -z "$msg2" ] || fatal "$msg2"
[ $ed -eq 0 ] && [ $em -eq 0 ] || exit 1

# Don't do anything more if neither .topdeps nor .topmsg is changing
changedeps=
changemsg=
mode=modify
headrev="$(git rev-parse --quiet --verify HEAD --)" || :
tab="	" # one tab in there
prefix="[A-Z][0-9]*$tab"
if [ -n "$headrev" ]; then
	headtree="$headrev^{tree}"
else
	headtree="$(: | git mktree)"
fi
while read -r status fn; do case "$fn" in
	".topdeps")
		changedeps=1
		case "$status" in "A"*) mode=create; esac
		;;
	".topmsg")
		case "$status" in "A"*) mode=create; esac
		changemsg=1
		;;
esac; done <<-EOT
	$(git diff-index --cached --name-status "$headtree" | grep -e "^$prefix\\.topdeps\$" -e "^$prefix\\.topmsg\$")
EOT
[ -n "$changedeps" ] || [ -n "$changemsg" ] || exit 0

check_cycle_name()
{
	[ "$head_" != "$_dep" ] ||
		die "TopGit dependencies form a cycle: perpetrator is $_name"
}

check_topdeps()
{
	# we only need to check newly added deps and for these if a path exists to the
	# current HEAD
	check_status
	base_remote=
	[ -z "$tg_topmerge" ] || [ ! -s "$git_dir/tg-update/remote" ] ||
	IFS= read -r base_remote <"$git_dir/tg-update/remote" || :
	git diff --cached --ignore-space-at-eol -- "$root_dir/.topdeps" | diff_added_lines |
	while read newly_added; do
		ref_exists "refs/heads/$newly_added" ||
		{ [ -n "$tg_topmerge" ] && auto_create_local_remote "$newly_added"; } ||
			die "invalid branch as dependent: $newly_added"

		# check for self as dep
		[ "$head_" != "$newly_added" ] ||
			die "cannot have myself as dependent"

		# deps can be non-tgish but we can't run recurse_deps() on them
		ref_exists "refs/$topbases/$newly_added" ||
			continue

		# recurse_deps uses dfs but takes the .topdeps from the tree,
		# therefore no endless loop in the cycle-check
		no_remotes=1 recurse_deps check_cycle_name "$newly_added"
	done
	test $? -eq 0

	# check for repetitions of deps
	depdir="$(get_temp tg-depdir -d)" ||
		die "cannot check for multiple occurrences of dependents"
	git cat-file blob ":0:.topdeps" 2>/dev/null |
		while read -r dep || [ -n "$dep" ]; do
			[ ! -d "$depdir/$dep" ] ||
				die "multiple occurrences of the same dependent: $dep"
			mkdir -p "$depdir/$dep" ||
				die "cannot check for multiple occurrences of dependents"
		done
	test $? -eq 0
}

# Only check .topdeps if it's been changed otherwise the assumption is it's been checked
[ -z "$changedeps" ] || check_topdeps

# If we are not sequestering TopGit files or the commit is changing only TopGit files we're done
[ -z "$tgnosequester" ] || exit 0
[ $(( ${changedeps:-0} + ${changemsg:-0} )) -ne $(git diff-index --cached --name-only "$headtree" | wc -l) ] || exit 0

# Sequester the TopGit-specific file changes into their own commit and notify the user we did so
tg_index="$git_dir/tg-index"
if [ -n "$headrev" ]; then
	GIT_INDEX_FILE="$tg_index" git read-tree "$headrev^{tree}"
else
	GIT_INDEX_FILE="$tg_index" git read-tree --empty
fi
prefix="100[0-9][0-9][0-9] $octet20$hexch* 0$tab"
{
	printf '%s\n' "0 $nullsha$tab.topdeps"
	printf '%s\n' "0 $nullsha$tab.topmsg"
	git ls-files --cached -s --full-name | grep -e "^$prefix\\.topdeps\$" -e "^$prefix\\.topmsg\$"
} | GIT_INDEX_FILE="$tg_index" git update-index --index-info
newtree="$(GIT_INDEX_FILE="$tg_index" git write-tree)"
rm -f "$tg_index"
files=
if [ -n "$changedeps" ] && [ -n "$changemsg" ]; then
	files=".topdeps and .topmsg"
elif [ -n "$changedeps" ]; then
	files=".topdeps"
else
	files=".topmsg"
fi
newcommit="$(git commit-tree -m "tg: $mode $files" ${headrev:+-p} ${headrev:+"$headrev"} "$newtree")"
git update-ref -m "tg: sequester $files changes into their own preliminary commit" HEAD "$newcommit"
warn "sequestered $files changes into their own preliminary commit"
info "run the same \`git commit\` command again to commit the remaining changes" >&2
exit 1
