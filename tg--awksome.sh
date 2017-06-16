#!/bin/sh
# TopGit awk scripts and related utility functions
# Copyright (C) 2017 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved.
# License GPLv2

## Several awk scripts are used to quickly process TopGit branches and
## their associated .topdeps files and with the exception of $gcfbo
## (which can be left unset) and the get_temp function, can be used
## independently; a suitable and simple get_temp function can be just:
##
##   get_temp() { mktemp "${TMPDIR:-/tmp}/${1:-temp}-XXXXXX"; }
##
## The utility functions all require use of the '%(rest)' atom format
## introduced with Git v1.8.5 for use with git cat-file --batch and
## --batch-check options.  Although it would be possible to simulate
## that functionality it would require a lot of extra processing that
## use of '%(rest)' eliminates so no attempt is made to support earlier
## versions of git.
##
## Note that the $gcfbopt variable may contain the value "--buffer"
## if Git is version 2.6.0 or later for increased acceleration
## (Git Cat-File Buffer OPTion)
##
## NOTE: This file contains only function definitions, variable assignments
#        and checks for the existence of the corresponding script files but
#        has no other non-function shell code than that

[ -n "$TG_INST_AWKDIR" ] || {
	TG_INST_AWKDIR="${TG_INST_CMDDIR%/}"
	[ -n "$TG_INST_AWKDIR" ] ||
	case "$0" in *"/"*[!/]) TG_INST_AWKDIR="${0%/*}"; esac
	[ -z "$TG_INST_AWKDIR" ] || TG_INST_AWKDIR="$TG_INST_AWKDIR/"
	TG_INST_AWKDIR="${TG_INST_AWKDIR}awk"
}

# die with a fatal programmer error bug
run_awk_bug()
{
	printf	'fatal: [BUG] programmer error\n%s%s\n' \
		'fatal: [BUG] ' "$*" >&2
	exit 2
}

# verify an awk script exists, is a file and is readable or die
run_awk_require()
{
	while [ $# -gt 0 ]; do
		[ -f "$TG_INST_AWKDIR/$1" ] && [ -r "$TG_INST_AWKDIR/$1" ] || {
			printf '%s\n' "fatal: awksome: missing awk script '$TG_INST_AWKDIR/$1'" >&2
			exit 2
		}
		shift
	done
}

[ -n "$mtblob" ] || run_awk_bug "mtblob must be set before sourcing awksome"

# run_awk_ref_match [opts] [<for-each-ref-pattern>...]
#
# --sort=<key>    sort key (repeatable) last is primary same names as --format
# --count=<max>   stop after this many matches
# --format=<fmt>  for-each-ref style format but only objname and refname ok
# -p              input is packed-refs style rather than "<ref> <hash>"
#
# input is one ref + hash table entry per line either packed-refs style or
# ref first then hash where nonsensical lines are ignored
#
# output is one "format expansion" per match but stopping after --count (if given)
#
# the <fmt> works like for-each-ref except that only the "refname" and "objectname"
# (and %-escapes) get expanded; well, actually, %(objecttype) is expeanded too, but
# always to the constant string "object" (unquoted) rather than a real type
#
# the sort keys work like for-each-ref too except that keys other than refname
# and/or objectname are ignored but reverse (leading "-") IS supported
#
run_awk_require "ref_match"
run_awk_ref_match()
{
	_ra_pckdrefs=
	_ra_sortkey=
	_ra_maxout=
	_ra_matchfmt=
	while [ $# -gt 0 ]; do case "$1" in
		-p)	    _ra_pckdrefs=1;;
		--sort=*)   _ra_sortkey="${_ra_sortkey:+$_ra_sortkey,}${1#--sort=}";;
		--count=*)  _ra_maxout="${1#--count=}";;
		--format=*) _ra_matchfmt="${1#--format=}";;
		--)    shift; break;;
		-?*)	run_awk_bug "unknown run_awk_ref_match option: $1";;
		*)	break;;
	esac; shift; done
	awk -f "$TG_INST_AWKDIR/ref_match" \
		-v "pckdrefs=$_ra_pckdrefs" \
		-v "sortkey=$_ra_sortkey" \
		-v "maxout=$_ra_maxout" \
		-v "matchfmt=$_ra_matchfmt" \
		-v "patterns=$*"
}

# run_awk_ref_prefixes [opts] <prefix1> <prefix2> [<prefixh>]
#
# -p  input is packed-refs format rather than full ref in first field
# -e  on error when both prefixes present use the default (prefix1) instead
# -n  no default instead error out
#
# input is one fully qualified ref name per line either in the first
# field (default) or in packed-refs format (second field) with -p
# (input need not be sorted in any particular order even with a third argument)
#
# on success output is <prefix1> or <prefix2) (with trailing slashes stripped)
# on error (both prefixes found and status 65) there's no output but -e will
# change that to be success with <prefix1> instead; using -n will cause an
# exit with status 66 if neither prefix is found rather than using <prefix1>
#
run_awk_require "ref_prefixes"
run_awk_ref_prefixes()
{
	_ra_pckdrefs=
	_ra_noerr=
	_ra_nodef=
	while [ $# -gt 0 ]; do case "$1" in
		-p)	_ra_pckdrefs=1;;
		-e)	_ra_noerr=1;;
		-n)	_ra_nodef=1;;
		--)	shift; break;;
		-?*)	run_awk_bug "unknown run_awk_ref_prefixes option: $1";;
		*)	break;;
	esac; shift; done
	[ $# -ge 2 ] && [ $# -le 3 ] ||
		run_awk_bug "run_awk_ref_prefixes requires exactly two or three non-option arguments"
	awk -f "$TG_INST_AWKDIR/ref_prefixes" \
		-v "pckdrefs=$_ra_pckdrefs" \
		-v "noerr=$_ra_noerr" \
		-v "nodef=$_ra_nodef" \
		-v "prefix1=$1" \
		-v "prefix2=$2" \
		-v "prefixh=$3"
}

