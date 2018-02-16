#!/usr/bin/awk -f

# topgit_msg_prepare - TopGit awk utility script used by tg--awksome
# Copyright (C) 2017 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved.
# License GPLv2

# topgit_msg_prepare
#
# variable arguments (-v):
#
#   brfile   if non-empty, the named file gets a list of TopGit branches
#   anfile   if non-empty, annihilated branch names are written here
#   withan   if true, include annihilated branches in brfile and output
#   withmt   empty branches: "" (like withan), true (include) false (exclude)
#   depsblob if true skip the 6th line of each group as it's a .topdeps blob
#   missing  if non-empty output its value for the .topmsg blob instead
#            of skipping, but still skip annihilated unless withan is true
#   misscmd  if missing is used and not seen in a "check" line run this once
#
# note that withan affects brfile and output but withmt only affects output
#
# note that empty branches are always included in anfile (and brfile when
# withan is true) regardless of any withmt setting
#
# if withan is false annihilated branches are excluded (but see withmt)
#
# if withmt is empty ("") empty branches are treated the same as annihilated
# branches; if withmt is true empty branches are always included even if withan
# is false; if withmt is false (but not "") empty branches are always excluded
# even if withan is true
#
# input must be result of awk_ref_prepare after feeding through the correct
# git --batch-check command and must be generated with the "msgblob" variable
# set to a TRUE value AND the same depsblob value must be passed as when
# awk_ref_prepare was run
#
# if missing is non-empty there are two different possible choices:
#
#   1. the hash of the empty blob, this is the recommended value and will
#      cause all annihilated (unless withan is false) and non-annihilaed
#      branches (unless withmt excludes them) without a .topmsg file to
#      produce an output line which can often be useful
#
#   2. an invalid ref value, do NOT use "missing" as there could be such a ref
#      name in the repository ("?" or "?missing" are good choices) and it must
#      not contain any whitespace either; in this case this will trigger the
#      subsequent git cat-file --batch to generate a "xxx missing" line which
#      will also remove the item and ultimately have the same effect as leaving
#      missing unset in the first place
#
#   3. it says "two" above, so don't do this, but if the blob hash of
#      a different .topmsg file is given its contents will be used as though
#      it had been the branch's .topmsg file in the first place (only for
#      annihilated/empty and branches without one though)
#
# If missing is non-empty AND it gets used AND misscmd is non-empty AND no
# "blob check ?" line was seen for missing then misscmd will be run the FIRST
# time missing is about to be output (it always runs BEFORE the line is output).
#
# output is 1 line per non-excluded TopGit branch with a .topmsg file where
# each output line has this format:
#
#   <blob_hash_of_.topmsg_file> K <TopGit_branch_name>
#
# where kind of branch value K has these possible values and meanings:
#
#   0  non-annihilated, non-empty branch WITH a .topmsg file
#   1  non-annihilated, non-empty branch WITHOUT a .topmsg file
#   2  annihilated branch
#   3  empty branch (an empty branch has the same branch and base commit hash)
#   4  bare branch (only if depsblob is true and has a value other than "1")
#
# if missing is empty K = 1..4 lines will not be output at all
# if missing is anything that causes a "missing" result it will defeat all
# K = 1..4 output lines when subsequently fed through git cat-file --batch
#
# in most other contexts empty branches are treated the same as annihilated
# branches (because their branch and base trees are necessarily the same), but
# here a distinction is made so a different message can be shown for them
#
# if depsblob is true and set to a value other than "1" then the depsblob line
# won't just be ignored, it should be a real depsblob line and it will be used
# to generate the K = 4 status value
#
# output should then be fed to:
#
#   git cat-file --batch='%(objecttype) %(objectsize) %(rest)' | tr '\0' '\27'
#
# note that brfile and anfile are both fully written and closed before the
# first line of stdout is written and will be truncated to empty even if there
# are no lines directed to them
#

BEGIN { exitcode = "" }
function exitnow(e) { exitcode=e; exit e }
END { if (exitcode != "") exit exitcode }

BEGIN {
	cnt = 0
	delay = 0
	if (anfile != "") {
		printf "" >anfile
		delay=1
	}
	if (brfile != "") {
		printf "" >brfile
		delay=1
	}
	FS = " "
	missblob = missing
	if (missing != "" && missing !~ /:/) missing = missing "^{blob}"
}

NF == 4 && $4 == "?" && $3 == "check" && $2 == "blob" && $1 != "" {
	check[$1] = "blob"
	next
}

function domissing() {
	if (misscmd == "" || missblob in check) return
	system(misscmd)
	check[missblob] = ""
}

NF == 4 && $4 == ":" && $3 != "" && $2 != "missing" && $1 != "" {
	if ((getline bc  + getline hc + \
	     getline bct + getline hct + getline hcm) != 5) exitnow(2)
	if (depsblob) {
		split(hcm, ahcd)
		if ((getline hcm) != 1) exitnow(2)
	}
	split(bc, abc)
	split(hc, ahc)
	split(bct, abct)
	split(hct, ahct)
	split(hcm, ahcm)
	if (abc[2] != "commit" || ahc[2] != "commit" ||
	    abct[2] != "tree"  || ahct[2] != "tree") next
	want = abct[1] != ahct[1]
	if (!want) {
		if (withmt != "" && abc[1] == ahc[1]) want = withmt
		else want = withan
	}
	K = 0
	if (abct[1] == ahct[1]) {
		if (anfile) print $3 >anfile
		if (!withan || missing == "") {
			if (!want || missing == "") {
				if (withan && brfile) print $3 >brfile
				next
			}
		}
		ahcm[1] = missing
		ahcm[2] = "blob"
		K = (abc[1] == ahc[1]) ? 3 : 2
		domissing()
	}
	if (brfile) print $3 >brfile
	if (missing != "" && ahcm[2] != "blob") {
		if (!K) {
			if (depsblob && depsblob != "1" &&
			    ahcd[2] == "missing" && ahcm[2] == "missing")
				K = 4
			else
				K = 1
		}
		ahcm[1] = missing
		ahcm[2] = "blob"
		domissing()
	}
	if (ahcm[2] == "blob") {
		if (delay)
			items[++cnt] = ahcm[1] " " K " " $3
		else
			print ahcm[1] " " K " " $3
	}
}

END {
	if (anfile) close(anfile)
	if (brfile) close(brfile)
	for (i = 1; i <= cnt; ++i) print items[i]
}
