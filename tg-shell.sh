#!/bin/sh
# TopGit wayback machine shell command
# (C) 2017 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved
# GPLv2

USAGE="\
Usage: ${tgname:-tg} [...] -w [:]<tgtag> shell [--directory=<dirpath>] [-q] [--] [<arg>...]"

usage()
{
	if [ "${1:-0}" != 0 ]; then
		printf '%s\n' "$USAGE" >&2
	else
		printf '%s\n' "$USAGE"
	fi
	exit ${1:-0}
}

quote=

while [ $# -gt 0 ]; do case "$1" in
	-h|--help|--directory|--directory=*)
		usage
		;;
	--directory|--directory=*)
		# only one is allowed and it should have been handled by tg.sh
		# which means this is the second one and it's a usage error
		usage 1
		;;
	--quote|-q)
		quote=1
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
[ -n "$wayback" ] || usage 1

# Everything's been handled by tg.sh except for verifying a TTY
# is present for an interactive shell

cmd=
redir=
theshell=@SHELL_PATH@
if [ $# -eq 0 ]; then
	[ -z "$SHELL" ] || theshell="$SHELL"
	test -t 0 || die "cannot use interactive wayback shell on non-TTY STDIN"
	if test -t 1; then
		test -t 2 || redir='2>&1'
	elif test -t 2; then
		redir='>&2'
	else
		die "cannot use interactive wayback shell on non-TTY STDOUT/STDERR"
	fi
	PS1='[../${PWD##*/}] wayback$ ' && export PS1
	wbname="${wayback#:}"
	[ -n "$wbname" ] || wbname='now?!'
	eval 'info "going wayback to $wbname..."' "$redir"
else
	if [ -z "$quote" ]; then
		cmd='-c "$*"'
	else
		# attempt to "quote" the arguments and then glue them together
		cmdstr=
		for cmdword in "$@"; do
			cmdworddq=1
			case "$cmdword" in [A-Za-z_]*)
				if test z"${cmdword%%[!A-Za-z_0-9]*}" = z"$cmdword"
				then
					cmdworddq=
				else case "$cmdword" in *=*)
					cmdvar="${cmdword%%=*}"
					if test z"${cmdvar%%[!A-Za-z_0-9]*}" = z"$cmdvar"
					then
						v_quotearg cmdword "${cmdword#*=}"
						cmdword="$cmdvar=$cmdword"
						cmdworddq=
					fi
				esac; fi
			esac
			test z"$cmdworddq" = z || v_quotearg cmdword "$cmdword"
			cmdstr="${cmdstr:+$cmdstr }$cmdword"
		done
		cmd='-c "$cmdstr"'
	fi
fi
eval '"$theshell"' "$cmd" "$redir"
