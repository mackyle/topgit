#!/bin/sh

# tg--index-merge-one-file-topmerge -- auto merge a file without touching working tree
# Copyright (C) 2017 Kyle J. McKay
# All rights reserved.
# License GPLv2+

# TG_INST_CMDDIR => location of tg--index-merge-one-file script

[ -n "$TG_INST_CMDDIR" ] || case "$0" in */?*[!/]) TG_INST_CMDDIR="${0%/*}"; esac

[ -n "$TG_INST_CMDDIR" ] && [ -d "$TG_INST_CMDDIR" ] &&
[ -f "$TG_INST_CMDDIR/tg--index-merge-one-file" ] &&
[ -r "$TG_INST_CMDDIR/tg--index-merge-one-file" ] || {
	echo "fatal: missing tg--index-merge-one-file script" >&2
	exit 2
}

tg_index_mergetop_behavior="merge"
. "$TG_INST_CMDDIR/tg--index-merge-one-file"
