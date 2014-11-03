# NOTE: Requires GNU make

all::

# This should give a reasonable hint that GNU make is required in non-GNU make
.error GNU_make_is_required:

# This should be fatal in non-GNU make
export MAKE

prefix ?= $(HOME)
bindir = $(prefix)/bin
cmddir = $(prefix)/libexec/topgit
sharedir = $(prefix)/share/topgit
hooksdir = $(cmddir)/hooks

commands_in := $(wildcard tg-*.sh)
hooks_in = hooks/pre-commit.sh

commands_out = $(patsubst %.sh,%,$(commands_in))
hooks_out = $(patsubst %.sh,%,$(hooks_in))
help_out = $(patsubst %.sh,%.txt,tg-help.sh $(commands_in))
html_out = $(patsubst %.sh,%.html,tg-help.sh tg-tg.sh $(commands_in))

version := $(shell test -d .git && git describe --match "topgit-[0-9]*" --abbrev=4 --dirty 2>/dev/null | sed -e 's/^topgit-//' )

-include config.mak

ifneq ($(strip $(version)),)
	version_arg = -e s/TG_VERSION=.*/TG_VERSION=$(version)/
endif

.PHONY: FORCE

all::	precheck $(commands_out) $(hooks_out) $(help_out)

tg $(commands_out) $(hooks_out): % : %.sh Makefile TG-PREFIX
	@echo "[SED] $@"
	@sed -e 's#@cmddir@#$(cmddir)#g;' \
		-e 's#@hooksdir@#$(hooksdir)#g' \
		-e 's#@bindir@#$(bindir)#g' \
		-e 's#@sharedir@#$(sharedir)#g' \
		$(version_arg) \
		$@.sh >$@+ && \
	chmod +x $@+ && \
	mv $@+ $@

$(help_out): README create-help.sh
	@CMD=`echo $@ | sed -e 's/tg-//' -e 's/\.txt//'` && \
	echo '[HELP]' $$CMD && \
	./create-help.sh $$CMD

.PHONY: html

html:: topgit.html $(html_out)

topgit.html: README
	@echo '[HTML] topgit'
	@rst2html.py README $@

$(html_out): create-html.sh
	@CMD=`echo $@ | sed -e 's/tg-//' -e 's/\.html//'` && \
	echo '[HTML]' $$CMD && \
	./create-html.sh $$CMD

.PHONY: precheck

precheck:: tg
ifeq ($(DESTDIR),)
	./$+ precheck
else
	@echo skipping precheck because DESTDIR is set
endif

.PHONY: install

install:: all
	install -d -m 755 "$(DESTDIR)$(bindir)"
	install tg "$(DESTDIR)$(bindir)"
	install -d -m 755 "$(DESTDIR)$(cmddir)"
	install $(commands_out) "$(DESTDIR)$(cmddir)"
	install -d -m 755 "$(DESTDIR)$(hooksdir)"
	install $(hooks_out) "$(DESTDIR)$(hooksdir)"
	install -d -m 755 "$(DESTDIR)$(sharedir)"
	install -m 644 $(help_out) "$(DESTDIR)$(sharedir)"
	install -m 644 README "$(DESTDIR)$(sharedir)/tg-tg.txt"
	install -m 644 leaves.awk "$(DESTDIR)$(sharedir)"

.PHONY: install-html

install-html:: html
	install -d -m 755 "$(DESTDIR)$(sharedir)"
	install -m 644 topgit.html $(html_out) "$(DESTDIR)$(sharedir)"

.PHONY: clean

clean::
	rm -f tg $(commands_out) $(hooks_out) $(help_out) topgit.html $(html_out)
	rm -f TG-PREFIX

define TRACK_PREFIX
$(bindir):$(cmddir):$(hooksdir):$(sharedir):$(version)
endef
export TRACK_PREFIX

TG-PREFIX: FORCE
	@if test x"$$TRACK_PREFIX" != x"`cat TG-PREFIX 2>/dev/null`"; then \
		echo "* new prefix flags"; \
		echo "$$TRACK_PREFIX" >TG-PREFIX; \
	fi