# run_awk_topgit_branches [opts] <bases-prefix> [<for-each-ref-pattern>...]
#
# -n         omit annihilated branches from output and -b=<file> (but not -a=<file>)
# -h=<head>  full ref prefix of heads location (default usually works fine)
# -a=<file>  write the TopGit branch names one per line of annihilated branches
# -b=<file>  write a copy of the stdout into here
# -p=<file>  write a copy of the ref prepare output into here
# -r=<file>  read substitute refs list from here
# -p         refs list is in packed-refs format rather than "<ref> <hash>"
# -rmr       remove -r= <file> after it's been read (convenience knob)
# -i=<inbr>  whitespace separated list of branch names to include (unless in -x)
# -x=<exbr>  whitespace separated list of branch names to exclude
# -db        enable output of .topdeps blob lines
# -mb        enable output of .topmsg blob lines
# -td=<tdbr> must be <branch>:<hash> to use <hash>^{blob} as <branch>'s .topdeps
# -tm=<tmbr> must be <branch>:<hash> to use <hash>^{blob} as <branch>'s .topmsg
#
# If given, the -a and -b files are always truncated if there are no matching
# branches for them
#
# input is a full top-bases prefix (i.e. "refs/top-bases" or
# "refs/remotes/origin/top-bases" or similar) and zero or more for-each-ref
# patterns the default being <bases-prefix> if no patterns are given
#
# note that <bases-prefix> is required because this file is independent and
# there is no universal default available
#
# output is one TopGit branch name per line (not output until after any -a or -b
# files have been fully written and closed)
#
# if -n is used annihilated branches will be omitted from the output (and any
# -b=<file>)
#
# If -b=<file> is used it will get a copy of the output being truncated if the
# output is empty
#
# If -a=<file> is used it will get a list of annihilated branches (regardless of
# whether or not -n is used) and will be truncated if there are none
#
# Note that since git for-each-ref sorts its results the output will always be
# sorted by branch name (including the -a=<file> output)
#
# Note that this function does NOT call get_temp
#
run_awk_require "ref_prepare" "topgit_branches"
run_awk_topgit_branches()
{
	_ra_noann=
	_ra_headbase=
	_ra_anfile=
	_ra_brfile=
	_ra_inclbr=
	_ra_exclbr=
	_ra_depsblob=
	_ra_msgblob=
	_ra_topdeps=
	_ra_topmsg=
	_ra_teeout=
	_ra_pckdrefs=
	_ra_refsfile=
	_ra_rmrf=
	while [ $# -gt 0 ]; do case "$1" in
		-n)	_ra_noann=1;;
		-p)	_ra_pckdrefs=1;;
		-h=*)	_ra_headbase="${1#-h=}";;
		-a=*)	_ra_anfile="${1#-a=}";;
		-b=*)	_ra_brfile="${1#-b=}";;
		-i=*)	_ra_inclbr="${1#-i=}";;
		-x=*)	_ra_exclbr="${1#-x=}";;
		-db)	_ra_depsblob=1;;
		-mb)	_ra_msgblob=1;;
		-td=*)	_ra_topdeps="${1#-td=}";;
		-tm=*)	_ra_topmsg="${1#-tm=}";;
		-p=*)	_ra_teeout="${1#-p=}";;
		-r=*)   _ra_refsfile="${1#-r=}";;
		-rmr)	_ra_rmrf=1;;
		--)    shift; break;;
		-?*)	run_awk_bug "unknown run_awk_topgit_branches option: $1";;
		*)	break;;
	esac; shift; done
	[ -n "$1" ] || run_awk_bug "run_awk_topgit_branches missing <bases-prefix>"
	_ra_topbases="$1"
	shift
	[ $# -gt 0 ] || set -- "$_ra_topbases"
	{
		if [ -n "$_ra_refsfile" ]; then
			run_awk_ref_match ${_ra_pckdrefs:+-p} <"$_ra_refsfile" \
				--format="%(refname)" "$@"
		else
			git for-each-ref --format="%(refname)" "$@"
		fi
	} |
	awk -f "$TG_INST_AWKDIR/ref_prepare" \
		-v "topbases=$_ra_topbases" \
		-v "headbase=$_ra_headbase" \
		-v "rmrf=$_ra_rmrf" \
		-v "refsfile=$_ra_refsfile" \
		-v "depsblob=$_ra_depsblob" \
		-v "msgblob=$_ra_msgblob" \
		-v "topdeps=$_ra_topdeps" \
		-v "topmsg=$_ra_topmsg" \
		-v "pckdrefs=$_ra_pckdrefs" \
		-v "teeout=$_ra_teeout" |
	git cat-file $gcfbopt --batch-check='%(objectname) %(objecttype) %(rest)' |
	awk -f "$TG_INST_AWKDIR/topgit_branches" \
		-v "noann=$_ra_noann" \
		-v "anfile=$_ra_anfile" \
		-v "brfile=$_ra_brfile" \
		-v "inclbr=$_ra_inclbr" \
		-v "exclbr=$_ra_exclbr"
}

