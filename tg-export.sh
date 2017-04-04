#!/bin/sh
# TopGit - A different patch queue manager
# (c) Petr Baudis <pasky@suse.cz>  2008
# GPLv2

name=
branches=
forcebranch=
checkout_opt=-b
output=
driver=collapse
flatten=false
numbered=false
strip=false
stripval=0
allbranches=false
binary=
pl=


## Parse options

while [ -n "$1" ]; do
	arg="$1"; shift
	case "$arg" in
	-a|--all)
		allbranches=true;;
	-b)
		branches="${branches:+$branches }$1"; shift;;
	--force)
		forcebranch=1;;
	--flatten)
		flatten=true;;
	--binary)
		binary=1;;
	--numbered)
		flatten=true
		numbered=true;;
	--strip*)
		val=${arg#*=}
		if [ "$val" = "--strip" ]; then
			strip=true
			stripval=9999
		elif [ -n "$val" -a "x$(echol "$val" | sed -e 's/[0-9]//g')" = "x" ]; then
			strip=true
			stripval=$val
		else
			die "invalid parameter $arg"
		fi;;
	--quilt)
		driver=quilt;;
	--collapse)
		driver=collapse;;
	--linearize)
		driver=linearize;;
	-*)
		echo "Usage: ${tgname:-tg} [...] export ([--collapse] <newbranch> [--force] | [-a | --all | -b <branch1>...] [--binary] --quilt <directory> | --linearize <newbranch> [--force])" >&2
		exit 1;;
	*)
		[ -z "$output" ] || die "output already specified ($output)"
		output="$arg";;
	esac
done



[ -z "$branches" -o "$driver" = "quilt" ] ||
	die "-b works only with the quilt driver"

[ "$driver" = "quilt" ] || ! "$numbered" ||
	die "--numbered works only with the quilt driver"

[ "$driver" = "quilt" ] || ! "$flatten" ||
	die "--flatten works only with the quilt driver"

[ "$driver" = "quilt" ] || [ -z "$binary" ] ||
	die "--binary works only with the quilt driver"

[ "$driver" = "quilt" ] || ! "$strip" ||
	die "--strip works only with the quilt driver"

[ "$driver" = "quilt" ] || ! "$allbranches" ||
	die "--all works only with the quilt driver"

[ -z "$branches" ] || ! "$allbranches" ||
	die "-b conflicts with the --all option"

if [ -z "$branches" ] && ! "$allbranches"; then
	# this check is only needed when no branches have been passed
	name="$(verify_topgit_branch HEAD)"
fi

if [ -n "$branches" ]; then
	oldbranches="$branches"
	branches=
	while read bname && [ -n "$bname" ]; do
		branches="${branches:+$branches }$(verify_topgit_branch "$bname")"
	done <<-EOT
	$(sed 'y/ /\n/' <<-LIST
	$oldbranches
	LIST
	)
	EOT
	unset oldbranches bname
fi

read -r nowsecs nowtzoff <<EOT
$(date '+%s %z')
EOT
playground="$(get_temp tg-export -d)"


## Collapse driver

bump_timestamp()
{
	nowsecs=$(( $nowsecs + 1 ))
}

create_tg_commit()
{
	name="$1"
	tree="$2"
	parent="$3"

	# Get commit message and authorship information
	git cat-file blob "$name:.topmsg" 2>/dev/null |
	git mailinfo "$playground/^msg" /dev/null > "$playground/^info"

	unset GIT_AUTHOR_NAME
	unset GIT_AUTHOR_EMAIL

	GIT_AUTHOR_NAME="$(sed -n '/^Author/ s/Author: //p' "$playground/^info")"
	GIT_AUTHOR_EMAIL="$(sed -n '/^Email/ s/Email: //p' "$playground/^info")"
	GIT_AUTHOR_DATE="$(sed -n '/^Date/ s/Date: //p' "$playground/^info")"
	SUBJECT="$(sed -n '/^Subject/ s/Subject: //p' "$playground/^info")"

	test -n "$GIT_AUTHOR_NAME" && export GIT_AUTHOR_NAME
	test -n "$GIT_AUTHOR_EMAIL" && export GIT_AUTHOR_EMAIL

	GIT_COMMITTER_DATE="$nowsecs $nowtzoff"
	: ${GIT_AUTHOR_DATE:=$GIT_COMMITTER_DATE}
	export GIT_AUTHOR_DATE
	export GIT_COMMITTER_DATE

	(printf '%s\n\n' "$SUBJECT"; cat "$playground/^msg") |
	git stripspace |
	git commit-tree "$tree" -p "$parent"

	unset GIT_AUTHOR_NAME
	unset GIT_AUTHOR_EMAIL
	unset GIT_AUTHOR_DATE
	unset GIT_COMMITTER_DATE
}

