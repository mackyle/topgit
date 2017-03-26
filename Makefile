# NOTE: Requires GNU make

all::

# This should give a reasonable hint that GNU make is required in non-GNU make
.error GNU_make_is_required:

# This should be fatal in non-GNU make
export MAKE

# Update if you add any code that requires a newer version of git
GIT_MINIMUM_VERSION ?= 1.8.5

# This avoids having this in no less than three different places!
TG_STATUS_HELP_USAGE = st[atus] [-v] [--exit-code]
export TG_STATUS_HELP_USAGE

prefix ?= $(HOME)
bindir = $(prefix)/bin
cmddir = $(prefix)/libexec/topgit
sharedir = $(prefix)/share/topgit
hooksdir = $(cmddir)/hooks

commands_in := $(wildcard tg-[!-]*.sh)
utils_in := $(wildcard tg--*.sh)
hooks_in = hooks/pre-commit.sh
helpers_in = $(wildcard t/helper/*.sh)

commands_out = $(patsubst %.sh,%,$(commands_in))
utils_out = $(patsubst %.sh,%,$(utils_in))
hooks_out = $(patsubst %.sh,%,$(hooks_in))
helpers_out = $(patsubst %.sh,%,$(helpers_in))
PROGRAMS = $(commands_out) $(utils_out)
help_out = $(patsubst %.sh,%.txt,tg-help.sh tg-status.sh $(commands_in))
html_out = $(patsubst %.sh,%.html,tg-help.sh tg-status.sh tg-tg.sh $(commands_in))

SHELL_PATH ?= /bin/sh
SHELL_PATH_SQ = $(subst ','\'',$(SHELL_PATH))

AWK_PATH ?= awk
AWK_PATH_SQ = $(subst ','\'',$(AWK_PATH))

version := $(shell test -d .git && git describe --match "topgit-[0-9]*" --abbrev=4 --dirty 2>/dev/null | sed -e 's/^topgit-//' )

-include config.mak
SHELL = $(SHELL_PATH)
ifeq ($(subst /,,$(AWK_PATH)),$(AWK_PATH))
AWK_PREFIX = /usr/bin/
else
AWK_PREFIX =
endif

ifneq ($(strip $(version)),)
	version_arg = -e s/TG_VERSION=.*/TG_VERSION=$(version)/
endif

.PHONY: FORCE

all::	shell_compatibility_test precheck $(commands_out) $(utils_out) $(hooks_out) $(helpers_out) bin-wrappers/tg $(help_out) tg-tg.txt

please_set_SHELL_PATH_to_a_more_modern_shell:
	@$$(:)

shell_compatibility_test: please_set_SHELL_PATH_to_a_more_modern_shell

define POUND
#
endef
AT = @
Q_ = $(AT)
Q_0 = $(Q_)
Q = $(Q_$(V))
QSED_ = $(AT)echo "[SED] $@" &&
QSED_0 = $(QSED_)
QSED = $(QSED_$(V))
QHELP_ = $(AT)CMD="$@" CMD="$${CMD$(POUND)tg-}" && echo "[HELP] $${CMD%.txt}" &&
QHELP_0 = $(QHELP_)
QHELP = $(QHELP_$(V))
QHELPTG_ = $(AT)echo "[HELP] tg" &&
QHELPTG_0 = $(QHELPTG_)
QHELPTG = $(QHELPTG_$(V))
QHTML_ = $(AT)CMD="$@" CMD="$${CMD$(POUND)tg-}" && echo "[HTML] $${CMD%.html}" &&
QHTML_0 = $(QHTML_)
QHTML = $(QHTML_$(V))
QHTMLTOPGIT_ = $(AT)echo "[HTML] topgit" &&
QHTMLTOPGIT_0 = $(QHTMLTOPGIT_)
QHTMLTOPGIT = $(QHTMLTOPGIT_$(V))
QWRAPPER_ = $(AT)echo "[WRAPPER] $@" &&
QWRAPPER_0 = $(QWRAPPER_)
QWRAPPER = $(QWRAPPER_$(V))

tg $(commands_out) $(utils_out) $(hooks_out) $(helpers_out): % : %.sh Makefile TG-BUILD-SETTINGS
	$(QSED)sed \
		-e '1s|#!.*/sh|#!$(SHELL_PATH_SQ)|' \
		-e '1s|#!.*/awk|#!$(AWK_PREFIX)$(AWK_PATH_SQ)|' \
		-e 's#@cmddir@#$(cmddir)#g;' \
		-e 's#@hooksdir@#$(hooksdir)#g' \
		-e 's#@bindir@#$(bindir)#g' \
		-e 's#@sharedir@#$(sharedir)#g' \
		-e 's#@mingitver@#$(GIT_MINIMUM_VERSION)#g' \
		-e 's#@tgsthelpusage@#$(TG_STATUS_HELP_USAGE)#g' \
		-e 's#@SHELL_PATH@#$(SHELL_PATH_SQ)#g' \
		-e 's#@AWK_PATH@#$(AWK_PATH_SQ)#g' \
		$(version_arg) \
		$@.sh >$@+ && \
	chmod +x $@+ && \
	mv $@+ $@

bin-wrappers/tg : $(commands_out) $(utils_out) $(hooks_out) $(helpers_out) tg
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
	$(QHELP)CMD="$@" CMD="$${CMD#tg-}" CMD="$${CMD%.txt}" && \
	$(SHELL_PATH) ./create-help.sh "$$CMD"

.PHONY: doc install-doc html

doc:: html

install-doc:: install-html

html:: topgit.html $(html_out)

tg-tg.txt: README create-html-usage.pl $(commands_in)
	$(QHELPTG)perl ./create-html-usage.pl --text < README > $@

topgit.html: README create-html-usage.pl $(commands_in)
	$(QHTMLTOPGIT)perl ./create-html-usage.pl < README | rst2html.py - $@

$(html_out): create-html.sh
	$(QHTML)CMD="$@" CMD="$${CMD#tg-}" CMD="$${CMD%.html}" && \
	$(SHELL_PATH) ./create-html.sh "$$CMD"

.PHONY: precheck

precheck:: tg
ifeq ($(DESTDIR),)
	$(Q)./$+ precheck
else
	$(Q)echo skipping precheck because DESTDIR is set
endif

.PHONY: install

install:: all
	install -d -m 755 "$(DESTDIR)$(bindir)"
	install tg "$(DESTDIR)$(bindir)"
	install -d -m 755 "$(DESTDIR)$(cmddir)"
	install $(commands_out) $(utils_out) "$(DESTDIR)$(cmddir)"
	install -d -m 755 "$(DESTDIR)$(hooksdir)"
	install $(hooks_out) "$(DESTDIR)$(hooksdir)"
	install -d -m 755 "$(DESTDIR)$(sharedir)"
	install -m 644 $(help_out) tg-tg.txt "$(DESTDIR)$(sharedir)"
	install -m 644 leaves.awk "$(DESTDIR)$(sharedir)"

.PHONY: install-html

install-html:: html
	install -d -m 755 "$(DESTDIR)$(sharedir)"
	install -m 644 topgit.html $(html_out) "$(DESTDIR)$(sharedir)"

.PHONY: clean

clean::
	rm -f tg $(commands_out) $(utils_out) $(hooks_out) $(helpers_out) $(help_out) topgit.html $(html_out)
	rm -f TG-BUILD-SETTINGS
	rm -rf bin-wrappers
	+$(Q)$(MAKE) -C t clean

define BUILD_SETTINGS
TG_INST_BINDIR='$(bindir)'
TG_INST_CMDDIR='$(cmddir)'
TG_INST_HOOKSDIR='$(hooksdir)'
TG_INST_SHAREDIR='$(sharedir)'
SHELL_PATH='$(SHELL_PATH)'
TG_VERSION='$(version)'
TG_GIT_MINIMUM_VERSION='$(GIT_MINIMUM_VERSION)'
endef
export BUILD_SETTINGS

TG-BUILD-SETTINGS: FORCE
	$(Q)if test x"$$BUILD_SETTINGS" != x"`cat $@ 2>/dev/null`"; then \
		echo "* new build settings"; \
		echo "$$BUILD_SETTINGS" >$@; \
	fi

test:: all
	+$(Q)$(MAKE) -C t all
