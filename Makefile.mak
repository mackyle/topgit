# Makefile.mak - POSIX Makefile.mak adjunct for TopGit

.POSIX:

#
## Makefile variables
##
## V        - set to 1 to get more verbose rule output
##            Default is empty
##            Any value other than empty or 0 will also activate verbose mode
##
## DESTDIR  - installation path prefix
##            Default is empty
##            The value is prefixed verbatim to the installation paths when
##            using any of the "install" targets but is otherwise ignored.
##            This allows the executables to be configured for one location
##            but installed to an alternate location before being moved to
##            their final location.  The executables will not work correctly
##            until they are then relocated into their final location.
##
## RST2HTML - location of rst2html.py
##            Default is "rst2html"
##            Only required to `make doc` aka `make html` (i.e. topgit.html)
##            If "rst2html" is not in $PATH this must be set
##            in order to successfully `make doc` (or `make html`)
##
## SHELL_PATH path to POSIX sh, default is /bin/sh if not otherwise set
##
## AWK_PATH   path to awk, default is /usr/bin/awk if not otherwise set
#

# Default target is all
all:

# Makefile.sh sets many variables used by this Makefile.mak

include $(CONFIGMAK)
SHELL = $(SHELL_PATH)

all: \
	shell_compatibility_test \
	precheck \
	tg $(commands_out) $(utils_out) $(awk_out) $(hooks_out) $(helpers_out) \
	bin-wrappers/tg bin-wrappers/pre-commit $(help_out) tg-tg.txt

settings: TG-BUILD-SETTINGS FORCE
	+$(Q)cd t && $(MAKE) settings

awk: $(awk_out)
hooks: $(hooks_out)
helpers: $(helpers_out)

please_set_SHELL_PATH_to_a_more_modern_shell: FORCE
	@$$(:)

shell_compatibility_test: please_set_SHELL_PATH_to_a_more_modern_shell

# $(POUND) expands to a single '#' courtesy of Makefile.sh
AT = @
Q_ = $(AT)
Q_0 = $(Q_)
Q = $(Q_$(V))
QPOUND_ = $(AT)$(POUND)
QPOUND_0 = $(QPOUND_)
QPOUND = $(QPOUND_$(V))
QSED_ = $(AT)echo "[SED] $@" &&
QSED_0 = $(QSED_)
QSED = $(QSED_$(V))
QHELP_ = $(AT)CMD="$@" && CMD="$${CMD$(POUND)tg-}" && echo "[HELP] $${CMD%.txt}" &&
QHELP_0 = $(QHELP_)
QHELP = $(QHELP_$(V))
QHELPTG_ = $(AT)echo "[HELP] tg" &&
QHELPTG_0 = $(QHELPTG_)
QHELPTG = $(QHELPTG_$(V))
QHTML_ = $(AT)CMD="$@" && CMD="$${CMD$(POUND)tg-}" && echo "[HTML] $${CMD%.html}" &&
QHTML_0 = $(QHTML_)
QHTML = $(QHTML_$(V))
QHTMLTOPGIT_ = $(AT)echo "[HTML] topgit" &&
QHTMLTOPGIT_0 = $(QHTMLTOPGIT_)
QHTMLTOPGIT = $(QHTMLTOPGIT_$(V))
QWRAPPER_ = $(AT)echo "[WRAPPER] $@" &&
QWRAPPER_0 = $(QWRAPPER_)
QWRAPPER = $(QWRAPPER_$(V))

# Very important rule to avoid "accidents" caused by Makefile.sh's existence
# Some ridiculous "make" implementations will always implicitly "make Makefile"
# even though .POSIX: has been specified and that's definitely NOT POSIX!
Makefile Makefile.mak Makefile.mt Makefile.dep Makefile.sh config.mak config.sh:
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

# The fatal flaw with .SUFFIXES is that while it's possible to add dependencies
# without listing rule commands, doing so prevents use of an inference rule
# because the dependency-adding-rule-with-no-commands is still considered a rule.
# Of course that means the free automatic dependency created by an inference rule
# also can't be picked up but fortunately we have DEPFILE instead.
include $(DEPFILE)

tg $(commands_out) $(utils_out) $(hooks_out) $(helpers_out): Makefile Makefile.mak Makefile.sh TG-BUILD-SETTINGS
	$(QSED)sed \
		-e '1s|#!.*/sh|#!$(SHELL_PATH)|' \
		-e '1s|#!.*/awk|#!$(AWK_PREFIX)$(AWK_PATH)|' \
		-e 's#@cmddir@#$(cmddir)#g;' \
		-e 's#@hooksdir@#$(hooksdir)#g' \
		-e 's#@bindir@#$(bindir)#g' \
		-e 's#@sharedir@#$(sharedir)#g' \
		-e 's#@mingitver@#$(GIT_MINIMUM_VERSION)#g' \
		-e 's#@tgsthelpusage@#$(TG_STATUS_HELP_USAGE)#g' \
		-e 's#@SHELL_PATH@#$(SHELL_PATH_SQ)#g' \
		-e 's#@AWK_PATH@#$(AWK_PATH_SQ)#g' \
		$(version_arg) \
		<"$@.sh" >"$@+" && \
	chmod +x "$@+" && \
	mv "$@+" "$@"

