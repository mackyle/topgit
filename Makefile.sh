# Makefile.sh - POSIX Makefile scripting adjunct for TopGit
# Copyright (C) 2017 Kyle J. McKay
# All rights reserved
# License GPL2

# Set MAKEFILESH_DEBUG to get:
#  1. All defined environment variales saved to Makefile.var
#  2. set -x
#  3. set -v if MAKEFILESH_DEBUG contains "v"

if [ -n "$MAKEFILESH_DEBUG" ]; then
	_setcmd="set -x"
	case "$MAKEFILESH_DEBUG" in *"v"*) _setcmd="set -vx"; esac
	eval "$_setcmd && unset _setcmd"
fi

# prevent crazy "sh" implementations from exporting functions into environment
set +a

# wrap it up for safe returns
# $1 is the current build target, if any
makefile() {

POUND="#"

# Update if you add any code that requires a newer version of git
: "${GIT_MINIMUM_VERSION:=1.8.5}"

# This avoids having this in no less than three different places!
TG_STATUS_HELP_USAGE="st[atus] [-v] [--exit-code]"

# These are initialized here so config.sh or config.mak can change them
# They are deliberately left with '$(...)' constructs for make to expand
# so that if config.mak just sets prefix they all automatically change
[ -n "$prefix"   ] || prefix="$HOME"
[ -n "$bindir"   ] || bindir='$(prefix)/bin'
[ -n "$cmddir"   ] || cmddir='$(prefix)/libexec/topgit'
[ -n "$sharedir" ] || sharedir='$(prefix)/share/topgit'
[ -n "$hooksdir" ] || hooksdir='$(prefix)/hooks'

v_wildcard commands_in 'tg-[!-]*.sh'
v_wildcard utils_in    'tg--*.sh'
v_wildcard awk_in      'awk/*.awk'
v_wildcard hooks_in    'hooks/*.sh'
v_wildcard helpers_in  't/helper/*.sh'

v_strip_sfx commands_out .sh  $commands_in
v_strip_sfx utils_out    .sh  $utils_in
v_strip_sfx awk_out      .awk $awk_in
v_strip_sfx hooks_out    .sh  $hooks_in
v_strip_sfx helpers_out  .sh  $helpers_in

v_stripadd_sfx help_out .sh .txt  tg-help.sh tg-status.sh $commands_in
v_stripadd_sfx html_out .sh .html tg-help.sh tg-status.sh tg-tg.sh $commands_in

DEPFILE="Makefile.dep"
{
	write_auto_deps '' '.sh' tg $commands_out $utils_out $hooks_out $helpers_out
} >"$DEPFILE"

: "${SHELL_PATH:=/bin/sh}" "${AWK_PATH:=awk}"
version="$(
	test -d .git && git describe --match "topgit-[0-9]*" --abbrev=4 --dirty 2>/dev/null |
	sed -e 's/^topgit-//')" || :

# config.sh is wrapped up for return safety
configsh

[ -n "$CONFIGMAK" ] || CONFIGMAK="config.mak"
[ -f "$CONFIGMAK" ] || CONFIGMAK="Makefile.mt"

# config.sh may not unset these
: "${SHELL_PATH:=/bin/sh}" "${AWK_PATH:=awk}"

case "$AWK_PATH" in */*) AWK_PREFIX=;; *) AWK_PREFIX="/usr/bin/"; esac
quotevar SHELL_PATH SHELL_PATH_SQ
quotevar AWK_PATH AWK_PATH_SQ

v_strip version "$version"
version_arg=
[ -z "$version" ] || version_arg="-e 's/TG_VERSION=.*/TG_VERSION=\"$version\"/'"

DESTDIRBOOL="No"
[ -z "$DESTDIR" ] || DESTDIRBOOL="Yes"

# the "t/" subdirectory still needs gmake
[ -n "$GMAKE" ] || GMAKE="$(cmd_path "gmake")" || :	# most common
[ -n "$GMAKE" ] || GMAKE="$(cmd_path "gnumake")" || :	# sometimes
[ -n "$GMAKE" ] || GMAKE='$(MAKE)' || :			# perhaps

[ -z "$MAKEFILESH_DEBUG" ] || {
	(unset BUILD_SETTINGS && printenv) | LC_ALL=C grep '^[_A-Za-z][_A-Za-z0-9]*=' | LC_ALL=C sort
	echo "---- BUILD_SETTINGS VALUE ----"
	printenv "BUILD_SETTINGS"
} >"Makefile.var"

# Force TG-BUILD-SETTINGS to be updated now if needed
${MAKE:-make} -f Makefile.mak FORCE_SETTINGS_BUILD=FORCE TG-BUILD-SETTINGS

# end of wrapper
}

##
## Utility Functions
##

# wrap it up for safety
configsh() {
	[ -f "config.sh" ] || return 0
	. ./"config.sh"
}

cmd_path() (
        { "unset" -f command unset unalias "$1"; } >/dev/null 2>&1 || :
        { "unalias" -a; } >/dev/null 2>&1 || :
        command -v "$1"
)

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

##
## Run "makefile" now
##

set -ea
makefile "$@"
