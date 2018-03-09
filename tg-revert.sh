#!/bin/sh
# TopGit revert command
# Copyright (C) 2015 Kyle J. McKay <mackyle@gmail.com>
# All rights reserved.
# GPLv2

USAGE="Usage: ${tgname:-tg} [...] revert (-f | -i | -n) [-q] [--tgish-only] [--no-deps] [--no-stash] [--exclude <ref>...] (<tagname> | --stash) [<ref>...]"
USAGE="$USAGE$lf   Or: ${tgname:-tg} [...] revert [-l] [--no-short] [--hash] [--tgish-only] [(--deps | --rdeps)] [--exclude <ref>...] (<tagname> | --stash) [(--[topgit-]heads] | <ref>...)]"

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
short=
hashonly=
headstopgit=

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
	--short|--short=*|--no-short)
		short="$1"
		;;
	--hash|--hash-only)
		hashonly=1
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
		case "${1#--exclude=}" in refs/*) rn="${1#--exclude=}";; *) rn="refs/heads/${1#--exclude=} refs/$topbases/${1#--exclude=}"; esac
		exclude="$exclude $rn";;
	--exclude)
		shift
		[ -n "$1" ] || die "--exclude requires a ref name"
		case "$1" in refs/*) rn="$1";; *) rn="refs/heads/$1 refs/$topbases/$1"; esac
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

[ -z "$list$short$hashonly" ] || [ -z "$force$interact$dryrun$nodeps$nostash" ] || usage 1
[ -z "$force$interact$dryrun" ] || [ -z "$list$short$hashonly$deps$rdeps" ] || usage 1
[ -z "$deps" ] || [ -z "$rdeps" ] || usage 1
[ -n "$list$force$interact$dryrun" ] || list=1
[ -z "$list" ] || [ -n "$short" ] || if [ -n "$hashonly" ]; then short="--no-short"; else short="--short"; fi
[ -n "$1" ] || { echo "Tag name required" >&2; usage 1; }
tagname="$1"
shift
[ "$1" != "--heads-independent" ] || { shift; set -- --heads "$@"; }
if [ "$1" = "--topgit-heads" ]; then
	shift
	headstopgit=1
	set -- "--heads" "$@"
fi
[ -n "$list" ] || [ "$1" != "--heads" ] || usage 1
[ "$tagname" != "--stash" ] || tagname=refs/tgstash
case "$tagname" in --stash"@{"*"}")
	strip="${tagname#--stash??}"
	strip="${strip%?}"
	tagname="refs/tgstash@{$strip}"
esac
refname="$tagname"
case "$refname" in HEAD|refs/*);;*)
	suffix="${refname%@*}"
	suffix="${refname#$suffix}"
	refname="${refname%$suffix}"
	if reftest="$(git rev-parse --revs-only --symbolic-full-name "$refname" -- 2>/dev/null)" &&
	   [ -n "$reftest" ]; then
		refname="$reftest$suffix"
	else
		if hash="$(git rev-parse --quiet --verify "$refname$suffix")"; then
			refname="$hash"
		else
			refname="refs/tags/$refname$suffix"
		fi
	fi
esac
reftype=tag
case "$refname" in refs/tags/*) tagname="${refname#refs/tags/}";; *) reftype=ref; tagname="$refname"; esac
git rev-parse --verify --quiet "$refname^{tag}" -- >/dev/null || die "not annotated/signed tag: $refname"
tgf="$(get_temp tag)"
trf="$(get_temp refs)"
tagdataref="$refname^{tag}"
while
	git cat-file tag "$tagdataref" >"$tgf"t || die "cannot read tag: $refname"
	sed -ne '/^-----BEGIN TOPGIT REFS-----$/,/^-----END TOPGIT REFS-----$/p' <"$tgf"t |
	sed -ne "/^\\($octet20\\) \\(refs\/[^ $tab][^ $tab]*\\)\$/{s//\\2 \\1/;p;}" |
	sed -e "s,^refs/$oldbases/,refs/$topbases/,g" |
	sort -u -b -k1,1 >"$trf"
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
vcnt=$(( $(cut -d ' ' -f 2 <"$trf" | git cat-file $gcfbopt --batch-check='%(objectname)' | grep -v ' missing$' | wc -l) ))
[ "$rcnt" -eq "$vcnt" ] || die "$reftype $tagname contains $rcnt ref(s) but only $vcnt are still valid"
cat "$trf" >"$tg_ref_cache"
create_ref_dirs
tg_ref_cache_only=1
tg_read_only=1

get_recorded_ref()
{
	printf '%s\n' "$1" | join - "$trf" | cut -d ' ' -f 2 || :
}

show_topgit_heads()
{
	topics="$(get_temp topics)"
	topics2="$(get_temp topics)"
	deplist="$(get_temp deplist)"
	<"$trf" >"$topics" \
	sed -e '\,^refs/'"$topbasesrx"'/,!d' -e 's,^refs/'"$topbasesrx"'/,refs/heads/,' -e 's/ .*//'
	while read -r oneref; do
		_rev="$(get_recorded_ref "$oneref")" && [ -n "$_rev" ] || continue
		printf '%s\n' "$oneref" >>"$topics2"
		git cat-file blob "$_rev:.topdeps" 2>/dev/null | awk '{print}'
	done <"$topics" | sed -e 's,^,refs/heads/,' | sort -u >"$deplist"
	topics="$topics2"
	join -v 1 "$topics" "$deplist"
}

