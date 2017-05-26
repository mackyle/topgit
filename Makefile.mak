# Makefile.mak - POSIX Makefile.mak adjunct for TopGit

.POSIX:

# Default target is all
all:

# Makefile.sh sets many variables used by this Makefile.mak

include $(CONFIGMAK)
SHELL = $(SHELL_PATH)

all: \
	shell_compatibility_test \
	precheck \
	tg $(commands_out) $(utils_out) $(awk_out) $(hooks_out) $(helpers_out) \
	bin-wrappers/tg $(help_out) tg-tg.txt

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
Makefile:
	@true

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
# Of course that means the free automatic dependency crated by an inference rule
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
		"$@.sh" >"$@+" && \
	chmod +x "$@+" && \
	mv "$@+" "$@"

tg--awksome: $(awk_out)
$(awk_out): Makefile TG-BUILD-SETTINGS
	$(QSED)sed \
		-e '1s|#!.*/awk|#!$(AWK_PREFIX)$(AWK_PATH_SQ)|' \
		"$@.awk" >"$@+" && \
	chmod +x "$@+" && \
	mv "$@+" "$@"

bin-wrappers/tg : tg
	$(QWRAPPER){ [ -d bin-wrappers ] || mkdir bin-wrappers; } && \
	echo '#!$(SHELL_PATH_SQ)' >"$@" && \
	curdir="$$(pwd -P)" && \
	echo "TG_INST_CMDDIR='$$curdir' && export TG_INST_CMDDIR" >>"$@" && \
	echo "TG_INST_SHAREDIR='$$curdir' && export TG_INST_SHAREDIR" >>"$@" && \
	echo "TG_INST_HOOKSDIR='$$curdir' && export TG_INST_HOOKSDIR" >>"$@" && \
	echo '[ -n "$$tg__include" ] || exec $(SHELL_PATH_SQ) -c '\''. "$$TG_INST_CMDDIR/tg"'\'' tg "$$@" || exit' >>"$@" && \
	echo ". '$$curdir/tg'" >>"$@" && \
	chmod a+x "$@"

$(help_out): README create-help.sh
	$(QHELP)CMD="$@" && CMD="$${CMD#tg-}" && CMD="$${CMD%.txt}" && \
	$(SHELL_PATH) ./create-help.sh "$$CMD"

doc: html

install-doc: install-html

html: topgit.html $(html_out)

tg-tg.txt: README create-html-usage.pl $(commands_in)
	$(QHELPTG)perl ./create-html-usage.pl --text < README > $@

topgit.html: README create-html-usage.pl $(commands_in)
	$(QHTMLTOPGIT)perl ./create-html-usage.pl < README | rst2html.py - $@

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
	rm -f tg $(commands_out) $(utils_out) $(awk_out) $(hooks_out) $(helpers_out) $(help_out) tg-tg.txt topgit.html $(html_out)
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
TG-BUILD-SETTINGS: $(FORCE_SETTINGS_BUILD)
	$(Q)$(BUILD_SETTINGS);if test x"$$(bs)" != x"`cat \"$@\" 2>/dev/null`"; then \
		echo "* new build settings"; \
		bs >"$@"; \
	fi

test: all FORCE
	+$(Q)cd t && $(MAKE) all

FORCE: __file_which_should_not_exist

# This "phony" target must have at least one command otherwise it will not
# actually run anything and so will not actually trigger the rules that depend
# on FORCE to run either.  By using "true" instead of ":" "make"s that
# short-circuit directly to execvp should be able to run "true" directly.
__file_which_should_not_exist:
	-@true
