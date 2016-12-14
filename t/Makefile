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
#

# Default target is all

all::

# Basic setup

-include ../config.mak
SHELL_PATH ?= /bin/sh
SHELL = $(SHELL_PATH)
PERL_PATH ?= $(shell command -v perl)
PERL_PATH ?= /usr/bin/perl
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

test: pre-clean $(TEST_LINT)
	@$(MAKE) aggregate-results-and-cleanup

prove: pre-clean $(TEST_LINT)
	@echo "*** prove ***"; $(PROVE) --exec '$(SHELL_PATH_SQ)' $(TESTLIB_PROVE_OPTS) $(T) :: $(TESTLIB_TEST_OPTS)
	@$(MAKE) -s clean-except-prove-cache

$(T):
	@echo "*** $@ ***"; '$(SHELL_PATH_SQ)' $@ $(TESTLIB_TEST_OPTS)

# How to clean up

pre-clean:
	@rm -r -f '$(TEST_RESULTS_DIRECTORY_SQ)'

clean-except-prove-cache:
	rm -r -f empty 'trash directory'.* '$(TEST_RESULTS_DIRECTORY_SQ)'

clean: clean-except-prove-cache
	rm -f .prove

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
	@'$(PERL_PATH_SQ)' check-non-portable-shell.pl $(LINTTESTS) $(LINTSCRIPTS)

test-lint-filenames:
	@# We do *not* pass a glob to ls-files but use grep instead, to catch
	@# non-ASCII characters (which are quoted within double-quotes)
	@bad="$$(git -c core.quotepath=true ls-files 2>/dev/null | \
			grep '['\''""*:<>?\\|]')"; \
		test -z "$$bad" || { \
		echo >&2 "non-portable file name(s): $$bad"; exit 1; }

# Run the tests without using prove

aggregate-results-and-cleanup: $(T)
	@$(MAKE) aggregate-results
	@$(MAKE) -s clean

aggregate-results:
	@for f in '$(TEST_RESULTS_DIRECTORY_SQ)'/t*-*.counts; do \
		echo "$$f"; \
	done | '$(SHELL_PATH_SQ)' ./aggregate-results.sh

.PHONY: pre-clean $(T) aggregate-results clean valgrind perf
