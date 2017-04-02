# Many parts shamelessly swiped from Git's t directory since that works
# and is GPL2 just like TopGit

# Copyright (C) 2016 Kyle J. McKay
# The lines swiped from Git are Copyright (C) 2005 Junio C Hamano et al.

#
## Make Targets
##
## all   -- default target which defaults to $(DEFAULT_TEST_TARGET) which
##          defaults to "test"
## prove -- run the tests using the $(PROVE) utility which is expected to
##          take the same arguments as Perl's prove
## test  -- run the tests without using an external helper utility
#

#
## Make Variables
##
## An existing config.mak in the parent directory IS read first
##
## SHELL_PATH -- path to POSIX sh, default is /bin/sh if not otherwise set
## PERL_PATH  -- path to Perl, default is $(command -v perl) if not set
## GIT_PATH   -- path to git to use, default is $(command -v git) if not set
## DIFF       -- diff to use, defaults to "diff"
## PROVE      -- prove executable to run, MAY contain options
##
## TESTLIB_PROVE_OPTS
##            -- passed to $(PROVE) if the "prove" target is used
##
## DEFAULT_TEST_TARGET
##            -- defaults to "test" but can be "prove" to run with prove
##
## TESTLIB_TEST_LINT
##            -- set to "test-lint" (the default) to do some lint tests
##               may be set to empty to skip these
##
## TESTLIB_NO_CLEAN
##            -- suppresses removal of test-results directory after testing
##
## TESTLIB_NO_CACHE
##            -- suppresses use of TG-TEST-CACHE for "test" and "prove" targets
##
## TESTLIB_SKIP_TESTS
##            -- space-separated "case" patterns to match against the
##               t[0-9][0-9][0-9][0-9] portion of the test file name.  To
##               skip multiple tests use standard '*', '?' and '[...]'
##               match operators.  For example, to skip test t1234-foo.sh and
##               t3210-hi.sh use TESTLIB_SKIP_TESTS="t1234 t3210" to do that.
##
## TESTLIB_NO_TOLERATE
##            -- if non-empty turns all test_tolerate_failure calls into
##               test_expect_success calls instead
##
## TESTLIB_TEST_OPTS
##            -- provided as options to all tests (undergoes field splitting)
##               might be set to, for example: --verbose -debug
##
## T          -- space-sparated list of tests to run, must be full filename
##               WITHOUT any directory part of the test INCLUDING the .sh
##               suffix.  The default is all t\d{4}-*.sh files in this dir.
##
## TG_TEST_INSTALLED
##            -- if not empty, test whatever "tg" is found in $PATH
#

# Default target is all

all::

# This should give a reasonable hint that GNU make is required in non-GNU make
.error GNU_make_is_required:

# This should be fatal in non-GNU make
export MAKE

# Basic setup

-include ../config.mak
SHELL_PATH ?= /bin/sh
SHELL = $(SHELL_PATH)
DIFF ?= diff
PROVE ?= prove
DEFAULT_TEST_TARGET ?= test
TEST_LINT ?= test-lint
ifdef TEST_OUTPUT_DIRECTORY
TEST_RESULTS_DIRECTORY = $(TEST_OUTPUT_DIRECTORY)/test-results
else
TEST_RESULTS_DIRECTORY = test-results
endif

# Shell quote;

SHELL_PATH_SQ = $(subst ','\'',$(SHELL_PATH))
PERL_PATH_SQ = $(subst ','\'',$(PERL_PATH))
GIT_PATH_SQ = $(subst ','\'',$(GIT_PATH))
TEST_RESULTS_DIRECTORY_SQ = $(subst ','\'',$(TEST_RESULTS_DIRECTORY))

# Default list of tests is all t????-*.sh files

ALLT = $(sort $(wildcard t[0-9][0-9][0-9][0-9]-*.sh))
T ?= $(ALLT)
LINTTESTS ?= $(T)

# Extra shell scripts to run through check-non-portable-shell.pl
# These will ALWAYS be "checked" whenever the test-lint target is made
# By default all $(T) test files are checked so they don't need to be
# in this list

LINTSCRIPTS = $(sort $(filter-out $(ALLT),$(wildcard *.sh)))

# But all is just an alias for DEFAULT_TEST_TARGET which defaults to test

all:: $(DEFAULT_TEST_TARGET)

ifndef TESTLIB_NO_CACHE

define CACHE_SETUP
TESTLIB_CACHE="$$($(SHELL_PATH_SQ) ./test-lib.sh --cache $(TESTLIB_TEST_OPTS) 2>/dev/null || :)"
endef

define CACHE_SETUP_TTY
! test -t 1 || { TESTLIB_FORCETTY=1 && export TESTLIB_FORCETTY; }; $(CACHE_SETUP)
endef