tg--awksome: $(awk_out)
$(awk_out): Makefile TG-BUILD-SETTINGS
	$(QSED)sed \
		-e '1s|#!.*/awk|#!$(AWK_PREFIX)$(AWK_PATH_SQ)|' \
		<"$@.awk" >"$@+" && \
	chmod +x "$@+" && \
	mv "$@+" "$@"

bin-wrappers/tg : tg
	$(QWRAPPER){ [ -d bin-wrappers ] || mkdir -p bin-wrappers; } && \
	echo '#!$(SHELL_PATH_SQ)' >"$@" && \
	curdir="$$(pwd -P)" && \
	echo "TG_INST_BINDIR='$$curdir' && export TG_INST_BINDIR" >>"$@" && \
	echo "TG_INST_CMDDIR='$$curdir' && export TG_INST_CMDDIR" >>"$@" && \
	echo "TG_INST_SHAREDIR='$$curdir' && export TG_INST_SHAREDIR" >>"$@" && \
	echo "TG_INST_HOOKSDIR='$$curdir/bin-wrappers' && export TG_INST_HOOKSDIR" >>"$@" && \
	echo '[ -n "$$tg__include" ] || exec $(SHELL_PATH_SQ) -c '\''. "$$TG_INST_BINDIR/tg"'\'' "$$0" "$$@" || exit $$?' >>"$@" && \
	echo ". '$$curdir/tg'" >>"$@" && sed <"$@" "/exec.* -c /s/ -c / -x -c /" >"$@x" && \
	chmod a+x "$@" "$@x"

bin-wrappers/pre-commit : hooks/pre-commit
	$(QWRAPPER){ [ -d bin-wrappers ] || mkdir -p bin-wrappers; } && \
	echo '#!$(SHELL_PATH_SQ)' >"$@" && \
	curdir="$$(pwd -P)" && \
	echo "TG_INST_BINDIR='$$curdir' && export TG_INST_BINDIR" >>"$@" && \
	echo "TG_INST_CMDDIR='$$curdir' && export TG_INST_CMDDIR" >>"$@" && \
	echo "TG_INST_SHAREDIR='$$curdir' && export TG_INST_SHAREDIR" >>"$@" && \
	echo "TG_INST_HOOKSDIR='$$curdir/bin-wrappers' && export TG_INST_HOOKSDIR" >>"$@" && \
	echo ". '$$curdir/hooks/pre-commit'" >>"$@" && \
	chmod a+x "$@"

$(help_out): README_DOCS.rst create-help.sh polish-help-txt.pl
	$(QHELP)CMD="$@" && CMD="$${CMD#tg-}" && CMD="$${CMD%.txt}" && \
	$(SHELL_PATH) ./create-help.sh "$$CMD"

doc: html

install-doc: install-html

html: topgit.html $(html_out)

tg-tg.txt: README_DOCS.rst create-html-usage.pl $(commands_in)
	$(QHELPTG)perl ./create-html-usage.pl --text < README_DOCS.rst > $@

TOPGIT_HTML_SRCS = \
	README_DOCS.rst \
	rsrc/stub0.bin \
	rsrc/stub1.bin \
	Makefile.mt
#TOPGIT_HTML_SRCS

topgit.html: $(TOPGIT_HTML_SRCS) Makefile.mak create-html-usage.pl $(commands_in)
	$(Q)command -v "$${RST2HTML:-rst2html}" >/dev/null || \
	{ echo "need $${RST2HTML:-rst2html} to make $@" >&2; exit 1; }
	$(QPOUND)echo "# \$${RST2HTML:-rst2html} is \"$${RST2HTML:-rst2html}\""
	$(QHTMLTOPGIT)perl ./create-html-usage.pl < README_DOCS.rst | \
	"$${RST2HTML:-rst2html}" --stylesheet-path=Makefile.mt - $@.tmp && \
	{ cat rsrc/stub1.bin && \
	LC_ALL=C sed -e 's/&nbsp;/\&#160;/g' -e 's/<th class=/<th align="left" class=/g' \
		-e 's/ -- / \&#x2013; /g' -e 's/&amp;#160;/\&#160;/g' \
		-e 's/<ol class="lowerroman/<ol type="i" class="lowerroman/g' \
		-e 's/<ol class="loweralpha/<ol type="a" class="loweralpha/g' <$@.tmp | \
	LC_ALL=C awk '/^<body/{p=1;next}/^<\/body/{p=0;next}p{print}' && \
	cat rsrc/stub0.bin; } >$@ && rm -f $@.tmp

