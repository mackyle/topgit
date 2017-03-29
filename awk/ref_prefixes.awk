#!/usr/bin/awk -f

# ref_prefixes - TopGit awk utility script used by tg--awksome
# Copyright (C) 2017 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved.
# License GPLv2

# ref_prefixes
#
#  pckdrefs  input refs are in packed-refs format (instead of just full ref name)
#  prefix1   first ref prefix to look for and the default
#  prefix2   second ref prefix to look for
#  prefixh   ignore prefix1/prefix2 matches without corresponding prefixh
#  noerr     instead of error 65 (EX_DATAERR) output default (prefix1) when both
#  nodef     instead of defaulting to prefix1, exit with error 66 (EX_NOINPUT)
#
# input is a list of full ref names one per line; if pckdrefs is true then the
# second field of the line will be used otherwise the first
#
# prefix1 may not be a prefix of prefix2 or vice versa
#
# if prefixh is non-empty then matches for prefix1 or prefix2 must also match
# another line from the input after replacing the prefix1/prefix2 part with
# prefixh or they are discarded and do not participate in choosing the output
#
# note that the input need not be sorted in any particular order or be
# duplicate free even when prefixh is non-empty
#
# a prefix will only match at a "/" boundary
#
# ontput according to this table:
#
#   any refs match   any refs match   noerr   exit     output
#   prefix1 prefix   prefix2 prefix   value   status   value
#   --------------   --------------   -----   ------  -------
#   no               no               any     0        prefix1
#   yes              no               any     0        prefix1
#   no               yes              any     0        prefix2
#   yes              yes              false   1
#   yes              yes              true    0        prefix1
#
# there is no output when exit status is 1
# the output value, if any, will have any trailing slash(es) removed from it
#

BEGIN { exitcode = "" }
function exitnow(e) { exitcode=e; exit e }
END { if (exitcode != "") exit exitcode }

BEGIN {
	sub(/\/+$/, "", prefix1)
	sub(/\/+$/, "", prefix2)
	sub(/\/+$/, "", prefixh)
	if (prefix1 == "" || prefix2 == "" ||
	    prefix1 == prefix2 ||
	    prefix1 == prefixh || prefix2 == prefixh)
		exitnow(2)
	if (substr(prefix1, 1, 5) != "refs/" ||
	    substr(prefix2, 1, 5) != "refs/" ||
	    (prefixh != "" && substr(prefixh, 1, 5) != "refs/"))
		exitnow(2)
	plen1 = length(prefix1)
	plen2 = length(prefix2)
	plenh = length(prefixh)
	if (plen1 < 6 || plen2 < 6) exitnow(2)
	prefix1 = prefix1 "/"
	prefix2 = prefix2 "/"
	++plen1
	++plen2
	if (prefixh != "") {
		prefixh = prefixh "/"
		++plenh
	}
	if (plen1 < plen2 && plen1 == substr(plen2, 1, plen1)) exitnow(2)
	if (plen1 > plen2 && substr(plen1, 1, plen2) == plen2) exitnow(2)
	sawp1 = 0
	sawp2 = 0
	cnt = 0
}

function check(r) {
	if (length(r) > plen1 && prefix1 == substr(r, 1, plen1)) {
		if (prefixh && !heads[substr(r, plen1)]) return 0
		sawp1 = 1
	} else if (length(r) > plen2 && prefix2 == substr(r, 1, plen2)) {
		if (prefixh && !heads[substr(r, plen2)]) return 0
		sawp2 = 1
	}
	if (sawp1 && sawp2) return 1
	return 0
}

{
	if (pckdrefs) ref = $2
	else ref = $1
	sub(/\/+$/, "", ref)
	if (length(ref) < 6 || substr(ref, 1, 5) != "refs/") next
	if (prefixh) {
		refs[++cnt] = ref
		if (length(ref) > plenh && prefixh == substr(ref, 1, plenh))
			heads[substr(ref, plenh)] = 1
	} else {
		if (check(ref)) exit
	}
}

END {
	for (i = 1; i <= cnt && !check(refs[i]); ++i) ;
	if (!noerr && sawp1 && sawp2) exit 65
	if (!sawp1 && !sawp2 && nodef) exit 66
	if (sawp1 || !sawp2)
		print substr(prefix1, 1, plen1 - 1)
	else
		print substr(prefix2, 1, plen2 - 1)
}