show_indep_heads()
{
	srt="$(get_temp sort)"
	sort -b -k2,2 <"$trf" >"$srt"
	git merge-base --independent $(cut -d ' ' -f 2 <"$srt") |
	sort -b -k1,1 |
	join -2 2 -o 2.1 - "$srt" |
	sort
}

show_heads()
{
	if [ -n "$headstopgit" ]; then
		show_topgit_heads "$@"
	else
		show_indep_heads "$@"
	fi
}

[ $# -ne 0 ] || [ -z "$rdeps$deps" ] || { set -- --heads; headstopgit=1; }
[ $# -ne 1 ] || [ -z "$deps" ] || [ "$1" != "--heads" ] || { deps=; set --; }
if [ $# -eq 1 ] && [ "$1" = "--heads" ]; then
	set -- $(show_heads)
fi

is_tgish() {
	case "$1" in
		refs/"$topbases"/*)
			ref_exists "refs/heads/${1#refs/$topbases/}"
			;;
		refs/heads/*)
			ref_exists "refs/$topbases/${1#refs/heads/}"
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
	case " $refs " in *" $rn "*);;*)
		refs="${refs:+$refs }$rn"
		if [ -z "$list" ] && { [ -z "$nodeps" ] || [ -z "$exp" ]; } && is_tgish "$rn"; then
			case "$rn" in
			refs/"$topbases"/*)
				refs="$refs refs/heads/${rn#refs/$topbases/}"
				;;
			refs/heads/*)
				refs="$refs refs/$topbases/${rn#refs/heads/}"
				;;
			esac
		fi
	esac
done

show_dep() {
	case "$exclude" in *" refs/heads/$_dep "*) return; esac
	case " $seen_deps " in *" $_dep "*) return 0; esac
	seen_deps="${seen_deps:+$seen_deps }$_dep"
	[ -z "$tgish" ] || [ -n "$_dep_is_tgish" ] || return 0
	printf 'refs/heads/%s\n' "$_dep"
	[ -z "$_dep_is_tgish" ] ||
	printf 'refs/%s/%s\n' "$topbases" "$_dep"
}

show_deps()
{
	no_remotes=1
	recurse_deps_exclude=
	while read _b && [ -n "$_b" ]; do
		case "$exclude" in *" $_b "*) continue; esac
		if ! is_tgish "$_b"; then
			[ -z "$tgish" ] || continue
			printf '%s\n' "$_b"
			continue
		fi
		case "$_b" in refs/"$topbases"/*) _b="refs/heads/${_b#refs/$topbases/}"; esac
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
	[ -z "$tgish" ] || [ -n "$_dep_is_tgish" ] || return 0
	v_ref_exists_rev_short _depshort "refs/heads/$_dep" $short
	if [ -n "$hashonly" ]; then
		printf '%s %s\n' "$_depchain" "$_depshort"
	else
		printf '%s %s\n' "$_depchain" "${_depshort}~$_dep"
	fi
}

show_rdeps()
{
	no_remotes=1
	show_break=
	seen_deps=
	[ "$short" != "--short" ] || v_get_core_abbrev _dummy
	while read _b && [ -n "$_b" ]; do
		case "$exclude" in *" $_b "*) continue; esac
		if ! is_tgish "$_b"; then
			[ -z "$tgish" ] || continue
			[ -z "$showbreak" ] || echo
			showbreak=1
			v_ref_exists_rev_short _bshort "refs/heads/$_b" $short
			if [ -n "$hashonly" ]; then
				printf '%s\n' "$_bshort"
			else
				printf '%s\n' "${_bshort}~$_b"
			fi
			continue
		fi
		case "$_b" in refs/"$topbases"/*) _b="refs/heads/${_b#refs/$topbases/}"; esac
		_b="${_b#refs/heads/}"
		case " $seen_deps " in *" $_b "*) continue; esac
		seen_deps="$seen_deps $_b"
		[ -z "$showbreak" ] || echo
		showbreak=1
		v_ref_exists_rev_short _bshort "refs/heads/$_b" $short
		{
			if [ -n "$hashonly" ]; then
				printf '%s\n' "$_bshort"
			else
				printf '%s\n' "${_bshort}~$_b"
			fi
			recurse_preorder=1
			recurse_deps show_rdep "$_b"
		} | sed -e 's/[^ ][^ ]*[ ]/  /g' -e 's/~/ /'
	done
}

refslist() {
	[ -z "$refs" ] || sed 'y/ /\n/' <<-EOT
	$refs
	EOT
}

if [ -n "$list" ]; then
	if [ -z "$deps$rdeps" ]; then
		# accelerate showing everything in full
		if [ -z "$refs$exclude" ] && [ z"$short" = z"--no-short" ]; then
			if [ -n "$hashonly" ]; then
				<"$trf" sed -n 's/^[^ ][^ ]* \([^ ][^ ]*\)$/\1/p'
			else
				<"$trf" sed -n 's/^\([^ ][^ ]*\) \([^ ][^ ]*\)$/\2 \1/p'
			fi
			exit
		fi
		while read -r name rev; do
			case "$exclude" in *" $name "*) continue; esac
			[ -z "$refs" ] || case " $refs " in *" $name "*);;*) continue; esac
			[ -z "$tgish" ] || is_tgish "$name" || continue
			if [ -n "$hashonly" ]; then
				printf '%s\n' "$(git rev-parse --verify --quiet $short "$rev" --)"
			else
				printf '%s %s\n' "$(git rev-parse --verify --quiet $short "$rev" --)" "$name"
			fi
		done <"$trf"
		exit 0
	fi
	if [ -n "$deps" ]; then
		refslist | show_deps | sort -u -b -k1,1 |
		join - "$trf" |
		while read -r name rev; do
			if [ -n "$hashonly" ]; then
				printf '%s\n' "$(git rev-parse --verify --quiet $short "$rev" --)"
			else
				printf '%s %s\n' "$(git rev-parse --verify --quiet $short "$rev" --)" "$name"
			fi
		done
		exit 0
	fi
	refslist | show_rdeps
	exit 0
fi
insn="$(get_temp isns)"

get_short() {
	[ -n "$interact" ] || { printf '%s' "$1"; return 0; }
	git rev-parse --verify --quiet --short "$1" --
}

if [ -n "$nodeps" ] || [ -z "$refs" ]; then
	while read -r name rev; do
		case "$exclude" in *" $name "*) continue; esac
		[ -z "$refs" ] || case " $refs " in *" $name "*);;*) continue; esac
		[ -z "$tgish" ] || is_tgish "$name" || continue
		printf 'revert %s %s\n' "$(get_short "$rev")" "$name"
	done <"$trf" | sort -u -b -k3,3 >"$insn"
else
	refslist | show_deps | sort -u -b -k1,1 |
	join - "$trf" |
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
	run_editor "$insn" ||
	die "there was a problem with the editor '$tg_editor'"
	git stripspace -s <"$insn" >"$insn"+
	mv -f "$insn"+ "$insn"
	[ -s "$insn" ] || die "nothing to do"
	while read -r op hash ref; do
		[ "$op" = "r" ] || [ "$op" = "revert" ] ||
		die "invalid op in instruction: $op $hash $ref"
		case "$ref" in refs/?*);;*)
			die "invalid ref in instruction: $op $hash $ref"
		esac
		ref_exists "$ref" ||
		die "unknown ref in instruction: $op $hash $ref"
	done <"$insn"
fi
msg="tgrevert: $reftype $tagname ($(( $(wc -l <"$insn") )) command(s))"
if [ -z "$dryrun" ]; then
	if [ -z "$nostash" ]; then
		tg tag -q -q --allow-any --none-ok -m "$msg" --stash || die "requested --stash failed"
	else
		tg tag --allow-any --none-ok --anonymous || die "anonymous --stash failed"
	fi
fi
refwidth="$(git config --get --int core.abbrev 2>/dev/null)" || :
[ -n "$refwidth" ] || refwidth=7
[ $refwidth -ge 4 ] && [ $refwidth -le 40 ] || refwidth=7
nullref="$(printf '%.*s' $refwidth "$nullsha")"
notewidth=$(( $refwidth + 4 + $refwidth ))
srh=
[ -n "$dryrun" ] || srh="$(git symbolic-ref --quiet HEAD)" || :
cut -d ' ' -f 3 <"$insn" | sort -u -b -k1,1 | join - "$trf" |
while read -r name rev; do
	orig="$(git rev-parse --verify --quiet "$name" --)" || :
	init_reflog "$name"
	if [ "$rev" != "$orig" ]; then
		[ -z "$dryrun" ] && [ -n "$quiet" ] ||
		origsh="$(git rev-parse --verify --short --quiet "$name" --)" || :
		if [ -z "$dryrun" ]; then
			if [ -n "$srh" ] && [ "$srh" = "$name" ]; then
				[ -n "$quiet" ] || warn "detaching HEAD to revert $name"
				detachat="$orig"
				[ -n "$detachat" ] || detachat="$(make_empty_commit)"
				git update-ref -m "tgrevert: detach HEAD to revert $name" --no-deref HEAD "$detachat" || die "detach failed"
				[ -n "$quiet" ] || warn "$(git --no-pager log -n 1 --format=format:'HEAD is now at %h... %s' HEAD)"
			fi
			git update-ref -m "$msg" "$name" "$rev"
		fi
		if [ -n "$dryrun" ] || [ -z "$quiet" ]; then
			revsh="$(git rev-parse --verify --short --quiet "$rev" --)" || :
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
		: #[ -z "$dryrun" ] && [ -n "$quiet" ] || printf "* %-*s  %s\n" $notewidth "[no change]" "$name"
	fi
done

exit 0