endif

test: pre-clean TG-TEST-SETTINGS $(TEST_LINT)
	@$(CACHE_SETUP_TTY) $(MAKE) aggregate-results-and-cleanup

prove: pre-clean TG-TEST-SETTINGS $(TEST_LINT)
	@echo "*** prove ***"; $(CACHE_SETUP) $(PROVE) --exec '$(SHELL_PATH_SQ)' $(TESTLIB_PROVE_OPTS) $(T) :: $(TESTLIB_TEST_OPTS)
ifndef TESTLIB_NO_CLEAN
	@$(MAKE) -s post-clean-except-prove-cache
endif

$(T):
	@echo "*** $@ ***"; '$(SHELL_PATH_SQ)' $@ $(TESTLIB_TEST_OPTS)

# How to clean up

pre-clean:
	@rm -r -f '$(TEST_RESULTS_DIRECTORY_SQ)'

post-clean-except-prove-cache:
	rm -r -f empty 'trash directory'.* '$(TEST_RESULTS_DIRECTORY_SQ)'
	rm -f TG-TEST-CACHE

post-clean: post-clean-except-prove-cache
	rm -f .prove

clean: post-clean
	rm -f TG-TEST-SETTINGS

# Pick off the lint

test-lint: test-lint-duplicates test-lint-executable test-lint-shell-syntax \
	test-lint-filenames

test-lint-duplicates:
	@dups=`echo $(ALLT) | tr ' ' '\n' | sed 's/-.*//' | sort | uniq -d` && \
		test -z "$$dups" || { \
		echo >&2 "duplicate test numbers:" $$dups; exit 1; }

test-lint-executable:
	@bad=`for i in $(LINTTESTS); do test -x "$$i" || echo $$i; done` && \
		test -z "$$bad" || { \
		echo >&2 "non-executable tests:" $$bad; exit 1; }

test-lint-shell-syntax:
	@p='$(PERL_PATH_SQ)'; "$${p:-perl}" check-non-portable-shell.pl $(LINTTESTS) $(LINTSCRIPTS)

test-lint-filenames:
	@# We do *not* pass a glob to ls-files but use grep instead, to catch
	@# non-ASCII characters (which are quoted within double-quotes)
	@g='$(GIT_PATH_SQ)'; bad="$$("$${g:-git}" -c core.quotepath=true ls-files 2>/dev/null | \
			grep '['\''""*:<>?\\|]')"; \
		test -z "$$bad" || { \
		echo >&2 "non-portable file name(s): $$bad"; exit 1; }

# Run the tests without using prove

run-individual-tests: $(T)

aggregate-results-and-cleanup:
	@ec=0; TESTLIB_TEST_PARENT_INT_ON_ERROR=1 $(MAKE) -k run-individual-tests || ec=$$?; \
	[ $$ec -eq 130 ] || $(MAKE) aggregate-results || exit && exit $$ec
ifndef TESTLIB_NO_CLEAN
	@$(MAKE) -s post-clean
endif

aggregate-results:
	@for f in '$(TEST_RESULTS_DIRECTORY_SQ)'/t*-*.counts; do \
		[ "$$f" = '$(TEST_RESULTS_DIRECTORY_SQ)/t*-*.counts' ] || echo "$$f"; \
	done | '$(SHELL_PATH_SQ)' ./aggregate-results.sh

.PHONY: clean pre-clean post-clean post-clean-except-settings
.PHONY: $(T) run-individual-tests aggregate-results valgrind perf

# Provide Makefile-determined settings in a test-available format

TEST_SETTINGS = : \
	"$${SHELL_PATH:=$(SHELL_PATH)}" \
	"$${PERL_PATH:=$(PERL_PATH)}" \
	"$${PERL_PATH:=perl}" \
	"$${GIT_PATH:=$(GIT_PATH)}" \
	"$${GIT_PATH:=git}" \
	"$${DIFF:=$(DIFF)}" \
	"$${TESTLIB_NO_TOLERATE=$(TESTLIB_NO_TOLERATE)}" \
	"$${GIT_MINIMUM_VERSION:=$(GIT_MINIMUM_VERSION)}" \
	"$${GIT_MINIMUM_VERSION:=$$TG_GIT_MINIMUM_VERSION}" \
#TEST_SETTINGS"

TG-TEST-SETTINGS: FORCE
	@if test x'$(TEST_SETTINGS)' != x"`cat \"$@\" 2>/dev/null`"; then \
		echo "* new test settings"; \
		printf '%s\n' '$(TEST_SETTINGS)' >"$@"; \
	fi

.PHONY: FORCE