# run_awk_topgit_msg [opts] <bases-prefix> [<for-each-ref-pattern>...]
#
# -c         do simple column formatting if more than one output column
# -n         omit annihilated branches from output and -b=<file> (but not -a=<file>)
# -nokind    omit the kind column from the output
# -mt=<mt>   empty branch treatment ("" = like ann; true = include; false not)
# -h=<head>  full ref prefix of heads location (default usually works fine)
# -a=<file>  write the TopGit branch names one per line of annihilated branches
# -b=<file>  write the TopGit branch names one per line into here
# -p=<file>  write a copy of the ref prepare output into here
# -r=<file>  read substitute refs list from here
# -p         refs list is in packed-refs format rather than "<ref> <hash>"
# -rmr       remove -r= <file> after it's been read (convenience knob)
# -i=<inbr>  whitespace separated list of branch names to include (unless in -x)
# -x=<exbr>  whitespace separated list of branch names to exclude
# -db        enable output of .topdeps blob lines
# -mb        ignored (output of .topmsg blob lines is always enabled)
# -td=<tdbr> must be <branch>:<hash> to use <hash>^{blob} as <branch>'s .topdeps
# -tm=<tmbr> must be <branch>:<hash> to use <hash>^{blob} as <branch>'s .topmsg
# --list     a convenience macro that sets -c -n -mt=1 -nokind
#
# If given, the -a and -b files are always truncated if there are no matching
# branches for them
#
# input is a full top-bases prefix (i.e. "refs/top-bases" or
# "refs/remotes/origin/top-bases" or similar) and zero or more for-each-ref
# patterns the default being <bases-prefix> if no patterns are given
#
# note that <bases-prefix> is required because this file is independent and
# there is no universal default available
#
# output is one TopGit branch edge (i.e. two space-separated TopGit branch
# names) per line (not output until after any -a or -b files have been fully
# written and closed)
#
# if -n is used annihilated branches will be omitted from the output (and any
# -b=<file> if used), but if -a=<file> is NOT used then get_temp WILL be called
# but the file will be subsequently removed before returning
#
# Note that using -a=<file> does NOT exclude annihilated branches (but does
# put them into that file); only the -n option will exclude annihilated branches
#
# If -b=<file> is used it will get a copy of the output being truncated if the
# output is empty
#
# If -a=<file> is used it will get a list of annihilated branches (regardless of
# whether or not -n is used) and will be truncated if there are none
#
# Note that since git for-each-ref sorts its results the output will always be
# sorted by branch name (always for the -a=<file> and -b=<file> output) but
# that will only be the case for the stdout results for the first (second with
# -r) branch name on each stdout line
#
# With -s a "self" link is output for each branch after all the .topdeps
# entries (before with -r) have been output for that branch and the entries are
# output in .topdeps order (reverse order with -r)
#
# Note that using -s and omitting -n is NOT enough to make a self link for
# annihilated branches appear in the output; in order for them to appear (and
# also any TopGit branches lacking a .topdeps file) the -m= option must be
# used and the value passed must be the empty blob's hash
#
# Each "link" line output is <branch_name> <.topdeps_entry> (reversed with -r)
#
# Note that this function WILL call get_temp if -a= is NOT given AND -n is used
# (but it will remove the temp file before returning)
#
run_awk_require "ref_prepare" "topgit_msg_prepare" "topgit_msg"
run_awk_topgit_msg()
{
	_ra_colfmt=
	_ra_nokind=
	_ra_withan=1
	_ra_withmt=
	_ra_headbase=
	_ra_anfile=
	_ra_rman=
	_ra_brfile=
	_ra_rmbr=
	_ra_inclbr=
	_ra_exclbr=
	_ra_depsblob=
	_ra_topdeps=
	_ra_topmsg=
	_ra_teeout=
	_ra_pckdrefs=
	_ra_refsfile=
	_ra_rmrf=
	while [ $# -gt 0 ]; do case "$1" in
		-c)	_ra_colfmt=1;;
		-n)	_ra_withan=;;
		-p)	_ra_pckdrefs=1;;
		-mt=*)	_ra_withmt="${1#-mt=}";;
		-nokind) _ra_nokind=1;;
		-h=*)	_ra_headbase="${1#-h=}";;
		-a=*)	_ra_anfile="${1#-a=}";;
		-b=*)	_ra_brfile="${1#-b=}";;
		-r=*)   _ra_refsfile="${1#-r=}";;
		-rmr)	_ra_rmrf=1;;
		-i=*)	_ra_inclbr="${1#-i=}";;
		-x=*)	_ra_exclbr="${1#-x=}";;
		-db)	_ra_depsblob=1;;
		-mb)	;;
		-tm=*)	_ra_topmsg="${1#-tm=}";;
		-td=*)	_ra_topdeps="${1#-td=}";;
		-p=*)	_ra_teeout="${1#-p=}";;
		--list)
			_ra_colfmt=1
			_ra_withan=
			_ra_withmt=1
			_ra_nokind=1
			;;
		--)	shift; break;;
		-?*)	run_awk_bug "unknown run_awk_topgit_msg option: $1";;
		*)	break;;
	esac; shift; done
	[ -n "$1" ] || run_awk_bug "run_awk_topgit_msg missing <bases-prefix>"
	_ra_topbases="$1"
	shift
	[ $# -gt 0 ] || set -- "$_ra_topbases"
	if [ -z "$_ra_withan" ] && [ -z "$_ra_anfile" ]; then
		_ra_anfile="$(get_temp rawk_annihilated)" || return 2
	fi
	{
		if [ -n "$_ra_refsfile" ]; then
			run_awk_ref_match ${_ra_pckdrefs:+-p} <"$_ra_refsfile" \
				--format="%(refname)" "$@"
		else
			git for-each-ref --format="%(refname)" "$@"
		fi
	} |
	awk -f "$TG_INST_AWKDIR/ref_prepare" \
		-v "topbases=$_ra_topbases" \
		-v "headbase=$_ra_headbase" \
		-v "rmrf=$_ra_rmrf" \
		-v "refsfile=$_ra_refsfile" \
		-v "depsblob=$_ra_depsblob" \
		-v "msgblob=1" \
		-v "topdeps=$_ra_topdeps" \
		-v "topmsg=$_ra_topmsg" \
		-v "pckdrefs=$_ra_pckdrefs" \
		-v "teeout=$_ra_teeout" |
	git cat-file $gcfbopt --batch-check='%(objectname) %(objecttype) %(rest)' |
	awk -f "$TG_INST_AWKDIR/topgit_msg_prepare" \
		-v "withan=$_ra_withan" \
		-v "withmt=$_ra_withmt" \
		-v "depsblob=$_ra_depsblob" \
		-v "anfile=$_ra_anfile" \
		-v "brfile=$_ra_brfile" \
		-v "missing=$mtblob" |
	git cat-file $gcfbopt --batch='%(objecttype) %(objectsize) %(rest)' | tr '\0' '\27' |
	awk -f "$TG_INST_AWKDIR/topgit_msg" \
		-v "withan=$_ra_withan" \
		-v "anfile=$_ra_anfile" \
		-v "rman=$_ra_rman" \
		-v "withmt=$_ra_withmt" \
		-v "brfile=$_ra_brfile" \
		-v "rmbr=$_ra_rmbr" \
		-v "nokind=$_ra_nokind" \
		-v "colfmt=$_ra_colfmt" \
		-v "inclbr=$_ra_inclbr" \
		-v "exclbr=$_ra_exclbr"
}

