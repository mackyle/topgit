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

# common defines for all makefile(s)
defines() {
	POUND="#"

	# Update if you add any code that requires a newer version of git
	: "${GIT_MINIMUM_VERSION:=1.9.0}"

	# This avoids having this in no less than three different places!
	TG_STATUS_HELP_USAGE="st[atus] [-v] [--exit-code]"

	# These are initialized here so config.sh or config.mak can change them
	# They are deliberately left with '$(...)' constructs for make to expand
	# so that if config.mak just sets prefix they all automatically change
	[ -n "$prefix"   ] || prefix="$HOME"
	[ -n "$bindir"   ] || bindir='$(prefix)/bin'
	[ -n "$cmddir"   ] || cmddir='$(prefix)/libexec/topgit'
	[ -n "$sharedir" ] || sharedir='$(prefix)/share/topgit'
	[ -n "$hooksdir" ] || hooksdir='$(cmddir)/hooks'
}

# wrap it up for safe returns
# "$@" is the current build target(s), if any
makefile() {

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
	write_auto_deps '' '.awk' $awk_out
} >"$DEPFILE"

: "${SHELL_PATH:=/bin/sh}" "${AWK_PATH:=awk}"
version="$(
	test -d .git && git describe --match "topgit-[0-9]*" --abbrev=4 --dirty 2>/dev/null |
	sed -e 's/^topgit-//')" || :

# config.sh is wrapped up for return safety
configsh

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

[ -z "$MAKEFILESH_DEBUG" ] || {
	printenv | LC_ALL=C grep '^[_A-Za-z][_A-Za-z0-9]*=' | LC_ALL=C sort
} >"Makefile.var"

# Force TG-BUILD-SETTINGS to be updated now if needed
${MAKE:-make} ${GNO_PD_OPT} -e -f Makefile.mak FORCE_SETTINGS_BUILD=FORCE TG-BUILD-SETTINGS

# end of wrapper
}

##
## Run "makefile" now unless MKTOP is set
##

set -ea
defines
test -n "$MKTOP" || {
	. ./gnomake.sh &&
	set_gno_pd_opt &&
	makefile "$@"
}
