#!/usr/bin/awk -f

# topgit_branches - TopGit awk utility script used by tg--awksome
# Copyright (C) 2017,2019 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved.
# License GPLv2

# topgit_branches
#
# variable arguments (-v):
#
#   brfile  if non-empty, the named file gets a copy of the output stream
#   anfile  if non-empty, annihilated branch names are written here
#   noann   if true, omit annihilated branches from output (and brfile)
#   exclbr  whitespace separated list of names to exclude (only from stdout)
#   inclbr  whitespace separated list of names to include (only for stdout)
#
# note that the "noann" variable affects both stdout and, if given, brfile
# but not anfile.
#
# if inclbr is non-empty a branch name must be listed to appear on stdout
# (but brfile, if given, is not affected)
#
# if a branch name appears in exclbr it is omitted from stdout trumping inclbr
# (but brfile, if given, is not affected)
#
# input must be output from awk_ref_prepare (depsblob and msgblob may have any
# setting) after feeding through the correct git --batch-check command
#
# output is one TopGit branch name per line omitting annihilated ones if noann
#
# note that brfile and anfile are both fully written and closed before the
# first line of stdout is written and will be truncated to empty even if there
# are no lines directed to them
#

BEGIN { exitcode = "" }
function exitnow(e) { exitcode=e; exit e }
END { if (exitcode != "") exit exitcode }

BEGIN {
	delay = 0
	if (anfile != "") {
		printf "" >anfile
		delay=1
	}
	if (brfile != "") {
		printf "" >brfile
		delay=1
	}
	inconly = 0
	cnt = split(inclbr, scratch, " ")
	if (cnt) {
		inconly = 1
		for (i = 1; i <= cnt; ++i) incnames[scratch[i]] = 1
	}
	cnt = split(exclbr, scratch, " ")
	for (i = 1; i <= cnt; ++i) excnames[scratch[i]] = 1
	FS = " "
	cnt = 0
}

NF == 4 && $4 == ":" && $3 != "" && $2 != "missing" && $1 != "" {
	if ((getline bc  + getline hc + \
	     getline bct + getline hct) != 4) exitnow(2)
	split(bc, abc)
	split(hc, ahc)
	split(bct, abct)
	split(hct, ahct)
	if (abc[2] != "commit" || ahc[2] != "commit" ||
	    abct[2] != "tree"  || ahct[2] != "tree") next
	if (abct[1] == ahct[1]) {
		if (anfile) print $3 >anfile
		if (noann) next
	}
	if (brfile) print $3 >brfile
	if ((!inconly || ($3 in incnames)) && !($3 in excnames)) {
		if (delay)
			items[++cnt] = $3
		else
			print $3
	}
}

END {
	if (anfile) close(anfile)
	if (brfile) close(brfile)
	for (i = 1; i <= cnt; ++i) print items[i]
}
