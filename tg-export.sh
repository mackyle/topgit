#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) 2008 Petr Baudis <pasky@suse.cz>
# Copyright (C) 2015-2021 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved
# GPLv2

USAGE="\
Usage: ${tgname:-tg} [...] export [--collapse] [--force] [<option>...] <newbranch>
   Or: ${tgname:-tg} [...] export --linearize [--force] [<option>...] <newbranch>
   Or: ${tgname:-tg} [...] export --quilt [--force] [-a | --all | -b <branch>...]
                [--binary] [--flatten] [--numbered] [--strip[=N]] <directory>
Options:
    -s <mode>           set subject bracketed [strings] strip mode
    --notes[=<ref>]     export .topmsg --- comment to notes ref <ref>
    --no-notes          discard .topmsg --- comment"

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
branches=
forceoutput=
checkout_opt=-b
output=
driver=collapse
flatten=
numbered=
strip=
stripval=0
smode=
allbranches=
binary=
notesflag=
notesref=
pl=

## Parse options

while [ -n "$1" ]; do
	arg="$1"; shift
	case "$arg" in
	-h|--help)
		usage;;
	-a|--all)
		allbranches=1;;
	-b)
		branches="${branches:+$branches }$1"; shift;;
	--force)
		forceoutput=1;;
	--flatten)
		flatten=1;;
	--binary)
		binary=1;;
	--numbered)
		flatten=1
		numbered=1;;
	--strip*)
		val=${arg#*=}
		if [ "$val" = "--strip" ]; then
			strip=1
			stripval=9999
		elif [ -n "$val" ] && [ "${val#*[!0-9]}" = "$val" ]; then
			strip=1
			stripval="$val"
		else
			die "invalid --strip parameter $arg"
		fi;;
	--notes*)
		val="${arg#*=}"
		if [ "$val" = "--notes" ]; then
			notesflag=1
			notesref="refs/notes/commits"
		elif [ -n "$val" ] && [ "${val#-}" = "$val" ]; then
			case "$val" in
			refs/notes/*) checknref="$val";;
			notes/*) checknref="refs/$val";;
			*) checknref="refs/notes/$val";;
			esac
			git check-ref-format "$checknref" >/dev/null 2>&1 ||
				die "invalid --notes parameter $arg"
			notesflag=1
			notesref="$checknref"
		else
			die "invalid --notes parameter $arg"
		fi;;
	--no-notes)
		notesflag=0
		notesref=;;
	-s)
		test $# -gt 0 && test -n "$1" || die "-s requires an argument"
		smode="$1"; shift;;
	--quilt)
		driver=quilt;;
	--collapse)
		driver=collapse;;
	--linearize)
		driver=linearize;;
	-*)
		usage 1;;
	*)
		[ -z "$output" ] || die "output already specified ($output)"
		output="$arg";;
	esac
done

[ -z "$smode" ] || [ "$driver" != "quilt" ] ||
	die "-s works only with the collapse/linearize driver"

[ "${notesflag:-0}" = "0" ] || [ "$driver" != "quilt" ] ||
	die "--notes works only with the collapse/linearize driver"

if [ "$driver" != "quilt" ]; then
	test -n "$smode" || smode="$(git config topgit.subjectmode)" || :
	case "${smode:-tg}" in
		tg) smode="topgit";;
		ws) smode="trim";;
		topgit|patch|mailinfo|trim|keep);;
		*) die "invalid subject mode: $smode"
	esac
	if [ -z "$notesflag" ]; then
		if notesflag="$(git config --bool --get topgit.notesexport 2>/dev/null)"; then
			case "$notesflag" in
			true) notesflag=1; notesref="refs/notes/commits";;
			false) notesflag=0; notesref=;;
			esac
		elif
			notesflag="$(git config --get topgit.notesexport 2>/dev/null)" &&
			test -n "$notesflag"
		then
			case "$notesflag" in
			"-"*) checknref="$notesflag";;
			refs/notes/*) checknref="$notesflag";;
			notes/*) checknref="refs/$notesflag";;
			*) checknref="refs/notes/$notesflag";;
			esac
			git check-ref-format "$checknref" >/dev/null 2>&1 ||
				die "invalid topgit.notesExport config setting \"$notesflag\""
			notesflag=1
			notesref="$checknref"
		fi
	fi
fi

[ -z "$branches" ] || [ "$driver" = "quilt" ] ||
	die "-b works only with the quilt driver"

[ "$driver" = "quilt" ] || [ -z "$numbered" ] ||
	die "--numbered works only with the quilt driver"

[ "$driver" = "quilt" ] || [ -z "$flatten" ] ||
	die "--flatten works only with the quilt driver"

[ "$driver" = "quilt" ] || [ -z "$binary" ] ||
	die "--binary works only with the quilt driver"

[ "$driver" = "quilt" ] || [ -z "$strip" ] ||
	die "--strip works only with the quilt driver"

[ "$driver" = "quilt" ] || [ -z "$allbranches" ] ||
	die "--all works only with the quilt driver"

[ -z "$branches" ] || [ -z "$allbranches" ] ||
	die "-b conflicts with the --all option"

if [ "$driver" = "linearize" ]; then
	setup_git_dir_is_bare
	if [ -n "$git_dir_is_bare" ]; then
		fatal 'export --linearize does not work on a bare repository...yet!'
		fatal '(but you can use `tg -w : export --linearize` instead for now)'
		ensure_work_tree
	fi
fi

if [ -z "$branches" ] && [ -z "$allbranches" ]; then
	# this check is only needed when no branches have been passed
	v_verify_topgit_branch name HEAD
fi

if [ -n "$branches" ]; then
	oldbranches="$branches"
	branches=
	while read bname && [ -n "$bname" ]; do
		v_verify_topgit_branch bname "$bname"
		branches="${branches:+$branches }$bname"
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

setup_smode()
{
	mik=
	test z"$smode" = z"mailinfo" || { mik=-k &&
	test z"$smode" = z"keep"; } ||
	sprefix="$(git config topgit.subjectprefix)" || :
}

create_tg_commit()
{
	name="$1"
	tree="$2"
	parent="$3"

	# Get commit message and authorship information
	git cat-file blob "$name:.topmsg" 2>/dev/null |
	awk -v nf="$playground/^notes" '
		BEGIN {m=0; printf "%s", "" >nf}
		m {print >nf; next}
		/^---[ \t]*$/ {m=1; next}
		{print}
		END {close(nf)}
	' | git mailinfo $mik "$playground/^msg" /dev/null > "$playground/^info"
	if
		[ "${notesflag:-0}" = "1" ] && [ -n "$notesref" ] &&
		[ -s "$playground/^notes" ]
	then
		git stripspace <"$playground/^notes" >"$playground/^notes,"
		mv -f "$playground/^notes," "$playground/^notes"
	fi

	unset GIT_AUTHOR_NAME
	unset GIT_AUTHOR_EMAIL

	GIT_AUTHOR_NAME="$(sed -n "/^Author/ s/Author:[ $tab]*//p" "$playground/^info")"
	GIT_AUTHOR_EMAIL="$(sed -n "/^Email/ s/Email:[ $tab]*//p" "$playground/^info")"
	GIT_AUTHOR_DATE="$(sed -n "/^Date/ s/Date:[ $tab]*//p" "$playground/^info")"
	SUBJECT="$(sed -n "/^Subject/ s/Subject:[ $tab]*//p" "$playground/^info")"
	if test z"$smode" != z"mailinfo" && test z"$smode" != z"keep"; then
		SUBJECT="$(printf '%s\n' "$SUBJECT" |
		awk -v mode="$smode" -v prefix="$sprefix" '{
			gsub(/[ \t]+/, " ")
			sub(/^[ \t]+/, "")
			sub(/[ \t]+$/, "")
			if (mode != "trim") {
				if (prefix != "" &&
				    tolower(substr($0, 1, (lp = 1 + length(prefix)))) == "[" tolower(prefix) &&
				    index($0, "]")) {
					if (substr($0, 1 + lp, 1) == " ") ++lp
					lead = tolower(substr($0, 1 + lp, 8))
					if (lead ~ /^patch/ || (mode == "topgit" &&
					    lead ~ /^(base|root|stage|release)\]/))
						$0 = "[" substr($0, 1 + lp)
				}
				if (!sub(/^\[[Pp][Aa][Tt][Cc][Hh][^]]*\][ \t]*/, "") &&
				    mode == "topgit")
					sub(/^\[([Bb][Aa][Ss][Ee]|[Rr][Oo][Oo][Tt]|[Ss][Tt][Aa][Gg][Ee]|[Rr][Ee][Ll][Ee][Aa][Ss][Ee])\][ \t]*/, "")
			}
			print
			exit
		}')"
	fi

	test -n "$GIT_AUTHOR_NAME" && export GIT_AUTHOR_NAME
	test -n "$GIT_AUTHOR_EMAIL" && export GIT_AUTHOR_EMAIL

	GIT_COMMITTER_DATE="$nowsecs $nowtzoff"
	: ${GIT_AUTHOR_DATE:=$GIT_COMMITTER_DATE}
	export GIT_AUTHOR_DATE
	export GIT_COMMITTER_DATE

	_cmttreecmd='{
		printf "%s\n\n" "${SUBJECT:-$name}"
		cat "$playground/^msg"
	} | git stripspace |
	git commit-tree "$tree" -p "$parent"'

	if
		[ "${notesflag:-0}" = "1" ] && [ -n "$notesref" ] &&
		[ -s "$playground/^notes" ]
	then
		_notesblob="$(git hash-object -t blob -w --stdin <"$playground/^notes")"
		_cmtnew="$(eval "$_cmttreecmd")"
		git notes --ref="$notesref" add -f -C "$_notesblob" "$_cmtnew" >/dev/null 2>&1 || :
		printf '%s\n' "$_cmtnew"
	else
		eval "$_cmttreecmd"
	fi

	unset GIT_AUTHOR_NAME
	unset GIT_AUTHOR_EMAIL
	unset GIT_AUTHOR_DATE
	unset GIT_COMMITTER_DATE
}

