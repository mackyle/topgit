#!/bin/sh
# TopGit - A different patch queue manager
# Copyright (C) Petr Baudis <pasky@suse.cz>  2008
# Copyright (C) Kyle J. McKay <mackyle@gmail.com>  2014,2015,2016
# All rights reserved.
# GPLv2

TG_VERSION=0.19.7

# Update in Makefile if you add any code that requires a newer version of git
GIT_MINIMUM_VERSION="@mingitver@"

## SHA-1 pattern

octet='[0-9a-f][0-9a-f]'
octet4="$octet$octet$octet$octet"
octet19="$octet4$octet4$octet4$octet4$octet$octet$octet"
octet20="$octet4$octet4$octet4$octet4$octet4"
nullsha="0000000000000000000000000000000000000000"
tab='	'
lf='
'

## Auxiliary functions

# Preserves current $? value while triggering a non-zero set -e exit if active
# This works even for shells that sometimes fail to correctly trigger a -e exit
check_exit_code()
{
	return $?
}

# This is the POSIX equivalent of which
cmd_path()
(
	{ "unset" -f command unset unalias "$1"; } >/dev/null 2>&1 || :
	{ "unalias" -a; } >/dev/null 2>&1 || :
	command -v "$1"
)

# helper for wrappers
# note deliberate use of '(' ... ')' rather than '{' ... '}'
exec_lc_all_c()
(
	LC_ALL="C" &&
	export LC_ALL &&
	exec "$@"
)

# These tools work better for us with LC_ALL=C and by using these little
# convenience functions LC_ALL=C does not have to appear in the code but
# any Git translations will still appear for Git commands
awk()	{ exec_lc_all_c @AWK_PATH@	"$@"; }
cat()	{ exec_lc_all_c cat		"$@"; }
cut()	{ exec_lc_all_c cut		"$@"; }
find()	{ exec_lc_all_c find		"$@"; }
grep()	{ exec_lc_all_c grep		"$@"; }
join()	{ exec_lc_all_c join		"$@"; }
paste()	{ exec_lc_all_c paste		"$@"; }
sed()	{ exec_lc_all_c sed		"$@"; }
sort()	{ exec_lc_all_c sort		"$@"; }
tr()	{ exec_lc_all_c tr		"$@"; }
wc()	{ exec_lc_all_c wc		"$@"; }
xargs()	{ exec_lc_all_c xargs		"$@"; }

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

# shift off first arg then return "$*" properly quoted in single-quotes
# if $1 was '' output goes to stdout otherwise it's assigned to $1
# the final \n, if any, is omitted from the result but any others are included
v_quotearg()
{
	_quotearg_v="$1"
	shift
	set -- "$_quotearg_v" \
	"sed \"s/'/'\\\\\\''/g;1s/^/'/;\\\$s/\\\$/'/;s/'''/'/g;1s/^''\\(.\\)/\\1/\"" "$*"
	unset _quotearg_v
	if [ -z "$3" ]; then
		if [ -z "$1" ]; then
			echo "''"
		else
			eval "$1=\"''\""
		fi
	else
		if [ -z "$1" ]; then
			printf "%s$4" "$3" | eval "$2"
		else
			eval "$1="'"$(printf "%s$4" "$3" | eval "$2")"'
		fi
	fi
}

# same as v_quotearg except there's no extra $1 so output always goes to stdout
quotearg()
{
	v_quotearg '' "$@"
}

vcmp()
{
	# Compare $1 to $3 each of which must match ^[^0-9]*\d*(\.\d*)*.*$
	# where only the "\d*" parts in the regex participate in the comparison
	# Since EVERY string matches that regex this function is easy to use
	# An empty string ('') for $1 or $3 or any "\d*" part is treated as 0
	# $2 is a compare op '<', '<=', '=', '==', '!=', '>=', '>'
	# Return code is 0 for true, 1 for false (or unknown compare op)
	# There is NO difference in behavior between '=' and '=='
	# Note that "vcmp 1.8 == 1.8.0.0.0.0" correctly returns 0
	set -- "$1" "$2" "$3" "${1%%[0-9]*}" "${3%%[0-9]*}"
	set -- "${1#"$4"}" "$2" "${3#"$5"}"
	set -- "${1%%[!0-9.]*}" "$2" "${3%%[!0-9.]*}"
	while
		vcmp_a_="${1%%.*}"
		vcmp_b_="${3%%.*}"
		[ "z$vcmp_a_" != "z" -o "z$vcmp_b_" != "z" ]
	do
		if [ "${vcmp_a_:-0}" -lt "${vcmp_b_:-0}" ]; then
			unset vcmp_a_ vcmp_b_
			case "$2" in "<"|"<="|"!=") return 0; esac
			return 1
		elif [ "${vcmp_a_:-0}" -gt "${vcmp_b_:-0}" ]; then
			unset vcmp_a_ vcmp_b_
			case "$2" in ">"|">="|"!=") return 0; esac
			return 1;
		fi
		vcmp_a_="${1#$vcmp_a_}"
		vcmp_b_="${3#$vcmp_b_}"
		set -- "${vcmp_a_#.}" "$2" "${vcmp_b_#.}"
	done
	unset vcmp_a_ vcmp_b_
	case "$2" in "="|"=="|"<="|">=") return 0; esac
	return 1
}

precheck() {
	if ! git_version="$(git version)"; then
		die "'git version' failed"
	fi
	case "$git_version" in [Gg]"it version "*);;*)
		die "'git version' output does not start with 'git version '"
	esac

	vcmp "$git_version" '>=' "$GIT_MINIMUM_VERSION" ||
		die "git version >= $GIT_MINIMUM_VERSION required but found $git_version instead"
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
	if [ -s "$tg_cache_dir/refs/heads/$1/.$2" ]; then
		if read _rev_match && [ "$_rev" = "$_rev_match" ]; then
			_line=
			while IFS= read -r _line || [ -n "$_line" ]; do
				printf '%s\n' "$_line"
			done
			return 0
		fi <"$tg_cache_dir/refs/heads/$1/.$2"
	fi
	[ -d "$tg_cache_dir/refs/heads/$1" ] || mkdir -p "$tg_cache_dir/refs/heads/$1" 2>/dev/null || :
	if [ -d "$tg_cache_dir/refs/heads/$1" ]; then
		printf '%s\n' "$_rev" >"$tg_cache_dir/refs/heads/$1/.$2"
		_line=
		git cat-file blob "$_rev:.$2" 2>/dev/null |
		while IFS= read -r _line || [ -n "$_line" ]; do
			printf '%s\n' "$_line" >&3
			printf '%s\n' "$_line"
		done 3>>"$tg_cache_dir/refs/heads/$1/.$2"
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
		git cat-file blob ":${path#*:}" 2>/dev/null
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
			git cat-file blob "$path" 2>/dev/null
			;;
		esac
		;;
	*)
		die "Wrong argument to cat_file: '$2'"
		;;
	esac
}

# if use_alt_temp_odb and tg_use_alt_odb are true try to write the object(s)
# into the temporary alt odb area instead of the usual location
git_temp_alt_odb_cmd()
{
	if [ -n "$use_alt_temp_odb" ] && [ -n "$tg_use_alt_odb" ] &&
	   [ -n "$TG_OBJECT_DIRECTORY" ] &&
	   [ -f "$TG_OBJECT_DIRECTORY/info/alternates" ]; then
		(
			GIT_ALTERNATE_OBJECT_DIRECTORIES="$TG_PRESERVED_ALTERNATES"
			GIT_OBJECT_DIRECTORY="$TG_OBJECT_DIRECTORY"
			unset TG_OBJECT_DIRECTORY TG_PRESERVED_ALTERNATES
			export GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_OBJECT_DIRECTORY
			git "$@"
		)
	else
		git "$@"
	fi
}

