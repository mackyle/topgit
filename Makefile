# Makefile - POSIX Makefile for TopGit
# Copyright (C) 2017,2021 Kyle J. McKay
# All rights reserved
# License GPL2

#
## THIS IS NOT THE MAKEFILE YOU ARE LOOKING FOR!
##
## You likely want Makefile.mak (docs are in there)
##
## NOTE: Makefile.sh feeds variables into Makefile.mak
##       You might want to look there too
##
## Makefile drives the process
## Makefile.sh provides POSIX sh support
## Makefile.mak does the actual building
## Makefile.mt always exists and is always empty (i.e. zero length)
#

.POSIX:

# Anything explicitly listed here will always avoid a bogus "up to date" result
TARGETS = \
	all clean tg awk hooks helpers doc html \
	precheck TG-BUILD-SETTINGS settings \
	install install-doc install-html \
	tg--awksome tg-tg.txt topgit.html \
	shell_compatibility_test \
	bin-wrappers/tg bin-wrapper/pre-commit \
	test \
#TARGETS

Makefile/default: Makefile/phony
	+@set -- && set -ae && MAKE="$(MAKE)" && . ./Makefile.sh && $(MAKE) $${GNO_PD_OPT} -e -f Makefile.mak

.DEFAULT:
	+@set -- "$@" && set -ae && MAKE="$(MAKE)" && . ./Makefile.sh && $(MAKE) $${GNO_PD_OPT} -e -f Makefile.mak "$$@"

target: Makefile/phony
	+@set -- $(TARGET) && set -ae && MAKE="$(MAKE)" && . ./Makefile.sh && $(MAKE) $${GNO_PD_OPT} -e -f Makefile.mak "$$@"

Makefile/any $(TARGETS): Makefile/phony
	+@set -- "$@" && set -ae && MAKE="$(MAKE)" && . ./Makefile.sh && $(MAKE) $${GNO_PD_OPT} -e -f Makefile.mak "$$@"

# Very important rule to avoid "accidents" caused by Makefile.sh's existence
# Some ridiculous "make" implementations will always implicitly "make Makefile"
# even though .POSIX: has been specified and that's definitely NOT POSIX!
Makefile Makefile.mak Makefile.mt Makefile.dep Makefile.sh:
	-@true

.PRECIOUS:

# Clean out the standard six single suffix inference rules
# Except for .sh (because it would then elicit a redefiniton warning)
.SUFFIXES:
.SUFFIXES: .c .sh .f .c˜ .sh˜ .f˜
.c:;
.f:;
#.sh:;
.c~:;
.f~:;
.sh~:;
.SUFFIXES:
.SUFFIXES: .sh .awk .txt .html

# These are imperfect because they don't really reflect the correct dependencies
# Running the default "make" or "make all" will always get it right, but when
# trying to make a specific target, these will often avoid the "up to date"
# output that would otherwise occur for existing files with no dependencies
.sh:
	+@set -- "$@" && set -ae && MAKE="$(MAKE)" && . ./Makefile.sh && $(MAKE) $${GNO_PD_OPT} -e -f Makefile.mak "$$@"
.awk:
	+@set -- "$@" && set -ae && MAKE="$(MAKE)" && . ./Makefile.sh && $(MAKE) $${GNO_PD_OPT} -e -f Makefile.mak "$$@"
.sh.txt:
	+@set -- "$@" && set -ae && MAKE="$(MAKE)" && . ./Makefile.sh && $(MAKE) $${GNO_PD_OPT} -e -f Makefile.mak "$$@"
.sh.html:
	+@set -- "$@" && set -ae && MAKE="$(MAKE)" && . ./Makefile.sh && $(MAKE) $${GNO_PD_OPT} -e -f Makefile.mak "$$@"

# This "phony" target must have at least one command otherwise it will not
# actually run anything and so will not actually trigger the rules that depend
# on it to run either.  By using "true" instead of ":" "makes" that
# short-circuit directly to execvp should be able to run "true" directly.
Makefile/phony:
	-@true