v_get_p_arg_list()
{
	_vname="$1"
	shift
	eval "$_vname="
	while [ $# -gt 0 ]; do
		[ -z "$1" ] || eval "$_vname=\"\${$_vname:+\$$_vname }-p \$1\""
		shift
	done
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
		while read -r p; do git rev-parse --quiet --verify "$p^0" -- || :; done)"
	if [ $(( $(cat "$playground/$name^parents" 2>/dev/null | wc -l) )) -gt 1 ]; then
		# Produce a merge commit first
		v_pretty_tree prtytree "$name" -b
		v_get_p_arg_list plist $parent
		parent="$({
			echo "TopGit-driven merge of branches:"
			echo
			cut -f 2 "$playground/$name^parents"
		} | GIT_AUTHOR_DATE="$nowsecs $nowtzoff" \
			GIT_COMMITTER_DATE="$nowsecs $nowtzoff" \
			git commit-tree "$prtytree" $plist)"
	fi

	if branch_empty "$name"; then
		echol "$parent"
	else
		v_pretty_tree prtytree "$name"
		create_tg_commit "$name" "$prtytree" "$parent"
	fi

	echol "$name" >>"$playground/^ticker"
}

# collapse
# This will collapse a single branch, using information about
# previously collapsed branches stored in $playground.
collapse()
{
	if [ -s "$playground/$_dep^commit" ]; then
		# We've already seen this dep
		commit="$(cat "$playground/$_dep^commit")"

	elif [ -z "$_dep_is_tgish" ]; then
		# This dep is not for rewrite
		commit="$(git rev-parse --verify "refs/heads/$_dep^0" --)"

	else
		# First time hitting this dep; the common case
		echo "Collapsing $_dep"
		test -d "$playground/${_dep%/*}" || mkdir -p "$playground/${_dep%/*}"
		commit="$(collapsed_commit "$_dep")"
		bump_timestamp
		echol "$commit" >"$playground/$_dep^commit"
	fi

	# Propagate our work through the dependency chain
	test -d "$playground/${_name%/*}" || mkdir -p "$playground/${_name%/*}"
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

	if [ -n "$strip" ]; then
		i="$stripval"
		while [ "$i" -gt 0 ]; do
			[ "$_dep_tmp" = "${_dep_tmp#*/}" ] && break
			_dep_tmp=${_dep_tmp#*/}
			i="$(( $i - 1 ))"
		done
	fi

	dn="${_dep_tmp%/}.diff"
	case "$dn" in */*);;*) dn="./$dn"; esac
	bn="${dn##*/}"
	dn="${dn%/*}/"
	[ "x$dn" = "x./" ] && dn=""

	if [ -n "$flatten" ] && [ "$dn" ]; then
		bn="$(echo "$_dep_tmp.diff" | sed -e 's#_#__#g' -e 's#/#_#g')"
		dn=""
	fi

	unset _dep_tmp

	if [ -e "$playground/$_dep^commit" ]; then
		# We've already seen this dep
		return
	fi

	test -d "$playground/${_dep%/*}" || mkdir -p "$playground/${_dep%/*}"
	>>"$playground/$_dep^commit"

	if branch_empty "$_dep"; then
		echo "Skip empty patch $_dep"
	else
		if [ -n "$numbered" ]; then
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

		v_pretty_tree _deptree "$_dep"
		v_pretty_tree _depbasetree "$_dep" -b
		git merge-recursive "$_depbasetree" -- HEAD "$_deptree" || retmerge="$?"

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

wayback_push=
if [ "$driver" = "collapse" ] || [ "$driver" = "linearize" ]; then
	[ -n "$output" ] ||
		die "no target branch specified"
	if ! ref_exists "refs/heads/$output"; then
		:
	elif [ -z "$forceoutput" ]; then
		die "target branch '$output' already exists; first run: git$gitcdopt branch -D $output, or run $tgdisplay export with --force"
	else
		checkout_opt=-B
	fi
	ensure_ident_available
	setup_smode
	[ -z "$wayback" ] || wayback_push="$(git config --get remote.wayback.url 2>/dev/null)" || :
	[ -z "$wayback" ] || [ -n "$wayback_push" ] || die "failed to configure wayback export"

elif [ "$driver" = "quilt" ]; then
	[ -n "$output" ] ||
		die "no target directory specified"
	[ -n "$forceoutput" ] || [ ! -e "$output" ] || is_empty_dir "$output" . ||
		die "non-empty target directory already exists (use --force to override): $output"

	mkdir -p "$output"
fi


driver()
{
	# FIXME should we abort on missing dependency?
	[ -z "$_dep_missing" ] || return 0

	[ -z "$_dep_is_tgish" ] || [ -z "$_dep_annihilated" ] || return 0

	case $_dep in ":"*) return; esac
	branch_needs_update >/dev/null
	[ "$_ret" -eq 0 ] ||
		die "cancelling export of $_dep (-> $_name): branch not up-to-date"

	$driver
}

