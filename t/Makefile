# Makefile - POSIX Makefile for TopGit tests
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
# ../Makefile.sh provides POSIX sh utility functions
# ../Makefile.mt always exists and is always empty (i.e. zero length)
#

.POSIX:

# Anything explicitly listed here will always avoid a bogus "up to date" result
TARGETS = \
	all prove test pre-clean clean post-clean-except-prove-cache post-clean \
	test-lint test-lint-duplicates test-lint-executable test-lint-shell-syntax \
	test-lint-filenames run-individual-tests aggregate-results-and-cleanup \
	aggregate-results TG-TEST-SETTINGS settings
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
Makefile Makefile.mak ../Makefile.mt ../Makefile.dep Makefile.sh:
	-@true

.PRECIOUS:

# Clean out the standard six single suffix inference rules
.SUFFIXES:
.SUFFIXES: .c .sh .f .c˜ .sh˜ .f˜
.c:;
.f:;
.sh:;
.c~:;
.f~:;
.sh~:;
.SUFFIXES:

# This "phony" target must have at least one command otherwise it will not
# actually run anything and so will not actually trigger the rules that depend
# on it to run either.  By using "true" instead of ":" "makes" that
# short-circuit directly to execvp should be able to run "true" directly.
Makefile/phony:
	-@true
