#!/usr/bin/awk -f

# topgit_deps - TopGit awk utility script used by tg--awksome
# Copyright (C) 2017 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved.
# License GPLv2

# topgit_deps
#
# variable arguments (-v):
#
#   brfile  if non-empty, read TopGit branch names from here
#   rmbr    if true run system rm on brfile (after reading) if non-empty brfile
#   anfile  if non-empty, annihilated branch names are read from here
#   rman    if true run system rm on anfile (after reading) if non-empty anfile
#   withan  if true, mostly pretend anfile was empty (this is a convenience knob)
#   withbr  if true, output an "edge to self" for each input branch
#   tgonly  if true only emit deps listed in brfile
#   rev     if true, reverse each dep and the order from each .topdeps file
#   exclbr  whitespace separated list of names to exclude
#   inclbr  whitespace separated list of names to include
#
# if inclbr is non-empty a branch name must be listed to appear on stdout
#
# if a branch name appears in exclbr it is omitted from stdout trumping inclbr
#
# input must be result of the git --batch output as described for
# awk_topgit_deps_prepare
#
# output is 0 or more dependency "edges" from the .topdeps blob files output
# in the same order they appear on the input except that if rev is true
# the lines from each individual .topdeps blob are processed in reverse order
# and the edges themselves are output in opposite order
#
# each output line has this format:
#
#   <TopGit_branch_name> <TopGit_branch_name>
#
# both branch names are guaranteed to be non-empty and non-matching unless
# withbr is true (but even then same-named branches from within the .topdeps
# content itself will still be suppressed) but other kinds of loops are not
# detected (until awk_topgit_recurse runs on the output)
#
# if withbr is true then a line will be output with the branch name as both
# the first and second fields (i.e. the edge points to itself) and this line
# will be output after all of the .topdeps content for the branch unless rev
# is true in which case it's output before any of the branch's .topdeps content
#
# Some valid TopGit branches may not have a .topdeps file and annihilated
# branches certainly do not so setting withbr true will only give good results
# if awk_topgit_deps_prepare was passed the empty blob's hash for its "missing"
# variable
#
# note that there can be duplicate output lines, especially when multiple
# patch series are present in the same repository and they share some of the
# patches
#
# note that anfile, if non-empty, is not read until after the first line of
# input is read, so the same file name passed to awk_topgit_deps_prepare can
# just be passed here as well without problem and, as a convenience, if rman
# is true the system "rm -f" command will be run on it after it's been read
# or if it's non-empty and withan is true
#
# using the withan knob, the same filename can always be passed as the anfile
# argument but it will be ignored when withan ("with annihilated in output")
# is set to true; this is done as a convenience as the same effect is always
# achieved by not passing any anfile value (or passing an empty string)
#
# any incoming branch names from the --batch .topdeps content that are not
# valid git ref names are silently discarded without notice
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
}

function quotevar(v) {
	gsub(/\047/, "\047\\\047\047", v)
	return "\047" v "\047"
}

function init(abranch, _e) {
	rmlist = ""
	if (brfile != "") {
		if (tgonly) {
			while ((_e = (getline abranch <brfile)) > 0) {
				if (abranch != "") tgish[abranch] = 1
			}
			close(brfile)
			if (_e < 0) exitnow(2)
		}
		if (rmbr) rmlist = rmlist " " quotevar(brfile)
	}
	if (!withan && anfile != "") {
		while ((_e = (getline abranch <anfile)) > 0) {
			if (abranch != "") ann[abranch] = 1
		}
		close(anfile)
		if (_e < 0) exitnow(2)
		if (rman) rmlist = rmlist " " quotevar(anfile)
	}
	if (rmlist != "") system("rm -f" rmlist)
}

function included(abranch) {
	return (!inconly || incnames[abranch]) && !excnames[abranch]
}

function wanted(abranch) {
	return !tgonly || tgish[abranch]
}

function validbr(branchname) {
	return "/" tolower(branchname) "/" !~ \
	"//|\\.\\.|@\\173|/\\.|\\./|\\.lock/|[\\001-\\040\\177~^:\\\\*?\\133]"
}

NR == 1 {init()}

NF == 3 && $2 != "missing" && $1 != "" && $2 ~ /^[0-9]+$/ && validbr($3) {
	bn = $3
	isann = ann[bn] || $1 != "blob"
	incl = included(bn)
	want = wanted(bn)
	datalen = $2 + 1
	curlen = 0
	if (withbr && rev && incl && want) print bn " " bn
	cnt = 0
	err = 0
	while (curlen < datalen && (err = getline) > 0) {
		curlen += length($0) + 1
		sub(/\r$/, "", $1)
		if (NF != 1 || $1 == "" || !validbr($1)) continue
		if (!isann && !ann[$1] && included($1) && wanted($1)) {
			if (rev)
				items[++cnt] = $1 " " bn
			else
				print bn " " $1
		}
	}
	if (err < 0) exitnow(2)
	for (i=cnt; i>0; --i) print items[i]
	if (withbr && !rev && incl && want) print bn " " bn
}