git_write_tree() { git_temp_alt_odb_cmd write-tree "$@"; }
git_mktree() { git_temp_alt_odb_cmd mktree "$@"; }

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
	git_write_tree
}

# get tree for the worktree
get_tree_w()
{
	i_tree=$(git_write_tree)
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
		git_write_tree &&
		rm -f "$TMP_INDEX"
	)
}

# get tree for arbitrary ref
get_tree_r()
{
	echo "$1"
}

# strip_ref "$(git symbolic-ref HEAD)"
# Output will have a leading refs/heads/ or refs/$topbases/ stripped if present
strip_ref()
{
	case "$1" in
		refs/"$topbases"/*)
			echol "${1#refs/$topbases/}"
			;;
		refs/heads/*)
			echol "${1#refs/heads/}"
			;;
		*)
			echol "$1"
	esac
}

# pretty_tree [-t] NAME [-b | -i | -w | -r]
# Output tree ID of a cleaned-up tree without tg's artifacts.
# NAME will be ignored for -i and -w, but needs to be present
# With -r NAME must be a full ref name to a treeish (it's used as-is)
# If -t is used the tree is written into the alternate temporary objects area
pretty_tree()
{
	use_alt_temp_odb=
	[ "$1" != "-t" ] || { shift; use_alt_temp_odb=1; }
	name="$1"
	source="${2#?}"
	git ls-tree --full-tree "$(get_tree_$source "$name")" |
		sed -ne '/	\.top.*$/!p' |
		git_mktree
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
				;;
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

# standard input is a diff
# standard output is the "+" lines with leading "+ " removed
diff_added_lines()
{
	awk '
BEGIN      { in_hunk = 0; }
/^@@ /     { in_hunk = 1; }
/^\+/      { if (in_hunk == 1) printf("%s\n", substr($0, 2)); }
/^[^@ +-]/ { in_hunk = 0; }
'
}

# $1 is name of new branch to create locally if all of these are true:
#   a) exists as a remote TopGit branch for "$base_remote"
#   b) the branch "name" does not have any invalid characters in it
#   c) neither of the two branch refs (branch or base) exist locally
# returns success only if a new local branch was created (and dumps message)
auto_create_local_remote()
{
	case "$1" in ""|*[" $tab$lf~^:\\*?["]*|.*|*/.*|*.|*./|/*|*/|*//*) return 1; esac
	[ -n "$base_remote" ] &&
	git update-ref --stdin <<-EOT >/dev/null 2>&1 &&
		verify refs/remotes/$base_remote/${topbases#heads/}/$1 refs/remotes/$base_remote/${topbases#heads/}/$1
		verify refs/remotes/$base_remote/$1 refs/remotes/$base_remote/$1
		create refs/$topbases/$1 refs/remotes/$base_remote/${topbases#heads/}/$1^0
		create refs/heads/$1 refs/remotes/$base_remote/$1^0
	EOT
	{ init_reflog "refs/$topbases/$1" || :; } &&
	info "topic branch '$1' automatically set up from remote '$base_remote'"
}

# setup_hook NAME
setup_hook()
{
	tgname="${0##*/}"
	hook_call="\"\$(\"$tgname\" --hooks-path)\"/$1 \"\$@\""
	if [ -f "$git_hooks_dir/$1" ] && grep -Fq "$hook_call" "$git_hooks_dir/$1"; then
		# Another job well done!
		return
	fi
	# Prepare incantation
	hook_chain=
	if [ -s "$git_hooks_dir/$1" -a -x "$git_hooks_dir/$1" ]; then
		hook_call="$hook_call"' || exit $?'
		if [ -L "$git_hooks_dir/$1" ] || ! sed -n 1p <"$git_hooks_dir/$1" | grep -Fqx "#!@SHELL_PATH@"; then
			chain_num=
			while [ -e "$git_hooks_dir/$1-chain$chain_num" ]; do
				chain_num=$(( $chain_num + 1 ))
			done
			mv -f "$git_hooks_dir/$1" "$git_hooks_dir/$1-chain$chain_num"
			hook_chain=1
		fi
	else
		hook_call="exec $hook_call"
		[ -d "$git_hooks_dir" ] || mkdir -p "$git_hooks_dir" || :
	fi
	# Don't call hook if tg is not installed
	hook_call="if command -v \"$tgname\" >/dev/null 2>&1; then $hook_call; fi"
	# Insert call into the hook
	{
		echol "#!@SHELL_PATH@"
		echol "$hook_call"
		if [ -n "$hook_chain" ]; then
			echol "exec \"\$0-chain$chain_num\" \"\$@\""
		else
			[ ! -s "$git_hooks_dir/$1" ] || cat "$git_hooks_dir/$1"
		fi
	} >"$git_hooks_dir/$1+"
	chmod a+x "$git_hooks_dir/$1+"
	mv "$git_hooks_dir/$1+" "$git_hooks_dir/$1"
}

# setup_ours (no arguments)
setup_ours()
{
	if [ ! -s "$git_common_dir/info/attributes" ] || ! grep -q topmsg "$git_common_dir/info/attributes"; then
		[ -d "$git_common_dir/info" ] || mkdir "$git_common_dir/info"
		{
			echo ".topmsg	merge=ours"
			echo ".topdeps	merge=ours"
		} >>"$git_common_dir/info/attributes"
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

# true if $1 is contained by (or the same as) $2
# this is never slower than merge-base --is-ancestor and is often slightly faster
contained_by()
{
        [ "$(git rev-list --count --max-count=1 "$1" --not "$2" --)" = "0" ]
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
	contained_by "$_revb2" "$_revb1" || _result=1
	if [ -d "$tg_cache_dir/$1/.bc/$2" ]; then
		echo "$_result" "$_revb1" "$_revb2" >"$tg_cache_dir/$1/.bc/$2/.d"
	fi
	return $_result
}

create_ref_dirs()
{
	[ ! -s "$tg_tmp_dir/tg~ref-dirs-created" -a -s "$tg_ref_cache" ] || return 0
	awk -v p="$tg_tmp_dir/cached/" '{print p $1}' <"$tg_ref_cache" | tr '\n' '\0' | xargs -0 mkdir -p
	echo 1 >"$tg_tmp_dir/tg~ref-dirs-created"
}

# If the first argument is non-empty, stores "1" there if this call created the cache
v_create_ref_cache()
{
	[ -n "$tg_ref_cache" -a ! -s "$tg_ref_cache" ] || return 0
	_remotespec=
	[ -z "$base_remote" ] || _remotespec="refs/remotes/$base_remote"
	[ -z "$1" ] || eval "$1=1"
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
		awk -v r="$1" 'BEGIN {e=1}; $1 == r {print $2; e=0; exit}; END {exit e}' <"$tg_ref_cache"
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
			;;
		$octet20)
			printf '%s' "$1"
			return;;
		*)
			die "ref_exists_rev requires fully-qualified ref name (given: $1)"
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
# Optional second argument defaults to --short but may be any --short=.../--no-short option
ref_exists_rev_short()
{
	case "$1" in
		refs/*)
			;;
		$octet20)
			;;
		*)
			die "ref_exists_rev_short requires fully-qualified ref name"
	esac
	[ -n "$tg_read_only" ] || { git rev-parse --quiet --verify ${2:---short} "$1^0" -- 2>/dev/null; return; }
	_result=
	_result_rev=
	{ read -r _result _result_rev <"$tg_tmp_dir/cached/$1/.rfs"; } 2>/dev/null || :
	[ -z "$_result" ] || { printf '%s' "$_result_rev"; return $_result; }
	_result_rev="$(rev_parse "$1")"
	_result=$?
	if [ $_result -eq 0 ]; then
		_result_rev="$(git rev-parse --verify ${2:---short} --quiet "$_result_rev" --)"
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
# Whether BRANCH has a remote equivalent (accepts ${topbases#heads/}/ too)
has_remote()
{
	[ -n "$base_remote" ] && ref_exists "refs/remotes/$base_remote/$1"
}

# Return the verified TopGit branch name for "$2" in "$1" or die with an error.
# If -z "$1" still set return code but do not return result
# As a convenience, if HEAD or @ is given and HEAD is a symbolic ref to
# refs/heads/... then ... will be verified instead.
# if "$3" = "-f" (for fail) then return an error rather than dying.
v_verify_topgit_branch()
{
	if [ "$2" = "HEAD" ] || [ "$2" = "@" ]; then
		_verifyname="$(git symbolic-ref HEAD 2>/dev/null)" || :
		[ -n "$_verifyname" -o "$3" = "-f" ] || die "HEAD is not a symbolic ref"
		case "$_verifyname" in refs/"$topbases"/*|refs/heads/*);;*)
			[ "$3" != "-f" ] || return 1
			die "HEAD is not a symbolic ref to the refs/heads namespace"
		esac
		set -- "$1" "$_verifyname" "$3"
	fi
	case "$2" in
		refs/"$topbases"/*)
			_verifyname="${2#refs/$topbases/}"
			;;
		refs/heads/*)
			_verifyname="${2#refs/heads/}"
			;;
		*)
			_verifyname="$2"
			;;
	esac
	if ! ref_exists "refs/heads/$_verifyname"; then
		[ "$3" != "-f" ] || return 1
		die "no such branch: $_verifyname"
	fi
	if ! ref_exists "refs/$topbases/$_verifyname"; then
		[ "$3" != "-f" ] || return 1
		die "not a TopGit-controlled branch: $_verifyname"
	fi
	[ -z "$1" ] || eval "$1="'"$_verifyname"'
}

# Return the verified TopGit branch name or die with an error.
# As a convenience, if HEAD or @ is given and HEAD is a symbolic ref to
# refs/heads/... then ... will be verified instead.
# if "$2" = "-f" (for fail) then return an error rather than dying.
verify_topgit_branch()
{
	v_verify_topgit_branch _verifyname "$@" || return
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
	{ read -r _result _result_rev _result_rev_base <"$tg_cache_dir/refs/heads/$_branch_name/.ann"; } 2>/dev/null || :
	[ -z "$_result" -o "$_result_rev" != "$_rev" -o "$_result_rev_base" != "$_rev_base" ] || return $_result

	# use the merge base in case the base is ahead.
	mb="$(git merge-base "$_rev_base" "$_rev" 2>/dev/null)"

	test -z "$mb" || test "$(rev_parse_tree "$mb")" = "$(rev_parse_tree "$_rev")"
	_result=$?
	[ -d "$tg_cache_dir/refs/heads/$_branch_name" ] || mkdir -p "$tg_cache_dir/refs/heads/$_branch_name" 2>/dev/null
	[ ! -d "$tg_cache_dir/refs/heads/$_branch_name" ] ||
	echo $_result $_rev $_rev_base >"$tg_cache_dir/refs/heads/$_branch_name/.ann" 2>/dev/null || :
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
# if optional "$1" given also verify that a checkout to "$1" would succeed
ensure_clean_tree()
{
	check_status
	[ -z "$tg_state$git_state" ] || { do_status; exit 1; }
	git update-index --ignore-submodules --refresh ||
		die "the working directory has uncommitted changes (see above) - first commit or reset them"
	[ -z "$(git diff-index --cached --name-status -r --ignore-submodules HEAD --)" ] ||
		die "the index has uncommited changes"
	[ -z "$1" ] || git read-tree -n -u -m "$1" ||
		die "git checkout \"$1\" would fail"
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
# followed by a 1 if the branch is "tgish" (2 if it also has a remote); 0 if not
# followed by a 0 for a non-leaf, 1 for a leaf or 2 for annihilated tgish
# but missing and remotes are always "0"
# then the branch name followed by its depedency chain (which might be empty)
# An output line might look like this:
#   0 1 1 t/foo/leaf t/foo/int t/stage
# If no_remotes is non-empty, exclude remotes
# If recurse_preorder is non-empty, do a preorder rather than postorder traversal
# but the leaf info will always be 0 or 2 in that case
# If with_top_level is non-empty, include the top-level that's normally omitted
# any branch names in the space-separated recurse_deps_exclude variable
# are skipped (along with their dependencies)
recurse_deps_internal()
{
	case " $recurse_deps_exclude " in *" $1 "*) return 0; esac
	_ref_hash=
	if ! _ref_hash="$(ref_exists_rev "refs/heads/$1")"; then
		[ -z "$2" ] || echo "1 0 0 $*"
		return 0
	fi

	_is_tgish=0
	_ref_hash_base=
	_is_leaf=0
	! _ref_hash_base="$(ref_exists_rev "refs/$topbases/$1")" || _is_tgish=1
	[ "$_is_tgish" = "0" ] || [ -n "$no_remotes" ] || ! has_remote "${topbases#heads/}/$1" || _is_tgish=2
	[ "$_is_tgish" = "0" ] || ! branch_annihilated "$1" "$_ref_hash" "$_ref_hash_base" || _is_leaf=2
	[ -z "$recurse_preorder" -o -z "${2:-$with_top_level}" ] || echo "0 $_is_tgish $_is_leaf $*"

	# If no_remotes is unset also check our base against remote base.
	# Checking our head against remote head has to be done in the helper.
	if [ "$_is_tgish" = "2" ]; then
		echo "0 0 0 refs/remotes/$base_remote/${topbases#heads/}/$1 $*"
	fi

	# if the branch was annihilated, it is considered to have no dependencies
	[ "$_is_leaf" = "2" ] || _is_leaf=1
	if [ "$_is_tgish" != "0" ] && [ "$_is_leaf" = "1" ]; then
		#TODO: handle nonexisting .topdeps?
		while read _dname && [ -n "$_dname" ]; do
			# Avoid depedency loops
			case " $* " in *" $_dname "*)
				warn "dependency loop detected in branch $_dname"
				_is_leaf=0
				continue
			esac
			# Shoo shoo, leave our environment alone!
			_dep_is_leaf=0
			(recurse_deps_internal "$_dname" "$@") || _dep_is_leaf=$?
			[ "$_dep_is_leaf" = "2" ] || _is_leaf=0
		done <<-EOT
			$(cat_deps "$1")
		EOT
	fi

	[ -n "$recurse_preorder" -o -z "${2:-$with_top_level}" ] || echo "0 $_is_tgish $_is_leaf $*"
	return ${_is_leaf:-0}
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
		! [ -e "$tg_tmp_dir/cached" ] && ! [ -e "$tg_tmp_dir/tg~ref-dirs-created" ] ||
		rm -rf "$tg_tmp_dir/cached" "$tg_tmp_dir/tg~ref-dirs-created"
		tg_read_only=1
	fi
	_my_ref_cache=
	v_create_ref_cache _my_ref_cache
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
	! [ -e "$tg_tmp_dir/cached" ] && ! [ -e "$tg_tmp_dir/tg~ref-dirs-created" ] ||
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
# CMD can refer to the following variables:
#
#   _ret              starts as 0; CMD can change; will be final return result
#   _dep              bare branch name or "refs/remotes/..." for a remote base
#   _name             has $_dep in its .topdeps ("" for top and $with_top_level)
#   _depchain         0+ space-separated branch names forming a path to top
#   _dep_missing      boolean "1" if no such $_dep ref; "" if ref present
#   _dep_is_leaf      boolean "1" if leaf; "" if not
#   _dep_is_tgish     boolean "1" if tgish; "" if not (which implies no remote)
#   _dep_has_remote   boolean "1" if $_dep has_remote; "" if not
#   _dep_annihilated  boolean "1" if $_dep annihilated; "" if not
#
# CMD may use a "return" statement without issue; its return value is ignored,
# but if CMD sets _ret to a negative value, e.g. "-0" or "-1" the enumeration
# will stop immediately and the value with the leading "-" stripped off will
# be the final result code
#
# CMD can refer to $_name for queried branch name,
# $_dep for dependency name,
# $_depchain for space-seperated branch backtrace,
# $_dep_missing boolean to check whether $_dep is present
# and the $_dep_is_tgish and $_dep_annihilated booleans.
# If recurse_preorder is NOT set then the $_dep_is_leaf boolean is also valid.
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
	recurse_deps_internal "$@" >>"$_depsfile" || :
	undo_become_cacheable

	_ret=0
	while read _ismissing _istgish _isleaf _dep _name _deppath; do
		_depchain="$_name${_deppath:+ $_deppath}"
		_dep_is_tgish=
		[ "$_istgish" = "0" ] || _dep_is_tgish=1
		_dep_has_remote=
		[ "$_istgish" != "2" ] || _dep_has_remote=1
		_dep_missing=
		if [ "$_ismissing" != "0" ]; then
			_dep_missing=1
			case " $missing_deps " in *" $_dep "*);;*)
				missing_deps="${missing_deps:+$missing_deps }$_dep"
			esac
		fi
		_dep_annihilated=
		_dep_is_leaf=
		if [ "$_isleaf" = "1" ]; then
			_dep_is_leaf=1
		elif [ "$_isleaf" = "2" ]; then
			_dep_annihilated=1
		fi
		do_eval "$_cmd" || :
		if [ "${_ret#-}" != "$_ret" ]; then
			_ret="${_ret#-}"
			break
		fi
	done <"$_depsfile"
	rm -f "$_depsfile"
	return ${_ret:-0}
}

find_leaves_internal()
{
	if [ -n "$_dep_is_leaf" ] && [ -z "$_dep_annihilated" ] && [ -z "$_dep_missing" ]; then
		if [ -n "$_dep_is_tgish" ]; then
			fulldep="refs/$topbases/$_dep"
		else
			fulldep="refs/heads/$_dep"
		fi
		case " $seen_leaf_refs " in *" $fulldep "*);;*)
			seen_leaf_refs="${seen_leaf_refs:+$seen_leaf_refs }$fulldep"
			if fullrev="$(ref_exists_rev "$fulldep")"; then
				case " $seen_leaf_revs " in *" $fullrev "*);;*)
					seen_leaf_revs="${seen_leaf_revs:+$seen_leaf_revs }$fullrev"
					# See if Git knows it by another name
					if tagname="$(git describe --exact-match "$fullrev" 2>/dev/null)" && [ -n "$tagname" ]; then
						echo "refs/tags/$tagname"
					else
						echo "$fulldep"
					fi
				esac
			fi
		esac
	fi
}

# find_leaves NAME
# output (one per line) the unique leaves of NAME
# a leaf is either
#   1) a non-tgish dependency
#   2) the base of a tgish dependency with no non-annihilated dependencies
# duplicates are suppressed (by commit rev) and remotes are always ignored
# if a leaf has an exact tag match that will be output
# note that recurse_deps_exclude IS honored for this operation
find_leaves()
{
	no_remotes=1
	with_top_level=1
	recurse_preorder=
	seen_leaf_refs=
	seen_leaf_revs=
	recurse_deps find_leaves_internal "$1"
	with_top_level=
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
		{ read -r _result _result_rev <"$tg_cache_dir/refs/heads/$1/.mt"; } 2>/dev/null || :
		[ -z "$_result" -o "$_result_rev" != "$_rev" ] || return $_result
		_result=0
		[ "$(pretty_tree -t "$1" -b)" = "$(pretty_tree -t "$1" $2)" ] || _result=$?
		[ -d "$tg_cache_dir/refs/heads/$1" ] || mkdir -p "$tg_cache_dir/refs/heads/$1" 2>/dev/null
		[ ! -d "$tg_cache_dir/refs/heads/$1" ] || echo $_result $_rev >"$tg_cache_dir/refs/heads/$1/.mt"
		return $_result
	else
		[ "$(pretty_tree -t "$1" -b)" = "$(pretty_tree -t "$1" $2)" ]
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

# checkout_symref_full [-f] FULLREF [SEED]
# Just like git checkout $iowopt -b FULLREF [SEED] except that FULLREF MUST start with
# refs/ and HEAD is ALWAYS set to a symref to it and [SEED] (default is FULLREF)
# MUST be a committish which if present will be used instead of current FULLREF
# (and FULLREF will be updated to it as well in that case)
# Any merge state is always cleared by this function
# With -f it's like git checkout $iowopt -f -b FULLREF (uses read-tree --reset
# instead of -m) but it will clear out any unmerged entries
# As an extension, FULLREF may also be a full hash to create a detached HEAD instead
checkout_symref_full()
{
	_mode=-m
	if [ "$1" = "-f" ]; then
		_mode="--reset"
		shift
	fi
	_ishash=
	case "$1" in
		refs/?*)
			;;
		$octet20)
			_ishash=1
			[ -z "$2" ] || [ "$1" = "$2" ] ||
				die "programmer error: invalid checkout_symref_full \"$1\" \"$2\""
			set -- HEAD "$1"
			;;
		*)
			die "programmer error: invalid checkout_symref_full \"$1\""
			;;
	esac
	_seedrev="$(git rev-parse --quiet --verify "${2:-$1}^0" --)" ||
		die "invalid committish: \"${2:-$1}\""
	# Clear out any MERGE_HEAD kruft
	rm -f "$git_dir/MERGE_HEAD" || :
	# We have to do all the hard work ourselves :/
	# This is like git checkout -b "$1" "$2"
	# (or just git checkout "$1"),
	# but never creates a detached HEAD (unless $1 is a hash)
	git read-tree -u $_mode HEAD "$_seedrev" &&
	{
		[ -z "$2" ] && [ "$(git cat-file -t "$1")" = "commit" ] ||
		git update-ref "$1" "$_seedrev"
	} && {
		[ -n "$_ishash" ] || git symbolic-ref HEAD "$1"
	}
}

# switch_to_base NAME [SEED]
switch_to_base()
{
	checkout_symref_full "refs/$topbases/$1" "$2"
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
		for cmd in "$TG_INST_CMDDIR"/tg-[!-]*; do
			! [ -r "$cmd" ] && continue
			# strip directory part and "tg-" prefix
			cmd="${cmd##*/}"
			cmd="${cmd#tg-}"
			[ "$cmd" != "migrate-bases" ] || continue
			[ "$cmd" != "summary" ] || cmd="st[atus]|$cmd"
			cmds="$cmds$sep$cmd"
			sep="|"
		done

		echo "TopGit version $TG_VERSION - A different patch queue manager"
		echo "Usage: $tgname [-C <dir>] [-r <remote> | -u] [-c <name>=<val>] ($cmds) ..."
		echo "   Or: $tgname help [-w] [<command>]"
		echo "Use \"$tgdisplaydir$tgname help tg\" for overview of TopGit"
	elif [ -r "$TG_INST_CMDDIR"/tg-$1 -o -r "$TG_INST_SHAREDIR/tg-$1.txt" ] ; then
		if [ -n "$_www" ]; then
			nohtml=
			if ! [ -r "$TG_INST_SHAREDIR/topgit.html" ]; then
				echo "${0##*/}: missing html help file:" \
					"$TG_INST_SHAREDIR/topgit.html" 1>&2
				nohtml=1
			fi
			if ! [ -r "$TG_INST_SHAREDIR/tg-$1.html" ]; then
				echo "${0##*/}: missing html help file:" \
					"$TG_INST_SHAREDIR/tg-$1.html" 1>&2
				nohtml=1
			fi
			if [ -n "$nohtml" ]; then
				echo "${0##*/}: use" \
					"\"${0##*/} help $1\" instead" 1>&2
				exit 1
			fi
			git web--browse -c help.browser "$TG_INST_SHAREDIR/tg-$1.html"
			exit
		fi
		output()
		{
			if [ -r "$TG_INST_CMDDIR"/tg-$1 ] ; then
				"$TG_INST_CMDDIR"/tg-$1 -h 2>&1 || :
				echo
			elif [ "$1" = "help" ]; then
				echo "Usage: ${tgname:-tg} help [-w] [<command>]"
				echo
			elif [ "$1" = "status" ] || [ "$1" = "st" ]; then
				echo "Usage: ${tgname:-tg} @tgsthelpusage@"
				echo
			fi
			if [ -r "$TG_INST_SHAREDIR/tg-$1.txt" ] ; then
				cat "$TG_INST_SHAREDIR/tg-$1.txt"
			fi
		}
		page output "$1"
	else
		echo "${0##*/}: no help for $1" 1>&2
		do_help
		exit 1
	fi
}

check_status()
{
	git_state=
	git_remove=
	if [ -e "$git_dir/MERGE_HEAD" ]; then
		git_state="merge"
	elif [ -e "$git_dir/rebase-apply/applying" ]; then
		git_state="am"
		git_remove="$git_dir/rebase-apply"
	elif [ -e "$git_dir/rebase-apply" ]; then
		git_state="rebase"
		git_remove="$git_dir/rebase-apply"
	elif [ -e "$git_dir/rebase-merge" ]; then
		git_state="rebase"
		git_remove="$git_dir/rebase-merge"
	elif [ -e "$git_dir/CHERRY_PICK_HEAD" ]; then
		git_state="cherry-pick"
	elif [ -e "$git_dir/BISECT_LOG" ]; then
		git_state="bisect"
	elif [ -e "$git_dir/REVERT_HEAD" ]; then
		git_state="revert"
	fi
	git_remove="${git_remove#./}"

	tg_state=
	tg_remove=
	tg_topmerge=
	if [ -e "$git_dir/tg-update" ]; then
		tg_state="update"
		tg_remove="$git_dir/tg-update"
		! [ -s "$git_dir/tg-update/merging_topfiles" ] || tg_topmerge=1
	fi
	tg_remove="${tg_remove#./}"
}

# Show status information
do_status()
{
	do_status_result=0
	do_status_verbose=
	do_status_help=
	abbrev=refs
	pfx=
	while [ $# -gt 0 ] && case "$1" in
		--help|-h)
			do_status_help=1
			break;;
		-vv)
			# kludge in this common bundling option
			abbrev=
			do_status_verbose=1
			pfx="## "
			;;
		--verbose|-v)
			[ -z "$do_status_verbose" ] || abbrev=
			do_status_verbose=1
			pfx="## "
			;;
		--exit-code)
			do_status_result=2
			;;
		*)
			die "unknown status argument: $1"
			;;
	esac; do shift; done
	if [ -n "$do_status_help" ]; then
		echo "Usage: ${tgname:-tg} @tgsthelpusage@"
		return
	fi
	check_status
	symref="$(git symbolic-ref --quiet HEAD)" || :
	headrv="$(git rev-parse --quiet --verify ${abbrev:+--short} HEAD --)" || :
	if [ -n "$symref" ]; then
		uprefpart=
		if [ -n "$headrv" ]; then
			upref="$(git rev-parse --symbolic-full-name @{upstream} 2>/dev/null)" || :
			if [ -n "$upref" ]; then
				uprefpart=" ... ${upref#$abbrev/remotes/}"
				mbase="$(git merge-base HEAD "$upref")" || :
				ahead="$(git rev-list --count HEAD ${mbase:+--not $mbase})" || ahead=0
				behind="$(git rev-list --count "$upref" ${mbase:+--not $mbase})" || behind=0
				[ "$ahead$behind" = "00" ] || uprefpart="$uprefpart ["
				[ "$ahead" = "0" ] || uprefpart="${uprefpart}ahead $ahead"
				[ "$ahead" = "0" ] || [ "$behind" = "0" ] || uprefpart="$uprefpart, "
				[ "$behind" = "0" ] || uprefpart="${uprefpart}behind $behind"
				[ "$ahead$behind" = "00" ] || uprefpart="$uprefpart]"
			fi
		fi
		echol "${pfx}HEAD -> ${symref#$abbrev/heads/} [${headrv:-unborn}]$uprefpart"
	else
		echol "${pfx}HEAD -> ${headrv:-?}"
	fi
	if [ -n "$tg_state" ]; then
		extra=
		if [ "$tg_state" = "update" ]; then
			IFS= read -r uname <"$git_dir/tg-update/name" || :
			[ -z "$uname" ] ||
			extra="; currently updating branch '$uname'"
		fi
		echol "${pfx}tg $tg_state in progress$extra"
		if [ -s "$git_dir/tg-update/fullcmd" ] && [ -s "$git_dir/tg-update/names" ]; then
			printf "${pfx}You are currently updating as a result of:\n${pfx}  "
			cat "$git_dir/tg-update/fullcmd"
			bcnt="$(( $(wc -w < "$git_dir/tg-update/names") ))"
			if [ $bcnt -gt 1 ]; then
				pcnt=0
				! [ -s "$git_dir/tg-update/processed" ] ||
				pcnt="$(( $(wc -w < "$git_dir/tg-update/processed") ))"
				echo "${pfx}$pcnt of $bcnt branches updated so far"
			fi
		fi
		if [ "$tg_state" = "update" ]; then
			echol "${pfx}  (use \"$tgdisplayac update --continue\" to continue)"
			echol "${pfx}  (use \"$tgdisplayac update --skip\" to skip this branch and continue)"
			echol "${pfx}  (use \"$tgdisplayac update --stop\" to stop and retain changes so far)"
			echol "${pfx}  (use \"$tgdisplayac update --abort\" to restore pre-update state)"
		fi
	fi
	[ -z "$git_state" ] || echo "${pfx}git $git_state in progress"
	if [ "$git_state" = "merge" ]; then
		ucnt="$(( $(git ls-files --unmerged --full-name --abbrev :/ | wc -l) ))"
		if [ $ucnt -gt 0 ]; then
			echo "${pfx}"'fix conflicts and then "git commit" the result'
		else
			echo "${pfx}"'all conflicts fixed; run "git commit" to record result'
		fi
	fi
	if [ -z "$git_state" ]; then
		gsp="$(git status --porcelain 2>/dev/null)" || return 0 # bare repository
		gspcnt=0
		[ -z "$gsp" ] ||
		gspcnt="$(( $(printf '%s\n' "$gsp" | sed -n '/^??/!p' | wc -l) ))"
		untr=
		if [ "$gspcnt" -eq 0 ]; then
			[ -z "$gsp" ] || untr="; non-ignored, untracked files present"
			echo "${pfx}working directory is clean$untr"
			[ -n "$tg_state" ] || do_status_result=0
		else
			echo "${pfx}working directory is DIRTY"
			[ -z "$do_status_verbose" ] || git status --short --untracked-files=no
		fi
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
			_gp="$(git var GIT_PAGER 2>/dev/null)" || :
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

	# this is needed so e.g. $(git diff) will still colorize it's output if
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

