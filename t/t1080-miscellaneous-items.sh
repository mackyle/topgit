#!/bin/sh

test_description='test miscellaneous tg.sh behaviors'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

test_plan 3

obj_count() {
	set -- $(git -C "${1:-.}" count-objects) || die git count-objects failed
	test z"${1%%[!0-9]*}" != z || die git count-objects returned nothing
	echo "${1%%[!0-9]*}"
}

test_expect_success 'func check' '
	test_create_repo check && cd check &&
	test $(obj_count) -eq 0 &&
	echo hi | git hash-object -t blob -w --stdin >/dev/null &&
	test $(obj_count) -eq 1 &&
	mtblob="$(git hash-object -t blob -w --stdin </dev/null)" &&
	test z"$mtblob" != z &&
	test $(obj_count) -eq 2 &&
	test_when_finished mtblob=$mtblob
'

[ -n "$mtblob" ] || die missing mtblob hash

test_expect_success 'no empty GIT_OBJECT_DIRECTORY' '
	test_create_repo ro && cd ro &&
	tg_test_include &&
	{
		test z"${GIT_OBJECT_DIRECTORY}" != z ||
		test z"${GIT_OBJECT_DIRECTORY+set}" != z"set"
	} &&
	test_must_fail printenv GIT_OBJECT_DIRECTORY >/dev/null
'

test_expect_success 'tg --make-empty-blob' '
	test_create_repo main &&
	test_create_repo alt &&
	test $(obj_count main) -eq 0 &&
	test $(obj_count alt) -eq 0 &&
	(cd main && tg --make-empty-blob) &&
	test $(obj_count main) -eq 1 &&
	test $(obj_count alt) -eq 0 &&
	rm -rf main alt &&
	test_create_repo main &&
	test_create_repo alt &&
	test $(obj_count main) -eq 0 &&
	test $(obj_count alt) -eq 0 &&
	TG_OBJECT_DIRECTORY="$PWD/alt/.git/objects" &&
	export TG_OBJECT_DIRECTORY &&
	(cd main && tg --make-empty-blob) &&
	test $(obj_count main) -eq 1 &&
	test $(obj_count alt) -eq 0 &&
	rm -rf main alt &&
	test_create_repo main &&
	test_create_repo alt &&
	test $(obj_count main) -eq 0 &&
	test $(obj_count alt) -eq 0 &&
	mkdir -p alt/.git/objects/info &&
	>>alt/.git/objects/info/alternates &&
	(cd main && tg --make-empty-blob) &&
	test $(obj_count main) -eq 0 &&
	test $(obj_count alt) -eq 1
'

test_done
