#!/usr/bin/awk -f

# topgit_msg - TopGit awk utility script used by tg--awksome
# Copyright (C) 2017 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved.
# License GPLv2

# topgit_msg
#
# variable arguments (-v):
#
#   withan  if true, include annihilated branches in output
#   withmt  empty branches: "" (like withan), true (include) false (exclude)
#   nokind  exclude the kind (2nd) field from any output lines
#   noname  exclude the name (1st) field from any output line
#   only1   exit successfully after outputting first result
#   colfmt  do some simple column formatting if more than one output column
#   kwregex case-insensitive keyword to match instead of "Subject"
#   exclbr  whitespace separated list of names to exclude
#   inclbr  whitespace separated list of names to include
#
# Note that if kwregex is non-empty and not "Subject" fancy missing
# descriptions will be omitted and an empty string will be used
#
# kwregex must match the entire keyword or it will not be considered a match
#
# if kwregex starts with a "+" the "+" will be stripped and each matching
# line will have the "pretty" keyword plus ": " prefixed to it (the "pretty"
# keyword is all lowercased except for the first and any chars following an
# internal "-" except that "ID" and "MIME" are always all uppercased)
#
# use of the "+"<regex> form will cause multiple matches for the same keyword
# to all be output in the order encountered (otherwise just the first match is
# output)
#
# if inclbr is non-empty a branch name must be listed to appear on stdout
#
# if a branch name appears in exclbr it is omitted from stdout trumping inclbr
#
# input must be result of the git --batch output as described for
# awk_topgit_msg_prepare
#
# output is 0 or more branch lines with .topmsg "Subject:" descriptions
# in the same order they appear on the input in this format:
#
#   <TopGit_branch_name> K description of the TopGit branch
#
# But if nokind is true the "K" field will be omitted; K has the same semantics
# as described for awk_topgit_msg_prepare output
#
# If noname is true the branch name field will be omitted (typically this is
# only ever useful when processing a single branch in which case a faked length
# may be used on the input as long as it includes at least the last character
# in the subject string -- it may even be much bigger than the actual data
# length with no problem if used together with only1 set to true)
#
# If withmt is empty then empty branches (K == 3) will be treated exactly the
# same as annihilated (K == 2) branches; otherwise if withmt is true empty
# branches will be included regardless of the withan value; otherwise if
# withmt is false (but not "") empty branches will be excluded regardless of
# the withan value
#
# If withan is true annihilated branches will be included (and empty branches
# if withmt is "") otherwise if withan is false annihilated branches will be
# excluded (and empty branches if withmt is "") from the output
#
# note that if branches were excluded during the prepare phase they will
# continue to be excluded here regardless of any withan/withmt values as this
# script lacks the ability to resurrect them in that case
#
# Some valid TopGit branches may not have a .topmsg file and annihilated
# branches certainly do not so setting withan/withmt true will only give good
# results if awk_topgit_msg_prepare was passed the empty blob's hash for its
# "missing" variable
#
# ALWAYS PASS THE EMPTY BLOB'S HASH AS awk_topgit_msg_prepare's missing VALUE!
#
# Read the previous paragraphs again; unless you are 100% certain that every
# branch you want to appear in the output has a .topmsg file even if only an
# empty one, do what it says to do when running the prepare step
#

BEGIN { exitcode = "" }
function exitnow(e) { exitcode=e; exit e }
END { if (exitcode != "") exit exitcode }