# collapsed_commit NAME
# Produce a collapsed commit of branch NAME.
collapsed_commit()
{
	name="$1"

	rm -f "$playground/^pre" "$playground/^post"
	>"$playground/^body"

	# Determine parent
	[ -s "$playground/$name^parents" ] || git rev-parse --verify "refs/$topbases/$name^0" -- >> "$playground/$name^parents"
	parent="$(cut -f 1 "$playground/$name^parents" 2> /dev/null |
		while read p; do [ "$(git cat-file -t "$p" 2> /dev/null)" = tag ] && git cat-file tag "$p" | head -1 | cut -d' ' -f2 || echol "$p"; done)"
	if [ $(( $(cat "$playground/$name^parents" 2>/dev/null | wc -l) )) -gt 1 ]; then
		# Produce a merge commit first
		parent="$({
			echo "TopGit-driven merge of branches:"
			echo
			cut -f 2 "$playground/$name^parents"
		} | GIT_AUTHOR_DATE="$nowsecs $nowtzoff" \
			GIT_COMMITTER_DATE="$nowsecs $nowtzoff" \
			git commit-tree "$(pretty_tree "$name" -b)" \
			$(for p in $parent; do echo "-p $p"; done))"
	fi

	if branch_empty "$name"; then
		echol "$parent"
	else
		create_tg_commit "$name" "$(pretty_tree "$name")" "$parent"
	fi

	echol "$name" >>"$playground/^ticker"
}

# collapse
# This will collapse a single branch, using information about
# previously collapsed branches stored in $playground.
collapse()
{
	if [ -s "$playground/$_dep" ]; then
		# We've already seen this dep
		commit="$(cat "$playground/$_dep")"

	elif [ -z "$_dep_is_tgish" ]; then
		# This dep is not for rewrite
		commit="$(git rev-parse --verify "refs/heads/$_dep^0" --)"

	else
		# First time hitting this dep; the common case
		echo "Collapsing $_dep"
		commit="$(collapsed_commit "$_dep")"
		bump_timestamp
		_depdn="${_dep%/}"
		case "$_depdn" in */*);;*) _depdn="./$_depdn"; esac
		mkdir -p "$playground/${_depdn%/*}"
		echol "$commit" >"$playground/$_dep"
	fi

	# Propagate our work through the dependency chain
	_namedn="${_name%/}"
	case "$_namedn" in */*);;*) _namedn="./$_namedn"; esac
	mkdir -p "$playground/${_namedn%/*}"
	echo "$commit	$_dep" >>"$playground/$_name^parents"
}


## Quilt driver