got_cdup_result=
git_cdup_result=
v_get_show_cdup()
{
	if [ -z "$got_cdup_result" ]; then
		git_cdup_result="$(git rev-parse --show-cdup)"
		got_cdup_result=1
	fi
	[ -z "$1" ] || eval "$1="'"$git_cdup_result"'
}

setup_git_dirs()
{
	[ -n "$git_dir" ] || git_dir="$(git rev-parse --git-dir)"
	if [ -n "$git_dir" ] && [ -d "$git_dir" ]; then
		git_dir="$(cd "$git_dir" && pwd)"
	fi
	if [ -z "$git_common_dir" ]; then
		if vcmp "$git_version" '>=' "2.5"; then
			# rev-parse --git-common-dir is broken and may give
			# an incorrect result unless the current directory is
			# already set to the top level directory
			v_get_show_cdup
			git_common_dir="$(cd "./$git_cdup_result" && cd "$(git rev-parse --git-common-dir)" && pwd)"
		else
			git_common_dir="$git_dir"
		fi
	fi
	[ -n "$git_dir" ] && [ -n "$git_common_dir" ] &&
	[ -d "$git_dir" ] && [ -d "$git_common_dir" ] || die "Not a git repository"
	git_hooks_dir="$git_common_dir/hooks"
	if vcmp "$git_version" '>=' "2.9" && gchp="$(git config --path --get core.hooksPath 2>/dev/null)" && [ -n "$gchp" ]; then
		case "$gchp" in
			/[!/]*)
				git_hooks_dir="$gchp"
				;;
			*)
				[ -n "$1" ] || warn "ignoring non-absolute core.hooksPath: $gchp"
				;;
		esac
		unset gchp
	fi
}

