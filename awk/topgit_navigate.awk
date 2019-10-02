#!/usr/bin/awk -f

# topgit_navigate - TopGit awk utility script used by tg--awksome
# Copyright (C) 2017,2019 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved.
# License GPLv2

# topgit_navigate
#
# variable arguments (-v):
#
#   brfile  if non-empty, read TopGit branch names from here
#   rmbr    if true run system rm on brfile (after reading) if non-empty brfile
#   anfile  if non-empty, annihilated branch names are read from here
#   rman    if true run system rm on anfile (after reading) if non-empty anfile
#   withan  if true, mostly pretend anfile was empty (this is a convenience knob)
#   exclbr  whitespace separated list of names to exclude
#   inclbr  whitespace separated list of names to include
#   startb  starting branch name(s); may be empty (see below)
#   pruneb  zero or more (space separated) nodes to limit results to (see below)
#   steps   how many steps to move, negative means as many as possible
#   chklps  always check for loops even when not necessary
#   rev     if true move in reverse order (towards start/first rather than end/last)
#   pin     if true and steps is > 0 and runs off the end keep last visited node
#   tgonly  if true only nodes listed in brfile are output
#   fldone  output only the first field on each line
#
# NOTE: an integer "steps" value is REQUIRED
# NOTE: if "steps" is zero, a non-empty "startb" value is REQUIRED
#
# if inclbr is non-empty a branch name must be listed to appear on stdout
#
# if a branch name appears in exclbr it is omitted from stdout trumping inclbr
#
# if a branch is excluded (either by not being in a non-empty inclbr list or
# by being listed in the exclbr list) then it will not be recursed into either
#
# input is a list of edges as output by run_awk_topgit_deps
#
# using the startb starting point the graph is walked forward (backward if rev)
# exactly steps times unless steps is negative in which case it's walked to the
# end (and pin is always implicitly true in that case)
#
# "forward" moves toward later patches whereas "backwards" moves towards earlier
# ones where earlier patches must be applied before later ones
#
# if startb is not empty and the starting node is excluded by !withan and/or
# tgonly, then if steps == 0 it's not output otherwise the first step will be
# to a non-excluded (by !withan || tgonly) node.  Otherwise a single "step" is
# always from an included node to an included node.  This allows starting from
# an annihilated or non-tgish node and navigating to a non-annihilated tgish
# node, for example.  And then possibly continuing to step further.
#
# if pruneb is non-empty after splitting a loop check will be forced and then
# items are taken as positive refs (unless they are prefixed with "^") until
# a sole "^" which flips state so unprefixed refs are takes as negative (unless
# they are prefixed with "^") and so on -- very much like git rev-list except
# that an isolated "^" takes the place of "--not".  However, if there are no
# positive refs found then all nodes in the input start out as positive.
# Then any positive refs are walked including all reachable nodes then any
# negative refs are walked excluding those so negative refs always trump
# positive refs just like git rev-list does; anything left over and not
# included acts like it was never there in the first place -- can't be visited
# or traversed
#
# if startb contains more than one branch name, the requested operation is
# performed for each one and the results combined in that order, but there will
# be no way to distinguish where the boundary between results for the different
# branches lies in the output, but since sometimes that doesn't matter it's a
# helpful mode to have.  Note that duplicate output is suppressed so, for
# example, using startb="a a" will always produce exactly the same output as
# just startb="a".
#
# if steps is 0 and startb is empty it's an error otherwise startb just gets
# dumped right back out unless it's been excluded (and no loop checking is
# performed in that case either unless chklps is true) on one line together
# with the containing head(s); this provides "contains" functionality and is an
# obvious special case of the general navigation described below
#
# if startb is empty then one step forward (!rev) moves to all the roots or
# "starting" nodes whereas one step backwards (rev) moves to all the heads or
# "ending" nodes; so an empty startb with a negative steps (all the way) and a
# forward (!rev) direction starts at the roots and moves to the heads resulting
# in the same thing as one step in the backwards direction from the empty node
# and vice-versa for an empty startb with negative steps and backwards (rev)
# direction; the two single step cases (empty startb and steps == 1) are
# recognized and converted to the equivalent -1 steps version automatically as
# both of the -1 steps versions are optimized and do NOT walk the graph nor
# cause loop checking (unless check chklps is true) and they also only output
# one field on each output line (the head or root) rather than two
#
# with all but the two special cases just mentioned, loop detection is
# performed first to avoid problems and will cause an exit status of EX_DATAERR
# (65) if loops are detected in which case no output is produced; the
# recommended way to check for loops is with an empty startb, steps=-1 and
# chklps=1 and redirecting output to /dev/null (or capturing the heads output
# on success) and then testing the exit status for an EX_DATAERR (65) result
#
# the effect of "navigation" is as though the heads containing startb are first
# determined (by walking "forward" as far as possible) then those heads are
# enumerated in postfix order (each node is only visited once though -- the
# first time it's encountered in the enumeration) forming one or more linear
# lists (this step is not possible if loops are present hence the loop
# detection check).  Then the requested number of steps are taken from the
# location startb appears in each list and the possibly none, possibly many
# results are output one per line like so:
#
#   <result_branch_name> <containing_topgit_head_branch_name>...
#
# there will always be at least one containing branch name even if it's the
# same as the result branch name (unless startb is empty and steps is negative
# or 1), but there could be more (space separated) if the branch is part of
# more than one patch series; if fldone is true then only the first field shown
# above (the result branch name) will be output on each line no matter what
#