# run_awk_topmsg_header [-r=<regex>] [--stdin] [opts] <branch_name> [blobish]
#
# -kind  include the kind field just before the description (normally omitted)
# -name  include the branch name field as a first field (normally omitted)
#
# with --stdin, the contents of a .topmsg file should be on stdin
# otherwise if blobish is given it provides the input otherwise
# refs/heads/<branch_name>:.topdeps^{blob} does
#
# with -r=<regex> a case-insensitive keyword regular expression (always
# has to match the entire keyword name) instead of "Subject" can be used
# to extract other headers ("Subject" is the default though)
#
# output will be the subject (or a suitable description if there is no .topmsg
# or blobish or the input is empty); for non-subject keywords if the header
# is not present just the empty string is output use -r="(Subject)" to do the
# same thing for the subject header and avoid descriptive "missing" text
#
# "<branch_name>" is always required because it's used in the output message
# whenever the "Subject:" header line is not present (for whatever reason)
#
run_awk_require "topgit_msg"
run_awk_topmsg_header()
{
	_usestdin=
	_ra_kwregex=
	_ra_colfmt=
	_ra_nokind=1
	_ra_noname=1
	while [ $# -gt 0 ]; do case "$1" in
		-c)	_ra_colfmt=1;;
		-kind)	_ra_nokind=;;
		-name)	_ra_noname=;;
		-r=*)	_ra_kwregex="${1#-r=}";;
		--stdin) _usestdin=1;;
		--)    shift; break;;
		-?*)	run_awk_bug "unknown run_awk_topmsg_header option: $1";;
		*)	break;;
	esac; shift; done
	if [ -n "$_usestdin" ]; then
		[ $# -eq 1 ] || run_awk_bug "run_awk_topmsg_header --stdin requires exactly 1 arg"
		[ -n "$1" ] || run_awk_bug "run_awk_topmsg_header --stdin requires a branch name"
	else
		[ $# -le 2 ] || run_awk_bug "run_awk_topmsg_header allows at most 2 args"
		[ $# -ge 1 ] && [ -n "$1" ] ||
			run_awk_bug "run_awk_topmsg_header requires a branch name"
	fi
	if [ -n "$_usestdin" ]; then
		printf 'blob 32767 0 %s\n' "$1"
		tr '\0' '\27'
	else
		printf '%s 0 %s\n' "${2:-refs/heads/$1:.topmsg}" "$1" |
		git cat-file $gcfbopt --batch='%(objecttype) %(objectsize) %(rest)' |
		tr '\0' '\27' | awk -v "bn=$1" \
			'1 == NR && $2 == "missing" {printf "blob 0 1 %s\n\n", bn; next}{print}'
	fi |
	awk -f "$TG_INST_AWKDIR/topgit_msg" \
		-v "noname=$_ra_noname" \
		-v "nokind=$_ra_nokind" \
		-v "kwregex=$_ra_kwregex" \
		-v "only1=1" \
		-v "colfmt=$_ra_colfmt"
}

# run_awk_topgit_deps [opts] <bases-prefix> [<for-each-ref-pattern>...]
#
# -n         omit annihilated branches from output and -b=<file> (but not -a=<file>)
# -t         only output tgish deps (i.e. dep is listed in -b=<file>)
# -r         reverse the dependency graph
# -s         include a link to itself for each branch
# -h=<head>  full ref prefix of heads location (default usually works fine)
# -a=<file>  write the TopGit branch names one per line of annihilated branches
# -b=<file>  write the TopGit branch names one per line into here
# -p=<file>  write a copy of the ref prepare output into here
# -r=<file>  read substitute refs list from here
# -p         refs list is in packed-refs format rather than "<ref> <hash>"
# -rmr       remove -r= <file> after it's been read (convenience knob)
# -i=<inbr>  whitespace separated list of branch names to include (unless in -x)
# -x=<exbr>  whitespace separated list of branch names to exclude
# -db        ignored (output of .topdeps blob lines is always enabled)
# -mb        enable output of .topmsg blob lines
# -td=<tdbr> must be <branch>:<hash> to use <hash>^{blob} as <branch>'s .topdeps
# -tm=<tmbr> must be <branch>:<hash> to use <hash>^{blob} as <branch>'s .topmsg
#
# If given, the -a and -b files are always truncated if there are no matching
# branches for them
#
# input is a full top-bases prefix (i.e. "refs/top-bases" or
# "refs/remotes/origin/top-bases" or similar) and zero or more for-each-ref
# patterns the default being <bases-prefix> if no patterns are given
#
# note that <bases-prefix> is required because this file is independent and
# there is no universal default available
#
# output is one TopGit branch edge (i.e. two space-separated TopGit branch
# names) per line (not output until after any -a or -b files have been fully
# written and closed)
#
# if -n is used annihilated branches will be omitted from the output (and any
# -b=<file> if used), but if -a=<file> is NOT used then get_temp WILL be called
# but the file will be subsequently removed before returning
#
# Note that using -a=<file> does NOT exclude annihilated branches (but does
# put them into that file); only the -n option will exclude annihilated branches
#
# If -b=<file> is used it will get a copy of the output being truncated if the
# output is empty
#
# If -a=<file> is used it will get a list of annihilated branches (regardless of
# whether or not -n is used) and will be truncated if there are none
#
# Note that since git for-each-ref sorts its results the output will always be
# sorted by branch name (always for the -a=<file> and -b=<file> output) but
# that will only be the case for the stdout results for the first (second with
# -r) branch name on each stdout line
#
# With -s a "self" link is output for each branch after all the .topdeps
# entries (before with -r) have been output for that branch and the entries are
# output in .topdeps order (reverse order with -r)
#
# Note that using -s and omitting -n is NOT enough to make a self link for
# annihilated branches appear in the output; in order for them to appear (and
# also any TopGit branches lacking a .topdeps file) the -m= option must be
# used and the value passed must be the empty blob's hash
#
# Each "link" line output is <branch_name> <.topdeps_entry> (reversed with -r)
#
# Note that this function WILL call get_temp if -a= is NOT given AND -n is used
# OR -b= is NOT given AND -t is used
# (but it will remove the temp file(s) before returning)
#
run_awk_require "ref_prepare" "topgit_deps_prepare" "topgit_deps"
run_awk_topgit_deps()
{
	_ra_noann=
	_ra_tgonly=
	_ra_rev=
	_ra_withbr=
	_ra_withan=
	_ra_headbase=
	_ra_anfile=
	_ra_rman=
	_ra_brfile=
	_ra_rmbr=
	_ra_inclbr=
	_ra_exclbr=
	_ra_msgblob=
	_ra_topdeps=
	_ra_topmsg=
	_ra_teeout=
	_ra_pckdrefs=
	_ra_refsfile=
	_ra_rmrf=
	while [ $# -gt 0 ]; do case "$1" in
		-n)	_ra_noann=1;;
		-t)	_ra_tgonly=1;;
		-r)	_ra_rev=1;;
		-s)	_ra_withbr=1;;
		-p)	_ra_pckdrefs=1;;
		-h=*)	_ra_headbase="${1#-h=}";;
		-a=*)	_ra_anfile="${1#-a=}";;
		-b=*)	_ra_brfile="${1#-b=}";;
		-r=*)   _ra_refsfile="${1#-r=}";;
		-rmr)	_ra_rmrf=1;;
		-i=*)	_ra_inclbr="${1#-i=}";;
		-x=*)	_ra_exclbr="${1#-x=}";;
		-db)	;;
		-mb)	_ra_msgblob=1;;
		-tm=*)	_ra_topmsg="${1#-tm=}";;
		-td=*)	_ra_topdeps="${1#-td=}";;
		-p=*)	_ra_teeout="${1#-p=}";;
		--)	shift; break;;
		-?*)	run_awk_bug "unknown run_awk_topgit_deps option: $1";;
		*)	break;;
	esac; shift; done
	[ -n "$1" ] || run_awk_bug "run_awk_topgit_deps missing <bases-prefix>"
	_ra_topbases="$1"
	shift
	[ $# -gt 0 ] || set -- "$_ra_topbases"
	if [ -n "$_ra_noann" ] && [ -z "$_ra_anfile" ]; then
		_ra_rman=1
		_ra_anfile="$(get_temp rawk_annihilated)" || return 2
	fi
	if [ -n "$_ra_tgonly" ] && [ -z "$_ra_brfile" ]; then
		_ra_rmbr=1
		_ra_brfile="$(get_temp rawk_branches)" || return 2
	fi
	[ -n "$_ra_noann" ] || _ra_withan=1
	{
		if [ -n "$_ra_refsfile" ]; then
			run_awk_ref_match ${_ra_pckdrefs:+-p} <"$_ra_refsfile" \
				--format="%(refname)" "$@"
		else
			git for-each-ref --format="%(refname)" "$@"
		fi
	} |
	awk -f "$TG_INST_AWKDIR/ref_prepare" \
		-v "topbases=$_ra_topbases" \
		-v "headbase=$_ra_headbase" \
		-v "rmrf=$_ra_rmrf" \
		-v "refsfile=$_ra_refsfile" \
		-v "depsblob=1" \
		-v "msgblob=$_ra_msgblob" \
		-v "topdeps=$_ra_topdeps" \
		-v "topmsg=$_ra_topmsg" \
		-v "pckdrefs=$_ra_pckdrefs" \
		-v "teeout=$_ra_teeout" |
	git cat-file $gcfbopt --batch-check='%(objectname) %(objecttype) %(rest)' |
	awk -f "$TG_INST_AWKDIR/topgit_deps_prepare" \
		-v "noann=$_ra_noann" \
		-v "anfile=$_ra_anfile" \
		-v "brfile=$_ra_brfile" \
		-v "missing=$mtblob" |
	git cat-file $gcfbopt --batch='%(objecttype) %(objectsize) %(rest)' | tr '\0' '\27' |
	awk -f "$TG_INST_AWKDIR/topgit_deps" \
		-v "withan=$_ra_withan" \
		-v "anfile=$_ra_anfile" \
		-v "rman=$_ra_rman" \
		-v "withbr=$_ra_withbr" \
		-v "brfile=$_ra_brfile" \
		-v "rmbr=$_ra_rmbr" \
		-v "tgonly=$_ra_tgonly" \
		-v "rev=$_ra_rev" \
		-v "inclbr=$_ra_inclbr" \
		-v "exclbr=$_ra_exclbr"
}

