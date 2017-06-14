# Makefile - POSIX Makefile for TopGit tests
# Copyright (C) 2017 Kyle J. McKay
# All rights reserved
# License GPL2

# Makefile drives the process
# Makefile.sh provides POSIX sh support
# Makefile.mak does the actual building
# ../Makefile.sh provides POSIX sh utility functions
# ../Makefile.mt always exists and is always empty (i.e. zero length)

.POSIX:

# Anything explicitly listed here will always avoid a bogus "up to date" result
TARGETS = \
	all prove test pre-clean clean post-clean-except-prove-cache post-clean \
	test-lint test-lint-duplicates test-lint-executable test-lint-shell-syntax \
	test-lint-filenames run-individual-tests aggregate-results-and-cleanup \
	aggregate-results TG-TEST-SETTINGS
#TARGETS

__default_target__: __file_which_should_not_exist
	+@set -- && set -ae && MAKE="$(MAKE)" && . ./Makefile.sh && $(MAKE) $${GNO_PD_OPT} -e -f Makefile.mak

.DEFAULT:
	+@set -- "$@" && set -ae && MAKE="$(MAKE)" && . ./Makefile.sh && $(MAKE) $${GNO_PD_OPT} -e -f Makefile.mak "$@"

target: __file_which_should_not_exist
	+@set -- $(TARGET) && set -ae && MAKE="$(MAKE)" && . ./Makefile.sh && $(MAKE) $${GNO_PD_OPT} -e -f Makefile.mak $(TARGET)

__any_target__ $(TARGETS): __file_which_should_not_exist
	+@set -- "$@" && set -ae && MAKE="$(MAKE)" && . ./Makefile.sh && $(MAKE) $${GNO_PD_OPT} -e -f Makefile.mak "$@"

# Very important rule to avoid "accidents" caused by Makefile.sh's existence
# Some ridiculous "make" implementations will always implicitly "make Makefile"
# even though .POSIX: has been specified and that's definitely NOT POSIX!
Makefile:
	@true

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
__file_which_should_not_exist:
	-@true