$(html_out): create-html.sh
	$(QHTML)CMD="$@" && CMD="$${CMD#tg-}" && CMD="$${CMD%.html}" && \
	$(SHELL_PATH) ./create-html.sh "$$CMD"

precheck: precheck_DESTDIR_$(DESTDIRBOOL)

precheck_DESTDIR_No: tg FORCE
	$(Q)./tg precheck
precheck_DESTDIR_Yes: FORCE
	$(Q)echo "skipping precheck because DESTDIR is set"

install: all FORCE
	install -d -m 755 "$(DESTDIR)$(bindir)"
	install tg "$(DESTDIR)$(bindir)"
	install -d -m 755 "$(DESTDIR)$(cmddir)"
	install $(commands_out) $(utils_out) "$(DESTDIR)$(cmddir)"
	install -d -m 755 "$(DESTDIR)$(cmddir)/awk"
	install $(awk_out) "$(DESTDIR)$(cmddir)/awk"
	install -d -m 755 "$(DESTDIR)$(hooksdir)"
	install $(hooks_out) "$(DESTDIR)$(hooksdir)"
	install -d -m 755 "$(DESTDIR)$(sharedir)"
	install -m 644 $(help_out) tg-tg.txt "$(DESTDIR)$(sharedir)"

install-html: html FORCE
	install -d -m 755 "$(DESTDIR)$(sharedir)"
	install -m 644 topgit.html $(html_out) "$(DESTDIR)$(sharedir)"

clean: FORCE
	rm -f tg $(commands_out) $(utils_out) $(awk_out) $(hooks_out) $(helpers_out) $(help_out) tg-tg.txt topgit.html topgit.html.tmp $(html_out)
	rm -f TG-BUILD-SETTINGS Makefile.dep Makefile.var
	rm -rf bin-wrappers
	+-$(Q)cd t && $(MAKE) clean

BUILD_SETTINGS = \
bs() { printf "%s\\n" \
	"TG_INST_BINDIR='$(bindir)'" \
	"TG_INST_CMDDIR='$(cmddir)'" \
	"TG_INST_HOOKSDIR='$(hooksdir)'" \
	"TG_INST_SHAREDIR='$(sharedir)'" \
	"SHELL_PATH='$(SHELL_PATH)'" \
	"AWK_PATH='$(AWK_PATH)'" \
	"TG_VERSION='$(version)'" \
	"TG_GIT_MINIMUM_VERSION='$(GIT_MINIMUM_VERSION)'" \
;}

# Makefile.sh sets FORCE_SETTINGS_BUILD to FORCE and pre-runs
# make -f Makefile.mak TG-BUILD-SETTINGS thus avoiding this always
# causing the targets that depend on it to build while still forcing
# a rebuild if any settings actually change.
TG-BUILD-SETTINGS: $(CONFIGDEPS) $(FORCE_SETTINGS_BUILD)
	$(Q)$(BUILD_SETTINGS);if test x"$$(bs)" != x"`cat \"$@\" 2>/dev/null`"; then \
		echo "* new build settings"; \
		bs >"$@"; \
	elif test z"$(FORCE_SETTINGS_BUILD)" = z; then touch "$@"; fi

test-sha1: all FORCE
	+$(Q)cd t && TESTLIB_GIT_DEFAULT_HASH=sha1 $(MAKE) all

test-sha256: all FORCE
	+$(Q)cd t && TESTLIB_GIT_DEFAULT_HASH=sha256 $(MAKE) all

test: all FORCE
	+$(Q)cd t && $(MAKE) settings && if helper/test_have_prereq GITSHA256; then \
		echo "* running Git hash algorithm sha1 tests" && \
		TESTLIB_GIT_DEFAULT_HASH=sha1 $(MAKE) all && \
		echo "* running Git hash algorithm sha256 tests" && \
		TESTLIB_GIT_DEFAULT_HASH=sha256 $(MAKE) all && \
		echo "* both Git hash algorithm sha1 and Git hash algorithm sha256 tests passed"; \
	else \
		echo "* running Git hash algorithm sha1 tests only (Git version < 2.29.0)" && \
		TESTLIB_GIT_DEFAULT_HASH=sha1 $(MAKE) all; \
	fi

FORCE all: Makefile.mak/phony

# This "phony" target must have at least one command otherwise it will not
# actually run anything and so will not actually trigger the rules that depend
# on FORCE to run either.  By using "true" instead of ":" "make"s that
# short-circuit directly to execvp should be able to run "true" directly.
Makefile.mak/phony:
	-@true
