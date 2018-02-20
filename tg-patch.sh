#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) Petr Baudis <pasky@suse.cz>  2008
# All rights reserved.
# GPLv2

name=
head_from=
binary=
quiet=
fixfrom=
fromaddr=

gec=0
bool="$(git config --get --bool topgit.from 2>/dev/null)" || gec=$?
if [ $gec -eq 128 ]; then
	fromaddr="$(git config --get topgit.from 2>/dev/null)" || :
	if [ "$fromaddr" = "quiet" ]; then
		quiet=1
	else
		[ -z "$fromaddr" ] || fixfrom=1
	fi
elif [ $gec -eq 0 ]; then
	[ "$bool" = "false" ] || fixfrom=1
fi

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
		echo "Usage: ${tgname:-tg} [...] patch [-q] [-i | -w] [--binary] [<name>] [--] [<git-diff-tree-option>...]" >&2
		exit 1;;
	-i|-w)
		[ -z "$head_from" ] || die "-i and -w are mutually exclusive"
		head_from="$arg";;
	--binary)
		binary=1;;
	-q|--quiet)
		quiet=1;;
	--no-from)
		fixfrom= fromaddr=;;
	--from)
		fixfrom=1;;
	--from=*)
		fixfrom=1 fromaddr="${1#--from=}";;
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

head="$(git symbolic-ref -q HEAD)" || :
head="${head#refs/heads/}"

[ -n "$name" ] ||
	name="${head:-HEAD}"
name="$(verify_topgit_branch "$name")"
base_rev="$(git rev-parse --short --verify "refs/$topbases/$name^0" -- 2>/dev/null)" ||
	die "not a TopGit-controlled branch"

if [ -n "$head_from" ] && [ "$name" != "$head" ]; then
	die "$head_from makes only sense for the current branch"
fi
[ -z "$head_from" ] || ensure_work_tree

usesob=
[ -z "$fixfrom" ] || [ -n "$fromaddr" ] || {
	fromaddr="$(git var GIT_AUTHOR_IDENT)" || exit
	usesob=1
}

# We now collect the rest of the code in this file into a function
# so we can redirect the output to the pager.
output()
{

# put out the commit message
# and put an empty line out, if the last one in the message was not an empty line
# and put out "---" if the commit message does not have one yet
result=0
cat_file "refs/heads/$name:.topmsg" $head_from |
	awk -v "fixfrom=$fixfrom" -v "fromaddr=$fromaddr" -v "usesob=$usesob" '
function trimfb(s) {
	sub(/^[ \t]+/, "", s)
	sub(/[ \t]+$/, "", s)
	return s
}
function fixident(val, fixmt, _name, _email) {
	val = trimfb(val)
	if (!fixmt && val == "") return ""
	_name=""
	_email=""
	if ((leftangle = index(val, "<")) > 0) {
		_name=trimfb(substr(val, 1, leftangle - 1))
		_email=substr(val, leftangle+1)
		sub(/>[^>]*$/, "", _email)
		_email=trimfb(_email)
	} else {
		if ((atsign = index(val, "@")) > 0) {
			_name=trimfb(substr(val, 1, atsign - 1))
			_email=trimfb(val)
		} else {
			_name=trimfb(val)
			if (_name != "") _email="-"
		}
	}
	if (!fixmt && _name == "" && _email == "") return ""
	if (_name == "") _name = "-"
	if (_email == "") _email = "-"
	return _name " <" _email ">"
}
BEGIN {
	hdrline = 0
	sawfrom = 0
	sobname = ""
	if (fixfrom) {
		fromaddr = fixident(fromaddr)
		if (fromaddr == "" && !usesob) fixfrom = 0
	}
	inhdr = 1
	bodyline = 0
}
inhdr && /^[Ff][Rr][Oo][Mm][ \t]*:/ {
	val = $0
	sub(/^[^:]*:/, "", val)
	val = fixident(val)
	if (val != "") sawfrom = 1
	if (val != "" || !fixfrom) hdrs[++hdrline] = $0
	next
}
inhdr && /^[ \t]*$/ {
	inhdr = 0
	next
}
inhdr { hdrs[++hdrline] = $0; next; }
function writehdrs() {
	if (!sawfrom && fixfrom && fromaddr != "") {
		print "From: " fromaddr
		sawfrom = 1
	}
	for (i=1; i <= hdrline; ++i) print hdrs[i]
	print ""
}
/^---/ { has_3dash=1 }
usesob && /^[Ss][Ii][Gg][Nn][Ee][Dd]-[Oo][Ff][Ff]-[Bb][Yy][ \t]*:[ \t]*[^ \t]/ {
	val = $0
	sub(/^[^:]*:/, "", val)
	val = fixident(val)
	if (val != "") fromaddr=val
}
{
	need_empty = 1
	if ($0 == "") need_empty = 0
	body[++bodyline] = $0
}
END {
	writehdrs()
	for (i = 1; i <= bodyline; ++i) print body[i]
	if (need_empty) print ""
	if (!has_3dash) print "---"
	exit sawfrom ? 0 : 67 # EX_NOUSER
}
' || result=$?
if [ "$result" = "67" ]; then
	[ -n "$quiet" ] ||
	echo "### tg: missing From: in .topmsg, 'git am' will barf (use --from to add)" >&2
	result=0
fi
[ "${result:-0}" = "0" ] || exit "$result"

v_pretty_tree b_tree -t "$name" -b
v_pretty_tree t_tree -t "$name" $head_from

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
		while [ $# -gt 0 ] && [ "$1" != "--" ]; do
			cmd="$cmd $(quotearg "$1")"
			shift
		done
		cmd="$cmd $(quotearg "$b_tree") $(quotearg "$t_tree")"
		while [ $# -gt 0 ]; do
			cmd="$cmd $(quotearg "$1")"
			shift
		done
		eval "$cmd"
	fi
fi

echo ''
echo '-- '
depon="$(cat_file "refs/heads/$name:.topdeps" $head_from 2>/dev/null | paste -s -d ' ' -)"
echo "$tgname: ($base_rev..) $name${depon:+ (depends on: $depon)}"
branch_contains "refs/heads/$name" "refs/$topbases/$name" ||
	echo "$tgname: The patch is out-of-date wrt. the base! Run \`$tgdisplay update\`."

}
USE_PAGER_TYPE=diff
page output "$@"
# ... and then we run it through the pager with the page function