basic_setup()
{
	setup_git_dirs $1
	if [ -z "$base_remote" ]; then
		if [ "${TG_EXPLICIT_REMOTE+set}" = "set" ]; then
			base_remote="$TG_EXPLICIT_REMOTE"
		else
			base_remote="$(git config topgit.remote 2>/dev/null)" || :
		fi
	fi
	tgsequester="$(git config --bool topgit.sequester 2>/dev/null)" || :
	tgnosequester=
	[ "$tgsequester" != "false" ] || tgnosequester=1
	unset tgsequester

	# catch errors if topbases is used without being set
	unset tg_topbases_set
	topbases="programmer*:error"
	topbasesrx="programmer*:error}"
	oldbases="$topbases"
}

## Initial setup
initial_setup()
{
	# suppress the merge log editor feature since git 1.7.10

	GIT_MERGE_AUTOEDIT=no
	export GIT_MERGE_AUTOEDIT

	basic_setup $1
	iowopt=
	! vcmp "$git_version" '>=' "2.5" || iowopt="--ignore-other-worktrees"
	auhopt=
	! vcmp "$git_version" '>=' "2.9" || auhopt="--allow-unrelated-histories"
	v_get_show_cdup root_dir
	root_dir="${root_dir:-.}"
	logrefupdates="$(git config --bool core.logallrefupdates 2>/dev/null)" || :
	[ "$logrefupdates" = "true" ] || logrefupdates=

	# make sure root_dir doesn't end with a trailing slash.

	root_dir="${root_dir%/}"

	# create global temporary directories, inside GIT_DIR

	tg_tmp_dir=
	trap 'rm -rf "$tg_tmp_dir"' EXIT
	trap 'exit 129' HUP
	trap 'exit 130' INT
	trap 'exit 131' QUIT
	trap 'exit 134' ABRT
	trap 'exit 143' TERM
	tg_tmp_dir="$(mktemp -d "$git_dir/tg-tmp.XXXXXX" 2>/dev/null)" || tg_tmp_dir=
	[ -n "$tg_tmp_dir" ] || tg_tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/tg-tmp.XXXXXX" 2>/dev/null)" || tg_tmp_dir=
	[ -n "$tg_tmp_dir" ] || [ -z "$TMPDIR" ] || tg_tmp_dir="$(mktemp -d "/tmp/tg-tmp.XXXXXX" 2>/dev/null)" || tg_tmp_dir=
	tg_ref_cache="$tg_tmp_dir/tg~ref-cache"
	[ -n "$tg_tmp_dir" ] && [ -w "$tg_tmp_dir" ] && { >"$tg_ref_cache"; } >/dev/null 2>&1 ||
		die "could not create a writable temporary directory"

	# make sure global cache directory exists inside GIT_DIR or $tg_tmp_dir

	user_id_no="$(id -u)" || :
	: "${user_id_no:=_99_}"
	tg_cache_dir="$git_common_dir/tg-cache"
	[ -d "$tg_cache_dir" ] || mkdir "$tg_cache_dir" >/dev/null 2>&1 || tg_cache_dir=
	[ -z "$tg_cache_dir" ] || tg_cache_dir="$tg_cache_dir/$user_id_no"
	[ -z "$tg_cache_dir" ] || [ -d "$tg_cache_dir" ] || mkdir "$tg_cache_dir" >/dev/null 2>&1 || tg_cache_dir=
	[ -z "$tg_cache_dir" ] || { >"$tg_cache_dir/.tgcache"; } >/dev/null 2>&1 || tg_cache_dir=
	if [ -z "$tg_cache_dir" ]; then
		tg_cache_dir="$tg_tmp_dir/tg-cache"
		[ -d "$tg_cache_dir" ] || mkdir "$tg_cache_dir" >/dev/null 2>&1 || tg_cache_dir=
		[ -z "$tg_cache_dir" ] || { >"$tg_cache_dir/.tgcache"; } >/dev/null 2>&1 || tg_cache_dir=
	fi
	[ -n "$tg_cache_dir" ] ||
		die "could not create a writable tg-cache directory (even a temporary one)"

	# GIT_ALTERNATE_OBJECT_DIRECTORIES can contain double-quoted entries
	# since Git v2.11.1; however, it's only necessary for : (or perhaps ;)
	# so we avoid it if possible and require v2.11.1 to do it at all
	# otherwise just don't make an alternates temporary store in that case;
	# it's okay to not have one; everything will still work; the nicety of
	# making the temporary tree objects vanish when tg exits just won't
	# happen in that case but nothing will break also be sure to reuse
	# the parent's if we've been recursively invoked and it's for the
	# same repository we were invoked on

	tg_use_alt_odb=1
	_odbdir="${GIT_OBJECT_DIRECTORY:-$git_common_dir/objects}"
	[ -n "$_odbdir" ] && [ -d "$_odbdir" ] || tg_use_alt_odb=
	_fulltmpdir=
	[ -z "$tg_use_alt_odb" ] || _fulltmpdir="$(cd "$tg_tmp_dir" && pwd -P)"
	case "$_fulltmpdir" in *[";:"]*) vcmp "$git_version" '>=' "2.11.1" || tg_use_alt_odb=; esac
	_fullodbdir=
	[ -z "$tg_use_alt_odb" ] || _fullodbdir="$(cd "$_odbdir" && pwd -P)"
	if [ -n "$tg_use_alt_odb" ] && [ -n "$TG_OBJECT_DIRECTORY" ] && [ -d "$TG_OBJECT_DIRECTORY/info" ] &&
	   [ -f "$TG_OBJECT_DIRECTORY/info/alternates" ] && [ -r "$TG_OBJECT_DIRECTORY/info/alternates" ]; then
		if IFS= read -r _otherodbdir <"$TG_OBJECT_DIRECTORY/info/alternates" &&
		   [ -n "$_otherodbdir" ] && [ "$_otherodbdir" = "$_fullodbdir" ]; then
			tg_use_alt_odb=2
		fi
	fi
	if [ "$tg_use_alt_odb" = "1" ]; then
		# create an alternate objects database to keep the ephemeral objects in
		mkdir -p "$tg_tmp_dir/objects/info"
		echol "$_fullodbdir" >"$tg_tmp_dir/objects/info/alternates"
		TG_OBJECT_DIRECTORY="$_fulltmpdir/objects"
		case "$TG_OBJECT_DIRECTORY" in
			*[";:"]*)
				# surround in "..." and backslash-escape internal '"' and '\\'
				_altodbdq="\"$(printf '%s\n' "$TG_OBJECT_DIRECTORY" |
					sed 's/\([""\\]\)/\\\1/g')\""
				;;
			*)
				_altodbdq="$TG_OBJECT_DIRECTORY"
				;;
		esac
		TG_PRESERVED_ALTERNATES="$GIT_ALTERNATE_OBJECT_DIRECTORIES"
		if [ -n "$GIT_ALTERNATE_OBJECT_DIRECTORIES" ]; then
			GIT_ALTERNATE_OBJECT_DIRECTORIES="$_altodbdq:$GIT_ALTERNATE_OBJECT_DIRECTORIES"
		else
			GIT_ALTERNATE_OBJECT_DIRECTORIES="$_altodbdq"
		fi
		export TG_PRESERVED_ALTERNATES TG_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_OBJECT_DIRECTORY
	fi
}

