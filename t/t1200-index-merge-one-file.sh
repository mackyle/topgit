#!/bin/sh

test_description='check tg index-merge-one-file works correctly'

. ./test-lib.sh

test_plan 325

version1="$(printf '%s\n' one two three | git hash-object -w -t blob --stdin)" || die
version2="$(printf '%s\n' alpha beta gamma | git hash-object -w -t blob --stdin)" || die
version3="$(printf '%s\n' setup check | git hash-object -w -t blob --stdin)" || die

test_asv_cache '
	commit1	sha1	4cb29ea
	commit2	sha1	85c3040
	commit3	sha1	2488d99

	commit1	sha256	c5df06a
	commit2	sha256	404b87a
	commit3	sha256	20ef10c
'
test_v_asv comit1 commit1
test_v_asv comit2 commit2
test_v_asv comit3 commit3

cat <<EOT >check
100644 $comit1 1	test
100644 $comit2 2	test
100644 $comit3 3	test
EOT

tg_exec_path="$(tg --exec-path)" && [ -n "$tg_exec_path" ] || die
tg_imof="$tg_exec_path/tg--index-merge-one-file"
[ -f "$tg_imof" ] && [ -x "$tg_imof" ] || die

write_script run-index-merge-one-file <<EOT || die
>"$PWD/.toolran" &&
"$tg_imof" \$USE_STRATEGY "\$@"
EOT

# $1, $2, $3 => "<n>" in $version<n> for hash of base (1), ours (2), theirs (3) stages
# $4 file name to use for all three
prepare_test() {
	rm -f .git/index
	[ "$1$2$3" = "000" ] ||
	{
		[ -z "$1" ] || [ "$1" = "0" ] ||
			eval printf \''100644 %s 1\011%s\n'\' "\"\$version$1\"" '"$4"' #'
		[ -z "$2" ] || [ "$2" = "0" ] ||
			eval printf \''100644 %s 2\011%s\n'\' "\"\$version$2\"" '"$4"' #'
		[ -z "$1" ] || [ "$3" = "0" ] ||
			eval printf \''100644 %s 3\011%s\n'\' "\"\$version$3\"" '"$4"' #'
	} | git update-index --index-info
}

# $1 expected result
#   0 is none
#   1, 2 or 3 is $version<n> hash at stage 0
#   -1 is 2 or more stage >0 entries but no stage 0 entries
# $2 expected file name for all entries
check_index() {
	cnt=0
	badname=
	badmode=
	sawstage0=
	while read mode hash stage name junk && [ -n "$name" ]; do
		cnt=$(( $cnt + 1 ))
		[ "$name" = "$2" ] || badname=1
		[ "$mode" = "100644" ] || badmode=1
		[ "$stage" != "0" ] || sawstage0="${hash:-1}"
	done <<-EOT
	$(git ls-files --full-name -s :/)
	EOT
	[ -z "$badname" ] || say_color error "# found wrong name in index"
	[ -z "$badmode" ] || say_color error "# found wrong (not 100644) mode in index"
	isbad=
	if [ "$1" = "0" ]; then
		if [ $cnt -gt 0 ]; then
			isbad=1
			say_color error "# expected no index entries, found $cnt"
		fi
	elif [ "$1" = "-1" ]; then
		if [ $cnt -lt 2 ]; then
			isbad=1
			say_color error "# expected at least 2 index entries, found $cnt"
		fi
		if [ -n "$sawstage0" ]; then
			isbad=1
			say_color error "# expected only conflict index stages but found stage 0"
		fi
	else
		eval check="\"\$version$1\""
		if [ $cnt -ne 1 ]; then
			isbad=1
			say_color error "# expected exactly one index entry, found $cnt"
		elif [ -z "$sawstage0" ]; then
			isbad=1
			say_color error "# expected exactly one stage 0 index entry"
		elif [ "$check" != "$sawstage0" ]; then
			isbad=1
			say_color error "# expected stage 0 hash $check but found $sawstage0"
		fi
	fi
	[ -z "$isbad" ] || git ls-files --full-name --abbrev -s | sed 's/^/# /'
	return ${isbad:-0}
}

check_table() {
	if [ "$1" = "3" ]; then
		shift
		check_index "-1" "$@"
	else
		check_index "$@"
	fi
}

run_index_merge() {
	strat=
	case "$1" in
		'r') strat="--remove";;
		't') strat="--theirs";;
		'm') strat="--merge";;
		'o');;
		  *) die;;
	esac
	sane_unset USE_STRATEGY
	[ -z "$strat" ] || USE_STRATEGY="$strat" && export USE_STRATEGY
	rm -f ".toolran" ".git/index-save"
	cp -f ".git/index" ".git/index-save"
	#ucnt="$(( $(git ls-files --unmerged --full-name --abbrev :/ | wc -l) ))" || :
	git merge-index "$PWD/run-index-merge-one-file" -a || :
	[ -e ".toolran" ] ||
	(
		GIT_INDEX_FILE=".git/index-save" && export GIT_INDEX_FILE &&
		ucnt="$(( $(git ls-files --unmerged --full-name --abbrev :/ | wc -l) ))" || : &&
		[ "$ucnt" = "0" ]
	) ||
	{
		say_color error "git merge-index did not run our tool"
		return 1
	}
}

