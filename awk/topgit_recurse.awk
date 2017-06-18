#!/usr/bin/awk -f

# topgit_recurse - TopGit awk utility script used by tg--awksome
# Copyright (C) 2017 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved.
# License GPLv2

# topgit_recurse
#
# variable arguments (-v):
#
#   brfile  if non-empty, read TopGit branch names from here
#   rmbr    if true run system rm on brfile (after reading) if non-empty brfile
#   anfile  if non-empty, annihilated branch names are read from here
#   rman    if true run system rm on anfile (after reading) if non-empty anfile
#   hdfile  if non-empty, existing head names are read from here
#   rmhd    if true run system rm on hdfile (after reading) if non-empty hdfile
#   cuthd   if true extract and cut cuthd field of each "refs/heads/" line
#   rtfile  if non-empty, read non-annihilated remote tg branch names from here
#   rmrt    if true run system rm on rtfile (after reading) if non-empty rtfile
#   usermt  if non-empty output remote base lines using this prefix if in rtfile
#   withan  if true, include L == 2 output lines
#   withbr  if true, output a line for the top-level branch
#   preord  if true, output the branch line before its .topdeps instead of after
#   exclbr  whitespace separated list of names to exclude
#   inclbr  whitespace separated list of names to include
#   startb  whitespace separated list of start branch plus extra path items
#   multib  if "1" startb is list of multiple start nodes (with no extra path)
#   filter  if 1 or 2 output dependency instead of recurse lines (see below)
#   once    if > 0 nodes when 1st visited only if < 0 deps on 1st visit only
#   leaves  if true omit output lines where L != 1 (withbr recommended if set)
#   tgonly  if true only T != 0 (or M == 1) lines are output
#   showlp  if true output a :loop: line for any loops
#
# in multi start mode (multib is true) duplicate start names are ignored
# (using a true value for "multib" other than "1" may have undefined behavior)
#
# if inclbr is non-empty a branch name must be listed to appear on stdout
#
# if a branch name appears in exclbr it is omitted from stdout trumping inclbr
#
# except for branches removed entirely from consideration by exclbr/inclbr
# or !withan and being in anfile, any other branch found to be missing
# (i.e. no hdfile entry) will generate a missing (M=1) line regardless of
# any !withbr or leaves or tgonly settings
#
# annihilated branches listed in anfile may also appear in brfile without harm
# but they do not need to for correct results (i.e. same results either way)
#
# Note that if non-empty, usermt must be the FULL prefix for remote base ref
# names for example "refs/remotes/origin/top-bases" works (if that's the
# correct top-bases location of course)
#
# if a branch is excluded (either by not being in a non-empty inclbr list or
# by being listed in the exclbr list) then it will not be recursed into either
#
# to get accurate output, brfile, anfile and hdfile must all be provided and,
# obviously, if remote information is needed rtfile as well (usermt will be
# effectively ignored unless rtfile is provided)
#
# input is a list of edges as output by run_awk_topgit_deps
#
# using the startb starting point the graph is walked outputting one line for
# each visited node with the following format:
#
#   M T L V <node> [<parent> <branch> <chain> <names>]
#
# where M T L are single numeric digits with the following meanings:
#
#   M=0  branch actually exists (i.e. it's NOT missing)
#   M=1  branch does not exist but was named in a .topdeps or startb (if withbr)
#
#   T=0  branch is NOT tgish or NOT local (missing and remotes are always 0)
#   T=1  branch IS local tgish (annihilated branches are always 1)
#   T=2  branch IS local tgish and has a non-annihilated remote tgish branch
#
#   L=0  not a leaf node (missing and remotes are always 0)
#   L=1  IS a leaf node (might or might NOT be tgish)
#   L=2  an annihilated tgish branch (they can never be leaves anyway)
#
# contrary to the non-awk code this replaces, L == 1 IS possible with preord
#
# The V value is a non-negative integer indicating excess visits to this node
# where the first visit is not in excess so it's 0 the next visit is the first
# excess visit so it's 1 and so on.
#
# note that <node> will always be present and non-empty
# unless withbr is true then <parent> will also always be present and non-empty
# even if withbr IS true <parent> will be non-empty if extra path items were
# provided (the first path item becomes the parent and the rest the chain)
# the rest of the path items show the link chain from <node> up to <startb>
# with any extra path items output on the end
#
# An output line might look like this:
#
#   0 1 1 0 t/foo/leaf t/foo/int t/stage
#
# L=2 "a leaf" means any node that is either not a TopGit branch or is a
# non-annihilated TopGit branch with NO non-annihilated dependencies (that
# means NO non-tgish dependencies either)
#
# loops are detected and avoided (the link causing the loop is dropped) and
# if showlp is true a line like the following will be output whenever one is
# encountered:
#
#   :loop: t/foo/int t/foo/leaf t/foo/int t/stage
#
# the two branch names immediately after LOOP show the link that was dropped
# to avoid the loop and the rest of the path is the normal branch chain
#
# in filter mode (filter is 1 or 2) the output is a list of deps (1) or
# edges (2) instead of recursion lines so the above sample output line would
# end up being this when filter mode is 1:
#
#   t/foo/leaf
#
# to get the "patch series" list used for navigation use withbr=1 once=1 and
# filter=1
#
# and just this output when filter mode is 2:
#
#   t/foo/int t/foo/leaf
#
# the first two node items from the recursion line are reversed (if withbr
# is active the single node name will be doubled to make an edge to itself)
# because the edge format is "<node-with-topdeps-line> <for-this-node>" whereas
# the normal recursion lines have the opposite order.
#
# extra items in startb are ignored in filter mode unless multib is "1" in
# which case they're then treated as additional starting nodes (just like
# normal multib=1 mode does).
#
# when filter mode is active the rtfile file and usermt settings are ignored
# (but rmrt will still work) while preord does work it's mostly pointless
# in filter mode.  the leaves option still works exactly the same way as it's
# just the final format of the output line that's affected by filter mode not
# which lines (other than omitting remote lines) are output.  Lines for
# missing (M == 1) items are, however, totally suppressed in filter mode
# since they're just not meaningful in that case.  loop lines will still be
# output in exactly the same format if showlp is true.
#
# filter mode can be helpful when the intent is to ultimately run
# awk_topgit_navigate on a subset of the TopGit dependency tree
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
	cnt = split(startb, scratch, " ")
	if (!cnt) exitnow(2)
	if (multib) {
		startcnt = 0
		for (i = 1; i <= cnt; ++i) {
			if (!seenstartbr[scratch[i]]) {
				startbr[++startcnt] = scratch[i]
				extrabr[startcnt] = ""
				seenstartr[scratch[i]] = 1
			}
		}
	} else {
		startbr[1] = scratch[1]
		xtrapth = ""
		for (i = 2; i <= cnt; ++i) xtrapth = xtrapth " " scratch[i]
		extrabr[1] = xtrapth;
		startcnt = 1
	}
	sub(/\/+$/, "", usermt)
	if (usermt != "") usermt = usermt "/"
	if (filter != "" && filter != 0 && filter != 1 && filter != 2) exitnow(2)
}

