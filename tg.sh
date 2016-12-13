#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) Petr Baudis <pasky@suse.cz>  2008
# Copyright (C) Kyle J. McKay <mackyle@gmail.com>  2014,2015,2016
# All rights reserved.
# GPLv2

TG_VERSION=0.19.4

# Update if you add any code that requires a newer version of git
GIT_MINIMUM_VERSION=1.8.5

## SHA-1 pattern

octet='[0-9a-f][0-9a-f]'
octet4="$octet$octet$octet$octet"
octet19="$octet4$octet4$octet4$octet4$octet$octet$octet"
octet20="$octet4$octet4$octet4$octet4$octet4"
nullsha="0000000000000000000000000000000000000000"

## Auxiliary functions

# Preserves current $? value while triggering a non-zero set -e exit if active
# This works even for shells that sometimes fail to correctly trigger a -e exit
check_exit_code()
{
	return $?
}

# Output arguments without any possible interpretation
# (Avoid misinterpretation of '\' characters or leading "-n", "-E" or "-e")
echol()
{
	printf '%s\n' "$*"
}

info()
{
	echol "${TG_RECURSIVE}${tgname:-tg}: $*"
}

warn()
{
	info "warning: $*" >&2
}

err()
{
	info "error: $*" >&2
}

die()
{
	info "fatal: $*" >&2
	exit 1
}

wc_l()
{
	echo $(wc -l)
}

vcmp()
{
	# Compare $1 to $2 each of which must match \d+(\.\d+)*
	# An empty string ('') for $1 or $2 is treated like 0
	# Outputs:
	#  -1 if $1 < $2
	#   0 if $1 = $2
	#   1 if $1 > $2
	# Note that `vcmp 1.8 1.8.0.0.0.0` correctly outputs 0.
	while
		_a="${1%%.*}"
		_b="${2%%.*}"
		[ -n "$_a" -o -n "$_b" ]
	do
		if [ "${_a:-0}" -lt "${_b:-0}" ]; then
			echo -1
			return
		elif [ "${_a:-0}" -gt "${_b:-0}" ]; then
			echo 1
			return
		fi
		_a2="${1#$_a}"
		_b2="${2#$_b}"
		set -- "${_a2#.}" "${_b2#.}"
	done
	echo 0
}

precheck() {
	if ! git_version="$(git version)"; then
		die "'git version' failed"
	fi
	case "$git_version" in
		[Gg]"it version "*) :;;
		*)
			die "'git version' output does not start with 'git version '"
	esac
	git_vernum="$(echo "$git_version" | sed -ne 's/^[^0-9]*\([0-9][0-9]*\(\.[0-9][0-9]*\)*\).*$/\1/p')"

	[ "$(vcmp "$git_vernum" $GIT_MINIMUM_VERSION)" -ge 0 ] ||
		die "git version >= $GIT_MINIMUM_VERSION required but found git version $git_vernum instead"
}

case "$1" in version|--version|-V)
	echo "TopGit version $TG_VERSION"
	exit 0
esac

precheck
[ "$1" = "precheck" ] && exit 0


cat_depsmsg_internal()
{
	_rev="$(ref_exists_rev "refs/heads/$1")" || return 0
	if [ -s "$tg_cache_dir/$1/.$2" ]; then
		if read _rev_match && [ "$_rev" = "$_rev_match" ]; then
			_line=
			while IFS= read -r _line || [ -n "$_line" ]; do
				printf '%s\n' "$_line"
			done
			return 0
		fi <"$tg_cache_dir/$1/.$2"
	fi
	[ -d "$tg_cache_dir/$1" ] || mkdir -p "$tg_cache_dir/$1" 2>/dev/null || :
	if [ -d "$tg_cache_dir/$1" ]; then
		printf '%s\n' "$_rev" >"$tg_cache_dir/$1/.$2"
		_line=
		git cat-file blob "$_rev:.$2" 2>/dev/null |
		while IFS= read -r _line || [ -n "$_line" ]; do
			printf '%s\n' "$_line" >&3
			printf '%s\n' "$_line"
		done 3>>"$tg_cache_dir/$1/.$2"
	else
		git cat-file blob "$_rev:.$2" 2>/dev/null
	fi
}

# cat_deps BRANCHNAME
# Caches result
cat_deps()
{
	cat_depsmsg_internal "$1" topdeps
}

# cat_msg BRANCHNAME
# Caches result
cat_msg()
{
	cat_depsmsg_internal "$1" topmsg
}