set_topbases()
{
	# refer to "top-bases" in a refname with $topbases

	[ -z "$tg_topbases_set" ] || return 0

	topbases_implicit_default=1
	# See if topgit.top-bases is set to heads or refs
	tgtb="$(git config "topgit.top-bases" 2>/dev/null)" || :
	if [ -n "$tgtb" ] && [ "$tgtb" != "heads" ] && [ "$tgtb" != "refs" ]; then
		if [ -n "$1" ]; then
			# never die on the hook script
			unset tgtb
		else
			die "invalid \"topgit.top-bases\" setting (must be \"heads\" or \"refs\")"
		fi
	fi
	if [ -n "$tgtb" ]; then
		case "$tgtb" in
		heads)
			topbases="heads/{top-bases}"
			topbasesrx="heads/[{]top-bases[}]"
			oldbases="top-bases";;
		refs)
			topbases="top-bases"
			topbasesrx="top-bases"
			oldbases="heads/{top-bases}";;
		esac
		# MUST NOT be exported
		unset tgtb tg_topbases_set topbases_implicit_default
		tg_topbases_set=1
		return 0
	fi
	unset tgtb

	# check heads and top-bases and see what state the current
	# repository is in.  remotes are ignored.

	hblist=" "
	topbases=
	both=
	newtb="heads/{top-bases}"
	while read -r rn && [ -n "$rn" ]; do case "$rn" in
		"refs/heads/{top-bases}"/*)
			case "$hblist" in *" ${rn#refs/$newtb/} "*)
				if [ "$topbases" != "heads/{top-bases}" ] && [ -n "$topbases" ]; then
					both=1
					break;
				else
					topbases="heads/{top-bases}"
					topbasesrx="heads/[{]top-bases[}]"
					oldbases="top-bases"
				fi
			esac;;
		"refs/top-bases"/*)
			case "$hblist" in *" ${rn#refs/top-bases/} "*)
				if [ "$topbases" != "top-bases" ] && [ -n "$topbases" ]; then
					both=1
					break;
				else
					topbases="top-bases"
					topbasesrx="top-bases"
					oldbases="heads/{top-bases}"
				fi
			esac;;
		"refs/heads"/*)
			hblist="$hblist${rn#refs/heads/} ";;
	esac; done <<-EOT
		$(git for-each-ref --format='%(refname)' "refs/heads" "refs/top-bases" 2>/dev/null)
	EOT
	if [ -n "$both" ]; then
		if [ -n "$1" ]; then
			# hook script always prefers newer without complaint
			topbases="heads/{top-bases}"
			topbasesrx="heads/[{]top-bases[}]"
			oldbases="top-bases"
		else
			# Complain and die
			err "repository contains existing TopGit branches"
			err "but some use refs/top-bases/... for the base"
			err "and some use refs/heads/{top-bases}/... for the base"
			err "with the latter being the new, preferred location"
			err "set \"topgit.top-bases\" to either \"heads\" to use"
			err "the new heads/{top-bases} location or \"refs\" to use"
			err "the old top-bases location."
			err "(the tg migrate-bases command can also resolve this issue)"
			die "schizophrenic repository requires topgit.top-bases setting"
		fi
	elif [ -n "$topbases" ]; then
		unset topbases_implicit_default
	fi

	[ -n "$topbases" ] || {
		# default is still top-bases for now
		topbases="top-bases"
		topbasesrx="top-bases"
		oldbases="heads/{top-bases}"
	}
	# MUST NOT be exported
	unset hblist both newtb rn tg_topases_set
	tg_topbases_set=1
	return 0
}

# init_reflog "ref"
# if "$logrefupdates" is set and ref is not under refs/heads/ then force
# an empty log file to exist so that ref changes will be logged
# "$1" must be a fully-qualified refname (i.e. start with "refs/")
# However, if "$1" is "refs/tgstash" then always make the reflog
# The only ref not under refs/ that Git will write a reflog for is HEAD;
# no matter what, it will NOT update a reflog for any other bare refs so
# just quietly succeed when passed TG_STASH without doing anything.
init_reflog()
{
	[ -n "$1" ] && [ "$1" != "TG_STASH" ] || return 0
	[ -n "$logrefupdates" ] || [ "$1" = "refs/tgstash" ] || return 0
	case "$1" in refs/heads/*|HEAD) return 0;; refs/*[!/]);; *) return 1; esac
	mkdir -p "$git_common_dir/logs/${1%/*}" 2>/dev/null || :
	{ >>"$git_common_dir/logs/$1" || :; } 2>/dev/null
 }

# store the "realpath" for "$2" in "$1" except the leaf is not resolved if it's
# a symbolic link.  The directory part must exist, but the basename need not.
v_get_abs_path()
{
	[ -n "$1" ] && [ -n "$2" ] || return 1
	set -- "$1" "$2" "${2%/}"
	case "$3" in
		*/*) set -- "$1" "$2" "${3%/*}";;
		*  ) set -- "$1" "$2" ".";;
	esac
	case "$2" in */)
		set -- "$1" "${2%/}" "$3" "/"
	esac
	[ -d "$3" ] || return 1
	eval "$1="'"$(cd "$3" && pwd -P)/${2##*/}$4"'
}