function quotevar(v) {
	gsub(/\047/, "\047\\\047\047", v)
	return "\047" v "\047"
}

function init(abranch, _e) {
	rmlist = ""
	if (brfile != "") {
		while ((_e = (getline abranch <brfile)) > 0) {
			if (abranch != "") tgish[abranch] = 1
		}
		close(brfile)
		if (_e < 0) exitnow(2)
		if (rmbr) rmlist = rmlist " " quotevar(brfile)
	}
	if (anfile != "") {
		while ((_e = (getline abranch <anfile)) > 0) {
			if (abranch != "") ann[abranch] = 1
		}
		close(anfile)
		if (_e < 0) exitnow(2)
		if (rman) rmlist = rmlist " " quotevar(anfile)
	}
	if (hdfile != "") {
		if (cuthd) {
			fno = 1
			if (cuthd ~ /^[1-9][0-9]*$/) fno = 0 + cuthd
		}
		while ((_e = (getline abranch <hdfile)) > 0) {
			if (fno) {
				if (split(abranch, scratch, " ") < fno || length(scratch[fno]) < 12 ||
				    substr(scratch[fno], 1, 11) != "refs/heads/") continue
				abranch = substr(scratch[fno], 12)
				sub(/[~:^].*$/, "", abranch)
			}
			if (abranch != "") heads[abranch] = 1
		}
		close(hdfile)
		if (_e < 0) exitnow(2)
		if (rmhd) rmlist = rmlist " " quotevar(hdfile)
	}
	if (rtfile != "") {
		if (!filter) {
			while ((_e = (getline abranch <rtfile)) > 0) {
				if (abranch != "") tgishr[abranch] = 1
			}
			close(rtfile)
			if (_e < 0) exitnow(2)
		}
		if (rmrt) rmlist = rmlist " " quotevar(rtfile)
	}
	if (rmlist != "") system("rm -f" rmlist)
}