BEGIN { exitcode = ""; stderr = "exec cat>&2"; }
function exitnow(e) { exitcode=e; exit e }
END { if (exitcode != "") exit exitcode }

BEGIN {
	if (steps !~ /^-?[0-9]+$/) exitnow(2)
	steps = 0 + steps
	startcnt = 0
	cnt = split(startb, ascratch, " ")
	for (i = 1; i <= cnt; ++i) {
		if (!(ascratch[i] in seen)) {
			starts[++startcnt] = ascratch[i]
			seen[ascratch[i]] = 1
		}
	}
	if (!steps && !startcnt) exitnow(2)
	if (!startcnt && steps == 1) {
		rev = !rev
		steps = -1
	}
	if (steps < 0) steps = -1
	inconly = 0
	cnt = split(inclbr, scratch, " ")
	if (cnt) {
		inconly = 1
		for (i = 1; i <= cnt; ++i) incnames[scratch[i]] = 1
	}
	cnt = split(exclbr, scratch, " ")
	for (i = 1; i <= cnt; ++i) excnames[scratch[i]] = 1
	prunecnt = split(pruneb, prunes, " ")
	nots = 0
	for (node in prunes) if (node == "^") ++nots
	if (nots >= prunecnt) prunecnt = 0
	ordidx = 0
}

function quotevar(v) {
	gsub(/\047/, "\047\\\047\047", v)
	return "\047" v "\047"
}

function rmfiles() {
	rmlist = ""
	if (rmbr && brfile != "") rmlist = rmlist " " quotevar(brfile)
	if (rman && anfile != "") rmlist = rmlist " " quotevar(anfile)
	if (rmlist != "") {
		system("rm -f" rmlist)
		rmbr = 0
		brfile = ""
		rman = 0
		anfile = ""
	}
}
END { rmfiles() }

function init(abranch, _e) {
	if (brfile != "") {
		if (tgonly) {
			while ((_e = (getline abranch <brfile)) > 0) {
				if (abranch != "") tgish[abranch] = 1
			}
			close(brfile)
			if (_e < 0) exitnow(2)
		}
	}
	if (anfile != "") {
		while ((_e = (getline abranch <anfile)) > 0) {
			if (abranch != "") ann[abranch] = 1
		}
		close(anfile)
		if (_e < 0) exitnow(2)
	}
	rmfiles()
}

function included(abranch) {
	return (!inconly || incnames[abranch]) && !excnames[abranch]
}

function wanted(abranch) {
	return (withan || !(abranch in ann)) && (!tgonly || (abranch in tgish))
}

NR == 1 {init()}

