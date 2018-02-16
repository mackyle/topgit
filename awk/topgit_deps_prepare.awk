#!/usr/bin/awk -f

# topgit_deps_prepare - TopGit awk utility script used by tg--awksome
# Copyright (C) 2017 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved.
# License GPLv2

# topgit_deps_prepare
#
# variable arguments (-v):
#
#   brfile   if non-empty, the named file gets a list of TopGit branches
#   anfile   if non-empty, annihilated branch names are written here
#   noann    if true, omit annihilated branches from brfile
#   missing  if non-empty output its value for the .topdeps blob instead
#            of skipping, but still skip annihilated if noann is true
#   misscmd  if missing is used and not seen in a "check" line run this once
#
# note that the "noann" variable only affects brfile, if true unless missing
# is non-empty (in which case it suppresses the annihilated missing output), as
# annihilated branches normally do not contribute to the output of this script
#
# input must be result of awk_ref_prepare after feeding through the correct
# git --batch-check command and must be generated with the "depsblob" variable
# set to a TRUE value when awk_ref_prepare was run (the "msgblob" setting can
# be any value as the extra .topmsg blob line, if present, will always be
# silently ignored)
#
# if missing is non-empty there are two different possible choices:
#
#   1. the hash of the empty blob, this is the recommended value and will
#      cause all annihilated (unless noann is true) and non-annihilaed branches
#      without a .topdeps file to produce an output line which can sometimes be
#      useful
#
#   2. an invalid ref value, do NOT use "missing" as there could be such a ref
#      name in the repository ("?" or "?missing" are good choices) and it must
#      not contain any whitespace either; in this case this will trigger the
#      subsequent git cat-file --batch to generate a "xxx missing" line which
#      will also remove the item and ultimately have the same effect as leaving
#      missing unset in the first place
#
#   3. it says "two" above, so don't do this, but if the blob hash of
#      a different .topdeps file is given its contents will be used as though
#      it had been the branch's .topdeps file in the first place (only for
#      annihilated and branches without one though)
#
# If missing is non-empty AND it gets used AND misscmd is non-empty AND no
# "blob check ?" line was seen for missing then misscmd will be run the FIRST
# time missing is about to be output (it always runs BEFORE the line is output).
#
# output is 1 line per non-annihilated TopGit branch with a .topdeps file where
# each output line has this format:
#
#   <blob_hash_of_.topdeps_file> <TopGit_branch_name>
#
# which should then be fed to:
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
	     getline bct + getline hct + getline hcd) != 5) exitnow(2)
	split(bc, abc)
	split(hc, ahc)
	split(bct, abct)
	split(hct, ahct)
	split(hcd, ahcd)
	if (abc[2] != "commit" || ahc[2] != "commit" ||
	    abct[2] != "tree"  || ahct[2] != "tree") next
	if (abct[1] == ahct[1]) {
		if (anfile) print $3 >anfile
		if (noann || missing == "") {
			if (!noann && brfile) print $3 >brfile
			next
		} else {
			ahcd[1] = missing
			ahcd[2] = "blob"
			domissing()
		}
	}
	if (brfile) print $3 >brfile
	if (missing != "" && ahcd[2] != "blob") {
		ahcd[1] = missing
		ahcd[2] = "blob"
		domissing()
	}
	if (ahcd[2] == "blob") {
		if (delay)
			items[++cnt] = ahcd[1] " " $3
		else
			print ahcd[1] " " $3
	}
}

END {
	if (anfile) close(anfile)
	if (brfile) close(brfile)
	for (i = 1; i <= cnt; ++i) print items[i]
}
