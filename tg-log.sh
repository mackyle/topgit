#!/bin/sh
# TopGit - A different patch queue manager
# (c) Petr Baudis <pasky@suse.cz>  2008
# (c) Bert Wesarg <Bert.Wesarg@googlemail.com>  2009
# GPLv2

name=


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
		echo "Usage: ${tgname:-tg} [...] log [<name>] [--] [<git-log-option>...]" >&2
		exit 1;;
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

name="$(verify_topgit_branch "${name:-HEAD}")"
base_rev="$(git rev-parse --short --verify "refs/$topbases/$name" -- 2>/dev/null)" ||
	die "not a TopGit-controlled branch"

hasdd=
for a; do
	[ "$a" != "--" ] || { hasdd=1; break; }
done
if [ -z "$hasdd" ]; then
	git log --first-parent --no-merges "$@" "refs/$topbases/$name".."$name"
else
	cmd='git log --first-parent --no-merges'
	while [ $# -gt 0 -a "$1" != "--" ]; do
		cmd="$cmd '$(quotearg "$1")'"
		shift
	done
	cmd="$cmd '$(quotearg "refs/$topbases/$name".."$name")'"
	while [ $# -gt 0 ]; do
		cmd="$cmd '$(quotearg "$1")'"
		shift
	done
	eval "$cmd"
fi
