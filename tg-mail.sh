#!/bin/sh
# TopGit - A different patch queue manager
# GPLv2

USAGE="\
Usage: ${tgname:-tg} [...] mail [-s <send-email-args>] [-r <reference-msgid>] [-i | -w] [<name>]
Options:
    -i                  use TopGit metadata from index instead of HEAD branch
    -w                  use metadata from working directory instead of branch"

usage()
{
	if [ "${1:-0}" != 0 ]; then
		printf '%s\n' "$USAGE" >&2
	else
		printf '%s\n' "$USAGE"
	fi
	exit ${1:-0}
}

name=
head_from=
send_email_args=
in_reply_to=

## Parse options

while [ -n "$1" ]; do
	arg="$1"; shift
	case "$arg" in
	-h|--help)
		usage;;
	-i|-w)
		[ -z "$head_from" ] || die "-i and -w are mutually exclusive"
		head_from="$arg";;
	-s)
		send_email_args="$1"; shift;;
	-r)
		in_reply_to="$1"; shift;;
	-*)
		usage 1;;
	*)
		[ -z "$name" ] || die "name already specified ($name)"
		name="$arg";;
	esac
done

v_verify_topgit_branch name "${name:-HEAD}"
base_rev="$(git rev-parse --short --verify "refs/$topbases/$name^0" -- 2>/dev/null)" ||
	die "not a TopGit-controlled branch"

if [ -n "$in_reply_to" ]; then
	send_email_args="$send_email_args --in-reply-to='$in_reply_to'"
fi


patchfile="$(get_temp tg-mail)"

[ -z "$head_from" ] || ensure_work_tree

# let tg patch sort out whether $head_from makes sense for $name
tg patch "$name" $head_from >"$patchfile"

header="$(sed -e '/^$/,$d' -e "s,','\\\\'',g" "$patchfile")"


from="$(echol "$header" | grep '^From:' | sed 's/From:\s*//')"
to="$(echol "$header" | grep '^To:' | sed 's/To:\s*//')"


people=
[ -n "$from" ] && people="$people --from '$from'"
# FIXME: there could be multiple To
[ -n "$to" ] && people="$people --to '$to'"

# NOTE: git-send-email handles cc itself
eval git send-email $send_email_args "$people" '"$patchfile"'