BEGIN {
	inconly = 0
	cnt = split(inclbr, scratch, " ")
	if (cnt) {
		inconly = 1
		for (i = 1; i <= cnt; ++i) incnames[scratch[i]] = 1
	}
	cnt = split(exclbr, scratch, " ")
	for (i = 1; i <= cnt; ++i) excnames[scratch[i]] = 1
	if (kwregex == "") kwregex = "subject"
	kwregex = tolower(kwregex)
	subjrx = kwregex == "subject"
	if (substr(kwregex, 1, 1) == "+") {
		inclkw = 1
		kwregex = substr(kwregex, 2)
	}
	if (index(kwregex, "|") &&
	    (substr(kwregex, 1, 1) != "(" || substr(kwregex, length(kwregex)) != ")"))
		kwregex = "(" kwregex ")"
	if (substr(kwregex, 1, 1) != "^") kwregex = "^" kwregex
	if (substr(kwregex, length(kwregex)) != "$") kwregex = kwregex "$"
	if (OFS == "") OFS = " "
}

function included(abranch) {
	return (!inconly || incnames[abranch]) && !excnames[abranch]
}

function wanted(abranch, akind) {
	return !akind || akind == 1 ||
	(withmt != "" && akind == 3 && withmt) ||
	((akind != 3 || withmt == "") && withan)
}

function strapp(str1, str2) {
	if (str1 == "") return str2
	if (str2 == "") return str1
	return str1 " " str2
}

function trimsp(str) {
	gsub(/[ \t\r\n]+/, " ", str)
	sub(/^[ \t\r\n]+/, "", str)
	sub(/[ \t\r\n]+$/, "", str)
	return str
}

function prettykw(k, _kparts, _i, _c, _ans, _kpart) {
	_ans = ""
	_c = split(tolower(k), _kparts, /-/)
	for (_i=1; _i<=_c; ++_i) {
		_kpart = _kparts[_i]
		if (_kpart == "id") _kpart = "ID"
		else if (_kpart == "mime") _kpart = "MIME"
		else _kpart = toupper(substr(_kpart, 1, 1)) substr(_kpart, 2)
		_ans = _ans "-" _kpart
	}
	return substr(_ans, 2)
}

NF == 4 && $4 != "" && $3 != "" && $2 != "missing" && $1 != "" &&
$3 ~ /^[0123]$/ && $2 ~ /^[0-9]+$/ {
	bn = $4
	kind = $3
	datalen = $2 + 1
	curlen = 0
	cnt = 0
	err = 0
	inbody = $1 != "blob"
	insubj = 0
	subj = ""
	while (curlen < datalen && (err = getline) > 0) {
		curlen += length($0) + 1
		if (!inbody) {
			if (/^[ \t]*$/) inbody = 1
			else if (insubj) {
				if (/^[ \t\r\n]/) subj = strapp(subj, trimsp($0))
				else if (inclkw) insubj = 0
				else inbody = 1
			}
		}
		if (inbody || insubj) continue
		if (match($0, /^[^ \t\r\n:]+:/) &&
		    match((kw=tolower(substr($0, RSTART, RLENGTH - 1))), kwregex)) {
			insubj = 1
			oldsubj = subj
			subj = trimsp(substr($0, RLENGTH + 2))
			if (inclkw) {
				subj = strapp(prettykw(kw) ":", subj)
				if (oldsubj != "") subj = oldsubj "\n" subj
			}
		}
	}
	if (included(bn) && wanted(bn, kind)) {
		if (subjrx) {
			if (!kind) {
				if (insubj) {
					if (subj == "")
						subj = "branch " bn " (empty \"Subject:\" in .topmsg)"
				} else {
					subj = "branch " bn " (missing \"Subject:\" in .topmsg)"
				}
			} else if (kind == 1) {
				subj = "branch " bn " (missing .topmsg)"
			} else if (kind == 3) {
				subj = "branch " bn " (no commits)"
			} else {
				subj = "branch " bn " (annihilated)"
			}
		}
		outline = ""
		if (!noname || !nokind) {
			if (!noname) {
				outline = bn
				if (!nokind) outline = outline " " kind
			} else outline = kind
			if (colfmt) outline = sprintf("%-39s\t", outline)
			else outline = outline OFS
		}
		print outline subj
		if (only1) exitnow(0)
	}
	if (err < 0) exitnow(2)
}