quilt()
{
	if [ -z "$_dep_is_tgish" ]; then
		# This dep is not for rewrite
		return
	fi

	_dep_tmp=$_dep

	if "$strip"; then
		i=$stripval
		while [ "$i" -gt 0 ]; do
			[ "$_dep_tmp" = "${_dep_tmp#*/}" ] && break
			_dep_tmp=${_dep_tmp#*/}
			i=$((i - 1))
		done
	fi

	dn="${_dep_tmp%/}.diff"
	case "$dn" in */*);;*) dn="./$dn"; esac
	bn="${dn##*/}"
	dn="${dn%/*}/"
	[ "x$dn" = "x./" ] && dn=""

	if "$flatten" && [ "$dn" ]; then
		bn="$(echo "$_dep_tmp.diff" | sed -e 's#_#__#g' -e 's#/#_#g')"
		dn=""
	fi

	unset _dep_tmp

	if [ -e "$playground/$_dep" ]; then
		# We've already seen this dep
		return
	fi

	_depdn="${_dep%/}"
	case "$_depdn" in */*);;*) _depdn="./$_depdn"; esac
	mkdir -p "$playground/${_depdn%/*}"
	>>"$playground/$_dep"

	if branch_empty "$_dep"; then
		echo "Skip empty patch $_dep"
	else
		if "$numbered"; then
			number="$(echo $(($(cat "$playground/^number" 2>/dev/null) + 1)))"
			bn="$(printf "%04u-$bn" $number)"
			echo "$number" >"$playground/^number"
		fi

		echo "Exporting $_dep"
		mkdir -p "$output/$dn"
		tg patch ${binary:+--binary} "$_dep" >"$output/$dn$bn"
		echol "$dn$bn -p1" >>"$output/series"
	fi
}

linearize()
{
	if test ! -f "$playground/^BASE"; then
		if [ -n "$_dep_is_tgish" ]; then
			head="$(git rev-parse --verify "refs/$topbases/$_dep^0" --)"
		else
			head="$(git rev-parse --verify "refs/heads/$_dep^0" --)"
		fi
		echol "$head" > "$playground/^BASE"
		git checkout -q $iowopt "$head"
		[ -n "$_dep_is_tgish" ] || return 0
	fi

	head=$(git rev-parse --verify HEAD --)

	if [ -z "$_dep_is_tgish" ]; then
		# merge in $_dep unless already included
		rev="$(git rev-parse --verify "refs/heads/$_dep^0" --)"
		common="$(git merge-base --all HEAD "$rev")" || :
		if test "$rev" = "$common"; then
			# already included, just skip
			:
		else
			retmerge=0

			git merge $auhopt -m "tgexport: merge $_dep into base" -s recursive "refs/heads/$_dep^0" || retmerge="$?"
			if test "x$retmerge" != "x0"; then
				echo "fix up the merge, commit and then exit."
				#todo error handling
				"${SHELL:-@SHELL_PATH@}" -i </dev/tty
			fi
		fi
	else
		retmerge=0

		git merge-recursive "$(pretty_tree "$_dep" -b)" -- HEAD "$(pretty_tree "$_dep")" || retmerge="$?"

		if test "x$retmerge" != "x0"; then
			git rerere
			echo "fix up the merge, update the index and then exit.  Don't commit!"
			#todo error handling
			"${SHELL:-@SHELL_PATH@}" -i </dev/tty
			git rerere
		fi

		result_tree=$(git write-tree)
		# testing branch_empty might not always give the right answer.
		# It can happen that the patch is non-empty but still after
		# linearizing there is no change.  So compare the trees.
		if test "x$result_tree" = "x$(git rev-parse --verify $head^{tree} --)"; then
			echo "skip empty commit $_dep"
		else
			newcommit=$(create_tg_commit "$_dep" "$result_tree" HEAD)
			bump_timestamp
			git update-ref HEAD $newcommit $head
			echo "exported commit $_dep"
		fi
	fi
}

## Machinery

if [ "$driver" = "collapse" ] || [ "$driver" = "linearize" ]; then
	[ -n "$output" ] ||
		die "no target branch specified"
	if ! ref_exists "refs/heads/$output"; then
		:
	elif [ -z "$forcebranch" ]; then
		die "target branch '$output' already exists; first run: git$gitcdopt branch -D $output, or run $tgdisplay export with --force"
	else
		checkout_opt=-B
	fi
	ensure_ident_available

elif [ "$driver" = "quilt" ]; then
	[ -n "$output" ] ||
		die "no target directory specified"
	[ ! -e "$output" ] ||
		die "target directory already exists: $output"

	mkdir -p "$output"
fi


driver()
{
	# FIXME should we abort on missing dependency?
	[ -z "$_dep_missing" ] || return 0

	[ -z "$_dep_is_tgish" ] || [ -z "$_dep_annihilated" ] || return 0

	case $_dep in refs/remotes/*) return;; esac
	branch_needs_update >/dev/null
	[ "$_ret" -eq 0 ] ||
		die "cancelling export of $_dep (-> $_name): branch not up-to-date"

	$driver
}

# Call driver on all the branches - this will happen
# in topological order.
if "$allbranches" ; then
	_dep_is_tgish=1
	non_annihilated_branches |
		while read _dep; do
			driver
		done
	test $? -eq 0
elif [ -z "$branches" ]; then
	recurse_deps driver "$name"
	(_ret=0; _dep="$name"; _name=; _dep_is_tgish=1; _dep_missing=; driver)
	test $? -eq 0
else
	while read _dep && [ -n "$_dep" ]; do
		_dep_is_tgish=1
		$driver
	done <<-EOT
	$(sed 'y/ /\n/' <<-LIST
	$branches
	LIST
	)
	EOT
	name="$branches"
	case "$branches" in *" "*) pl="es"; esac
fi


if [ "$driver" = "collapse" ]; then
	cmd='git update-ref "refs/heads/$output" "$(cat "$playground/$name")"'
	[ -n "$forcebranch" ] || cmd="$cmd \"\""
	eval "$cmd"

	depcount=$(( $(cat "$playground/^ticker" | wc -l) ))
	echo "Exported topic branch $name (total $depcount topics) to branch $output"

elif [ "$driver" = "quilt" ]; then
	depcount=$(( $(cat "$output/series" | wc -l) ))
	echo "Exported topic branch$pl $name (total $depcount topics) to directory $output"

elif [ "$driver" = "linearize" ]; then
	git checkout -q $iowopt $checkout_opt $output

	echol "$name"
	if test $(git rev-parse --verify "$(pretty_tree "$name")^{tree}" --) != $(git rev-parse --verify "HEAD^{tree}" --); then
		echo "Warning: Exported result doesn't match"
		echo "tg-head=$(git rev-parse --verify "refs/heads/$name" --), exported=$(git rev-parse --verify "HEAD" --)"
		#git diff $head HEAD
	fi

fi

# vim:noet
