#!/bin/sh
# TopGit rebase command
# (C) 2015 Kyle J. McKay <mackyle@gmail.com>
# GPLv2

USAGE="Usage: ${tgname:-tg} [...] rebase (-m | --merge) [<git-rebase-arg>...]"

case "$1" in -h|--help)
	printf '%s\n' "$USAGE"
	exit 0
esac

optmerge=
optcontinue=
for arg; do
	case "$arg" in
		-m|--merge)
			optmerge=1
			;;
		--skip|--continue|--abort|--edit-todo)
			optcontinue=1
			;;
	esac
done
if [ -n "$optcontinue" ]; then
	if [ -n "$git_dir" ] && [ -d "$git_dir" ] && ! [ -d "$git_dir/rebase-merge" ]; then
		exec git rebase "$@"
		exit 1
	fi
fi
if [ -z "$optmerge" -a -z "$optcontinue" ]; then
    cat <<EOT >&2
${tgname:-tg} rebase is intended as a drop-in replacement for git rebase -m.
Either add the -m (or --merge) option to the command line or use git rebase
directly.  When using rebase to flatten history the merge mode is superior.
EOT
    exit 1
fi

if [ -z "$optcontinue" ]; then
	rerereon="$(git config --get --bool rerere.enabled 2>/dev/null || :)"
	[ "$rerereon" = "true" ] || \
	warn "rerere.enabled is false, automatic --continue not possible"
fi

continuemsg='"git rebase --continue"'
lasthead=
newhead="$(git rev-parse --verify --quiet HEAD -- || :)"

while
	lasthead="$newhead"
	hascontinuemsg=
	err=0
	msg="$(git -c rerere.autoupdate=true rebase "$@"  3>&2 2>&1 1>&3 3>&-)" || err=$?
	case "$msg" in *"$continuemsg"*) hascontinuemsg=1; esac
	newhead="$(git rev-parse --verify --quiet HEAD -- || :)"
	[ "$newhead" != "$lasthead" ] || hascontinuemsg=
	msg="$(printf '%s\n' "$msg" | sed -e 's~git rebase ~'"$tgdisplay"' rebase ~g')"
	[ $err -ne 0 ]
do
	if [ -n "$hascontinuemsg" ] && [ $(git ls-files --unmerged | wc -l) -eq 0 ]; then
		while IFS= read -r line; do case "$line" in
			"Staged "*|"Resolved "*|"Recorded "*)
				printf '%s\n' "$line";;
			*)
				break;;
		esac; done <<-EOT
			$msg
		EOT
		set -- --continue
		continue
	fi
	break
done

[ -z "$msg" ] || printf '%s\n' "$msg" >&2
exit $err
