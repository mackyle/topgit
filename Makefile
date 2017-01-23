# NOTE: Requires GNU make

all::

# This should give a reasonable hint that GNU make is required in non-GNU make
.error GNU_make_is_required:

# This should be fatal in non-GNU make
export MAKE

# Update if you add any code that requires a newer version of git
GIT_MINIMUM_VERSION ?= 1.8.5

prefix ?= $(HOME)
bindir = $(prefix)/bin
cmddir = $(prefix)/libexec/topgit
sharedir = $(prefix)/share/topgit
hooksdir = $(cmddir)/hooks

commands_in := $(wildcard tg-[!-]*.sh)
utils_in := $(wildcard tg--*.sh)
hooks_in = hooks/pre-commit.sh

commands_out = $(patsubst %.sh,%,$(commands_in))
utils_out = $(patsubst %.sh,%,$(utils_in))
hooks_out = $(patsubst %.sh,%,$(hooks_in))
help_out = $(patsubst %.sh,%.txt,tg-help.sh $(commands_in))
html_out = $(patsubst %.sh,%.html,tg-help.sh tg-tg.sh $(commands_in))

SHELL_PATH ?= /bin/sh
SHELL_PATH_SQ = $(subst ','\'',$(SHELL_PATH))

version := $(shell test -d .git && git describe --match "topgit-[0-9]*" --abbrev=4 --dirty 2>/dev/null | sed -e 's/^topgit-//' )

-include config.mak
SHELL = $(SHELL_PATH)

ifneq ($(strip $(version)),)
	version_arg = -e s/TG_VERSION=.*/TG_VERSION=$(version)/
endif

.PHONY: FORCE

all::	shell_compatibility_test precheck $(commands_out) $(utils_out) $(hooks_out) bin-wrappers/tg $(help_out) tg-tg.txt

please_set_SHELL_PATH_to_a_more_modern_shell:
	@$$(:)

shell_compatibility_test: please_set_SHELL_PATH_to_a_more_modern_shell

tg $(commands_out) $(utils_out) $(hooks_out): % : %.sh Makefile TG-BUILD-SETTINGS
	@echo "[SED] $@"
	@sed -e '1s|#!.*/sh|#!$(SHELL_PATH_SQ)|' \
		-e 's#@cmddir@#$(cmddir)#g;' \
		-e 's#@hooksdir@#$(hooksdir)#g' \
		-e 's#@bindir@#$(bindir)#g' \
		-e 's#@sharedir@#$(sharedir)#g' \
		-e 's#@mingitver@#$(GIT_MINIMUM_VERSION)#g' \
		-e 's|@SHELL_PATH@|$(SHELL_PATH_SQ)|' \
		$(version_arg) \
		$@.sh >$@+ && \
	chmod +x $@+ && \
	mv $@+ $@

bin-wrappers/tg : $(commands_out) $(utils_out) $(hooks_out) tg
	@echo "[WRAPPER] $@"
	@[ -d bin-wrappers ] || mkdir bin-wrappers
	@echo '#!$(SHELL_PATH_SQ)' >"$@"
	@curdir="$$(pwd -P)"; \
	 echo "TG_INST_CMDDIR='$$curdir' && export TG_INST_CMDDIR" >>"$@"; \
	 echo "TG_INST_SHAREDIR='$$curdir' && export TG_INST_SHAREDIR" >>"$@"; \
	 echo "TG_INST_HOOKSDIR='$$curdir' && export TG_INST_HOOKSDIR" >>"$@"; \
	 echo "exec '$$curdir/tg' \"\$$@\"" >>"$@"
	@chmod a+x "$@"

$(help_out): README create-help.sh
	@CMD=`echo $@ | sed -e 's/tg-//' -e 's/\.txt//'` && \
	echo '[HELP]' $$CMD && \
	$(SHELL_PATH) ./create-help.sh $$CMD

.PHONY: doc install-doc html

doc:: html

install-doc:: install-html

html:: topgit.html $(html_out)

tg-tg.txt: README create-html-usage.pl $(commands_in)
	@echo '[HELP] tg'
	@perl ./create-html-usage.pl --text < README > $@

topgit.html: README create-html-usage.pl $(commands_in)
	@echo '[HTML] topgit'
	@perl ./create-html-usage.pl < README | rst2html.py - $@

$(html_out): create-html.sh
	@CMD=`echo $@ | sed -e 's/tg-//' -e 's/\.html//'` && \
	echo '[HTML]' $$CMD && \
	$(SHELL_PATH) ./create-html.sh $$CMD

.PHONY: precheck

precheck:: tg
ifeq ($(DESTDIR),)
	@./$+ precheck
else
	@echo skipping precheck because DESTDIR is set
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
	rm -f tg $(commands_out) $(utils_out) $(hooks_out) $(help_out) topgit.html $(html_out)
	rm -f TG-BUILD-SETTINGS
	rm -rf bin-wrappers
	+@$(MAKE) -C t clean

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
	@if test x"$$BUILD_SETTINGS" != x"`cat $@ 2>/dev/null`"; then \
		echo "* new build settings"; \
		echo "$$BUILD_SETTINGS" >$@; \
	fi

test:: all
	+@$(MAKE) -C t all