# cat_file TOPIC:PATH [FROM]
# cat the file PATH from branch TOPIC when FROM is empty.
# FROM can be -i or -w, than the file will be from the index or worktree,
# respectively. The caller should than ensure that HEAD is TOPIC, to make sense.
cat_file()
{
	path="$1"
	case "$2" in
	-w)
		cat "$root_dir/${path#*:}"
		;;
	-i)
		# ':file' means cat from index
		git cat-file blob ":${path#*:}"
		;;
	'')
		case "$path" in
		refs/heads/*:.topdeps)
			_temp="${path%:.topdeps}"
			cat_deps "${_temp#refs/heads/}"
			;;
		refs/heads/*:.topmsg)
			_temp="${path%:.topmsg}"
			cat_msg "${_temp#refs/heads/}"
			;;
		*)
			git cat-file blob "$path"
			;;
		esac
		;;
	*)
		die "Wrong argument to cat_file: '$2'"
		;;
	esac
}

# get tree for the committed topic
get_tree_()
{
	echo "refs/heads/$1"
}

# get tree for the base
get_tree_b()
{
	echo "refs/$topbases/$1"
}

# get tree for the index
get_tree_i()
{
	git write-tree
}

# get tree for the worktree
get_tree_w()
{
	i_tree=$(git write-tree)
	(
		# the file for --index-output needs to sit next to the
		# current index file
		cd "$root_dir"
		: ${GIT_INDEX_FILE:="$git_dir/index"}
		TMP_INDEX="$(mktemp "${GIT_INDEX_FILE}-tg.XXXXXX")"
		git read-tree -m $i_tree --index-output="$TMP_INDEX" &&
		GIT_INDEX_FILE="$TMP_INDEX" &&
		export GIT_INDEX_FILE &&
		git diff --name-only -z HEAD |
			git update-index -z --add --remove --stdin &&
		git write-tree &&
		rm -f "$TMP_INDEX"
	)
}

# strip_ref "$(git symbolic-ref HEAD)"
# Output will have a leading refs/heads/ or refs/$topbases/ stripped if present
strip_ref()
{
	case "$1" in
		refs/heads/*)
			echol "${1#refs/heads/}"
			;;
		refs/"$topbases"/*)
			echol "${1#refs/$topbases/}"
			;;
		*)
			echol "$1"
	esac
}

# pretty_tree NAME [-b | -i | -w]
# Output tree ID of a cleaned-up tree without tg's artifacts.
# NAME will be ignored for -i and -w, but needs to be present
pretty_tree()
{
	name=$1
	source=${2#?}
	git ls-tree --full-tree "$(get_tree_$source "$name")" |
		LC_ALL=C sed -ne '/	\.top.*$/!p' |
		git mktree
}

# return an empty-tree root commit -- date is either passed in or current
# If passed in "$*" must be epochsecs followed by optional hhmm offset (+0000 default)
# An invalid secs causes the current date to be used, an invalid zone offset
# causes +0000 to be used
make_empty_commit()
(
	# the empty tree is guaranteed to always be there even in a repo with
	# zero objects, but for completeness we force it to exist as a real object
	SECS=
	read -r SECS ZONE JUNK <<-EOT || :
		$*
		EOT
	case "$SECS" in *[!0-9]*) SECS=; esac
	if [ -z "$SECS" ]; then
		MTDATE="$(date '+%s %z')"
	else
		case "$ZONE" in
			-[01][0-9][0-5][0-9]|+[01][0-9][0-5][0-9])
				:;;
			[01][0-9][0-5][0-9])
				ZONE="+$ZONE"
				;;
			*)
				ZONE="+0000"
		esac
		MTDATE="$SECS $ZONE"
	fi
	EMPTYID="- <-> $MTDATE"
	EMPTYTREE="$(git hash-object -t tree -w --stdin < /dev/null)"
	printf '%s\n' "tree $EMPTYTREE" "author $EMPTYID" "committer $EMPTYID" '' |
	git hash-object -t commit -w --stdin
)

# setup_hook NAME
setup_hook()
{
	tgname="$(basename "$0")"
	hook_call="\"\$(\"$tgname\" --hooks-path)\"/$1 \"\$@\""
	if [ -f "$git_dir/hooks/$1" ] && fgrep -q "$hook_call" "$git_dir/hooks/$1"; then
		# Another job well done!
		return
	fi
	# Prepare incantation
	hook_chain=
	if [ -s "$git_dir/hooks/$1" -a -x "$git_dir/hooks/$1" ]; then
		hook_call="$hook_call"' || exit $?'
		if ! LC_ALL=C sed -n 1p <"$git_dir/hooks/$1" | LC_ALL=C fgrep -qx "#!@SHELL_PATH@"; then
			chain_num=
			while [ -e "$git_dir/hooks/$1-chain$chain_num" ]; do
				chain_num=$(( $chain_num + 1 ))
			done
			cp -p "$git_dir/hooks/$1" "$git_dir/hooks/$1-chain$chain_num"
			hook_chain=1
		fi
	else
		hook_call="exec $hook_call"
	fi
	# Don't call hook if tg is not installed
	hook_call="if which \"$tgname\" > /dev/null; then $hook_call; fi"
	# Insert call into the hook
	{
		echol "#!@SHELL_PATH@"
		echol "$hook_call"
		if [ -n "$hook_chain" ]; then
			echol "exec \"\$0-chain$chain_num\" \"\$@\""
		else
			[ ! -s "$git_dir/hooks/$1" ] || cat "$git_dir/hooks/$1"
		fi
	} >"$git_dir/hooks/$1+"
	chmod a+x "$git_dir/hooks/$1+"
	mv "$git_dir/hooks/$1+" "$git_dir/hooks/$1"
}

# setup_ours (no arguments)
setup_ours()
{
	if [ ! -s "$git_dir/info/attributes" ] || ! grep -q topmsg "$git_dir/info/attributes"; then
		[ -d "$git_dir/info" ] || mkdir "$git_dir/info"
		{
			echo ".topmsg	merge=ours"
			echo ".topdeps	merge=ours"
		} >>"$git_dir/info/attributes"
	fi
	if ! git config merge.ours.driver >/dev/null; then
		git config merge.ours.name '"always keep ours" merge driver'
		git config merge.ours.driver 'touch %A'
	fi
}

# measure_branch NAME [BASE] [EXTRAHEAD...]
measure_branch()
{
	_bname="$1"; _base="$2"
	shift; shift
	[ -n "$_base" ] || _base="refs/$topbases/$(strip_ref "$_bname")"
	# The caller should've verified $name is valid
	_commits="$(git rev-list --count "$_bname" "$@" ^"$_base" --)"
	_nmcommits="$(git rev-list --count --no-merges "$_bname" "$@" ^"$_base" --)"
	if [ $_commits -ne 1 ]; then
		_suffix="commits"
	else
		_suffix="commit"
	fi
	echo "$_commits/$_nmcommits $_suffix"
}

# branch_contains B1 B2
# Whether B1 is a superset of B2.
branch_contains()
{
	_revb1="$(ref_exists_rev "$1")" || return 0
	_revb2="$(ref_exists_rev "$2")" || return 0
	if [ -s "$tg_cache_dir/$1/.bc/$2/.d" ]; then
		if read _result _rev_matchb1 _rev_matchb2 &&
			[ "$_revb1" = "$_rev_matchb1" -a "$_revb2" = "$_rev_matchb2" ]; then
			return $_result
		fi <"$tg_cache_dir/$1/.bc/$2/.d"
	fi
	[ -d "$tg_cache_dir/$1/.bc/$2" ] || mkdir -p "$tg_cache_dir/$1/.bc/$2" 2>/dev/null || :
	_result=0
	[ -z "$(git rev-list --max-count=1 ^"$_revb1" "$_revb2" --)" ] || _result=$?
	if [ -d "$tg_cache_dir/$1/.bc/$2" ]; then
		echo "$_result" "$_revb1" "$_revb2" >"$tg_cache_dir/$1/.bc/$2/.d"
	fi
	return $_result
}

create_ref_dirs()
{
	[ ! -s "$tg_tmp_dir/tg~ref-dirs-created" -a -s "$tg_ref_cache" ] || return 0
	sed -e 's/ .*$//;'"s~^~$tg_tmp_dir/cached/~" <"$tg_ref_cache" | xargs mkdir -p
	echo 1 >"$tg_tmp_dir/tg~ref-dirs-created"
}

# If the first argument is non-empty, outputs "1" if this call created the cache
create_ref_cache()
{
	[ -n "$tg_ref_cache" -a ! -s "$tg_ref_cache" ] || return 0
	_remotespec=
	[ -z "$base_remote" ] || _remotespec="refs/remotes/$base_remote"
	[ -z "$1" ] || printf '1'
	git for-each-ref --format='%(refname) %(objectname)' \
		refs/heads "refs/$topbases" $_remotespec >"$tg_ref_cache"
	create_ref_dirs
}

remove_ref_cache()
{
	[ -n "$tg_ref_cache" -a -s "$tg_ref_cache" ] || return 0
	>"$tg_ref_cache"
}

# setting tg_ref_cache_only to non-empty will force non-$tg_ref_cache lookups to fail
rev_parse()
{
	if [ -n "$tg_ref_cache" -a -s "$tg_ref_cache" ]; then
		LC_ALL=C awk -v r="$1" 'BEGIN {e=1}; $1 == r {print $2; e=0; exit}; END {exit e}' <"$tg_ref_cache"
	else
		[ -z "$tg_ref_cache_only" ] || return 1
		git rev-parse --quiet --verify "$1^0" -- 2>/dev/null
	fi
}

# ref_exists_rev REF
# Whether REF is a valid ref name
# REF must be fully qualified and start with refs/heads/, refs/$topbases/
# or, if $base_remote is set, refs/remotes/$base_remote/
# Caches result if $tg_read_only and outputs HASH on success
ref_exists_rev()
{
	case "$1" in
		refs/*)
			:;;
		$octet20)
			printf '%s' "$1"
			return;;
		*)
			die "ref_exists_rev requires fully-qualified ref name"
	esac
	[ -n "$tg_read_only" ] || { git rev-parse --quiet --verify "$1^0" -- 2>/dev/null; return; }
	_result=
	_result_rev=
	{ read -r _result _result_rev <"$tg_tmp_dir/cached/$1/.ref"; } 2>/dev/null || :
	[ -z "$_result" ] || { printf '%s' "$_result_rev"; return $_result; }
	_result_rev="$(rev_parse "$1")"
	_result=$?
	[ -d "$tg_tmp_dir/cached/$1" ] || mkdir -p "$tg_tmp_dir/cached/$1" 2>/dev/null
	[ ! -d "$tg_tmp_dir/cached/$1" ] ||
	echo $_result $_result_rev >"$tg_tmp_dir/cached/$1/.ref" 2>/dev/null || :
	printf '%s' "$_result_rev"
	return $_result
}

# Same as ref_exists_rev but output is abbreviated hash
ref_exists_rev_short()
{
	case "$1" in
		refs/*)
			:;;
		$octet20)
			:;;
		*)
			die "ref_exists_rev_short requires fully-qualified ref name"
	esac
	[ -n "$tg_read_only" ] || { git rev-parse --quiet --verify --short "$1^0" -- 2>/dev/null; return; }
	_result=
	_result_rev=
	{ read -r _result _result_rev <"$tg_tmp_dir/cached/$1/.rfs"; } 2>/dev/null || :
	[ -z "$_result" ] || { printf '%s' "$_result_rev"; return $_result; }
	_result_rev="$(rev_parse "$1")"
	_result=$?
	if [ $_result -eq 0 ]; then
		_result_rev="$(git rev-parse --verify --short --quiet "$_result_rev" --)"
		_result=$?
	fi
	[ -d "$tg_tmp_dir/cached/$1" ] || mkdir -p "$tg_tmp_dir/cached/$1" 2>/dev/null
	[ ! -d "$tg_tmp_dir/cached/$1" ] ||
	echo $_result $_result_rev >"$tg_tmp_dir/cached/$1/.rfs" 2>/dev/null || :
	printf '%s' "$_result_rev"
	return $_result
}

# ref_exists REF
# Whether REF is a valid ref name
# REF must be fully qualified and start with refs/heads/, refs/$topbases/
# or, if $base_remote is set, refs/remotes/$base_remote/
# Caches result
ref_exists()
{
	ref_exists_rev "$1" >/dev/null
}

# rev_parse_tree REF
# Runs git rev-parse REF^{tree}
# Caches result if $tg_read_only
rev_parse_tree()
{
	[ -n "$tg_read_only" ] || { git rev-parse --verify "$1^{tree}" -- 2>/dev/null; return; }
	if [ -f "$tg_tmp_dir/cached/$1/.rpt" ]; then
		if IFS= read -r _result <"$tg_tmp_dir/cached/$1/.rpt"; then
			printf '%s\n' "$_result"
			return 0
		fi
		return 1
	fi
	[ -d "$tg_tmp_dir/cached/$1" ] || mkdir -p "$tg_tmp_dir/cached/$1" 2>/dev/null || :
	if [ -d "$tg_tmp_dir/cached/$1" ]; then
		git rev-parse --verify "$1^{tree}" -- >"$tg_tmp_dir/cached/$1/.rpt" 2>/dev/null || :
		if IFS= read -r _result <"$tg_tmp_dir/cached/$1/.rpt"; then
			printf '%s\n' "$_result"
			return 0
		fi
		return 1
	fi
	git rev-parse --verify "$1^{tree}" -- 2>/dev/null
}

# has_remote BRANCH
# Whether BRANCH has a remote equivalent (accepts $topbases/ too)
has_remote()
{
	[ -n "$base_remote" ] && ref_exists "refs/remotes/$base_remote/$1"
}

# Return the verified TopGit branch name or die with an error.
# As a convenience, if HEAD is given and HEAD is a symbolic ref to
# refs/heads/... then ... will be verified instead.
# if "$2" = "-f" (for fail) then return an error rather than dying.
verify_topgit_branch()
{
	case "$1" in
		refs/heads/*)
			_verifyname="${1#refs/heads/}"
			;;
		refs/"$topbases"/*)
			_verifyname="${1#refs/$topbases/}"
			;;
		HEAD)
			_verifyname="$(git symbolic-ref HEAD 2>/dev/null || :)"
			[ -n "$_verifyname" -o "$2" = "-f" ] || die "HEAD is not a symbolic ref"
			case "$_verifyname" in refs/heads/*) :;; *)
				[ "$2" != "-f" ] || return 1
				die "HEAD is not a symbolic ref to the refs/heads namespace"
			esac
			_verifyname="${_verifyname#refs/heads/}"
			;;
		*)
			_verifyname="$1"
			;;
	esac
	if ! ref_exists "refs/heads/$_verifyname"; then
		[ "$2" != "-f" ] || return 1
		die "no such branch: $_verifyname"
	fi
	if ! ref_exists "refs/$topbases/$_verifyname"; then
		[ "$2" != "-f" ] || return 1
		die "not a TopGit-controlled branch: $_verifyname"
	fi
	printf '%s' "$_verifyname"
}

# Caches result
# $1 = branch name (i.e. "t/foo/bar")
# $2 = optional result of rev-parse "refs/heads/$1"
# $3 = optional result of rev-parse "refs/$topbases/$1"
branch_annihilated()
{
	_branch_name="$1"
	_rev="${2:-$(ref_exists_rev "refs/heads/$_branch_name")}"
	_rev_base="${3:-$(ref_exists_rev "refs/$topbases/$_branch_name")}"

	_result=
	_result_rev=
	_result_rev_base=
	{ read -r _result _result_rev _result_rev_base <"$tg_cache_dir/$_branch_name/.ann"; } 2>/dev/null || :
	[ -z "$_result" -o "$_result_rev" != "$_rev" -o "$_result_rev_base" != "$_rev_base" ] || return $_result

	# use the merge base in case the base is ahead.
	mb="$(git merge-base "$_rev_base" "$_rev" 2>/dev/null)"

	test -z "$mb" || test "$(rev_parse_tree "$mb")" = "$(rev_parse_tree "$_rev")"
	_result=$?
	[ -d "$tg_cache_dir/$_branch_name" ] || mkdir -p "$tg_cache_dir/$_branch_name" 2>/dev/null
	[ ! -d "$tg_cache_dir/$_branch_name" ] ||
	echo $_result $_rev $_rev_base >"$tg_cache_dir/$_branch_name/.ann" 2>/dev/null || :
	return $_result
}

non_annihilated_branches()
{
	[ $# -gt 0 ] || set -- "refs/$topbases"
	git for-each-ref --format='%(objectname) %(refname)' "$@" |
		while read rev ref; do
			name="${ref#refs/$topbases/}"
			if branch_annihilated "$name" "" "$rev"; then
				continue
			fi
			echol "$name"
		done
}

# Make sure our tree is clean
ensure_clean_tree()
{
	git update-index --ignore-submodules --refresh ||
		die "the working directory has uncommitted changes (see above) - first commit or reset them"
	[ -z "$(git diff-index --cached --name-status -r --ignore-submodules HEAD --)" ] ||
		die "the index has uncommited changes"
}

# is_sha1 REF
# Whether REF is a SHA1 (compared to a symbolic name).
is_sha1()
{
	case "$1" in $octet20) return 0;; esac
	return 1
}

# recurse_deps_internal NAME [BRANCHPATH...]
# get recursive list of dependencies with leading 0 if branch exists 1 if missing
# followed by a 1 if the branch is "tgish" or a 0 if not
# then the branch name followed by its depedency chain (which might be empty)
# An output line might look like this:
#   0 1 t/foo/leaf t/foo/int t/stage
# If no_remotes is non-empty, exclude remotes
# If recurse_preorder is non-empty, do a preorder rather than postorder traversal
# any branch names in the space-separated recurse_deps_exclude variable
# are skipped (along with their dependencies)
recurse_deps_internal()
{
	case " $recurse_deps_exclude " in *" $1 "*) return 0; esac
	_ref_hash=
	if ! _ref_hash="$(ref_exists_rev "refs/heads/$1")"; then
		[ -z "$2" ] || echo "1 0 $*"
		return
	fi

	_is_tgish=0
	_ref_hash_base=
	! _ref_hash_base="$(ref_exists_rev "refs/$topbases/$1")" || _is_tgish=1
	[ -z "$recurse_preorder" -o -z "$2" ] || echo "0 $_is_tgish $*"

	# If no_remotes is unset also check our base against remote base.
	# Checking our head against remote head has to be done in the helper.
	if [ -n "$_is_tgish" -a -z "$no_remotes" ] && has_remote "$topbases/$1"; then
		echo "0 0 refs/remotes/$base_remote/$topbases/$1 $*"
	fi

	# if the branch was annihilated, it is considered to have no dependencies
	if [ -n "$_is_tgish" ] && ! branch_annihilated "$1" "$_ref_hash" "$_ref_hash_base"; then
		#TODO: handle nonexisting .topdeps?
		cat_deps "$1" |
		while read _dname; do
			# Avoid depedency loops
			case " $* " in *" $_dname "*)
				warn "dependency loop detected in branch $_dname"
				continue
			esac
			# Shoo shoo, leave our environment alone!
			(recurse_deps_internal "$_dname" "$@")
		done
	fi

	[ -n "$recurse_preorder" -o -z "$2" ] || echo "0 $_is_tgish $*"
}

# do_eval CMD
# helper for recurse_deps so that a return statement executed inside CMD
# does not return from recurse_deps.  This shouldn't be necessary, but it
# seems that it actually is.
do_eval()
{
	eval "$@"
}

# becomes read-only for caching purposes
# assigns new value to tg_read_only
# become_cacheable/undo_become_cacheable calls may be nested
become_cacheable()
{
	_old_tg_read_only="$tg_read_only"
	if [ -z "$tg_read_only" ]; then
		rm -rf "$tg_tmp_dir/cached" "$tg_tmp_dir/tg~ref-dirs-created"
		tg_read_only=1
	fi
	_my_ref_cache="$(create_ref_cache 1)"
	_my_ref_cache="${_my_ref_cache:+1}"
	tg_read_only="undo${_my_ref_cache:-0}-$_old_tg_read_only"
}

# restores tg_read_only and ref_cache to state before become_cacheable call
# become_cacheable/undo_bocome_cacheable calls may be nested
undo_become_cacheable()
{
	case "$tg_read_only" in
		"undo"[01]"-"*)
			_suffix="${tg_read_only#undo?-}"
			[ "${tg_read_only%$_suffix}" = "undo0-" ] || remove_ref_cache
			tg_read_only="$_suffix"
	esac
}

# just call this, no undo, sets tg_read_only= and removes ref cache and cached results
become_non_cacheable()
{
	remove_ref_cache
	tg_read_only=
	rm -rf "$tg_tmp_dir/cached" "$tg_tmp_dir/tg~ref-dirs-created"
}

# call this to make sure Git will not complain about a missing user/email
# result is cached in TG_IDENT_CHECKED and a non-empty value suppresses the check
ensure_ident_available()
{
	[ -z "$TG_IDENT_CHECKED" ] || return 0
	git var GIT_AUTHOR_IDENT >/dev/null &&
	git var GIT_COMMITTER_IDENT >/dev/null || exit
	TG_IDENT_CHECKED=1
	export TG_IDENT_CHECKED
	return 0
}

# recurse_deps CMD NAME [BRANCHPATH...]
# Recursively eval CMD on all dependencies of NAME.
# Dependencies are visited in topological order.
# CMD can refer to $_name for queried branch name,
# $_dep for dependency name,
# $_depchain for space-seperated branch backtrace,
# $_dep_missing boolean to check whether $_dep is present
# and the $_dep_is_tgish boolean.
# It can modify $_ret to affect the return value
# of the whole function.
# If recurse_deps() hits missing dependencies, it will append
# them to space-separated $missing_deps list and skip them
# after calling CMD with _dep_missing set.
# remote dependencies are processed if no_remotes is unset.
# any branch names in the space-separated recurse_deps_exclude variable
# are skipped (along with their dependencies)
recurse_deps()
{
	_cmd="$1"; shift

	become_cacheable
	_depsfile="$(get_temp tg-depsfile)"
	recurse_deps_internal "$@" >>"$_depsfile"
	undo_become_cacheable

	_ret=0
	while read _ismissing _istgish _dep _name _deppath; do
		_depchain="$_name${_deppath:+ $_deppath}"
		_dep_is_tgish=
		[ "$_istgish" = "0" ] || _dep_is_tgish=1
		_dep_missing=
		if [ "$_ismissing" != "0" ]; then
			_dep_missing=1
			case " $missing_deps " in *" $_dep "*) :;; *)
				missing_deps="${missing_deps:+$missing_deps }$_dep"
			esac
		fi
		do_eval "$_cmd"
	done <"$_depsfile"
	rm -f "$_depsfile"
	return $_ret
}

# branch_needs_update
# This is a helper function for determining whether given branch
# is up-to-date wrt. its dependencies. It expects input as if it
# is called as a recurse_deps() helper.
# In case the branch does need update, it will echo it together
# with the branch backtrace on the output (see needs_update()
# description for details) and set $_ret to non-zero.
branch_needs_update()
{
	if [ -n "$_dep_missing" ]; then
		echo "! $_dep $_depchain"
		return 0
	fi

	if [ -n "$_dep_is_tgish" ]; then
		branch_annihilated "$_dep" && return 0

		if has_remote "$_dep"; then
			branch_contains "refs/heads/$_dep" "refs/remotes/$base_remote/$_dep" ||
				echo "refs/remotes/$base_remote/$_dep $_dep $_depchain"
		fi
		# We want to sync with our base first and should output this before
		# the remote branch, but the order does not actually matter to tg-update
		# as it just recurses regardless, but it does matter for tg-info (which
		# treats out-of-date bases as though they were already merged in) so
		# we output the remote before the base.
		branch_contains "refs/heads/$_dep" "refs/$topbases/$_dep" || {
			echo ": $_dep $_depchain"
			_ret=1
			return
		}
	fi

	if [ -n "$_name" ]; then
		case "$_dep" in refs/*) _fulldep="$_dep";; *) _fulldep="refs/heads/$_dep";; esac
		if ! branch_contains "refs/$topbases/$_name" "$_fulldep"; then
			# Some new commits in _dep
			echo "$_dep $_depchain"
			_ret=1
		fi
	fi
}

# needs_update NAME
# This function is recursive; it outputs reverse path from NAME
# to the branch (e.g. B_DIRTY B1 B2 NAME), one path per line,
# inner paths first. Innermost name can be refs/remotes/<remote>/<name>
# if the head is not in sync with the <remote> branch <name>, ':' if
# the head is not in sync with the base (in this order of priority)
# or '!' if dependency is missing.  Note that the remote branch, base
# order is reversed from the order they will actually be updated in
# order to accomodate tg info which treats out-of-date items that are
# only in the base as already being in the head for status purposes.
# It will also return non-zero status if NAME needs update.
# If needs_update() hits missing dependencies, it will append
# them to space-separated $missing_deps list and skip them.
needs_update()
{
	recurse_deps branch_needs_update "$1"
}

# branch_empty NAME [-i | -w]
branch_empty()
{
	if [ -z "$2" ]; then
		_rev="$(ref_exists_rev "refs/heads/$1")" || return 0
		_result=
		_result_rev=
		{ read -r _result _result_rev <"$tg_cache_dir/$1/.mt"; } 2>/dev/null || :
		[ -z "$_result" -o "$_result_rev" != "$_rev" ] || return $_result
		_result=0
		[ "$(pretty_tree "$1" -b)" = "$(pretty_tree "$1" $2)" ] || _result=$?
		[ -d "$tg_cache_dir/$1" ] || mkdir -p "$tg_cache_dir/$1" 2>/dev/null
		[ ! -d "$tg_cache_dir/$1" ] || echo $_result $_rev >"$tg_cache_dir/$1/.mt"
		return $_result
	else
		[ "$(pretty_tree "$1" -b)" = "$(pretty_tree "$1" $2)" ]
	fi
}

# list_deps [-i | -w] [BRANCH]
# -i/-w apply only to HEAD
list_deps()
{
	head_from=
	[ "$1" != "-i" -a "$1" != "-w" ] || { head_from="$1"; shift; }
	head="$(git symbolic-ref -q HEAD)" ||
		head="..detached.."

	git for-each-ref --format='%(objectname) %(refname)' "refs/$topbases${1:+/$1}" |
		while read rev ref; do
			name="${ref#refs/$topbases/}"
			if branch_annihilated "$name" "" "$rev"; then
				continue
			fi

			from=$head_from
			[ "refs/heads/$name" = "$head" ] ||
				from=
			cat_file "refs/heads/$name:.topdeps" $from | while read dep; do
				dep_is_tgish=true
				ref_exists "refs/$topbases/$dep" ||
					dep_is_tgish=false
				if ! "$dep_is_tgish" || ! branch_annihilated $dep; then
					echo "$name $dep"
				fi
			done
		done
}

# switch_to_base NAME [SEED]
switch_to_base()
{
	_base="refs/$topbases/$1"; _seed="$2"
	# We have to do all the hard work ourselves :/
	# This is like git checkout -b "$_base" "$_seed"
	# (or just git checkout "$_base"),
	# but does not create a detached HEAD.
	git read-tree -u -m HEAD "${_seed:-$_base}"
	[ -z "$_seed" ] || git update-ref "$_base" "$_seed"
	git symbolic-ref HEAD "$_base"
}

# run editor with arguments
# the editor setting will be cached in $tg_editor (which is eval'd)
# result non-zero if editor fails or GIT_EDITOR cannot be determined
run_editor()
{
	tg_editor="$GIT_EDITOR"
	[ -n "$tg_editor" ] || tg_editor="$(git var GIT_EDITOR)" || return $?
	eval "$tg_editor" '"$@"'
}

# Show the help messages.
do_help()
{
	_www=
	if [ "$1" = "-w" ]; then
		_www=1
		shift
	fi
	if [ -z "$1" ] ; then
		# This is currently invoked in all kinds of circumstances,
		# including when the user made a usage error. Should we end up
		# providing more than a short help message, then we should
		# differentiate.
		# Petr's comment: http://marc.info/?l=git&m=122718711327376&w=2

		## Build available commands list for help output

		cmds=
		sep=
		for cmd in "@cmddir@"/tg-*; do
			! [ -r "$cmd" ] && continue
			# strip directory part and "tg-" prefix
			cmd="$(basename "$cmd")"
			cmd="${cmd#tg-}"
			cmds="$cmds$sep$cmd"
			sep="|"
		done

		echo "TopGit version $TG_VERSION - A different patch queue manager"
		echo "Usage: $tgname [-C <dir>] [-r <remote> | -u] [-c <name>=<val>] ($cmds) ..."
		echo "   Or: $tgname help [-w] [<command>]"
		echo "Use \"$tgdisplaydir$tgname help tg\" for overview of TopGit"
	elif [ -r "@cmddir@"/tg-$1 -o -r "@sharedir@/tg-$1.txt" ] ; then
		if [ -n "$_www" ]; then
			nohtml=
			if ! [ -r "@sharedir@/topgit.html" ]; then
				echo "`basename $0`: missing html help file:" \
					"@sharedir@/topgit.html" 1>&2
				nohtml=1
			fi
			if ! [ -r "@sharedir@/tg-$1.html" ]; then
				echo "`basename $0`: missing html help file:" \
					"@sharedir@/tg-$1.html" 1>&2
				nohtml=1
			fi
			if [ -n "$nohtml" ]; then
				echo "`basename $0`: use" \
					"\"`basename $0` help $1\" instead" 1>&2
				exit 1
			fi
			git web--browse -c help.browser "@sharedir@/tg-$1.html"
			exit
		fi
		output()
		{
			if [ -r "@cmddir@"/tg-$1 ] ; then
				"@cmddir@"/tg-$1 -h 2>&1 || :
				echo
			fi
			if [ -r "@sharedir@/tg-$1.txt" ] ; then
				cat "@sharedir@/tg-$1.txt"
			fi
		}
		page output "$1"
	else
		echo "`basename $0`: no help for $1" 1>&2
		do_help
		exit 1
	fi
}

## Pager stuff

# isatty FD
isatty()
{
	test -t $1
}

# pass "diff" to get pager.diff
# if pager.$1 is a boolean false returns cat
# if set to true or unset fails
# otherwise succeeds and returns the value
get_pager()
{
	if _x="$(git config --bool "pager.$1" 2>/dev/null)"; then
		[ "$_x" != "true" ] || return 1
		echo "cat"
		return 0
	fi
	if _x="$(git config "pager.$1" 2>/dev/null)"; then
		echol "$_x"
		return 0
	fi
	return 1
}

# setup_pager
# Set TG_PAGER to a valid executable
# After calling, code to be paged should be surrounded with {...} | eval "$TG_PAGER"
# See also the following "page" function for ease of use
# emptypager will be set to 1 (otherwise empty) if TG_PAGER was set to "cat" to not be empty
# Preference is (same as Git):
#   1. GIT_PAGER
#   2. pager.$USE_PAGER_TYPE (but only if USE_PAGER_TYPE is set and so is pager.$USE_PAGER_TYPE)
#   3. core.pager (only if set)
#   4. PAGER
#   5. git var GIT_PAGER
#   6. less
setup_pager()
{
	isatty 1 || { emptypager=1; TG_PAGER=cat; return 0; }

	emptypager=
	if [ -z "$TG_PAGER_IN_USE" ]; then
		# TG_PAGER = GIT_PAGER | PAGER | less
		# NOTE: GIT_PAGER='' is significant
		if [ -n "${GIT_PAGER+set}" ]; then
			TG_PAGER="$GIT_PAGER"
		elif [ -n "$USE_PAGER_TYPE" ] && _dp="$(get_pager "$USE_PAGER_TYPE")"; then
			TG_PAGER="$_dp"
		elif _cp="$(git config core.pager 2>/dev/null)"; then
			TG_PAGER="$_cp"
		elif [ -n "${PAGER+set}" ]; then
			TG_PAGER="$PAGER"
		else
			_gp="$(git var GIT_PAGER 2>/dev/null || :)"
			[ "$_gp" != ":" ] || _gp=
			TG_PAGER="${_gp:-less}"
		fi
		if [ -z "$TG_PAGER" ]; then
			emptypager=1
			TG_PAGER=cat
		fi
	else
		emptypager=1
		TG_PAGER=cat
	fi

	# Set pager default environment variables
	# see pager.c:setup_pager
	if [ -z "${LESS+set}" ]; then
		LESS="-FRX"
		export LESS
	fi
	if [ -z "${LV+set}" ]; then
		LV="-c"
		export LV
	fi

	# this is needed so e.g. `git diff` will still colorize it's output if
	# requested in ~/.gitconfig with color.diff=auto
	GIT_PAGER_IN_USE=1
	export GIT_PAGER_IN_USE

	# this is needed so we don't get nested pagers
	TG_PAGER_IN_USE=1
	export TG_PAGER_IN_USE
}

# page eval_arg [arg ...]
#
# Calls setup_pager then evals the first argument passing it all the rest
# where the output is piped through eval "$TG_PAGER" unless emptypager is set
# by setup_pager (in which case the output is left as-is).
#
# To handle arbitrary paging duties, collect lines to be paged into a
# function and then call page with the function name or perhaps func_name "$@".
#
# If no arguments at all are passed in do nothing (return with success).
page()
{
	[ $# -gt 0 ] || return 0
	setup_pager
	_evalarg="$1"; shift
	if [ -n "$emptypager" ]; then
		eval "$_evalarg" '"$@"'
	else
		eval "$_evalarg" '"$@"' | eval "$TG_PAGER"
	fi
}

# get_temp NAME [-d]
# creates a new temporary file (or directory with -d) in the global
# temporary directory $tg_tmp_dir with pattern prefix NAME
get_temp()
{
	mktemp $2 "$tg_tmp_dir/$1.XXXXXX"
}

# automatically called by strftime
# does nothing if already setup
# may be called explicitly if the first call would otherwise be in a subshell
# so that the setup is only done once before subshells start being spawned
setup_strftime()
{
	[ -z "$strftime_is_setup" ] || return 0

	# date option to format raw epoch seconds values
	daterawopt=
	_testes='951807788'
	_testdt='2000-02-29 07:03:08 UTC'
	_testfm='%Y-%m-%d %H:%M:%S %Z'
	if [ "$(TZ=UTC date "-d@$_testes" "+$_testfm" 2>/dev/null)" = "$_testdt" ]; then
		daterawopt='-d@'
	elif [ "$(TZ=UTC date "-r$_testes" "+$_testfm" 2>/dev/null)" = "$_testdt" ]; then
		daterawopt='-r'
	fi
	strftime_is_setup=1
}

# $1 => strftime format string to use
# $2 => raw timestamp as seconds since epoch
# $3 => optional time zone string (empty/absent for local time zone)
strftime()
{
	setup_strftime
	if [ -n "$daterawopt" ]; then
		if [ -n "$3" ]; then
			TZ="$3" date "$daterawopt$2" "+$1"
		else
			date "$daterawopt$2" "+$1"
		fi
	else
		if [ -n "$3" ]; then
			TZ="$3" perl -MPOSIX=strftime -le 'print strftime($ARGV[0],localtime($ARGV[1]))' "$1" "$2"
		else
			perl -MPOSIX=strftime -le 'print strftime($ARGV[0],localtime($ARGV[1]))' "$1" "$2"
		fi
	fi
}

## Initial setup
initial_setup()
{
	# suppress the merge log editor feature since git 1.7.10

	GIT_MERGE_AUTOEDIT=no
	export GIT_MERGE_AUTOEDIT

	auhopt=
	[ "$(vcmp "$git_vernum" 2.9)" -lt 0 ] || auhopt="--allow-unrelated-histories"
	git_dir="$(git rev-parse --git-dir)"
	root_dir="$(git rev-parse --show-cdup)"; root_dir="${root_dir:-.}"
	logrefupdates="$(git config --bool core.logallrefupdates 2>/dev/null || :)"
	[ "$logrefupdates" = "true" ] || logrefupdates=
	tgsequester="$(git config --bool topgit.sequester 2>/dev/null || :)"
	tgnosequester=
	[ "$tgsequester" != "false" ] || tgnosequester=1
	unset tgsequester

	# make sure root_dir doesn't end with a trailing slash.

	root_dir="${root_dir%/}"
	[ -n "$base_remote" ] || base_remote="$(git config topgit.remote 2>/dev/null)" || :

	# make sure global cache directory exists inside GIT_DIR

	tg_cache_dir="$git_dir/tg-cache"
	[ -d "$tg_cache_dir" ] || mkdir "$tg_cache_dir"

	# create global temporary directories, inside GIT_DIR

	tg_tmp_dir=
	trap 'rm -rf "$tg_tmp_dir"' EXIT
	trap 'exit 129' HUP
	trap 'exit 130' INT
	trap 'exit 131' QUIT
	trap 'exit 134' ABRT
	trap 'exit 143' TERM
	tg_tmp_dir="$(mktemp -d "$git_dir/tg-tmp.XXXXXX")"
	tg_ref_cache="$tg_tmp_dir/tg~ref-cache"

	# refer to "top-bases" in a refname with $topbases

	topbases="top-bases"
}

# return the "realpath" for the item except the leaf is not resolved if it's
# a symbolic link.  The directory part must exist, but the basename need not.
get_abs_path()
{
	[ -n "$1" -a -d "$(dirname "$1")" ] || return 1
	printf '%s' "$(cd -- "$(dirname "$1")" && pwd -P)/$(basename "$1")"
}

## Startup

[ -d "@cmddir@" ] ||
	die "No command directory: '@cmddir@'"

if [ -n "$tg__include" ]; then

	# We were sourced from another script for our utility functions;
	# this is set by hooks.  Skip the rest of the file.  A simple return doesn't
	# work as expected in every shell.  See http://bugs.debian.org/516188

	# ensure setup happens

	initial_setup

else

	set -e

	tg="$0"
	tgdir="$(dirname "$tg")/"
	tgname="$(basename "$tg")"
	[ "$0" != "$tgname" ] || tgdir=""

	# If tg contains a '/' but does not start with one then replace it with an absolute path

	case "$0" in /*) :;; */*)
		tgdir="$(cd "$(dirname "$0")" && pwd -P)/"
		tg="$tgdir$tgname"
	esac

	# If the tg in the PATH is the same as "$tg" just display the basename
	# tgdisplay will include any explicit -C <dir> option whereas tg will not

	tgdisplaydir="$tgdir"
	tgdisplay="$tg"
	if [ "$(get_abs_path "$tg")" = "$(get_abs_path "$(which "$tgname" || :)" || :)" ]; then
		tgdisplaydir=""
		tgdisplay="$tgname"
	fi

	explicit_remote=
	explicit_dir=
	gitcdopt=
	noremote=

	cmd=
	while :; do case "$1" in

		help|--help|-h)
			cmd=help
			shift
			break;;

		--hooks-path)
			cmd=hooks-path
			shift
			break;;

		-r)
			shift
			if [ -z "$1" ]; then
				echo "Option -r requires an argument." >&2
				do_help
				exit 1
			fi
			unset noremote
			base_remote="$1"
			explicit_remote="$base_remote"
			tg="$tgdir$tgname -r $explicit_remote"
			tgdisplay="$tgdisplaydir$tgname"
			[ -z "$explicit_dir" ] || tgdisplay="$tgdisplay -C \"$explicit_dir\""
			tgdisplay="$tgdisplay -r $explicit_remote"
			shift;;

		-u)
			unset base_remote explicit_remote
			noremote=1
			tg="$tgdir$tgname -u"
			tgdisplay="$tgdisplaydir$tgname"
			[ -z "$explicit_dir" ] || tgdisplay="$tgdisplay -C \"$explicit_dir\""
			tgdisplay="$tgdisplay -u"
			shift;;

		-C)
			shift
			if [ -z "$1" ]; then
				echo "Option -C requires an argument." >&2
				do_help
				exit 1
			fi
			cd "$1"
			unset GIT_DIR
			explicit_dir="$1"
			gitcdopt=" -C \"$explicit_dir\""
			tg="$tgdir$tgname"
			tgdisplay="$tgdisplaydir$tgname -C \"$explicit_dir\""
			[ -z "$explicit_remote" ] || tg="$tg -r $explicit_remote"
			[ -z "$explicit_remote" ] || tgdisplay="$tgdisplay -r $explicit_remote"
			[ -z "$noremote" ] || tg="$tg -u"
			[ -z "$noremote" ] || tg="$tgdisplay -u"
			shift;;

		-c)
			shift
			if [ -z "$1" ]; then
				echo "Option -c requires an argument." >&2
				do_help
				exit 1
			fi
			param="'$(printf '%s\n' "$1" | sed "s/[']/'\\\\''/g")'"
			GIT_CONFIG_PARAMETERS="${GIT_CONFIG_PARAMETERS:+$GIT_CONFIG_PARAMETERS }$param"
			export GIT_CONFIG_PARAMETERS
			shift;;

		--)
			shift
			break;;

		-*)
			echo "Invalid option $1 (subcommand options must appear AFTER the subcommand)." >&2
			do_help
			exit 1;;

		*)
			break;;

	esac; done

	[ -n "$cmd" -o $# -lt 1 ] || { cmd="$1"; shift; }

	## Dispatch

	[ -n "$cmd" ] || { do_help; exit 1; }

	case "$cmd" in

		help)
			do_help "$@"
			exit 0;;

		hooks-path)
			# Internal command
			echol "@hooksdir@";;

		*)
			[ -r "@cmddir@"/tg-$cmd ] || {
				echo "Unknown subcommand: $cmd" >&2
				do_help
				exit 1
			}

			initial_setup
			[ -z "$noremote" ] || unset base_remote

			nomergesetup=
			case "$cmd" in info|log|summary|rebase|revert|tag)
				# avoid merge setup where not necessary

				nomergesetup=1
			esac

			if [ -z "$nomergesetup" ]; then
				# make sure merging the .top* files will always behave sanely

				setup_ours
				setup_hook "pre-commit"
			fi

			_use_ref_cache=
			tg_read_only=1
			case "$cmd" in
				summary|info|export|tag)
					_use_ref_cache=1;;
				annihilate|create|delete|depend|import|update)
					tg_read_only=;;
			esac
			[ -z "$_use_ref_cache" ] || create_ref_cache

			. "@cmddir@"/tg-$cmd;;
	esac

fi

# vim:noet
