#!/usr/bin/awk -f

# ref_match - TopGit awk utility script used by tg--awksome
# Copyright (C) 2017 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved.
# License GPLv2

# ref_match
#
#  pckdrefs  input refs are in packed-refs format
#  patterns  whitespace-separated for-each-ref style patterns to match
#  matchfmt  a for-each-ref format string (limited, see below)
#  sortkey   optional "[-]<key>" or "[-]<key>,[-]<key>" (see below)
#  maxout    stop after no more matches than this
#
# input is a list of "<ref> <hash>" per line (or packed-refs style if
# pckdrefs is true) if there are multiple entries for the same ref name
# only one wins (which exactly is indeterminate since the sort is unstable)
#
# hash values are always converted to lowercase
#
# output is each matching ref shown using the output matchfmt format whcih
# is a limited form of the for-each-ref format in that the default is similar
# to for-each-ref and only fields "%(refname)" and "%(objectname)" are
# supported along with "%%" and "%xx" EXCEPT "%00" (it will try don't expect
# it to work though) any other % sequence will pass through unchanged
#
# here is the actual format string (as a --format argument) used by default:
#
#   --format="%(objectname) object%09%(refname)"
#
# while this is similar the for-each-ref default it uses "object" for the object
# type since one is not available and, in fact, %(objecttype) will indeed also
# be replaced with "object"
#
# output will be sorted by "refname" by default (it's always sorted somehow)
# and for the two-key form, the LAST key is the primary key; if the leading
# "-" is present it's a descending sort instead of ascending; only "objectname"
# and "refname" keys are supported (obviously)
#
# This one was supposed to be just a simple quick little thing *sigh*
#

function arrayswp(anarray, i1, i2, _swapper) {
	_swapper = anarray[i1]
	anarray[i1] = anarray[i2]
	anarray[i2] = _swapper
	if (!multisort) return # ** cough **
	_swapper = hashes[i1]
	hashes[i1] = hashes[i2]
	hashes[i2] = _swapper
}

function kasort_order3(anarray, i1, i2, i3, _c12, _c13, _c23) {
	_c12 = cmpkeys(anarray, i1, i2)
	_c23 = cmpkeys(anarray, i2, i3)
	if (_c12 <= 0) {
		if (_c23 <= 0) return (!_c12 || !_c23) ? -1 : 0
		if (_c12 == 0) {
			arrayswp(anarray, i1, i3)
			return -1
		}
	} else if (_c23 >= 0) {
		arrayswp(anarray, i1, i3)
		return _c23 ? 0 : -1
	}
	_c13 = cmpkeys(anarray, i1, i3)
	if (_c13 > 0) arrayswp(anarray, i1, i3)
	if (_c12 <= 0) arrayswp(anarray, i2, i3)
	else arrayswp(anarray, i1, i2)
	return 0
}

# Could "ka" mean, oh I don't know, perhaps one of these?  ;)
#   Kyle's Awesome alternativve to the low iQ sort
#   Kick Ass sort
#   Kyle's Array sort
#
function kasort_partition(anarray, si, ei, _mi, _le, _ge, _o3) {
	if (ei <= si) return
	if (si + 1 == ei) {
		if (cmpkeys(anarray, si, ei) > 0)
			arrayswp(anarray, si, ei)
		return
	}
	_mi = int((si + ei) / 2)
	_o3 = kasort_order3(anarray, si, _mi, ei)
	if (si + 2 == ei) return
	_le = si
	_ge = ei
	for (;;) {
		if (_le < _mi)
			while (++_le < _ge && _le != _mi && cmpkeys(anarray, _le, _mi) <= _o3) ;
		if (_le < _ge)
			while (_mi < _ge && _le < --_ge && cmpkeys(anarray, _mi, _ge) <= _o3) ;
		if (_le < _ge && _ge <= _mi)
			while (_le < --_ge && cmpkeys(anarray, _mi, _ge) < 0) ;
		if (_mi <= _le && _le < _ge)
			while (++_le < _ge && cmpkeys(anarray, _le, _mi) < 0) ;
		if (_le < _ge) {
			arrayswp(anarray, _le, _ge)
			continue
		}
		if (_le < _mi) {
			arrayswp(anarray, _le, _mi)
			_mi = _le
		} else if (_mi < _ge) {
			arrayswp(anarray, _mi, _ge)
			_mi = _ge
		}
		kasort_partition(anarray, si, _mi - 1)
		kasort_partition(anarray, _mi + 1, ei)
		return
	}
}

