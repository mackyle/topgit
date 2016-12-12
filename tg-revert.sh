#!/bin/sh
# TopGit revert command
# Copyright (C) 2015 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved.
# GPLv2

lf="$(printf '\n.')" && lf="${lf%?}"
tab="$(printf '\t.')" && tab="${tab%?}"
USAGE="Usage: ${tgname:-tg} [...] revert (-f | -i | -n) [-q] [--tgish-only] [--no-deps] [--no-stash] [--exclude <ref>...] (<tagname> | --stash) [<ref>...]"
USAGE="$USAGE$lf   Or: ${tgname:-tg} [...] revert [-l] [--tgish-only] [(--deps | --rdeps)] [--exclude <ref>...] (<tagname> | --stash) [(--heads | <ref>...)]"

usage()
{
	if [ "${1:-0}" != 0 ]; then
		printf '%s\n' "$USAGE" >&2
	else
		printf '%s\n' "$USAGE"
	fi
	exit ${1:-0}
}

## Parse options

force=
interact=
dryrun=
list=
deps=
rdeps=
tgish=
nodeps=
nostash=
exclude=
quiet=

while [ $# -gt 0 ]; do case "$1" in
	-h|--help)
		usage
		;;
	-q|--quiet)
		quiet=1
		;;
	-l|--list)
		list=1
		;;
	--deps|--deps-only)
		deps=1
		;;
	--rdeps)
		rdeps=1
		;;
	--tgish-only)
		tgish=1
		;;
	-f|--force)
		force=1
		;;
	-i|--interactive)
		interact=1
		;;
	-n|--dry-run)
		dryrun=1
		;;
	--no-deps)
		nodeps=1
		;;
	--no-stash)
		nostash=1
		;;
	--exclude=*)
		[ -n "${1#--exclude=}" ] || die "--exclude= requires a ref name"
		case "${1#--exclude=}" in refs/*) rn="${1#--exclude=}";; *) rn="refs/heads/${1#--exclude=} refs/top-bases/${1#--exclude=}"; esac
		exclude="$exclude $rn";;
	--exclude)
		shift
		[ -n "$1" ] || die "--exclude requires a ref name"
		case "$1" in refs/*) rn="$1";; *) rn="refs/heads/$1 refs/top-bases/$1"; esac
		exclude="$exclude $rn";;
	--)
		shift
		break
		;;
	--stash|--stash"@{"*"}")
		break
		;;
	-?*)
		echo "Unknown option: $1" >&2
		usage 1
		;;
	*)
		break
		;;
esac; shift; done
[ -z "$exclude" ] || exclude="$exclude "

[ -z "$list" -o -z "$force$interact$dryrun$nodeps$nostash" ] || usage 1
[ -z "$force$interact$dryrun" -o -z "$list$deps$rdeps" ] || usage 1
[ -z "$deps" -o -z "$rdeps" ] || usage 1
[ -n "$list$force$interact$dryrun" ] || list=1
[ -n "$1" ] || { echo "Tag name required" >&2; usage 1; }
tagname="$1"
shift
[ -n "$list" -o "$1" != "--heads" ] || usage 1
[ "$tagname" != "--stash" ] || tagname=refs/tgstash
case "$tagname" in --stash"@{"*"}")
	strip="${tagname#--stash??}"
	strip="${strip%?}"
	tagname="refs/tgstash@{$strip}"
esac
refname="$tagname"
case "$refname" in HEAD|refs/*) :;; *)
	suffix="${refname%@*}"
	suffix="${refname#$suffix}"
	refname="${refname%$suffix}"
	if reftest="$(git rev-parse --revs-only --symbolic-full-name "$refname" -- 2>/dev/null)" && \
	   [ -n "$reftest" ]; then
		refname="$reftest$suffix"
	else
		refname="refs/tags/$refname$suffix"
	fi
esac
reftype=tag
case "$refname" in refs/tags/*) tagname="${refname#refs/tags/}";; *) reftype=ref; tagname="$refname"; esac
git rev-parse --verify --quiet "$refname^{tag}" -- >/dev/null || die "not annotated/signed tag: $refname"
tgf="$(get_temp tag)"
trf="$(get_temp refs)"
tagdataref="$refname^{tag}"
while
	git cat-file tag "$tagdataref" >"$tgf" || die "cannot read tag: $refname"
	sed -ne '/^-----BEGIN TOPGIT REFS-----$/,/^-----END TOPGIT REFS-----$/p' <"$tgf" | \
	sed -ne "/^\\($octet20\\) \\(refs\/[^ $tab][^ $tab]*\\)\$/{s//\\2 \\1/;p;}" | \
	LC_ALL=C sort -u -b -k1,1 >"$trf"
	! [ -s "$trf" ]
do
	# If it's a tag of a tag, dereference it and try again
	read -r field tagtype <<-EOT || break
		$(sed -n '1,/^$/p' <"$tgf" | grep '^type [^ ][^ ]*$' || :)
	EOT
	[ "$tagtype" = "tag" ] || break
	read -r field tagdataref <<-EOT || break
		$(sed -n '1,/^$/p' <"$tgf" | grep '^object [^ ][^ ]*$' || :)
	EOT
	[ -n "$tagdataref" ] || break
	tagdataref="$tagdataref^{tag}"
	git rev-parse --verify --quiet "$tagdataref" -- >/dev/null || break
done
[ -s "$trf" ] || die "$reftype $tagname does not contain a TOPGIT REFS section"
rcnt=$(( $(wc -l <"$trf") ))
vcnt=$(( $(cut -d ' ' -f 2 <"$trf" | git cat-file --batch-check='%(objectname)' | grep -v ' missing$' | wc -l) ))
[ "$rcnt" -eq "$vcnt" ] || die "$reftime $tagname contains $rcnt ref(s) but only $vcnt are still valid"
cat "$trf" >"$tg_ref_cache"
create_ref_dirs
tg_ref_cache_only=1
tg_read_only=1

[ $# -ne 0 -o -z "$rdeps$deps" ] || set -- --heads
[ $# -ne 1 -o -z "$deps" -o "$1" != "--heads" ] || { deps=; set --; }
if [ $# -eq 1 -a "$1" = "--heads" ]; then
	srt="$(get_temp sort)"
	LC_ALL=C sort -b -k2,2 <"$trf" >"$srt"
	set -- $(
	git merge-base --independent $(cut -d ' ' -f 2 <"$srt") | \
	LC_ALL=C sort -b -k1,1 | \
	join -2 2 -o 2.1 - "$srt" | \
	LC_ALL=C sort)
fi

is_tgish() {
	case "$1" in
		refs/heads/*)
			ref_exists "refs/top-bases/${1#refs/heads/}"
			;;
		refs/top-bases/*)
			ref_exists "refs/heads/${1#refs/top-bases/}"
			;;
		*)
			! :
			;;
	esac
}

refs=
for b; do
	exp=
	case "$b" in refs/*) exp=1; rn="$b";; *) rn="refs/heads/$b"; esac
	ref_exists "$rn" || die "not present in tag data (try --list): $rn"
	case " $refs " in *" $rn "*) :;; *)
		refs="${refs:+$refs }$rn"
		if [ -z "$list" ] && [ -z "$nodeps" -o -z "$exp" ] && is_tgish "$rn"; then
			case "$rn" in
			refs/heads/*)
				refs="$refs refs/top-bases/${rn#refs/heads/}"
				;;
			refs/top-bases/*)
				refs="$refs refs/heads/${rn#refs/top-bases/}"
				;;
			esac
		fi
	esac
done

show_dep() {
	case "$exclude" in *" refs/heads/$_dep "*) return; esac
	case " $seen_deps " in *" $_dep "*) return 0; esac
	seen_deps="${seen_deps:+$seen_deps }$_dep"
	[ -z "$tgish" -o -n "$_dep_is_tgish" ] || return 0
	printf 'refs/heads/%s\n' "$_dep"
	[ -z "$_dep_is_tgish" ] || \
	printf 'refs/top-bases/%s\n' "$_dep"
}

show_deps()
{
	no_remotes=1
	recurse_deps_exclude=
	for _b; do
		case "$exclude" in *" $_b "*) continue; esac
		if ! is_tgish "$_b"; then
			[ -z "$tgish" ] || continue
			printf '%s\n' "$_b"
			continue
		fi
		case "$_b" in refs/top-bases/*) _b="refs/heads/${_b#refs/top-bases/}"; esac
		_b="${_b#refs/heads/}"
		case " $recurse_deps_exclude " in *" $_b "*) continue; esac
		seen_deps=
		_dep="$_b"; _dep_is_tgish=1; show_dep
		recurse_deps show_dep "$_b"
		recurse_deps_exclude="$recurse_deps_exclude $seen_deps"
	done
}

show_rdep()
{
	case "$exclude" in *" refs/heads/$_dep "*) return; esac
	[ -z "$tgish" -o -n "$_dep_is_tgish" ] || return 0
	printf '%s %s\n' "$_depchain" "$(ref_exists_rev_short "refs/heads/$_dep")~$_dep"
}

show_rdeps()
{
	no_remotes=1
	show_break=
	seen_deps=
	for _b; do
		case "$exclude" in *" $_b "*) continue; esac
		if ! is_tgish "$_b"; then
			[ -z "$tgish" ] || continue
			[ -z "$showbreak" ] || echo
			showbreak=1
			printf '%s\n' "$_b"
			continue
		fi
		case "$_b" in refs/top-bases/*) _b="refs/heads/${_b#refs/top-bases/}"; esac
		_b="${_b#refs/heads/}"
		case " $seen_deps " in *" $_b "*) continue; esac
		seen_deps="$seen_deps $_b"
		[ -z "$showbreak" ] || echo
		showbreak=1
		{
			echo "$(ref_exists_rev_short "refs/heads/$_b")~$_b"
			recurse_preorder=1
			recurse_deps show_rdep "$_b"
		} | sed -e 's/[^ ][^ ]*[ ]/  /g' -e 's/~/ /'
	done
}

if [ -n "$list" ]; then
	if [ -z "$deps$rdeps" ]; then
		while read -r name rev; do
			case "$exclude" in *" $name "*) continue; esac
			[ -z "$refs" ] || case " $refs " in *" $name "*) :;; *) continue; esac
			[ -z "$tgish" ] || is_tgish "$name" || continue
			printf '%s %s\n' "$(git rev-parse --verify --quiet --short "$rev" --)" "$name"
		done <"$trf"
		exit 0
	fi
	if [ -n "$deps" ]; then
		show_deps $refs | LC_ALL=C sort -u -b -k1,1 | \
		join - "$trf" | \
		while read -r name rev; do
			printf '%s %s\n' "$(git rev-parse --verify --quiet --short "$rev" --)" "$name"
		done
		exit 0
	fi
	show_rdeps $refs
	exit 0
fi
insn="$(get_temp isns)"

get_short() {
	[ -n "$interact" ] || { printf '%s' "$1"; return 0; }
	git rev-parse --verify --quiet --short "$1" --
}

if [ -n "$nodeps" -o -z "$refs" ]; then
	while read -r name rev; do
		case "$exclude" in *" $name "*) continue; esac
		[ -z "$refs" ] || case " $refs " in *" $name "*) :;; *) continue; esac
		[ -z "$tgish" ] || is_tgish "$name" || continue
		printf 'revert %s %s\n' "$(get_short "$rev")" "$name"
	done <"$trf" | LC_ALL=C sort -u -b -k3,3 >"$insn"
else
	show_deps $refs | LC_ALL=C sort -u -b -k1,1 | \
	join - "$trf" | \
	while read -r name rev; do
		printf 'revert %s %s\n' "$(get_short "$rev")" "$name"
	done >"$insn"
fi
if [ -n "$interact" ]; then
	count=$(( $(wc -l <"$insn") ))
	cat <<EOT >>"$insn"

# Revert using $refname data ($count command(s))
#
# Commands:
# r, revert = revert ref to specified hash
#
# Note that changing the hash value shown here will have NO EFFECT.
#
# If you remove a line here THAT REVERT WILL BE SKIPPED.
#
# However, if you remove everything, the revert will be aborted.
EOT
	run_editor "$insn" || \
	die "there was a problem with the editor '$tg_editor'"
	git stripspace -s <"$insn" >"$insn"+
	mv -f "$insn"+ "$insn"
	[ -s "$insn" ] || die "nothing to do"
	while read -r op hash ref; do
		[ "$op" = "r" -o "$op" = "revert" ] || \
		die "invalid op in instruction: $op $hash $ref"
		case "$ref" in refs/?*) :;; *)
			die "invalid ref in instruction: $op $hash $ref"
		esac
		ref_exists "$ref" || \
		die "unknown ref in instruction: $op $hash $ref"
	done <"$insn"
fi
msg="tgrevert: $reftype $tagname ($(( $(wc -l <"$insn") )) command(s))"
[ -n "$dryrun" -o -n "$nostash" ] || $tg tag -q --none-ok -m "$msg" --stash
refwidth="$(git config --get --int core.abbrev 2>/dev/null || :)"
[ -n "$refwidth" ] || refwidth=7
[ $refwidth -ge 4 -a $refwidth -le 40 ] || refwidth=7
nullref="$(printf '%.*s' $refwidth "$nullsha")"
notewidth=$(( $refwidth + 4 + $refwidth ))
srh=
[ -n "$dryrun" ] || srh="$(git symbolic-ref --quiet HEAD || :)"
cut -d ' ' -f 3 <"$insn" | LC_ALL=C sort -u -b -k1,1 | join - "$trf" | \
while read -r name rev; do
	orig="$(git rev-parse --verify --quiet "$name" -- || :)"
	if [ -n "$logrefupdates" -o "$name" = "refs/tgstash" ]; then
		case "$name" in refs/heads/*|refs/top-bases/*|refs/tgstash)
			mkdir -p "$git_dir/logs/$(dirname "$name")" 2>/dev/null || :
			{ >>"$git_dir/logs/$name" || :; } 2>/dev/null
		esac
	fi
	if [ "$rev" != "$orig" ]; then
		[ -z "$dryrun" -a -n "$quiet" ] || \
		origsh="$(git rev-parse --verify --short --quiet "$name" -- || :)"
		if [ -z "$dryrun" ]; then
			if [ -n "$srh" ] && [ "$srh" = "$name" ]; then
				[ -n "$quiet" ] || echo "Detaching HEAD to revert $name"
				detachat="$orig"
				[ -n "$detachat" ] || detachat="$(make_empty_commit)"
				git update-ref -m "tgrevert: detach HEAD to revert $name" --no-deref HEAD "$detachat"
				[ -n "$quiet" ] || git log -n 1 --format=format:'HEAD is now at %h... %s' HEAD
			fi
			git update-ref -m "$msg" "$name" "$rev"
		fi
		if [ -n "$dryrun" -o -z "$quiet" ]; then
			revsh="$(git rev-parse --verify --short --quiet "$rev" -- || :)"
			if [ -n "$origsh" ]; then
				hdr=' '
				[ -z "$dryrun" ] || hdr='-'
				printf '%s %s -> %s  %s\n' "$hdr" "$origsh" "$revsh" "$name"
			else
				hdr='*'
				[ -z "$dryrun" ] || hdr='-'
				printf '%s %s -> %s  %s\n' "$hdr" "$nullref" "$revsh" "$name"
			fi
		fi
	else
		[ -z "$dryrun" -a -n "$quiet" ] || printf "* %-*s  %s\n" $notewidth "[no change]" "$name"
	fi
done

exit 0