function included(abranch) {
	return (!inconly || incnames[abranch]) && !excnames[abranch]
}

NR == 1 {init()}

NF == 2 && $1 != "" && $2 != "" && $1 != $2 &&
included($1) && included($2) && !ann[$1] && (withan || !ann[$2]) {
	linkval = links[$1]
	if (linkval != "") {
		if (index(" " linkval " ", " " $2 " ")) next
		links[$1] = linkval " " $2
	} else {
		links[$1] = $2
	}
	if (withan && !ann[$2]) {
		# when using withan, linksx is the tree !withan would generate
		# (it eXcludes all annihilated links)
		# no need for it if !withan in effect as it would match links
		linkval = linksx[$1]
		if (linkval != "") linksx[$1] = linkval " " $2
		else linksx[$1] = $2
	}
}

function xvisits(node) {
	if (node in xvisitcnts)
		xvisitcnts[node] = xvisitcnts[node] + 1
	else
		xvisitcnts[node] = 0
	return xvisitcnts[node]
}

function walktree(node, trail, level,
	oncenodes, istgish, isleaf, children, childcnt, parent, child, visited, i)
{
	if (once > 0 && (node in oncenodes)) return
	if (!heads[node]) {
		if (!filter) print "1 0 0 " xvisits(node) " " node trail
		if (once) oncenodes[node] = 1
		return
	}
	if (filter == 2) {
		parent = substr(trail, 2)
		sub(/ .*$/, "", parent)
		if (parent == "") parent = node
		parent = parent " "
	}
	istgish = 0
	isleaf = 0
	if (ann[node]) {
		istgish = 1
		isleaf = 2
	} else if (tgish[node]) {
		istgish = tgishr[node] ? 2 : 1
	}
	if (isleaf != 2) isleaf = !istgish || (withan?linksx[node]:links[node]) == ""
	if (preord && (level > 0 || withbr) && (!leaves || isleaf == 1) && (!tgonly || istgish)) {
		if (filter) print parent node
		else print "0 " istgish " " isleaf " " xvisits(node) " " node trail
	}
	if (!once || !(node in oncenodes)) {
		if (istgish == 2 && usermt && !leaves && !tgonly)
			print "0 0 0 " xvisits(usermt node) " " usermt node " " node trail
		if ((childcnt = split(links[node], children, " "))) {
			visited = " " node trail " "
			for (i = 1; i <= childcnt; ++i) {
				child = children[i]
				if (index(visited, " " child " ")) {
					if (showlp) print ":loop: " child " " node trail
					continue
				}
				walktree(child, " " node trail, level + 1, oncenodes)
			}
		}
	}
	if (!preord && (level > 0 || withbr) && (!leaves || isleaf == 1) && (!tgonly || istgish)) {
		if (filter) print parent node
		else print "0 " istgish " " isleaf " " xvisits(node) " " node trail
	}
	if (once) oncenodes[node] = 1
}

END {
	for (startidx = 1; startidx <= startcnt; ++startidx) {
		astart = startbr[startidx]
		if (included(astart) && (!heads[astart] || withan || !ann[astart]))
			walktree(astart, extrabr[startidx], 0)
	}
}