# run_awk_topgit_recurse [opts] <branch> [<name>...]
#
# -d         output ":loop: some bad branch chain path" for any detected loops
# -n	     omit annihilated branches (L == 2) from output
# -f         output branch first before dependencies (i.e. preorder not post)
# -s	     include a line for the starting node (recommended when using -m)
# -l         only output L == 1 lines (leaves)
# -t         only output T != 0 lines (tgish)
# -m         activate multimode, any [<name>...] are more branches to process
# -e=<type>  emit only dependency graph edges (2) or deps (1) (aka filter mode)
# -o=<once>  only output node on 1st visit (1) or visit its deps only 1st (-1)
# -u=<remt>  prefix for -r=<file> branch names (e.g. "refs/remotes/x/top-bases")
# -c=<hfld>  use only field <hfld> from -h= and cut off leading "refs/heads/"
# -b=<file>  file with list of TopGit branches (one per line, e.g. "t/foo")
# -rmb       remove -b= <file> after it's been read (convenience knob)
# -a=<file>  file with list of annihilated TopGit branches
# -rma       remove -a= <file> after it's been read (convenience knob)
# -h=<file>  file with list of existing "refs/heads/..." refs (see -c=)
# -rmh       remove -h= <file> after it's been read (convenience knob)
# -r=<file>  file with list of TopGit branches with a remote (one per line)
# -rmr       remove -r= <file> after it's been read (convenience knob)
# -i=<inbr>  whitespace separated list of branch names to include (unless in -x)
# -x=<exbr>  whitespace separated list of branch names to exclude
# --series   a convenience macro that sets -e=1 -o=1 -s -n -t options
#
# REQUIRED OPTIONS: -a=<file> -b=<file>
#
# But, if -h=<file> is omitted, get_temp WILL be called!
#
# Note that it is guaranteed to be safe to use the same name for the -a and -b
# options of a run_awk_topgit_deps command that is piping output into this
# command because they are guaranteed to be fully written and closed by that
# command before it outputs the first line and this command is guaranteed to
# not start reading them until after it receives the first line
#
# if the -c=<hfld> option is NOT used then the -h= <file> must contain only the
# branch name (e.g. "t/foo") on each line; but if -c=<hfld> IS used then the
# chosen field (use -c=2 for packed-refs) must be a full ref starting with the
# "refs/heads/" prefix; a file with one full refname per line (i.e. starts with
# "refs/heads/") instead of just the branch name should use -c=1 for it to work
#
# note that no matter what options are used, missing lines (i.e. M == 1) are
# always output when applicable (any branch name not found in the -h= <file>
# will always generate a missing line)
#
# if -r=<file> is omitted no remote lines will ever be generated and the
# -u=<remt> option will be ignored; if -r=<file> is used but -u=<remt> is
# omitted then remote base lines will never be generated, but any branch
# names in both -b=<file> AND -r=<file> but NOT -a=<file> will still have a
# T == 2 value in their output lines
#
# With -s a "starting" line is output for <branch> (and each additional <name>
# when using -m) either before (with -f) or after (the default) recursively
# processing all of that branch's dependencies
#
# if both -s AND -m are used AND at least two nodes are specified the effect
# on the output is as though a virtual starting node was passed that had a
# .topdeps file consisting of the nodes listed on the command line (in command
# line order) AND the -s flag was than not passed when recursing on that
# fictional virtual node; if -m and more than one node is used without the
# -s option it will not generally be possible to determine where the output
# from one node's recursion ends and the next begins in the output
#
# input is the output of run_awk_topgit_deps and despite the availability of
# the -n option here, if it was used on the run_awk_topgit_deps command line
# the links to annihilated branches will not be present in the input so the
# only possible L == 2 line in that case (if -n is NOT used) would be for a
# starting <branch> and then only if -s IS used; this is usually fine because
# in most cases the annihilated branches need to disappear anyway
#
# output lines look like this:
#
#   M T L <node> [<parent> <branch> <chain> <names>]
#
# where (see awk_topgit_recurse) M is 0 (not) or 1 (missing), T is 0 (not)
# or 1 (tgish) or 2 (with remote) and L is 0 (not) or 1 (leaf) or 2 (annihilated)
# so the following is an example of a possible output line:
#
#   0 1 1 t/foo/leaf t/foo/int t/stage
#
# Note that unlike most of the other run_awk_... functions, this function is
# primarily just a convenience wrapper around the awk_topgit_recurse script
# (although it will provide the required -h=<file> if necessary) and
# really does not provide any additional and/or changed behavior so the script
# may also be used directly (by running awk) instead of via this function
#
# however, if "-o" mode is active instead of the above example output line
# this line would be output instead:
#
#   t/foo/int t/foo/leaf
#
# note the reversed ordering as the first branch name is the branch with the
# .topdeps file that contains the the second branch name
#
# Note that this function WILL call get_temp if -h=<file> is NOT given
#
run_awk_require "topgit_recurse"
run_awk_topgit_recurse()
{
	_ra_showlp=
	_ra_withan=1
	_ra_preord=
	_ra_withbr=
	_ra_leaves=
	_ra_tgonly=
	_ra_multib=
	_ra_filter=
	_ra_once=
	_ra_usermt=
	_ra_cuthd=
	_ra_brfile=
	_ra_anfile=
	_ra_hdfile=
	_ra_rtfile=
	_ra_rmbr=
	_ra_rman=
	_ra_rmhd=
	_ra_rmrt=
	_ra_inclbr=
	_ra_exclbr=
	while [ $# -gt 0 ]; do case "$1" in
		-d)	_ra_showlp=1;;
		-n)	_ra_withan=;;
		-f)	_ra_preord=1;;
		-s)	_ra_withbr=1;;
		-l)	_ra_leaves=1;;
		-t)	_ra_tgonly=1;;
		-m)	_ra_multib=1;;
		--filter=*) _ra_filter="${1#--filter=}";;
		--emit=*) _ra_filter="${1#--emit=}";;
		-e=*)	_ra_filter="${1#-e=}";;
		-o=*)	_ra_once="${1#-o=}";;
		-u=*)	_ra_usermt="${1#-u=}";;
		-c=*)	_ra_cuthd="${1#-c=}";;
		-b=*)	_ra_brfile="${1#-b=}";;
		-a=*)	_ra_anfile="${1#-a=}";;
		-h=*)	_ra_hdfile="${1#-h=}";;
		-r=*)   _ra_rtfile="${1#-r=}";;
		-rmb)	_ra_rmbr=1;;
		-rma)	_ra_rman=1;;
		-rmh)	_ra_rmhd=1;;
		-rmr)	_ra_rmrt=1;;
		-i=*)	_ra_inclbr="${1#-i=}";;
		-x=*)	_ra_exclbr="${1#-x=}";;
		--series|--patch-series)
			_ra_filter=1
			_ra_once=1
			_ra_withbr=1
			_ra_withan=
			_ra_tgonly=1
			;;
		--)	shift; break;;
		-?*)	run_awk_bug "unknown run_awk_topgit_recurse option: $1";;
		*)	break;;
	esac; shift; done
	[ -z "${_ra_filter#[12]}" ] ||
		run_awk_bug "run_awk_topgit_recurse -e filter value must be 1 or 2"
	[ -z "${_ra_once#[1]}" ] || [ "$_ra_once" = "-1" ] ||
		run_awk_bug "run_awk_topgit_recurse -o value must be 1 or -1"
	[ -n "$_ra_brfile" ] || run_awk_bug "run_awk_topgit_recurse missing required -b=<file>"
	[ -n "$_ra_anfile" ] || run_awk_bug "run_awk_topgit_recurse missing required -a=<file>"
	[ -n "$1" ] || run_awk_bug "run_awk_topgit_recurse missing <branch>"
	if [ -z "$_ra_hdfile" ]; then
		_ra_hdfile="$(get_temp rawk_heads)" || return 2
		_ra_rmhd=1
		git for-each-ref --format="%(refname)" "refs/heads" >"$_ra_hdfile" || {
			err=$?
			rm -f "$ra_hdfile"
			exit $err
		}
		_ra_cuthd=1
	fi
	awk -f "$TG_INST_AWKDIR/topgit_recurse" \
		-v "showlp=$_ra_showlp" \
		-v "withan=$_ra_withan" \
		-v "preord=$_ra_preord" \
		-v "withbr=$_ra_withbr" \
		-v "leaves=$_ra_leaves" \
		-v "multib=$_ra_multib" \
		-v "usermt=$_ra_usermt" \
		-v "cuthd=$_ra_cuthd" \
		-v "brfile=$_ra_brfile" \
		-v "anfile=$_ra_anfile" \
		-v "hdfile=$_ra_hdfile" \
		-v "rtfile=$_ra_rtfile" \
		-v "rmbr=$_ra_rmbr" \
		-v "rman=$_ra_rman" \
		-v "rmhd=$_ra_rmhd" \
		-v "rmrt=$_rt_rmrt" \
		-v "tgonly=$_ra_tgonly" \
		-v "inclbr=$_ra_inclbr" \
		-v "exclbr=$_ra_exclbr" \
		-v "startb=$*" \
		-v "filter=$_ra_filter" \
		-v "once=$_ra_once"
}

