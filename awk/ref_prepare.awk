#!/usr/bin/awk -f

# ref_prepare - TopGit awk utility script used by tg--awksome
# Copyright (C) 2017,2019 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved.
# License GPLv2

# ref_prepare
#
# variable arguments (-v):
#
#   topbases  the full target topbases prefix (e.g. "refs/top-bases")
#   headbase  the full heads prefix (default is based on topbases value)
#   chkblob   if set spit out a verification line for this blob first
#   depsblob  if true include 6th line ".topdeps" blob otherwise not
#   msgblob   if true include 6th or 7th line ".topmsg" blob otherwise not
#   refsfile  ref definitions are read from here and used to output hashes
#   pckdrefs  ref table is in packed-refs format (ignored without refsfile)
#   rmrf      if true run system rm on refsfile (after reading)
#   topdeps   if in form <branch>:<hash> substitute <hash> for branch:.topdeps
#   topmsg    if in form <branch>:<hash> substitute <hash> for branch:.topmsg
#   teeout    if non-empty output lines are written here too
#
# if refsfile is non-empty, each line of the file it names must 2+ fields:
#
#   <full-ref-name> <full-hash-for-ref> <anything-else-on-line-ignored>
#
# Unless pckdrefs is true and then packed-refs format is expected instead
#
# if refsfile is non-empty, instead of outputting refnames, the name will be
# looked up in the refsfile table and the corresponding hash (or a value
# guaranteed to generate a "missing" result) used
#
# if topdeps is provided (and matches <branch>:<hash> e.g. "t/foo:1234") then
# when depsblob is requested and the current branch is <branch> then instead
# of the normal output, <hash>^{blob} will be output instead which can be
# used to substitute an index or working tree version of a .topdeps file
#
# input must be a list of full ref names one per line
#
# output is 5, 6 or 7 lines per input line matching /^$topbases/
# to feed to:
#
#   git cat-file --batch-check='%(objectname) %(objecttype) %(rest)'
#
# if both depsblob and msgblob are true depsblob is output before msgblob and
# both always come after the fixed first 5 lines
#
# if chkblob is not empty an additional line will precede all other output
# that verifies the existence of the chkblob object (and resolves it to a hash)
#
# note that if teeout is non-empty it will always be truncated before starting
# to write the output even if no output is produced; also note that unlike the
# other scripts this one writes to teeout simultaneously with stdout
#

BEGIN { exitcode = "" }
function exitnow(e) { exitcode=e; exit e }
END { if (exitcode != "") exit exitcode }

BEGIN {
	sub(/\/+$/, "", topbases)
	if (topbases == "") exitnow(2)
	topbases = topbases "/"
	tblen = length(topbases)
	tbdrop = tblen + 1
	if (headbase == "") {
		if (topbases !~ /^refs\//) exitnow(2)
		if (topbases ~ /^refs\/remotes\//) {
			if (topbases !~ /^refs\/remotes\/[^\/]+\/[^\/]+\//) exitnow(2)
			headbase = topbases
			sub(/\/[^\/]+\/$/, "/", headbase)
		} else {
			headbase = "refs/heads/"
		}
	} else {
		sub(/\/+$/, "", headbase)
		if (headbase == "") exitnow(2)
		headbase = headbase "/"
	}
	if (topdeps ~ /^[^ \t\r\n:]+:[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]+$/) {
		colonat = index(topdeps, ":")
		topdepsbr = substr(topdeps, 1, colonat - 1)
		topdepsha = tolower(substr(topdeps, colonat + 1))
	}
	if (topmsg ~ /^[^ \t\r\n:]+:[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]+$/) {
		colonat = index(topmsg, ":")
		topmsgbr = substr(topmsg, 1, colonat - 1)
		topmsgha = tolower(substr(topmsg, colonat + 1))
	}
	if (teeout != "") printf "" >teeout
}

function doprint(line) {
	if (teeout != "") print line >teeout
	print line
}

function quotevar(v) {
	gsub(/\047/, "\047\\\047\047", v)
	return "\047" v "\047"
}

function rmrefs() {
	if (refsfile != "" && rmrf) {
		system("rm -f " quotevar(refsfile))
		rmrf = 0
		refsfile = ""
	}
}
END { rmrefs() }

function init(_e) {
	if (refsfile != "") {
		while ((_e = (getline info <refsfile)) > 0) {
			cnt = split(info, scratch, " ")
			if (cnt < 2 || scratch[1] == "" || scratch[2] == "") continue
			if (pckdrefs) {
				swapfield = scratch[1]
				scratch[1] = scratch[2]
				scratch[2] = swapfield
			}
			if (scratch[1] ~ /^refs\/./ &&
			    scratch[2] ~ /^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]+$/)
				refs[scratch[1]] = scratch[2]
		}
		close(refsfile)
		if (_e < 0) exitnow(2)
	}
	rmrefs()
}

BEGIN {
	if (chkblob != "") doprint(chkblob "^{blob}" " check ?")
}

NR == 1 {init()}

function getref(r) { return refsfile == "" ? r : ((r in refs) ? refs[r] : "?") }

NF == 1 && substr($1, 1, tblen) == topbases {
	bn = substr($1, tbdrop)
	if (bn == "") next
	baseref = getref(topbases bn)
	headref = getref(headbase bn)
	doprint(baseref " " bn " :")
	doprint(baseref "^0")
	doprint(headref "^0")
	doprint(baseref "^{tree}")
	doprint(headref "^{tree}")
	if (depsblob) {
		if (bn == topdepsbr)
			doprint(topdepsha "^{blob}")
		else
			doprint(headref "^{tree}:.topdeps")
	}
	if (msgblob) {
		if (bn == topmsgbr)
			doprint(topmsgha "^{blob}")
		else
			doprint(headref "^{tree}:.topmsg")
	}
}
