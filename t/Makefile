# Makefile - POSIX Makefile for TopGit tests
# Copyright (C) 2017,2021,2025 Kyle J. McKay
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

# These should not pass through from the environment
# But instead must be specified on the make command line
# For example "make V=1" or "make T=0001"
V =
DESTDIR =
RST2HTML =
GIT_MINIMUM_VERSION =
MKTOP =
MAKEFILESH_DEBUG =
T =
SHELL_PATH =
PERL_PATH =
AWK_PATH =
GIT_PATH =
DIFF =
PROVE =
TESTLIB_PROVE_OPTS =
TESTLIB_MAKE_OPTS =
DEFAULT_TEST_TARGET =
TESTLIB_TEST_LINT =
TESTLIB_NO_CLEAN =
TESTLIB_NO_CACHE =
TESTLIB_SKIP_TESTS =
TESTLIB_NO_TOLERATE =
TESTLIB_TEST_OPTS =
TG_TEST_INSTALLED =

Makefile/default: Makefile/phony
	+@set -- && set -ae && MAKE="$(MAKE)" T="$(T)" && . ./Makefile.sh && $(MAKE) $${GNO_PD_OPT} -e -f Makefile.mak T="$$T"

.DEFAULT:
	+@set -- "$@" && set -ae && MAKE="$(MAKE)" T="$(T)" && . ./Makefile.sh && $(MAKE) $${GNO_PD_OPT} -e -f Makefile.mak T="$$T" "$$@"

target: Makefile/phony
	+@set -- $(TARGET) && set -ae && MAKE="$(MAKE)" T="$(T)" && . ./Makefile.sh && $(MAKE) $${GNO_PD_OPT} -e -f Makefile.mak T="$$T" "$$@"

Makefile/any $(TARGETS): Makefile/phony
	+@set -- "$@" && set -ae && MAKE="$(MAKE)" T="$(T)" && . ./Makefile.sh && $(MAKE) $${GNO_PD_OPT} -e -f Makefile.mak T="$$T" "$$@"

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