# Call driver on all the branches - this will happen
# in topological order.
if [ -n "$allbranches" ]; then
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
	cmd='git update-ref "refs/heads/$output" "$(cat "$playground/$name^commit")"'
	[ -n "$forceoutput" ] || cmd="$cmd \"\""
	eval "$cmd"
	[ -z "$wayback_push" ] || git -c "remote.wayback.url=$wayback_push" push -q ${forceoutput:+--force} wayback "refs/heads/$output:refs/heads/$output"

	depcount=$(( $(cat "$playground/^ticker" | wc -l) ))
	echo "Exported topic branch $name (total $depcount topics) to branch $output"

elif [ "$driver" = "quilt" ]; then
	depcount=$(( $(cat "$output/series" | wc -l) ))
	echo "Exported topic branch$pl $name (total $depcount topics) to directory $output"

elif [ "$driver" = "linearize" ]; then
	git checkout -q --no-track $iowopt $checkout_opt $output
	[ -z "$wayback_push" ] || git -c "remote.wayback.url=$wayback_push" push -q ${forceoutput:+--force} wayback "refs/heads/$output:refs/heads/$output"

	echol "$name"
	v_pretty_tree nametree "$name"
	if test $(git rev-parse --verify "$nametree^{tree}" --) != $(git rev-parse --verify "HEAD^{tree}" --); then
		echo "Warning: Exported result doesn't match"
		echo "tg-head=$(git rev-parse --verify "refs/heads/$name" --), exported=$(git rev-parse --verify "HEAD" --)"
		#git diff $head HEAD
	fi

fi
ec=$?
tmpdir_cleanup || :
git gc --auto || :
exit $ec
