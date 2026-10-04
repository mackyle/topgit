#!/bin/sh

test_description='hook wrappers stop on failed or empty path lookups and upgrade safely'

. ./test-lib.sh

test_plan 4

test_expect_success 'setup wrapper and failing tg shims' '
	tg_test_setup_topgit &&
	cp .git/hooks/pre-commit wrapper &&
	mkdir fake &&
	write_script fake/tg <<-\EOF
		echo /ignored
		exit 19
	EOF
'

test_expect_success LASTOK 'failed path lookup preserves status without executing a hook' '
	test_env PATH="$PWD/fake:$PATH" test_expect_code 19 ./wrapper >actual 2>&1 &&
	test ! -s actual
'

test_expect_success 'empty successful path lookup stops with a clear error' '
	write_script fake/tg <<-\EOF &&
		exit 0
	EOF
	test_env PATH="$PWD/fake:$PATH" test_expect_code 1 ./wrapper >actual 2>&1 &&
	grep -q "empty hooks path" actual &&
	! grep -q "/pre-commit: not found" actual
'

test_expect_success 'upgrade both wrapper generations and preserve the original hook' '
	for generation in legacy successor; do
		for mode in exec chain; do
			case "$generation" in
				legacy) call="\"\$(tg --hooks-path)\"/pre-commit \"\$@\""; check="which \"tg\" > /dev/null";;
				successor) call="\"\$(\"tg\" --hooks-path)\"/pre-commit \"\$@\""; check="command -v \"tg\" >/dev/null 2>&1";;
			esac &&
			case "$mode" in
				exec) call="exec $call";;
				chain) call="$call || exit \$?";;
			esac &&
			write_script .git/hooks/pre-commit <<-EOF &&
				if $check; then $call; fi
				printf "%s\n" "\$@" >hook-ran
				exit 23
			EOF
			tg_test_setup_topgit &&
			test "$(grep -c -- --hooks-path .git/hooks/pre-commit)" = 1 &&
			test_expect_code 23 .git/hooks/pre-commit "one two" three &&
			printf "%s\n" "one two" three >expected &&
			test_cmp expected hook-ran || return
		done
	done
'

test_done
