#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) Petr Baudis <pasky@suse.cz>  2008
# All rights reserved.
# GPLv2

name=
head_from=
binary=

## Parse options

while [ -n "$1" ]; do
	arg="$1"
	case "$arg" in
	--)
		case "$2" in
		-*)
			shift; break;;
		*)
			break;;
		esac;;
	-|-h|--help)
		echo "Usage: ${tgname:-tg} [...] patch [-i | -w] [--binary] [<name>] [--] [<git-diff-tree-option>...]" >&2
		exit 1;;
	-i|-w)
		[ -z "$head_from" ] || die "-i and -w are mutually exclusive"
		head_from="$arg";;
	--binary)
		binary=1;;
	-?*)
		if test="$(verify_topgit_branch "$arg" -f)"; then
			[ -z "$name" ] || die "name already specified ($name)"
			name="$arg"
		else
			break
		fi;;
	*)
		[ -z "$name" ] || die "name already specified ($name)"
		name="$arg";;
	esac
	shift
done

quotearg() {
	printf '%s' "$1" | sed 's/\(['\''!]\)/'\'\\\\\\1\''/g'
}

head="$(git symbolic-ref -q HEAD || :)"
head="${head#refs/heads/}"

[ -n "$name" ] ||
	name="${head:-HEAD}"
name="$(verify_topgit_branch "$name")"
base_rev="$(git rev-parse --short --verify "refs/top-bases/$name" -- 2>/dev/null)" ||
	die "not a TopGit-controlled branch"

if [ -n "$head_from" ] && [ "$name" != "$head" ]; then
	die "$head_from makes only sense for the current branch"
fi



# We now collect the rest of the code in this file into a function
# so we can redirect the output to the pager.
output()
{

# put out the commit message
# and put an empty line out, if the last one in the message was not an empty line
# and put out "---" if the commit message does not have one yet
cat_file "refs/heads/$name:.topmsg" $head_from |
	awk '
/^---/ {
    has_3dash=1;
}
       {
    need_empty = 1;
    if ($0 == "")
        need_empty = 0;
    print;
}
END    {
    if (need_empty)
        print "";
    if (!has_3dash)
        print "---";
}
'

b_tree=$(pretty_tree "$name" -b)
t_tree=$(pretty_tree "$name" $head_from)

if [ $b_tree = $t_tree ]; then
	echo "No changes."
else
	hasdd=
	for a; do
		[ "$a" != "--" ] || { hasdd=1; break; }
	done
	if [ -z "$hasdd" ]; then
		git diff-tree -p --stat --summary ${binary:+--binary} "$@" $b_tree $t_tree
	else
		cmd="git diff-tree -p --stat --summary ${binary:+--binary}"
		while [ $# -gt 0 -a "$1" != "--" ]; do
			cmd="$cmd '$(quotearg "$1")'"
			shift
		done
		cmd="$cmd '$(quotearg "$b_tree")' '$(quotearg "$t_tree")'"
		while [ $# -gt 0 ]; do
			cmd="$cmd '$(quotearg "$1")'"
			shift
		done
		eval "$cmd"
	fi
fi

echo '-- '
depon="$(cat_file "refs/heads/$name:.topdeps" $head_from 2>/dev/null | paste -s -d ' ' -)"
echo "$tgname: ($base_rev..) $name${depon:+ (depends on: $depon)}"
branch_contains "refs/heads/$name" "refs/top-bases/$name" ||
	echo "$tgname: The patch is out-of-date wrt. the base! Run \`$tgdisplay update\`."

}
USE_PAGER_TYPE=diff
page output "$@"
# ... and then we run it through the pager with the page function

# vim:noet
