# gnomake.sh - POSIX Makefile.sh utility functions
# Copyright (C) 2017 Kyle J. McKay
# All rights reserved
# License GPL2

##
## Utility functions for Makefile.sh scripts
##

# prevent crazy "sh" implementations from exporting functions into environment
set +a

# always run in errexit mode
set -e

# configsh sources config.sh if it exists and then sets
# CONFIGMAK to either Makefile.mt (if there is no config.mak)
# or "config.mak" if there is.
#
# If MKTOP is set, they are looked for there instead of in
# the current directory.
#
# The CONFIGDEPS variable will be set to the ones that exist
# (for use in dependency lines).
#
# wrap it up for safety
configsh() {
	[ z"$MKTOP" = z"/" ] || MKTOP="${MKTOP%/}"
	CONFIGDEPS=
	! [ -f "${MKTOP:+$MKTOP/}config.sh" ] || {
		. ./"${MKTOP:+$MKTOP/}config.sh"
		CONFIGDEPS="${CONFIGDEPS:+$CONFIGDEPS }${MKTOP:+$MKTOP/}config.sh"
	}
	# now set CONFIGMAK and make it an absolute path
	[ -n "$CONFIGMAK" ] || CONFIGMAK="${MKTOP:+$MKTOP/}config.mak"
	if [ -f "$CONFIGMAK" ]; then
		CONFIGDEPS="${CONFIGDEPS:+$CONFIGDEPS }$CONFIGMAK"
	else
		CONFIGMAK="${MKTOP:+$MKTOP/}Makefile.mt"
	fi
	case "$CONFIGMAK" in */?*);;*) CONFIGMAK="./$CONFIGMAK"; esac
	CONFIGMAK="$(cd "${CONFIGMAK%/*}" && pwd)/${CONFIGMAK##*/}"
}

# "which" but using only POSIX shell built-ins
cmd_path() (
        { "unset" -f command unset unalias "$1"; } >/dev/null 2>&1 || :
        { "unalias" -a || unalias -m "*"; } >/dev/null 2>&1 || :
        command -v "$1"
)

# set GNO_PD_OPT to --no-print-directory
#  - unless GNO_PD_OPT is already set (even if to empty)
#  - unless "w" appears in MAKEFLAGS (check skipped if first arg is not-empty)
#  - the $(MAKE) binary does NOT contain GNUmakefile
#  - the $(MAKE) binary does NOT produce a "GNU Make ..." --version line
set_gno_pd_opt() {
	if test z"$GNO_PD_OPT" = z"--no-print-directory"; then
		# It likes to sneak back in so rip it back out
		case "$MAKEFLAGS" in "w"*)
			MAKEFLAGS="${MAKEFLAGS#w}"
		esac
		return 0
	fi
	test z"${GNO_PD_OPT+set}" != z"set" || return 0
	GNO_PD_OPT=
	if test z"$1" = z; then
		case "${MAKEFLAGS%%[ =]*}" in *w*)
			return 0
		esac
	fi
	set -- "$("${MAKE:-make}" --no-print-directory --version 2>/dev/null)" || :
	case "$1" in "GNU "[Mm]"ake "*)
		GNO_PD_OPT="--no-print-directory"
	esac
	return 0
}

# VAR += VAL
# => vplus VAR VAL
#
# vplus appends the second and following arguments (concatenated with a space)
# to the variable named by the first with a space if it's set and non-empty
# or otherwise it's just set.  If there are no arguments nothing is done but
# appending an empty string will set the variable to empty if it's not set
vplus() {
	test z"$1" != z || return 1
	test $# -ge 2 || return 0
	vplus_v_="$1"
	shift
	vplus_val_="$*"
	set -- "$vplus_v_" "" "$vplus_val_"
	unset vplus_v_ vplus_val_
	eval set -- '"$1"' "\"\$$1\"" '"$3"'
	set -- "$1" "${2:+$2 }$3"
	eval "$1="'"$2"'
}

# vpre prepends the second and following arguments (concatenated with a space)
# to the variable named by the first with a space if it's set and non-empty
# or otherwise it's just set.  If there are no arguments nothing is done but
# appending an empty string will set the variable to empty if it's not set
vpre() {
	test z"$1" != z || return 1
	test $# -ge 2 || return 0
	vpre_v_="$1"
	shift
	vpre_val_="$*"
	set -- "$vpre_v_" "" "$vpre_val_"
	unset vpre_v_ vpre_val_
	eval set -- '"$1"' "\"\$$1\"" '"$3"'
	set -- "$1" "$3${2:+ $2}"
	eval "$1="'"$2"'
}

# stores the single-quoted value of the variable name passed as
# the first argument into the variable name passed as the second
# (use quotevar 3 varname "$value" to quote a value directly)
quotevar() {
	eval "set -- \"\${$1}\" \"$2\""
	case "$1" in *"'"*)
		set -- "$(printf '%s\nZ\n' "$1" | sed "s/'/'\\\''/g")" "$2"
		set -- "${1%??}" "$2"
	esac
	eval "$2=\"'$1'\""
}

# The result(s) of stripping the second argument from the end of the
# third and following argument(s) is joined using a space and stored
# in the variable named by the first argument
v_strip_sfx() {
	_var="$1"
	_sfx="$2"
	shift 2
	_result=
	for _item in "$@"; do
		_result="$_result ${_item%$_sfx}"
	done
	eval "$_var="'"${_result# }"'
	unset _var _sfx _result _item
}