function getpatarr(patstr,
	_p, _pi, _pc, _sa1, _c2, _sa2, _lpat, _llen, _i) {

	split(patstr, _sa1, " ")
	_c2 = 0
	for (_pi in _sa1) {
		_p = _sa1[_pi]
		if (_p !~ /^refs\/./) continue
		if (_p !~ /\/$/) _p = _p "/"
		_sa2[++_c2] = _p
	}
	_pc = 0
	if (_c2 > 1) {
		kasort_partition(_sa2, 1, _c2)
		_lpat = _sa2[1]
		_llen = length(_lpat)
		patarr[++_pc] = _lpat
		for (_i = 2; _i <= _c2; ++_i) {
			_p = _sa2[_i]
			if (length(_p) >= _llen && _lpat == substr(_p, 1, _llen))
				continue
			patarr[++_pc] = _p
			_lpat = _p
			_llen = length(_lpat)
		}
	} else if (!_c2) {
		patarr[++_pc] = "refs/"
	} else {
		patarr[++_pc] = _sa2[1]
	}
	patarr[_pc + 1] = "zend"
	return _pc
}

BEGIN {
	multisort = 0
	dosortobj = 0
	cnt = 0
	sortobj = 0
	sortref = 0
	patcnt = getpatarr(patterns)
	for (i = split(tolower(sortkey), keys, /[, \t\r\n]+/); i >= 1; --i) {
		if (keys[i] == "refname") {
			sortref = 1
			break
		} else if (keys[i] == "-refname") {
			sortref = -1
			break
		}
		if (sortobj == 0 && keys[i] == "objectname") sortobj = 1
		if (sortobj == 0 && keys[i] == "-objectname") sortobj = -1
	}
	if (!sortref) sortref = 1
	if (matchfmt == "") matchfmt = "%(objectname) %(objecttype)%09%(refname)"
	fc = split(matchfmt, fmts, /%(%|[0-9a-fA-F]{2})/)
	fi = 1
	theformat = fmts[fi]
	fpos = length(theformat) + 1
	while (fpos <= length(matchfmt)) {
		pct = tolower(substr(matchfmt, fpos, 3))
		if (substr(pct, 1, 2) == "%%") {
			theformat = theformat "%"
			fpos += 2
		} else {
			hexval = (index("0123456789abcdef", substr(pct, 2, 1)) - 1) * 16
			hexval += index("0123456789abcdef", substr(pct, 3, 1)) - 1
			theformat = theformat sprintf("%c", hexval)
			fpos += 3
		}
		if (fi <= fc) {
			theformat = theformat fmts[++fi]
			fpos += length(fmts[fi])
		}
	}
}

pckdrefs && $2 ~ /^refs\/./ && $1 ~ /^[0-9A-Fa-f]{4,}$/ {
	r = $2
	sub(/\/+$/, "", r)
	refs[++cnt] = r "/"
	hashes[cnt] = tolower($1)
}

!pckdrefs && $1 ~ /^refs\/./ && $2 ~ /^[0-9A-Fa-f]{4,}$/ {
	r = $1
	sub(/\/+$/, "", r)
	refs[++cnt] = r "/"
	hashes[cnt] = tolower($2)
}

function cmpkeys(anarray, i1, i2, _k1, _k2, _ans) {
	_ans = 0
	if (dosortobj) { # ** cough **
		_k1 = hashes[i1]
		_k2 = hashes[i2]
		if (_k1 < _k2) _ans = -1
		else if (_k1 > _k2) _ans = 1
		if (sortobj < 0) _ans = 0 - _ans
	}
	if (!_ans) {
		_k1 = anarray[i1]
		_k2 = anarray[i2]
		if (_k1 < _k2) _ans = -1
		else if (_k1 > _k2) _ans = 1
		if (sortref < 0) _ans = 0 - _ans
	}
	return _ans
}

function formatline(rname, oname, _out) {
	_out = theformat
	gsub(/%\(objectname\)/, oname, _out)
	gsub(/%\(objecttype\)/, "object", _out)
	gsub(/%\(refname\)/, rname, _out)
	return _out
}

END {
	multisort = 1
	presortedbyrefonly = 0
	if (patcnt > 1 || patarr[1] != "refs/") {
		savesortref = sortref
		sortref = 1
		if (cnt > 1) kasort_partition(refs, 1, cnt)
		presortedbyrefonly = 1
		ji = 1
		ref = ""
		curpat = patarr[ji]
		for (i = 1; i <= cnt; ++i) {
			if (refs[i] == ref) {
				refs[i] = ""
				continue
			}
			ref = refs[i]
			if (ref < curpat) {
				refs[i] = ""
				continue
			}
			if (substr(ref, 1, length(curpat)) == curpat) continue
			while (patarr[++ji] < ref) ;
			curpat = patarr[ji]
			ref = ""
			--i
		}
		sortref = savesortref
	}
	dosortobj = sortobj
	if (cnt > 1 && (!presortedbyrefonly || sortobj || sortref < 0))
		kasort_partition(refs, 1, cnt)
	outcnt = 0
	for (i = 1; i <= cnt; ++i) {
		refname = refs[i]
		sub(/\/+$/, "", refname)
		if (refname == "") continue
		if (maxout > 0 && ++outcnt > maxout) exit 0
		objname = hashes[i]
		print formatline(refname, objname)
	}
}
