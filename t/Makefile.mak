# Makefile.mak - POSIX Makefile.mak adjunct for TopGit tests

# Many parts shamelessly swiped from Git's t directory since that works
# and is GPL2 just like TopGit

# Copyright (C) 2016,2017,2021,2025 Kyle J. McKay
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
## AWK_PATH   -- path to awk, default is /usr/bin/awk if not otherwise set
## GIT_PATH   -- path to git to use, default is $(command -v git) if not set
## DIFF       -- diff to use, defaults to "diff"
## PROVE      -- prove executable to run, MAY contain options
##
## TESTLIB_PROVE_OPTS
##            -- passed to $(PROVE) if the "prove" target is used
##
## TESTLIB_MAKE_OPTS
##            -- passed to multi-test sub $(MAKE) if the "test" target is used
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

.POSIX:

# Default target is all
all:

# Makefile.sh sets many variables used by this Makefile.mak

include $(CONFIGMAK)
SHELL = $(SHELL_PATH)

# Very important rule to avoid "accidents" caused by Makefile.sh's existence
# Some ridiculous "make" implementations will always implicitly "make Makefile"
# even though .POSIX: has been specified and that's definitely NOT POSIX!
Makefile Makefile.mak ../Makefile.mt ../Makefile.dep Makefile.sh ../config.mak ../config.sh:
	-@true

# Clean out the standard six single suffix inference rules to avoid accidents
.SUFFIXES: .c .sh .f .c˜ .sh˜ .f˜
.c:;
.f:;
.sh:;
.c~:;
.f~:;
.sh~:;
.SUFFIXES:

AT = @
Q_ = $(AT)
Q_0 = $(Q_)
Q = $(Q_$(V))
TEST_TARGET_test = test
TEST_TARGET_prove = prove
TEST_TARGET_ = $(TEST_TARGET_test)
DEFAULT_TEST_TARGET_=$(DEFAULT_TEST_TARGET)
TEST_TARGET = $(TEST_TARGET_$(DEFAULT_TEST_TARGET_))

# But all is just an alias for DEFAULT_TEST_TARGET which defaults to test

all: $(TEST_TARGET)

settings: TG-TEST-SETTINGS
	-@true # avoids the "Nothing to be done" message

test: pre-clean TG-TEST-SETTINGS $(TESTLIB_TEST_LINT) FORCE
	$(Q)helper/git_version "*** testing using" && set -m && ec_=0 && { \
	 $(CACHE_SETUP_TTY) $(MAKE) $${GNO_PD_OPT} -f Makefile.mak aggregate-results-and-cleanup || ec_=$$?; } && \
	 wait && setec_() { return "$$1"; } && setec_ "$$ec_"

prove: pre-clean TG-TEST-SETTINGS $(TESTLIB_TEST_LINT) FORCE
	@helper/git_version "*** testing using" && echo "*** prove ***" && set -m && ec_=0 && { \
	 $(CACHE_SETUP) $(PROVE) --exec $(SHELL_PATH_SQ)'' $(TESTLIB_PROVE_OPTS) $(T) :: $(TESTLIB_TEST_OPTS) || ec_=$$?; } && \
	 wait && setec_() { return "$$1"; } && setec_ "$$ec_"
	$(Q)$(NOCLEANCMT)$(MAKE) $${GNO_PD_OPT} -f Makefile.mak -s post-clean-except-prove-cache

.PRECIOUS: $(T)
$(T): FORCE
	@echo "*** $@ ***"; $(SHELL_PATH_SQ)'' $@ $(TESTLIB_TEST_OPTS)

# How to clean up

pre-clean:
	$(Q)rm -r -f $(TEST_RESULTS_DIRECTORY_SQ)''

post-clean-except-prove-cache:
	rm -r -f $(TEST_RESULTS_DIRECTORY_SQ)''
	@chmod -R u+rw 'trash directory'.* >/dev/null 2>&1 || :
	@chmod -R u+rw 'trash tmp directory'.* >/dev/null 2>&1 || :
	rm -r -f empty 'trash directory'.* 'trash tmp directory'.*
	rm -f TG-TEST-CACHE

post-clean: post-clean-except-prove-cache FORCE
	rm -f .prove

clean: post-clean FORCE
	rm -f TG-TEST-SETTINGS Makefile.var

# Pick off the lint

test-lint: test-lint-duplicates test-lint-executable test-lint-shell-syntax \
	test-lint-filenames

