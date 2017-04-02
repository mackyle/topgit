# Makefile - POSIX Makefile for TopGit
# Copyright (C) 2017 Kyle J. McKay
# All rights reserved
# License GPL2

# Makefile drives the process
# Makefile.sh provides POSIX sh support
# Makefile.mak does the actual building
# Makefile.mt always exists and is always empty (i.e. zero length)

.POSIX:

# Anything explicitly listed here will always avoid a bogus "up to date" result
TARGETS = \
	all clean tg awk hooks helpers doc html \
	precheck TG-BUILD-SETTINGS \
	install	install-doc install-html \
	tg--awksome tg-tg.txt topgit.html \
	shell_compatibility_test \
	bin-wrappers/tg \
	test \
#TARGETS

__default_target__: __file_which_should_not_exist
	+@set -- && set -ae && . ./Makefile.sh && $(MAKE) -f Makefile.mak

.DEFAULT:
	+@set -- "$@" && set -ae && . ./Makefile.sh && $(MAKE) -f Makefile.mak "$@"

__any_target__ $(TARGETS): __file_which_should_not_exist
	+@set -- "$@" && set -ae && . ./Makefile.sh && $(MAKE) -f Makefile.mak "$@"

# Very important rule to avoid "accidents" caused by Makefile.sh's existence
# Some ridiculous "make" implementations will always implicitly "make Makefile"
# even though .POSIX: has been specified and that's definately NOT POSIX!
Makefile:
	@true

.PRECIOUS:

# Clean out the standard six single suffix inference rules
# Except for .sh (because it would then elicit a redefiniton warning)
.SUFFIXES: .c .sh .f .c˜ .sh˜ .f˜
.c:;
.f:;
#.sh:;
.c~:;
.f~:;
.sh~:;
.SUFFIXES: .sh .awk .txt .html

# These are imperfect because they don't really reflect the correct dependencies
# Running the default "make" or "make all" will always get it right, but when
# trying to make a specific target, these will often avoid the "up to date"
# output that would otherwise occur for existing files with no dependencies
.sh:
	+@set -- "$@" && set -ae && . ./Makefile.sh && $(MAKE) -f Makefile.mak "$@"
.awk:
	+@set -- "$@" && set -ae && . ./Makefile.sh && $(MAKE) -f Makefile.mak "$@"
.sh.txt:
	+@set -- "$@" && set -ae && . ./Makefile.sh && $(MAKE) -f Makefile.mak "$@"
.sh.html:
	+@set -- "$@" && set -ae && . ./Makefile.sh && $(MAKE) -f Makefile.mak "$@"

# This "phony" target must have at least one command otherwise it will not
# actually run anything and so will not actually trigger the rules that depend
# on it to run either.  By using "true" instead of ":" "makes" that
# short-circuit directly to execvp should be able to run "true" directly.
__file_which_should_not_exist:
	-@true
