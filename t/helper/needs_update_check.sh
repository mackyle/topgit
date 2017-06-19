#!/bin/sh
# TopGit needs_update_check test helper command
# Copyright (C) 2015,2017 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved.
# License GPLv2

USAGE="\
Usage: ${0##*/} [-C <dir>] [-r <remote>] [-u] [--no-cache] [--no-remotes] [--no-self] [--no-same] [--] <options_and_args>"

usage()
{
	if [ "${1:-0}" != 0 ]; then
		printf '%s\n' "$USAGE" >&2
	else
		printf '%s\n' "$USAGE"
	fi
	exit ${1:-0}
}

fatal()
{
        printf 'fatal: %s\n' "$*" >&2
        exit 1
}

cmd_path() (
        { "unset" -f command unset unalias "$1"; } >/dev/null 2>&1 || :
        { "unalias" -a || unalias -m "*"; } >/dev/null 2>&1 || :
        command -v "$1"
)

# unset that ignnores error code that shouldn't be produced according to POSIX
unset_() {
	unset "$@" || :
}

set -e

tgbin="$(cmd_path tg)" && [ -n "$tgbin" ] && [ -x "$tgbin" ] && [ -r "$tgbin" ] ||
	fatal "tg not found in \$PATH or not executable or not readable"

unset_ noremote nocache
while [ $# -gt 0 ]; do case "$1" in
	-h|--help)
		usage
		;;
	-C)
		shift
		[ -n "$1" ] || fatal "option -C requires an argument"
		cd "$1"
		;;
	-u)
		noremote=1
		;;
	-r)
		shift
		[ -n "$1" ] || fatal "option -r requires an argument"
		base_remote="$1"
		unset_ noremote
		;;
	--no-cache)
		nocache=1
		;;
	--no-remotes)
		no_remotes=1
		;;
	--no-self)
		needs_update_check_no_self=1
		;;
	--no-same)
		needs_update_check_no_same=1
		;;
	--)
		shift
		break
		;;
	-?*)
		echo "Unknown option: $1" >&2
		usage 1
		;;
	*)
		break
		;;
esac; shift; done

tg__include=1
# MUST do this AFTER changing the current directory since it sets $git_dir!
. "$tgbin"
[ -z "$noremote" ] || base_remote=

[ -n "$nocache" ] || become_cacheable
[ $# -gt 0 ] || set -- $(navigate_deps -s=-1)
needs_update_check "$@"
printf '%s\n' \
	"${needs_update_processed:-:}" \
	"${needs_update_behind:-:}" \
	"${needs_update_ahead:-:}" \
	"${needs_update_partial:-:}"
