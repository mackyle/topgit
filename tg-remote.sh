#!/bin/sh
# TopGit - A different patch queue manager
# (C) Petr Baudis <pasky@suse.cz>  2008
# (C) Kyle J. McKay <mackyle@gmail.com>  2016,2017
# All rights reserved.
# GPLv2

populate= # Set to 1 if we shall seed local branches with this
name=


## Parse options

while [ -n "$1" ]; do
	arg="$1"; shift
	case "$arg" in
	--populate)
		populate=1;;
	-*)
		echo "Usage: ${tgname:-tg} [...] remote [--populate] [<remote>]" >&2
		exit 1;;
	*)
		name="$arg";;
	esac
done

[ -n "$name" ] ||
	name="$base_remote"

git config "remote.$name.url" >/dev/null || die "unknown remote '$name'"

fetchdone=
if [ -n "$topbases_implicit_default" ]; then
	# set $topbases based on remote bases as the local repository does not have
	# any bases already present and has not explicitly set topgit.top-bases
	if [ -n "$populate" ]; then
		# Do the fetch now but fetch both old and new top-bases
		fetchdone=1
		git fetch --prune "$name" \
			"+refs/top-bases/*:refs/remotes/$name/top-bases/*" \
			"+refs/heads/*:refs/remotes/$name/*"
	fi
	# see if we have any remote bases
	sawnew=
	sawold=
	while read -r rn && [ -n "$rn" ]; do
		case "$rn" in
			"refs/remotes/$name/{top-bases}"/?*)
				sawnew=1;;
			"refs/remotes/$name/top-bases"/?*)
				sawold=1;;
		esac
		[ "$sawnew$sawold" != "11" ] || break
	done <<-EOT
		$(git for-each-ref --format='%(refname)' "refs/remotes/$name/{top-bases}" "refs/remotes/$name/top-bases")
	EOT
	if [ "$sawold$sawnew" = "11" ]; then
		err "remote \"$name\" has top-bases in both locations:"
		err "  refs/remotes/$name/{top-bases}/..."
		err "  refs/remotes/$name/top-bases/..."
		err "set \"topgit.top-bases\" to \"heads\" for the first, preferred location"
		err "or set \"topgit.top-bases\" to \"refs\" for the second, old location"
		err "(the \"-c topgit.top-bases=<val>\" option can be used for this)"
		err "then re-run the tg remote command"
		err "(the tg migrate-bases command can also help with this problem)"
		die "schizophrenic remote \"$name\" requires topgit.top-bases setting"
	fi
	if [ -n "$sawold$sawnew" ]; then
		val="heads"
		[ -z "$sawold" ] || val="refs"
		GIT_CONFIG_PARAMETERS="${GIT_CONFIG_PARAMETERS:+$GIT_CONFIG_PARAMETERS }'topgit.top-bases=$val'"
		export GIT_CONFIG_PARAMETERS
		unset tg_topbases_set
		set_topbases
	fi
fi

## Configure the remote

git config --replace-all "remote.$name.fetch" "+refs/$topbases/*:refs/remotes/$name/${topbases#heads/}/*" \
	"\\+?refs/(top-bases|heads/[{]top-bases[}])/\\*:refs/remotes/$name/(top-bases|[{]top-bases[}])/\\*"

if git config --get-all "remote.$name.push" "\\+refs/top-bases/\\*:refs/top-bases/\\*" >/dev/null && test "xtrue" != "x$(git config --bool --get topgit.dontwarnonoldpushspecs)"; then
	info "Probably you want to remove the push specs introduced by an old version of topgit:"
	info '       git config --unset-all "remote.'"$name"'.push" "\\+refs/top-bases/\\*:refs/top-bases/\\*"'
	info '       git config --unset-all "remote.'"$name"'.push" "\\+refs/heads/\\*:refs/heads/\\*"'
	info '(or use git config --bool --add topgit.dontwarnonoldpushspecs true to get rid of this warning)'
fi

info "Remote $name can now follow TopGit topic branches."
if [ -z "$populate" ]; then
	info "Next, do: git fetch $name"
	exit
fi


## Populate local branches

info "Populating local topic branches from remote '$name'..."

## The order of refspecs is very important, because both heads and
## $topbases are mapped under the same namespace refs/remotes/$name.
## If we put the 2nd refspec before the 1st one, stale refs reverse
## lookup would fail and "refs/remotes/$name/$topbases/XX" reverse
## lookup as a non-exist "refs/heads/$topbases/XX", and would be
## deleted by accident.
[ -n "$fetchdone" ] || git fetch --prune "$name" \
	"+refs/$topbases/*:refs/remotes/$name/${topbases#heads/}/*" \
	"+refs/heads/*:refs/remotes/$name/*"

git for-each-ref --format='%(objectname) %(refname)' "refs/remotes/$name/${topbases#heads/}" |
	while read rev ref; do
		branch="${ref#refs/remotes/$name/${topbases#heads/}/}"
		if ! git rev-parse --verify "refs/remotes/$name/$branch" -- >/dev/null 2>&1; then
			info "Skipping remote $name/${topbases#heads/}/$branch that's missing its branch"
			continue
		fi
		if git rev-parse --verify "refs/heads/$branch" -- >/dev/null 2>&1; then
			git rev-parse --verify "refs/$topbases/$branch" -- >/dev/null 2>&1 || {
				init_reflog "refs/$topbases/$branch"
				git update-ref "refs/$topbases/$branch" "$rev"
			}
			info "Skipping branch $branch: Already exists"
			continue
		fi
		info "Adding branch $branch..."
		init_reflog "refs/$topbases/$branch"
		git update-ref "refs/$topbases/$branch" "$rev"
		git update-ref "refs/heads/$branch" "$(git rev-parse --verify "$name/$branch" --)"
	done

git config "topgit.remote" "$name"
info "The remote '$name' is now the default source of topic branches."