test-lint-duplicates:
	$(Q)dups=`echo $(ALLT) | tr ' ' '\n' | sed 's/-.*//' | sort | uniq -d` && \
		test -z "$$dups" || { \
		echo >&2 "duplicate test numbers:" $$dups; exit 1; }

test-lint-executable:
	$(Q)bad=`for i in $(LINTTESTS); do test -x "$$i" || echo $$i; done` && \
		test -z "$$bad" || { \
		echo >&2 "non-executable tests:" $$bad; exit 1; }

test-lint-shell-syntax:
	$(Q)p=$(PERL_PATH_SQ)''; "$${p:-perl}" check-non-portable-shell.pl $(LINTTESTS) $(LINTSCRIPTS)

test-lint-filenames:
	@# We do *not* pass a glob to ls-files but use grep instead, to catch
	@# non-ASCII characters (which are quoted within double-quotes)
	$(Q)g=$(GIT_PATH_SQ)''; bad="$$("$${g:-git}" -c core.quotepath=true ls-files 2>/dev/null | \
			LC_ALL=C grep '['\''""*:<>?\\|]')" || :; \
		test -z "$$bad" || { \
		echo >&2 "non-portable file name(s): $$bad"; exit 1; }

# Run the tests without using prove

run-individual-tests: $(T)

aggregate-results-and-cleanup:
	$(Q)set -m && ec_=0 && trap : INT && { \
	 $(SHELL_PATH_SQ)'' -c 'TESTLIB_TEST_PARENT_INT_ON_ERROR=$$$$ exec "$$@"' $(SHELL_PATH_SQ)'' \
	 $(MAKE) $${GNO_PD_OPT} -f Makefile.mak -k $(TESTLIB_MAKE_OPTS) run-individual-tests || ec_=$$?; } && wait && \
	 test -e $(TEST_RESULTS_DIRECTORY_SQ)/bailout || { $(MAKE) $${GNO_PD_OPT} -f Makefile.mak aggregate-results || exit; } && setec_() { return "$$1"; } && setec_ "$$ec_"
	$(Q)$(NOCLEANCMT)$(MAKE) $${GNO_PD_OPT} -f Makefile.mak -s post-clean

aggregate-results:
	$(Q)for f in $(TEST_RESULTS_DIRECTORY_SQ)/*.counts; do \
		[ "$$f" = '$(TEST_RESULTS_DIRECTORY_SQ)/*.counts' ] || echo "$$f"; \
	done | $(SHELL_PATH_SQ)'' ./aggregate-results.sh

# Provide Makefile-determined settings in a test-available format

TEST_SETTINGS = \
ts() { printf "%s\\n" \
	': "$${SHELL_PATH:=$(SHELL_PATH)}"' \
	': "$${AWK_PATH:=$(AWK_PATH)}"' \
	': "$${AWK_PATH:=awk}"' \
	': "$${PERL_PATH:=$(PERL_PATH)}"' \
	': "$${PERL_PATH:=perl}"' \
	': "$${GIT_PATH:=$(GIT_PATH)}"' \
	': "$${GIT_PATH:=git}"' \
	': "$${DIFF:=$(DIFF)}"' \
	': "$${TESTLIB_NO_TOLERATE=$(TESTLIB_NO_TOLERATE)}"' \
	': "$${TESTLIB_TEST_TAP_ONLY=$(TESTLIB_TEST_TAP_ONLY)}"' \
	': "$${GIT_MINIMUM_VERSION:=$(GIT_MINIMUM_VERSION)}"' \
	': "$${GIT_MINIMUM_VERSION:=$$TG_GIT_MINIMUM_VERSION}"' \
;}

TG-TEST-SETTINGS: $(CONFIGDEPS) $(FORCE_SETTINGS_BUILD)
	$(Q)$(TEST_SETTINGS);if test x"$$(ts)" != x"`cat \"$@\" 2>/dev/null`"; then \
		echo "* new test settings"; \
		ts >"$@"; \
	elif test z"$(FORCE_SETTINGS_BUILD)" = z; then touch "$@"; fi

FORCE: Makefile.mak/phony

# This "phony" target must have at least one command otherwise it will not
# actually run anything and so will not actually trigger the rules that depend
# on FORCE to run either.  By using "true" instead of ":" "make"s that
# short-circuit directly to execvp should be able to run "true" directly.
Makefile.mak/phony:
	-@true