function addlink(anarray, anode, alink, _linkstr) {
	if (alink == "") return
	_linkstr = anarray[anode]
	if (length(_linkstr) < 3) {
		_linkstr = " " alink " "
	} else if (!index(_linkstr, " " alink " ")) {
		_linkstr = _linkstr alink " "
	}
	anarray[anode] = _linkstr
}

NF == 2 && $1 != "" && $2 != "" {
	isexcl = 2
	if (included($2)) {
		if (!($2 in nodes)) {
			nodes[$2] = 1
			ordered[++ordidx] = $2
		}
		--isexcl
	}
	if (included($1)) {
		if (!($1 in nodes)) {
			nodes[$1] = 1
			ordered[++ordidx] = $1
		}
		--isexcl
	}
	if (!isexcl && $1 != $2 && !($1 in ann)) {
		addlink(incoming, $2, $1)
		addlink(outgoing, $1, $2)
		edgenodes[$1] = 1
		edgenodes[$2] = 1
	}
}

function checkloops() {
	for (edge in incoming) curinc[edge] = incoming[edge]
	for (node in edgenodes) if (!(node in curinc)) curnodes[node] = 1
	for (;;) {
		node = ""
		for (node in curnodes) break
		if (node == "") break
		delete curnodes[node]
		if ((node in outgoing) && split(outgoing[node], links, " ")) {
			for (linki in links) {
				link = links[linki]
				if (link in curinc) {
					inclist = curinc[link]
					if ((idx = index(inclist, " " node " "))) {
						inclist = substr(inclist, 1, idx) \
							substr(inclist,
							       idx + length(node) + 2)
						if (length(inclist) < 3) {
							delete curinc[link]
							curnodes[link] = 1
						} else {
							curinc[link] = inclist
						}
					}
				}
			}
		}
		delete edgenodes[node]
	}
	for (node in edgenodes) exitnow(65)
}

function collectstarts(anarray, _i) {
	for (_i = 1; _i <= ordidx; ++_i) {
		if ((ordered[_i] in nodes) && !(ordered[_i] in anarray))
			starts[++startcnt] = ordered[_i]
	}
}

function marknodes(anode, val, _outlinks, _oneout) {
	if (!(anode in nodes)) return
	if (nodes[anode] == val) return
	nodes[anode] = val
	if (anode in outgoing) {
		split(outgoing[anode], _outlinks, " ")
		for (_oneout in _outlinks) marknodes(_outlinks[_oneout], val)
	}
}

function getheads_(anode, theheads, seen, headcnt, _cnt, _i, _inlinks) {
	if (!(anode in nodes)) return
	if (!(anode in incoming)) {
		if (!(anode in seen)) {
			seen[anode] = 1
			theheads[++headcnt[0]] = anode
		}
		return
	}
	_cnt = split(incoming[anode], _inlinks, " ")
	for (_i = 1; _i <= _cnt; ++_i)
		getheads_(_inlinks[_i], theheads, seen, headcnt)
}

function getheads(anode, theheads, _seen, _headcnt) {
	split("", theheads, " ")
	split("", _seen, " ")
	_headcnt[0] = 0
	getheads_(anode, theheads, _seen, _headcnt)
	return _headcnt[0]
}

function getpath_(anode, pnodes, arlinks, _seen, _pcnt, _children, _ccnt, _i) {
	if (anode in _seen) return
	_seen[anode] = 1
	if (anode in arlinks) {
		_ccnt = split(arlinks[anode], _children, " ")
		for (_i = 1; _i <= _ccnt; ++_i)
			getpath_(_children[_i], pnodes, arlinks, _seen, _pcnt)
	}
	pnodes[++_pcnt[0]] = anode
}

function getpath(anode, pnodes, arlinks, _seen, _pcnt, _z) {
	split("", pnodes, " ");
	split("", _seen, " ")
	_pcnt[0] = 0
	getpath_(anode, pnodes, arlinks, _seen, _pcnt)
	return _pcnt[0]
	printf "%s", "PATH " anode " |"
	for (_z = 1; _z <= _pcnt[0]; ++_z) printf " %s" pnodes[_z]
	printf "\n"
}