## Startup

: "${TG_INST_CMDDIR:=@cmddir@}"
: "${TG_INST_SHAREDIR:=@sharedir@}"
: "${TG_INST_HOOKSDIR:=@hooksdir@}"

[ -d "$TG_INST_CMDDIR" ] ||
	die "No command directory: '$TG_INST_CMDDIR'"

if [ -n "$tg__include" ]; then

	# We were sourced from another script for our utility functions;
	# this is set by hooks.  Skip the rest of the file.  A simple return doesn't
	# work as expected in every shell.  See http://bugs.debian.org/516188

	# ensure setup happens

	initial_setup 1
	set_topbases 1

else

	set -e

	tgbin="$0"
	tgdir="${tgbin%/}"
	case "$tgdir" in */*);;*) tgdir="./$tgdir"; esac
	tgdir="${tgdir%/*}/"
	tgname="${tgbin##*/}"
	[ "$0" != "$tgname" ] || tgdir=""

	# If tg contains a '/' but does not start with one then replace it with an absolute path

	case "$0" in /*) ;; */*)
		tgdir="$(cd "${0%/*}" && pwd -P)/"
		tgbin="$tgdir$tgname"
	esac

	# tgdisplay will include any explicit -C <dir> etc. options whereas tgname will not
	# tgdisplayac is the same as tgdisplay but without any -r or -u options (ac => abort/continue)

	tgdisplaydir="$tgdir"
	tgdisplay="$tgbin"
	tgdisplayac="$tgdisplay"
	if
	    v_get_abs_path _tgnameabs "$(cmd_path "$tgname")" &&
	    _tgabs="$_tgnameabs" &&
	    { [ "$tgbin" = "$tgname" ] || v_get_abs_path _tgabs "$tgbin"; } &&
	    [ "$_tgabs" = "$_tgnameabs" ]
	then
		tgdisplaydir=""
		tgdisplay="$tgname"
		tgdisplayac="$tgdisplay"
	fi
	[ -z "$_tgabs" ] || tgbin="$_tgabs"
	unset _tgabs _tgnameabs

	tg() { command "$tgbin" "$@"; }

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

		status|--status)
			cmd=status
			shift
			break;;

		--hooks-path)
			cmd=hooks-path
			shift
			break;;

		--exec-path)
			cmd=exec-path
			shift
			break;;

		--top-bases)
			cmd=top-bases
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
			tgdisplay="$tgdisplaydir$tgname$gitcdopt -r $explicit_remote"
			TG_EXPLICIT_REMOTE="$base_remote" && export TG_EXPLICIT_REMOTE
			shift;;

		-u)
			unset base_remote explicit_remote
			noremote=1
			tgdisplay="$tgdisplaydir$tgname$gitcdopt -u"
			TG_EXPLICIT_REMOTE= && export TG_EXPLICIT_REMOTE
			shift;;

		-C)
			shift
			if [ -z "$1" ]; then
				echo "Option -C requires an argument." >&2
				do_help
				exit 1
			fi
			cd "$1"
			unset GIT_DIR GIT_COMMON_DIR
			if [ -z "$explicit_dir" ]; then
				explicit_dir="$1"
			else
				explicit_dir="$PWD"
			fi
			gitcdopt=" -C \"$explicit_dir\""
			[ "$explicit_dir" != "." ] || explicit_dir="." gitcdopt=" -C ."
			tgdisplay="$tgdisplaydir$tgname$gitcdopt"
			tgdisplayac="$tgdisplay"
			[ -z "$explicit_remote" ] || tgdisplay="$tgdisplay -r $explicit_remote"
			[ -z "$noremote" ] || tgdisplay="$tgdisplay -u"
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

		status|st)
			unset base_remote
			basic_setup
			set_topbases
			do_status "$@"
			exit ${do_status_result:-0};;

		hooks-path)
			# Internal command
			echol "$TG_INST_HOOKSDIR";;

		exec-path)
			# Internal command
			echol "$TG_INST_CMDDIR";;

		top-bases)
			# Maintenance command
			! git rev-parse --git-dir >/dev/null 2>&1 || setup_git_dirs
			set_topbases
			echol "refs/$topbases";;

		*)
			isutil=
			case "$cmd" in index-merge-one-file)
				isutil="-"
			esac
			[ -r "$TG_INST_CMDDIR"/tg-$isutil$cmd ] || {
				looplevel="$TG_ALIAS_DEPTH"
				[ "${looplevel#[1-9]}" != "$looplevel" ] &&
				[ "${looplevel%%[!0-9]*}" = "$looplevel" ] ||
				looplevel=0
				tgalias="$(git config "topgit.alias.$cmd" 2>/dev/null)" || :
				[ -n "$tgalias" ] || {
					echo "Unknown subcommand: $cmd" >&2
					do_help
					exit 1
				}
				looplevel=$(( $looplevel + 1 ))
				[ $looplevel -le 10 ] || die "topgit.alias nesting level 10 exceeded"
				TG_ALIAS_DEPTH="$looplevel"
				export TG_ALIAS_DEPTH
				if [ "!${tgalias#?}" = "$tgalias" ]; then
					unset GIT_PREFIX
					if pfx="$(git rev-parse --show-prefix 2>/dev/null)"; then
						GIT_PREFIX="$pfx"
						export GIT_PREFIX
					fi
					cd "./$(git rev-parse --show-cdup 2>/dev/null)"
					exec @SHELL_PATH@ -c "${tgalias#?} \"\$@\"" @SHELL_PATH@ "$@"
				else
					eval 'exec "$tgbin"' "$tgalias" '"$@"'
				fi
				die "alias execution failed for: $tgalias"
			}
			unset TG_ALIAS_DEPTH

			showing_help=
			if [ "$*" = "-h" ] || [ "$*" = "--help" ]; then
				showing_help=1
			fi

			[ -n "$showing_help" ] || initial_setup
			[ -z "$noremote" ] || unset base_remote

			nomergesetup="$showing_help"
			case "$cmd" in base|contains|info|log|rebase|revert|summary|tag)
				# avoid merge setup where not necessary

				nomergesetup=1
			esac

			if [ -z "$nomergesetup" ]; then
				# make sure merging the .top* files will always behave sanely

				setup_ours
				setup_hook "pre-commit"
			fi

			# everything but rebase needs topbases set
			carefully="$showing_help"
			[ "$cmd" != "migrate-bases" ] || carefully=1
			[ "$cmd" = "rebase" ] || set_topbases $carefully

			_use_ref_cache=
			tg_read_only=1
			case "$cmd$showing_help" in
				contains|export|info|summary|tag)
					_use_ref_cache=1;;
				annihilate|create|delete|depend|import|update)
					tg_use_alt_odb=
					tg_read_only=;;
			esac
			[ -z "$_use_ref_cache" ] || v_create_ref_cache

			fullcmd="${tgname:-tg} $cmd $*"
			. "$TG_INST_CMDDIR"/tg-$isutil$cmd;;
	esac

fi