test_expect_success 'setup' '
	prepare_test 1 2 3 test &&
	git ls-files --full-name --abbrev -s >lsfiles &&
	test_cmp lsfiles check
'

while read base ours theirs strategy tgresult gresult; do
	test_expect_success "b=$base o=$ours t=$theirs s=$strategy r=$tgresult .topdeps" '
		prepare_test "$base" "$ours" "$theirs" ".topdeps" &&
		run_index_merge "$strategy" &&
		check_table "$tgresult" ".topdeps"
	'
	test_expect_success "b=$base o=$ours t=$theirs s=$strategy r=$tgresult .topmsg" '
		prepare_test "$base" "$ours" "$theirs" ".topmsg" &&
		run_index_merge "$strategy" &&
		check_table "$tgresult" ".topmsg"
	'
	test_expect_success "b=$base o=$ours t=$theirs s=$strategy r=$gresult testfile" '
		prepare_test "$base" "$ours" "$theirs" "testfile" &&
		run_index_merge "$strategy" &&
		check_table "$gresult" "testfile"
	'
# Test Table
# BASE OURS THEIRS STRATEGY TGRESULT GRESULT
# where BASE, OURS, THEIRS can be 0 (none), 1 (version1) or 2 (version2)
# STRATEGY is 'r' (remove), 't' (theirs), 'o' (ours) or 'm' (merge)
# RESULT is 0, 1, 2 or 3 (conflicted)
done <<EOT
0 0 0 r 0 0
0 0 0 t 0 0
0 0 0 o 0 0
0 0 0 m 0 0
0 0 1 r 0 1
0 0 1 t 1 1
0 0 1 o 0 1
0 0 1 m 1 1
0 0 2 r 0 2
0 0 2 t 2 2
0 0 2 o 0 2
0 0 2 m 2 2
0 1 0 r 0 1
0 1 0 t 0 1
0 1 0 o 1 1
0 1 0 m 1 1
0 1 1 r 0 1
0 1 1 t 1 1
0 1 1 o 1 1
0 1 1 m 1 1
0 1 2 r 0 3
0 1 2 t 2 3
0 1 2 o 1 3
0 1 2 m 3 3
0 2 0 r 0 2
0 2 0 t 0 2
0 2 0 o 2 2
0 2 0 m 2 2
0 2 1 r 0 3
0 2 1 t 1 3
0 2 1 o 2 3
0 2 1 m 3 3
0 2 2 r 0 2
0 2 2 t 2 2
0 2 2 o 2 2
0 2 2 m 2 2
1 0 0 r 0 0
1 0 0 t 0 0
1 0 0 o 0 0
1 0 0 m 0 0
1 0 1 r 0 0
1 0 1 t 1 0
1 0 1 o 0 0
1 0 1 m 0 0
1 0 2 r 0 3
1 0 2 t 2 3
1 0 2 o 0 3
1 0 2 m 3 3
1 1 0 r 0 0
1 1 0 t 0 0
1 1 0 o 1 0
1 1 0 m 0 0
1 1 1 r 0 1
1 1 1 t 1 1
1 1 1 o 1 1
1 1 1 m 1 1
1 1 2 r 0 2
1 1 2 t 2 2
1 1 2 o 1 2
1 1 2 m 2 2
1 2 0 r 0 3
1 2 0 t 0 3
1 2 0 o 2 3
1 2 0 m 3 3
1 2 1 r 0 2
1 2 1 t 1 2
1 2 1 o 2 2
1 2 1 m 2 2
1 2 2 r 0 2
1 2 2 t 2 2
1 2 2 o 2 2
1 2 2 m 2 2
2 0 0 r 0 0
2 0 0 t 0 0
2 0 0 o 0 0
2 0 0 m 0 0
2 0 1 r 0 3
2 0 1 t 1 3
2 0 1 o 0 3
2 0 1 m 3 3
2 0 2 r 0 0
2 0 2 t 2 0
2 0 2 o 0 0
2 0 2 m 0 0
2 1 0 r 0 3
2 1 0 t 0 3
2 1 0 o 1 3
2 1 0 m 3 3
2 1 1 r 0 1
2 1 1 t 1 1
2 1 1 o 1 1
2 1 1 m 1 1
2 1 2 r 0 1
2 1 2 t 2 1
2 1 2 o 1 1
2 1 2 m 1 1
2 2 0 r 0 0
2 2 0 t 0 0
2 2 0 o 2 0
2 2 0 m 0 0
2 2 1 r 0 1
2 2 1 t 1 1
2 2 1 o 2 1
2 2 1 m 1 1
2 2 2 r 0 2
2 2 2 t 2 2
2 2 2 o 2 2
2 2 2 m 2 2
EOT

test_done