# The result(s) of appending the second argument to the end of the
# third and following argument(s) is joined using a space and stored
# in the variable named by the first argument
v_add_sfx() {
	_var="$1"
	_sfx="$2"
	shift 2
	_result=
	for _item in "$@"; do
		_result="$_result $_item$_sfx"
	done
	eval "$_var="'"${_result# }"'
	unset _var _sfx _result _item
}

# The result(s) of stripping the second argument from the end of the
# fourth and following argument(s) and then appending the third argument is
# joined using a space and stored in the variable named by the first argument
v_stripadd_sfx() {
	_var2="$1"
	_stripsfx="$2"
	_addsfx="$3"
	shift 3
	v_strip_sfx _result2 "$_stripsfx" "$@"
	v_add_sfx "$_var2" "$_addsfx" $_result2
	unset _var2 _stripsfx _addsfx _result2
}

# The second and following argument(s) are joined with a space and
# stored in the variable named by the first argument
v_strip_() {
	_var="$1"
	shift
	eval "$_var="'"$*"'
	unset _var
}

# The second and following argument(s) are joined with a space and then
# the result has leading and trailing whitespace removed and internal
# whitespace sequences replaced with a single space and is then stored
# in the variable named by the first argument and pathname expansion is
# disabled during the stripping process
v_strip() {
	_var="$1"
	shift
	set -f
	v_strip_ "$_var" $*
	set +f
}

# Expand the second and following argument(s) using pathname expansion but
# skipping any that have no match and join all the results using a space and
# store that in the variable named by the first argument
v_wildcard() {
	_var="$1"
	shift
	_result=
	for _item in "$@"; do
		eval "_exp=\"\$(printf ' %s' $_item)\""
		[ " $_item" = "$_exp" ] && ! [ -e "$_item" ] || _result="$_result$_exp"
	done
	eval "$_var="'"${_result# }"'
	unset _var _result _item _exp
}

# Sort the second and following argument(s) removing duplicates and join all the
# results using a space and store that in the variable named by the first argument
v_sort() {
	_var="$1"
	_saveifs="$IFS"
	shift
	IFS='
'
	set -- $(printf '%s\n' "$@" | LC_ALL=C sort -u)
	IFS="$_saveifs"
	eval "$_var="'"$*"'
	unset _var _saveifs
}

# Filter the fourth and following argument(s) according to the space-separated
# list of '%' pattern(s) in the third argument doing a "filter-out" instead of
# a "filter" if the second argument is true and join all the results using a
# space and store that in the variable named by the first argument
v_filter_() {
	_var="$1"
	_fo="$2"
	_pat="$3"
	_saveifs="$IFS"
	shift 3
	IFS='
'
	set -- $(awk -v "fo=$_fo" -f - "$_pat" "$*"<<'EOT'
function qr(p) {
	gsub(/[][*?+.|{}()^$\\]/, "\\\\&", p)
	return p
}
function qp(p) {
	if (match(p, /\\*%/)) {
		return qr(substr(p, 1, RSTART - 1)) \
			substr(p, RSTART, RLENGTH - (2 - RLENGTH % 2)) \
			(RLENGTH % 2 ? ".*" : "%") \
			qr(substr(p, RSTART + RLENGTH))
	}
	else
		return qr(p)
}
function qm(s, _l, _c, _a, _i, _g) {
	if (!(_c = split(s, _l, " "))) return "^$"
	if (_c == 1) return "^" qp(_l[1]) "$"
	_a = ""
	_g = "^("
	for (_i = 1; _i <= _c; ++_i) {
		_a = _a _g qp(_l[_i])
		_g = "|"
	}
	return _a ")$"
}
BEGIN {exit}
END {
	pat = ARGV[1]
	vals = ARGV[2]
	qpat = qm(pat)
	cnt = split(vals, va, " ")
	for (i=1; i<=cnt; ++i)
		if ((va[i] ~ qpat) == !fo) print va[i]
}
EOT
	)
	IFS="$_saveifs"
	eval "$_var="'"$*"'
	unset _var _fo _pat _saveifs
}

# Filter the third and following argument(s) according to the space-separated
# list of '%' pattern(s) in the second argument and join all the results using
# a space and store that in the variable named by the first argument
v_filter() {
	_var="$1"
	shift
	v_filter_ "$_var" "" "$@"
}

# Filter out the third and following argument(s) according to the space-separated
# list of '%' pattern(s) in the second argument and join all the results using
# a space and store that in the variable named by the first argument
v_filter_out() {
	_var="$1"
	shift
	v_filter_ "$_var" "1" "$@"
}

# Write the third and following target arguments out as target with a dependency
# line(s) to standard output where each line is created by stripping the target
# argument suffix specified by the first argument ('' to strip nothing) and
# adding the suffix specified by the second argument ('' to add nothing).
# Does nothing if "$1" = "$2".  (Set $1 = " " and $2 = "" to write out
# dependency lines with no prerequisites.)
write_auto_deps() {
	[ "$1" != "$2" ] || return 0
	_strip="$1"
	_add="$2"
	shift 2
	for _targ in "$@"; do
		printf '%s: %s\n' "$_targ" "${_targ%$_strip}$_add"
	done
	unset _strip _add _targ
}

# always turn on allexport now
set -a