# run_awk_topgit_navigate [opts] <branch> [<head>...]
#
# -d         do loop detection even when not strictly necessary
# -n         omit annihilated branches (default)
# -N	     do NOT omit annihilated branches from output
# -r         reverse direction for movement
# -k         keep last node when running off end
# -t         include only TopGit branches in the output (ineffective without -b=)
# -1         omit all but the first field of each output line
# -s=<steps> how many steps to move
# -b=<file>  file with list of TopGit branches (one per line, e.g. "t/foo")
# -rmb       remove -b= <file> after it's been read (convenience knob)
# -a=<file>  file with list of annihilated TopGit branches
# -rma       remove -a= <file> after it's been read (convenience knob)
# -i=<inbr>  whitespace separated list of branch names to include (unless in -x)
# -x=<exbr>  whitespace separated list of branch names to exclude
#
# The [<head>...] list is actually a tree pruning list of nodes similar to
# git rev-list except that an isolated "^" replaces the "--not" functionality
# and if there are no positive nodes listed all nodes are considered positive
# before applying the negative node references
#
# input is the output of run_awk_topgit_deps and despite the availability of
# the -N option here, if -n was used on the run_awk_topgit_deps command line
# the links to annihilated branches will not be present in the input so they
# cannot be output in that case;  to avoid missing hermit nodes
# run_awk_topgit_deps should be run with the -s otherwise those nodes will be
# invisible to navigation (which is occasionally useful)
#
# output nodes are written one per line in this format:
#
#   <result_branch_name> <containing_topgit_head_branch_name>...
#
# where the second field will be empty only if navigating 1 or a negative
# number of steps from no node (i.e. ""); note that pruning IS allowed
# with the "no node" value but then the "no node" must be explicitly given
# as "" in order to avoid interpreting the first pruning ref as the starting
# node; and it's also possible to provide multiple space-separated starting
# nodes provided they are quoted together into the first argument
#
#
run_awk_require "topgit_navigate"
run_awk_topgit_navigate()
{
	_ra_chklps=
	_ra_withan=
	_ra_tgonly=
	_ra_fldone=
	_ra_brfile=
	_ra_anfile=
	_ra_rmbr=
	_ra_rman=
	_ra_rev=
	_ra_steps=
	_ra_pin=
	_ra_inclbr=
	_ra_exclbr=
	while [ $# -gt 0 ]; do case "$1" in
		-d)	_ra_chklps=1;;
		-n)	_ra_withan=;;
		-N)	_ra_withan=1;;
		-r)	_ra_rev=1;;
		-k|--pin) _ra_pin=1;;
		-t)	_ra_tgonly=1;;
		-1)	_ra_fldone=1;;
		-s=*)	_ra_steps="${1#-s=}";;
		-b=*)	_ra_brfile="${1#-b=}";;
		-a=*)	_ra_anfile="${1#-a=}";;
		-rmb)	_ra_rmbr=1;;
		-rma)	_ra_rman=1;;
		-i=*)	_ra_inclbr="${1#-i=}";;
		-x=*)	_ra_exclbr="${1#-x=}";;
		--)	shift; break;;
		-?*)	run_awk_bug "unknown run_awk_topgit_navigate option: $1";;
		*)	break;;
	esac; shift; done
	[ -n "$_ra_steps" ] ||
		run_awk_bug "run_awk_topgit_navigate -s steps value must not be empty"
	badsteps=1
	case "$_ra_steps" in -[0-9]*|[0-9]*)
		badsteps= _t="${_ra_steps#-}" && [ "$_t" = "${_t%%[!0-9]*}" ] || badsteps=1
	esac
	[ -z "$badsteps" ] ||
		run_awk_bug "run_awk_topgit_navigate -s steps value must be empty an integer"
	_ra_startb=
	[ $# -eq 0 ] || { _ra_startb="$1"; shift; }
	awk -f "$TG_INST_AWKDIR/topgit_navigate" \
		-v "chklps=$_ra_chklps" \
		-v "withan=$_ra_withan" \
		-v "rev=$_ra_rev" \
		-v "steps=$_ra_steps" \
		-v "brfile=$_ra_brfile" \
		-v "anfile=$_ra_anfile" \
		-v "rmbr=$_ra_rmbr" \
		-v "rman=$_ra_rman" \
		-v "tgonly=$_ra_tgonly" \
		-v "fldone=$_ra_fldone" \
		-v "pin=$_ra_pin" \
		-v "inclbr=$_ra_inclbr" \
		-v "exclbr=$_ra_exclbr" \
		-v "startb=$_ra_startb" \
		-v "pruneb=$*"
}