END {
	if (chklps || startcnt || prunecnt || steps >= 0) checkloops()
	if (prunecnt) {
		state = 1
		for (i = 1; i <= prunecnt; ++ i) {
			onep = prunes[i]
			if (onep == "^") {
				state = 1 - state
				continue
			}
			if (substr(onep, 1, 1) == "^") {
				if (state) negnodes[substr(onep, 2)] = 1
				else poznodes[substr(onep, 2)] = 1
			} else {
				if (state) poznodes[onep] = 1
				else negnodes[onep] = 1
			}
		}
		for (onep in poznodes) {
			for (anode in nodes) nodes[anode] = ""
			break
		}
		for (onep in poznodes) marknodes(onep, 1)
		for (onep in negnodes) {
			marknodes(onep, 0)
			if (onep in incoming && split(incoming[onep], links, " ")) {
				for (linki in links) {
					link = links[linki]
					if (link in outgoing) {
						outlist = outgoing[link]
						if ((idx = index(outlist, " " onep " "))) {
							outlist = substr(outlist, 1, idx) \
								substr(outlist,
								       idx + length(onep) + 2)
							if (length(outlist) < 3)
								delete outgoing[link]
							else
								outgoing[link] = outlist
						}
					}
				}
			}
		}
		for (onep in nodes) if (!nodes[onep]) delete nodes[onep]
	}
	if (!startcnt) {
		if ((steps < 0 && !rev) || (steps > 0 && rev))
			collectstarts(incoming)
		else if ((steps < 0 && rev) || (steps > 0 && !rev))
			collectstarts(outgoing)
		if (steps < 0 || !startcnt) {
			for (i = 1; i <= startcnt; ++i)
				if (wanted(starts[i])) print starts[i]
			exit 0
		}
	}
	resultcnt = 0
	for (i = 1; i <= startcnt; ++i) {
		headcnt = getheads(starts[i], heads)
		for (j = 1; j <= headcnt; ++j) {
			pathcnt = getpath(heads[j], path, outgoing)
			for (pathidx = 1; pathidx <= pathcnt; ++pathidx)
				if (path[pathidx] == starts[i]) break
			if (pathidx > pathcnt) continue
			adjsteps = steps
			if (!wanted(path[pathidx])) {
				if (!steps) continue
				if (steps > 0) --adjsteps
				incr = rev ? -1 : 1
				do pathidx += incr
				while (pathidx >= 1 && pathidx <= pathcnt &&
					!wanted(path[pathidx]))
			}
			if (pathidx >= 1 && pathidx <= pathcnt) {
				oldcnt = pathcnt
				newstart = path[pathidx]
				pathidx = 0
				pathcnt = 0
				for (k = 1; k <= oldcnt; ++k) {
					if (wanted(path[k])) {
						path[++pathcnt] = path[k]
						if (!pathidx && path[pathcnt] == newstart)
							pathidx = pathcnt
					}
				}
				if (!pathidx) {
					print "internal error: wanted disappeared" |stderr
					exitnow(70) # EX_SOFTWARE
				}
			}
			if (steps < 0) {
				pathidx = rev ? 1 : pathcnt
			} else {
				if (rev) pathidx -= adjsteps
				else pathidx += adjsteps
			}
			if (pin) {
				if (pathidx < 1) pathidx = 1
				else if (pathidx > pathcnt) pathidx = pathcnt
			}
			if (pathidx < 1 || pathidx > pathcnt) continue
			aresult = path[pathidx]
			if (aresult in seenresults) {
				resultidx = seenresults[aresult]
				resultlist = results[resultidx]
			} else {
				resultidx = ++resultcnt
				resultnames[resultidx] = aresult
				seenresults[aresult] = resultidx
				resultlist = " "
			}
			if (!index(resultlist, " " heads[j] " ")) {
				resultlist = resultlist heads[j] " "
				results[resultidx] = resultlist
			}
		}
	}
	for (i = 1; i <= resultcnt; ++i) {
		if (fldone) print resultnames[i]
		else print resultnames[i] substr(results[i], 1, length(results[i]) - 1)
	}
}
