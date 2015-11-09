#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) Petr Baudis <pasky@suse.cz>  2008
# Copyright (C) Kyle J. McKay <mackyle@gmail.com>  2015
# All rights reserved.
# GPLv2

terse=
graphviz=
sort=
deps=
depsonly=
rdeps=
head_from=
branches=
head=
exclude=

## Parse options

usage()
{
	echo "Usage: ${tgname:-tg} [...] summary [-t | --list | --sort | --deps | --deps-only | --rdeps | --graphviz] [-i | -w] [--exclude branch]... [--all | branch...]" >&2
	exit 1
}

while [ -n "$1" ]; do
	arg="$1"
	case "$arg" in
	-i|-w)
		[ -z "$head_from" ] || die "-i and -w are mutually exclusive"
		head_from="$arg";;
	-t|--list|-l)
		terse=1;;
	--graphviz)
		graphviz=1;;
	--sort)
		sort=1;;
	--deps)
		deps=1;;
	--deps-only)
		head=HEAD
		depsonly=1;;
	--rdeps)
		head=HEAD
		rdeps=1;;
	--all)
		break;;
	--exclude=*)
		[ -n "${1#--exclude=}" ] || die "--exclude= requires a branch name"
		exclude="$exclude ${1#--exclude=}";;
	--exclude)
		shift
		[ -n "$1" -a "$1" != "--all" ] || die "--exclude requires a branch name"
		exclude="$exclude $1";;
	-*)
		usage;;
	*)
		break;;
	esac
	shift
done
[ -z "$exclude" ] || exclude="$exclude "
if [ "$1" = "--all" ]; then
      [ $# -eq 1 ] || usage
      shift
      head=
fi
[ $# -ne 0 -o -z "$head" ] || set -- "$head"

[ "$terse$graphviz$sort$deps$depsonly" = "" ] ||
	[ "$terse$graphviz$sort$deps$depsonly$rdeps" = "1" ] ||
	die "mutually exclusive options given"

for b; do
	[ "$b" != "--all" ] || usage
	branches="$branches $(verify_topgit_branch "$b")"
done

get_branch_list()
{
	if [ -n "$branches" ]; then
		printf '%s\n' $branches
	else
		non_annihilated_branches
	fi
}

show_dep() {
	case "$exclude" in *" $_dep "*) return; esac
	case " $seen_deps " in *" $_dep "*) return 0; esac
	seen_deps="${seen_deps:+$seen_deps }$_dep"
	printf '%s\n' "$_dep"
}

show_deps()
{
	no_remotes=1
	recurse_deps_exclude=
	get_branch_list | while read _b; do
		case "$exclude" in *" $_b "*) continue; esac
		case " $recurse_deps_exclude " in *" $_b "*) continue; esac
		seen_deps=
		_dep="$_b"; _dep_is_tgish=1; show_dep
		recurse_deps show_dep "$_b"
		recurse_deps_exclude="$recurse_deps_exclude $seen_deps"
	done
}

if [ -n "$depsonly" ]; then
	show_deps | LC_ALL=C sort -u -b -k1,1
	exit 0
fi

show_rdeps()
{
	case "$exclude" in *" $_dep "*) return; esac
	printf '%s %s\n' "$_depchain" "$_dep"
}

if [ -n "$rdeps" ]; then
	no_remotes=1
	showbreak=
	get_branch_list |
		while read b; do
			case "$exclude" in *" $b "*) continue; esac
			[ -z "$showbreak" ] || echo
			showbreak=1 
			ref_exists "refs/heads/$b" || continue
			{
				echo "$b"
				recurse_preorder=1
				recurse_deps show_rdeps "$b"
			} | sed -e 's/[^ ][^ ]*[ ]/  /g'
		done
	exit 0
fi

curname="$(strip_ref "$(git symbolic-ref HEAD 2>/dev/null)")"

if [ -n "$graphviz" ]; then
	cat <<EOT
# GraphViz output; pipe to:
#   | dot -Tpng -o <output>
# or
#   | dot -Txlib

digraph G {

graph [
  rankdir = "TB"
  label="TopGit Layout\n\n\n"
  fontsize = 14
  labelloc=top
  pad = "0.5,0.5"
];

EOT
fi

if [ -n "$sort" ]; then
	tsort_input="$(get_temp tg-summary-sort)"
	exec 4>$tsort_input
	exec 5<$tsort_input
fi

## List branches

process_branch()
{
	missing_deps=

	current=' '
	[ "$name" != "$curname" ] || current='>'
	from=$head_from
	[ "$name" = "$curname" ] ||
		from=
	nonempty=' '
	! branch_empty "$name" $from || nonempty='0'
	remote=' '
	[ -z "$base_remote" ] || remote='l'
	! has_remote "$name" || remote='r'
	rem_update=' '
	[ "$remote" != 'r' ] || ! ref_exists "refs/remotes/$base_remote/top-bases/$name" || {
		branch_contains "refs/top-bases/$name" "refs/remotes/$base_remote/top-bases/$name" &&
		branch_contains "refs/heads/$name" "refs/remotes/$base_remote/$name"
	} || rem_update='R'
	[ "$remote" != 'r' -o "$rem_update" = 'R' ] || {
		branch_contains "refs/remotes/$base_remote/$name" "refs/heads/$name" 2>/dev/null
	} || rem_update='L'
	deps_update=' '
	needs_update "$name" >/dev/null || deps_update='D'
	deps_missing=' '
	[ -z "$missing_deps" ] || deps_missing='!'
	base_update=' '
	branch_contains "refs/heads/$name" "refs/top-bases/$name" || base_update='B'

	if [ "$(ref_exists_rev "refs/heads/$name")" != "$(ref_exists_rev "refs/top-bases/$name")" ]; then
		subject="$(cat_file "refs/heads/$name:.topmsg" $from | sed -n 's/^Subject: //p')"
	else
		# No commits yet
		subject="(No commits)"
	fi

	printf '%s\t%-31s\t%s\n' "$current$nonempty$remote$rem_update$deps_update$deps_missing$base_update" \
		"$name" "$subject"
}

if [ -n "$deps" ]; then
	if [ -n "$branches" ]; then
		get_branch_list |
			while read b; do
				case "$exclude" in *" $b "*) continue; esac
				list_deps $head_from $b |
					while read name dep; do
						case "$exclude" in *" $dep "*) continue; esac
						echo "$name $dep"
					done
			done
	else
		list_deps $head_from |
			while read name dep; do
				case "$exclude" in *" $dep "*) continue; esac
				echo "$name $dep"
			done
	fi
	exit 0
fi

get_branch_list |
	while read name; do
		case "$exclude" in *" $name "*) continue; esac
		if [ -n "$terse" ]; then
			echo "$name"
		elif [ -n "$graphviz$sort" ]; then
			from=$head_from
			[ "$name" = "$curname" ] ||
				from=
			cat_file "refs/heads/$name:.topdeps" $from | while read dep; do
				dep_is_tgish=true
				ref_exists "refs/top-bases/$dep" ||
					dep_is_tgish=false
				if ! "$dep_is_tgish" || ! branch_annihilated $dep; then
					if [ -n "$graphviz" ]; then
						echo "\"$name\" -> \"$dep\";"
						if [ "$name" = "$curname" ] || [ "$dep" = "$curname" ]; then
							echo "\"$curname\" [style=filled,fillcolor=yellow];"
						fi
					else
						echo "$name $dep" >&4
					fi
				fi
			done
		else
			process_branch
		fi
	done

if [ -n "$graphviz" ]; then
	echo '}'
fi

if [ -n "$sort" ]; then
	tsort <&5
fi


# vim:noet
