#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) Petr Baudis <pasky@suse.cz>  2008
# Copyright (C) Kyle J. McKay <mackyle@gmail.com>  2015
# All rights reserved.
# GPLv2

## Set up all the tg machinery

set -e
tg__include=1
tg_util() {
	. "@bindir@"/tg
}
tg_util


## Generally have fun

# Don't do anything on a non-TopGit branch
if head_=$(git symbolic-ref -q HEAD); then
	case "$head_" in
		refs/heads/*)
			head_="${head_#refs/heads/}"
			git rev-parse -q --verify "refs/top-bases/$head_" -- >/dev/null || exit 0;;
		*)
			exit 0;;
	esac

else
	exit 0;
fi

check_topfile()
{
	_tree=$1
	_file=$2
	_zerook="$3"

	_ls_line="$(git ls-tree --long "$_tree" "$_file")" ||
		die "cannot ls tree for $_file"

	[ -n "$_ls_line" ] ||
		die "$_file is missing"

	# check for type and size
	set -- $_ls_line
	_type=$2
	_size=$4

	# check file is of type blob (file)
	[ "x$_type" = "xblob" ] ||
		die "$_file is not a file (i.e. not a 'blob')"

	# check for positive size
	[ -n "$_zerook" -o "$_size" -gt 0 ] ||
		die "$_file has empty size"
}

tree=$(git write-tree) ||
	die "cannot write tree"

check_topfile "$tree" ".topdeps" 1
check_topfile "$tree" ".topmsg"

# Don't do anything more if neither .topdeps nor .topmsg is changing
changedeps=
changemsg=
mode=modify
headrev="$(git rev-parse --quiet --verify HEAD -- || :)"
tab="$(printf '\t.')" && tab="${tab%?}"
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
[ -n "$changedeps" -o -n "$changemsg" ] || exit 0

check_cycle_name()
{
	[ "$head_" != "$_dep" ] ||
		die "TopGit dependencies form a cycle: perpetrator is $_name"
}

check_topdeps()
{
	# we only need to check newly added deps and for these if a path exists to the
	# current HEAD
	git diff --cached "$root_dir/.topdeps" |
		awk '
	BEGIN      { in_hunk = 0; }
	/^@@ /     { in_hunk = 1; }
	/^\+/      { if (in_hunk == 1) printf("%s\n", substr($0, 2)); }
	/^[^@ +-]/ { in_hunk = 0; }
	' |
		while read newly_added; do
			ref_exists "refs/heads/$newly_added" ||
				die "invalid branch as dependent: $newly_added"

			# check for self as dep
			[ "$head_" != "$newly_added" ] ||
				die "cannot have myself as dependent"

			# deps can be non-tgish but we can't run recurse_deps() on them
			ref_exists "refs/top-bases/$newly_added" ||
				continue

			# recurse_deps uses dfs but takes the .topdeps from the tree,
			# therefore no endless loop in the cycle-check
			no_remotes=1 recurse_deps check_cycle_name "$newly_added"
		done
	test $? -eq 0

	# check for repetitions of deps
	depdir="$(get_temp tg-depdir -d)" ||
		die "cannot check for multiple occurrences of dependents"
	cat_file "$head_:.topdeps" -i |
		while read dep; do
			[ ! -d "$depdir/$dep" ] ||
				die "multiple occurrences of the same dependent: $dep"
			mkdir -p "$depdir/$dep" ||
				die "cannot check for multiple occurrences of dependents"
		done
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
prefix="100[0-9][0-9][0-9] $octet20 0$tab"
{
	printf '%s\n' "0 $nullsha$tab.topdeps"
	printf '%s\n' "0 $nullsha$tab.topmsg"
	git ls-files --cached -s --full-name | grep -e "^$prefix\\.topdeps\$" -e "^$prefix\\.topmsg\$"
} | GIT_INDEX_FILE="$tg_index" git update-index --index-info
newtree="$(GIT_INDEX_FILE="$tg_index" git write-tree)"
rm -f "$tg_index"
files=
if [ -n "$changedeps" -a -n "$changemsg" ]; then
	files=".topdeps and .topmsg"
elif [ -n "$changedeps" ]; then
	files=".topdeps"
else
	files=".topmsg"
fi
newcommit="$(git commit-tree -m "tg: $mode $files" ${headrev:+-p $headrev} "$newtree")"
git update-ref -m "tg: sequester $files changes into their own preliminary commit" HEAD "$newcommit"
warn "sequestered $files changes into their own preliminary commit"
info "run the same \`git commit\` command again to commit the remaining changes" >&2
exit 1
