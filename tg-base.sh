#!/bin/sh
# TopGit - A different patch queue manager
# (C) Petr Baudis <pasky@suse.cz>  2008
# (C) Per Cederqvist <ceder@lysator.liu.se>  2010
# (C) Kyle J. McKay <mackyle@gmail.com>  2017, 2021
# All rights reserved
# GPLv2

USAGE="\
Usage: ${tgname:-tg} [...] base [--short[=<n>] | --no-short] [--] [branch...]
Options:
    --short[=<n>]       display shortened hashes (default)
    --no-short          display full hashes"

usage()
{
	if [ "${1:-0}" != 0 ]; then
		printf '%s\n' "$USAGE" >&2
	else
		printf '%s\n' "$USAGE"
	fi
	exit ${1:-0}
}

## Parse options

short="--short"

while [ $# -gt 0 ]; do case "$1" in
	-h|--help)
		usage;;
	--short|--short=*|--no-short)
		short="$1";;
	--)
		shift
		break;;
	-?*)
		die "unrecognized option: $1";;
	*)
		break;;
esac; shift; done

if [ "$#" -eq 0 ]; then
	set -- HEAD
fi

rv=0
for rev in "$@"; do
	[ "$rev" != "@" ] || rev="HEAD"
	name="$(git symbolic-ref -q "$rev" 2>/dev/null)" || name="$rev"
	v_strip_ref name "$name"
	git rev-parse --verify $short "refs/$topbases/$name^0" -- 2>/dev/null || {
		rv=1
		echo "$rev is not a TopGit branch" >&2
	}
done
exit $rv
