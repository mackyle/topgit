#!/bin/sh

test_description='test tg tag creation'

TEST_NO_CREATE_REPO=1

. ./test-lib.sh

GNUPGHOME="$PWD/gnupg" &&
mkdir "$GNUPGHOME" &&
test -d "$GNUPGHOME" &&
chmod go-rwx "$GNUPGHOME" &&
export GNUPGHOME || die

gpgscript="$PWD/gpg-sign.sh"
gitgpg() {
	git -c gpg.program="$gpgscript" "$@"
}
tggpg() {
	tg -c gpg.program="$gpgscript" "$@"
}

test_plan 40

test_tolerate_failure 'gpg check and setup' '
	if gpg --version; then
		gpg --import "$TEST_DIRECTORY/$this_test/framework-key.gpg" &&
		gpg --import-ownertrust "$TEST_DIRECTORY/$this_test/framework-key.trust" &&
		write_script "$gpgscript" <<-\EOT &&
			exec gpg --batch --passphrase "framework" "$@"
		EOT
		test_create_repo gpg-repo &&
		cd gpg-repo &&
		test_commit gpg &&
		gitgpg tag -s -m "signed tag" signed-tag &&
		git tag -v signed-tag &&
		test_when_finished test_set_prereq GPG
	fi
'

if test_have_prereq GPG; then
	test_expect_success GPG 'gpg tests enabled' ': # gpg available and tested'
else
	test_expect_success !GPG 'gpg tests disabled' ': # gpg not available'
fi

test_expect_success 'setup' '
	test_create_repo empty &&
	test_create_repo tgonly &&
	test_create_repo nontg &&
	test_create_repo both &&
	test_create_repo outdated &&
	test_create_repo ann &&
	cd nontg &&
	test_commit one &&
	test_commit two &&
	git read-tree --empty &&
	git symbolic-ref HEAD refs/heads/other &&
	test_commit o1 &&
	test_commit o2 &&
	cd ../tgonly &&
	tg_test_create_branch t/branch1 : &&
	git checkout -f t/branch1 &&
	test_commit tgb1a &&
	test_commit tgb1b &&
	tg_test_create_branch t/branch2 : &&
	git checkout -f t/branch2 &&
	test_commit tgb2a &&
	test_commit tgb2b &&
	cd ../both &&
	test_commit m1 &&
	test_commit m2 &&
	git read-tree --empty &&
	git symbolic-ref HEAD refs/heads/other &&
	test_commit o1 &&
	test_commit o2 &&
	git read-tree --empty &&
	git symbolic-ref HEAD "$(tg --top-bases)/t/orphanbase" &&
	test_commit tgorphanbase &&
	git read-tree --empty &&
	git symbolic-ref HEAD refs/heads/tgbranch1 &&
	test_commit tgbefore1 &&
	tg_test_create_branch t/both1 tgbranch1 &&
	git checkout -f t/both1 &&
	test_commit both1 &&
	git read-tree --empty &&
	git symbolic-ref HEAD refs/heads/tgbranch2 &&
	test_commit tgbefore2 &&
	tg_test_create_branch t/both2 tgbranch2 &&
	git checkout -f t/both2 &&
	test_commit both2 &&
	cd ../outdated &&
	test_commit first &&
	tg_test_create_branch t/branch master &&
	test_commit second &&
	cd ../ann &&
	git read-tree --empty &&
	git symbolic-ref HEAD refs/heads/base1 &&
	test_commit base1 &&
	git read-tree --empty &&
	git symbolic-ref HEAD refs/heads/base2 &&
	test_commit base2 &&
	tg_test_create_branch t/branch1 base1 &&
	git checkout -f t/branch1 &&
	test_commit branch1 &&
	anc="$(git commit-tree -m "annihilate" -p HEAD "$(git rev-parse --verify "$(tg --top-bases)/t/branch1^{tree}" --)")" &&
	test -n "$anc" &&
	git update-ref -m "annihilate branch" HEAD "$anc" HEAD &&
	tg_test_create_branch t/hold1 t/branch1 &&
	tg_test_create_branch t/branch2 base2 &&
	git checkout -f t/branch2 &&
	test_commit branch2 &&
	tg_test_create_branch t/hold2 t/branch2 &&
	tg_test_create_branch t/holdboth t/branch1 t/branch2 &&
	test_when_finished test_set_prereq SETUP
'

test_expect_success SETUP 'empty fails' '
	cd empty &&
	test_must_fail tg tag --refs &&
	test_must_fail tg tag --refs --all &&
	test_must_fail tg tag --stash &&
	test_must_fail tg tag --stash --all &&
	test_must_fail tg tag --anonymous &&
	test_must_fail tg tag --anonymous --all &&
	test_must_fail tg tag foo &&
	test_must_fail tg tag foo --all
'

test_expect_success SETUP 'empty --allow-any fails' '
	cd empty &&
	test_must_fail tg tag --allow-any --refs &&
	test_must_fail tg tag --allow-any --refs --all &&
	test_must_fail tg tag --allow-any --stash &&
	test_must_fail tg tag --allow-any --stash --all &&
	test_must_fail tg tag --allow-any --anonymous &&
	test_must_fail tg tag --allow-any --anonymous --all &&
	test_must_fail tg tag --allow-any foo &&
	test_must_fail tg tag --allow-any foo --all
'

test_expect_success SETUP 'empty --none-ok fails' '
	cd empty &&
	test_must_fail tg tag --none-ok --refs &&
	test_must_fail tg tag --none-ok --refs --all &&
	test_must_fail tg tag --none-ok --stash &&
	test_must_fail tg tag --none-ok --stash --all &&
	tg tag --none-ok --anonymous && # --anonymous implies --quiet
	tg tag --none-ok --anonymous --all && # --anonymous implies --quiet
	test_must_fail tg tag --none-ok foo &&
	test_must_fail tg tag --none-ok foo --all
'

test_expect_success SETUP 'empty --none-ok --quiet succeeds' '
	cd empty &&
	test_must_fail tg tag --none-ok --quiet --refs && # bad HEAD
	tg tag --none-ok --quiet --refs --all &&
	tg tag --none-ok --quiet --stash &&
	tg tag --none-ok --quiet --stash --all &&
	tg tag --none-ok --quiet --anonymous &&
	tg tag --none-ok --quiet --anonymous --all &&
	test_must_fail tg tag --none-ok --quiet foo && # bad HEAD
	tg tag --none-ok --quiet foo --all
'

test_expect_success SETUP 'empty --none-ok --quiet --quiet succeeds' '
	cd empty &&
	test_must_fail tg tag --none-ok --quiet --quiet --refs && # bad HEAD
	tg tag --none-ok --quiet --quiet --refs --all &&
	tg tag --none-ok --quiet --quiet --stash &&
	tg tag --none-ok --quiet --quiet --stash --all &&
	tg tag --none-ok --quiet --quiet --anonymous &&
	tg tag --none-ok --quiet --quiet --anonymous --all &&
	test_must_fail tg tag --none-ok --quiet --quiet foo && # bad HEAD
	tg tag --none-ok --quiet foo --all
'

test_expect_success SETUP 'nontg fails' '
	cd nontg &&
	test_must_fail tg tag --refs &&
	test_must_fail tg tag --refs --all &&
	test_must_fail tg tag --stash &&
	test_must_fail tg tag --stash --all &&
	test_must_fail tg tag --anonymous &&
	test_must_fail tg tag --anonymous --all &&
	test_must_fail tg tag foo &&
	test_must_fail tg tag foo --all
'

test_expect_success SETUP 'nontg --allow-any succeeds' '
	cd nontg &&
	tg tag --allow-any --refs &&
	tg tag --allow-any --refs --all &&
	tg tag --allow-any --stash &&
	tg tag --allow-any --stash --all &&
	tg tag --allow-any --anonymous &&
	tg tag --allow-any --anonymous --all &&
	tg tag --allow-any foonon-1 &&
	tg tag --allow-any foonon-2 --all
'

test_expect_success SETUP 'tgonly succeeds' '
	cd tgonly &&
	tg tag --refs &&
	tg tag --refs --all &&
	tg tag --stash &&
	tg tag --stash --all &&
	tg tag --anonymous &&
	tg tag --anonymous --all &&
	tg tag fooonly-1 &&
	tg tag fooonly-2 --all
'

test_expect_success SETUP 'both succeeds' '
	cd both &&
	tg tag --refs &&
	tg tag --refs --all &&
	tg tag --stash &&
	tg tag --stash --all &&
	tg tag --anonymous &&
	tg tag --anonymous --all &&
	tg tag fooboth-1 &&
	tg tag fooboth-2 --all
'

test_expect_success SETUP 'non-stash outdated needs --allow-outdated' '
	cd outdated &&
	test_must_fail tg tag --refs t/branch &&
	test_must_fail tg tag sometag t/branch &&
	tg tag --allow-outdated --refs t/branch >/dev/null &&
	tg tag --allow-outdated sometag t/branch
'

test_expect_success SETUP '--stash allows outdated' '
	cd outdated &&
	tg tag --stash t/branch &&
	tg tag --anonymous t/branch
'

test_expect_success SETUP '--stash --all allows outdated' '
	cd outdated &&
	tg tag --stash &&
	tg tag --stash t/branch &&
	tg tag --anonymous &&
	tg tag --anonymous t/branch
'

test_expect_success SETUP 'non-stash --all allows outdated' '
	cd outdated &&
	tg tag --refs --all &&
	tg tag alltag --all
'

test_expect_success SETUP 'replace requires -f' '
	cd both &&
	test_must_fail git rev-parse --verify --quiet replaceme -- >/dev/null &&
	tg tag replaceme &&
	git rev-parse --verify --quiet replaceme -- >/dev/null &&
	test_must_fail  tg tag replaceme &&
	tg tag -f replaceme &&
	git rev-parse --verify --quiet replaceme -- >/dev/null
'

test_expect_success SETUP 'HEAD --refs' '
	cd both &&
	cat <<-EOT >expected &&
		-----BEGIN TOPGIT REFS-----
		56035f3acec7b94aa0d7c38efbf978c16711920c refs/heads/t/both2
		b468326bcc77566ad05a8ecdb613b0fc737472cf refs/heads/tgbranch2
		b468326bcc77566ad05a8ecdb613b0fc737472cf refs/top-bases/t/both2
		-----END TOPGIT REFS-----
	EOT
	tg tag --refs >actual &&
	test_cmp actual expected &&
	tg tag --refs HEAD >actual &&
	test_cmp actual expected &&
	tg tag --refs @ >actual &&
	test_cmp actual expected &&
	tg tag --refs @ HEAD >actual &&
	test_cmp actual expected &&
	tg tag --refs HEAD @ >actual &&
	test_cmp actual expected &&
	tg tag --refs HEAD HEAD >actual &&
	test_cmp actual expected &&
	tg tag --refs @ @ >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 't/both2 --refs' '
	cd both &&
	cat <<-EOT >expected &&
		-----BEGIN TOPGIT REFS-----
		56035f3acec7b94aa0d7c38efbf978c16711920c refs/heads/t/both2
		b468326bcc77566ad05a8ecdb613b0fc737472cf refs/heads/tgbranch2
		b468326bcc77566ad05a8ecdb613b0fc737472cf refs/top-bases/t/both2
		-----END TOPGIT REFS-----
	EOT
	tg tag --refs t/both2 >actual &&
	test_cmp actual expected &&
	tg tag --refs t/both2 t/both2 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 't/both1 --refs' '
	cd both &&
	cat <<-EOT >expected &&
		-----BEGIN TOPGIT REFS-----
		4c9786c5edd2095cad2226d787462fd2b9f28eac refs/heads/t/both1
		1f2e77bea71b03b41209b5233dda7458d7528ef1 refs/heads/tgbranch1
		1f2e77bea71b03b41209b5233dda7458d7528ef1 refs/top-bases/t/both1
		-----END TOPGIT REFS-----
	EOT
	tg tag --refs t/both1 >actual &&
	test_cmp actual expected &&
	tg tag --refs t/both1 t/both1 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 't/orphanbase --refs' '
	cd both &&
	cat <<-EOT >expected &&
		-----BEGIN TOPGIT REFS-----
		8b5716e97e03bafa97f7a5e7e0e155305dccac02 refs/top-bases/t/orphanbase
		-----END TOPGIT REFS-----
	EOT
	test_must_fail tg tag --refs t/orphanbase &&
	test_must_fail tg tag --refs refs/heads/t/orphanbase &&
	tg tag --refs "$(tg --top-bases)"/t/orphanbase >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 't/both1 t/both2 --refs' '
	cd both &&
	cat <<-EOT >expected &&
		-----BEGIN TOPGIT REFS-----
		4c9786c5edd2095cad2226d787462fd2b9f28eac refs/heads/t/both1
		56035f3acec7b94aa0d7c38efbf978c16711920c refs/heads/t/both2
		1f2e77bea71b03b41209b5233dda7458d7528ef1 refs/heads/tgbranch1
		b468326bcc77566ad05a8ecdb613b0fc737472cf refs/heads/tgbranch2
		1f2e77bea71b03b41209b5233dda7458d7528ef1 refs/top-bases/t/both1
		b468326bcc77566ad05a8ecdb613b0fc737472cf refs/top-bases/t/both2
		-----END TOPGIT REFS-----
	EOT
	tg tag --refs t/both1 t/both2 >actual &&
	test_cmp actual expected &&
	tg tag --refs t/both2 t/both1 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 't/both1 {base}t/orphanbase --refs' '
	cd both &&
	cat <<-EOT >expected &&
		-----BEGIN TOPGIT REFS-----
		4c9786c5edd2095cad2226d787462fd2b9f28eac refs/heads/t/both1
		1f2e77bea71b03b41209b5233dda7458d7528ef1 refs/heads/tgbranch1
		1f2e77bea71b03b41209b5233dda7458d7528ef1 refs/top-bases/t/both1
		8b5716e97e03bafa97f7a5e7e0e155305dccac02 refs/top-bases/t/orphanbase
		-----END TOPGIT REFS-----
	EOT
	tg tag --refs t/both1 "$(tg --top-bases)/t/orphanbase" >actual &&
	test_cmp actual expected &&
	tg tag --refs "$(tg --top-bases)/t/orphanbase" t/both1 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 't/both1 {base}t/orphanbase t/both2 --refs' '
	cd both &&
	cat <<-EOT >expected &&
		-----BEGIN TOPGIT REFS-----
		4c9786c5edd2095cad2226d787462fd2b9f28eac refs/heads/t/both1
		56035f3acec7b94aa0d7c38efbf978c16711920c refs/heads/t/both2
		1f2e77bea71b03b41209b5233dda7458d7528ef1 refs/heads/tgbranch1
		b468326bcc77566ad05a8ecdb613b0fc737472cf refs/heads/tgbranch2
		1f2e77bea71b03b41209b5233dda7458d7528ef1 refs/top-bases/t/both1
		b468326bcc77566ad05a8ecdb613b0fc737472cf refs/top-bases/t/both2
		8b5716e97e03bafa97f7a5e7e0e155305dccac02 refs/top-bases/t/orphanbase
		-----END TOPGIT REFS-----
	EOT
	tg tag --refs t/both1 "$(tg --top-bases)/t/orphanbase" t/both2 >actual &&
	test_cmp actual expected &&
	tg tag --refs "$(tg --top-bases)/t/orphanbase" t/both1 t/both2 >actual &&
	test_cmp actual expected &&
	tg tag --refs t/both2 t/both1 "$(tg --top-bases)/t/orphanbase" >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'explicit non-tgish fails --refs' '
	cd both &&
	test_must_fail tg tag --refs master &&
	test_must_fail tg tag --refs other &&
	test_must_fail tg tag --refs refs/heads/master &&
	test_must_fail tg tag --refs refs/heads/other &&
	test_must_fail tg tag --refs master other &&
	test_must_fail tg tag --refs other master &&
	test_must_fail tg tag --refs other refs/heads/master &&
	test_must_fail tg tag --refs refs/heads/other master
'

test_expect_success SETUP 'explicit non-tgish succeeds --allow-any --refs' '
	cd both &&
	cat <<-EOT >expected &&
		-----BEGIN TOPGIT REFS-----
		24863d9c5498b120622ba4b67b5de2a5c9b67a94 refs/heads/master
		-----END TOPGIT REFS-----
	EOT
	tg tag --allow-any --refs master >actual &&
	test_cmp actual expected &&
	tg tag --allow-any --refs refs/heads/master >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		-----BEGIN TOPGIT REFS-----
		516124ddbb5f9e2c33be37a1d6f3f2c4b0c23dd2 refs/heads/other
		-----END TOPGIT REFS-----
	EOT
	tg tag --allow-any --refs other >actual &&
	test_cmp actual expected &&
	tg tag --allow-any --refs refs/heads/other >actual &&
	test_cmp actual expected &&
	cat <<-EOT >expected &&
		-----BEGIN TOPGIT REFS-----
		24863d9c5498b120622ba4b67b5de2a5c9b67a94 refs/heads/master
		516124ddbb5f9e2c33be37a1d6f3f2c4b0c23dd2 refs/heads/other
		-----END TOPGIT REFS-----
	EOT
	tg tag --allow-any --refs master other >actual &&
	test_cmp actual expected &&
	tg tag --allow-any --refs other master >actual &&
	test_cmp actual expected &&
	tg tag --allow-any --refs other refs/heads/master >actual &&
	test_cmp actual expected &&
	tg tag --allow-any --refs refs/heads/other master >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 't/both1 master --refs needs --allow-any' '
	cd both &&
	cat <<-EOT >expected &&
		-----BEGIN TOPGIT REFS-----
		24863d9c5498b120622ba4b67b5de2a5c9b67a94 refs/heads/master
		4c9786c5edd2095cad2226d787462fd2b9f28eac refs/heads/t/both1
		1f2e77bea71b03b41209b5233dda7458d7528ef1 refs/heads/tgbranch1
		1f2e77bea71b03b41209b5233dda7458d7528ef1 refs/top-bases/t/both1
		-----END TOPGIT REFS-----
	EOT
	test_must_fail tg tag --refs t/both1 master &&
	test_must_fail tg tag --refs master t/both1 &&
	tg tag --allow-any --refs t/both1 master >actual &&
	test_cmp actual expected &&
	tg tag --allow-any --refs master t/both1 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP '--all refs impliclt and explicit' '
	cd both &&
	cat <<-EOT >expected &&
		-----BEGIN TOPGIT REFS-----
		4c9786c5edd2095cad2226d787462fd2b9f28eac refs/heads/t/both1
		56035f3acec7b94aa0d7c38efbf978c16711920c refs/heads/t/both2
		1f2e77bea71b03b41209b5233dda7458d7528ef1 refs/heads/tgbranch1
		b468326bcc77566ad05a8ecdb613b0fc737472cf refs/heads/tgbranch2
		1f2e77bea71b03b41209b5233dda7458d7528ef1 refs/top-bases/t/both1
		b468326bcc77566ad05a8ecdb613b0fc737472cf refs/top-bases/t/both2
		8b5716e97e03bafa97f7a5e7e0e155305dccac02 refs/top-bases/t/orphanbase
		-----END TOPGIT REFS-----
	EOT
	tg tag --all --refs >actual &&
	test_cmp actual expected &&
	tg tag --refs --all >actual &&
	test_cmp actual expected &&
	tg tag --refs t/both1 t/both2 "$(tg --top-bases)/t/orphanbase" >actual &&
	test_cmp actual expected
'

test_expect_success SETUP '--allow-any --all refs impliclt and explicit' '
	cd both &&
	cat <<-EOT >expected &&
		-----BEGIN TOPGIT REFS-----
		24863d9c5498b120622ba4b67b5de2a5c9b67a94 refs/heads/master
		516124ddbb5f9e2c33be37a1d6f3f2c4b0c23dd2 refs/heads/other
		4c9786c5edd2095cad2226d787462fd2b9f28eac refs/heads/t/both1
		56035f3acec7b94aa0d7c38efbf978c16711920c refs/heads/t/both2
		1f2e77bea71b03b41209b5233dda7458d7528ef1 refs/heads/tgbranch1
		b468326bcc77566ad05a8ecdb613b0fc737472cf refs/heads/tgbranch2
		1f2e77bea71b03b41209b5233dda7458d7528ef1 refs/top-bases/t/both1
		b468326bcc77566ad05a8ecdb613b0fc737472cf refs/top-bases/t/both2
		8b5716e97e03bafa97f7a5e7e0e155305dccac02 refs/top-bases/t/orphanbase
		-----END TOPGIT REFS-----
	EOT
	tg tag --all --refs >actual &&
	test_must_fail test_cmp actual expected &&
	tg tag --refs --all >actual &&
	test_must_fail test_cmp actual expected &&
	tg tag --refs t/both1 t/both2 "$(tg --top-bases)/t/orphanbase" >actual &&
	test_must_fail test_cmp actual expected &&
	tg tag --allow-any --all --refs >actual &&
	test_cmp actual expected &&
	tg tag --allow-any --refs --all >actual &&
	test_cmp actual expected &&
	test_must_fail tg tag --refs master other t/both1 t/both2 "$(tg --top-bases)/t/orphanbase" &&
	tg tag --allow-any --refs master other t/both1 t/both2 "$(tg --top-bases)/t/orphanbase" >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'annihilated --all'  '
	cd ann &&
	cat <<-EOT >expected &&
		-----BEGIN TOPGIT REFS-----
		46ba22545c6bed4b0a55a2426f2c4f6d1a9617bb refs/heads/base2
		fcc5e64345ed3758678342fc04bfa0aa803d8897 refs/heads/t/branch1
		067958167cc682564f55865c6056af4a7a71421c refs/heads/t/branch2
		bed0691bb40fbc621864b3d522ae905c77962f72 refs/heads/t/hold1
		569495b4c2ad34234744f48f0f9ae14a2350313d refs/heads/t/hold2
		3efadbea0c9156b1cf2ae484bc78d7a0ce7bdbcb refs/heads/t/holdboth
		ebbc158db4c933fbc1b915c5da3aede2e1bfae30 refs/top-bases/t/branch1
		46ba22545c6bed4b0a55a2426f2c4f6d1a9617bb refs/top-bases/t/branch2
		fcc5e64345ed3758678342fc04bfa0aa803d8897 refs/top-bases/t/hold1
		e6f05ae1f7586c2efc3816a2e6c806e109c9026a refs/top-bases/t/hold2
		fcc5e64345ed3758678342fc04bfa0aa803d8897 refs/top-bases/t/holdboth
		-----END TOPGIT REFS-----
	EOT
	tg tag --refs --all >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'annihilated --allow-any --all'  '
	cd ann &&
	cat <<-EOT >expected &&
		-----BEGIN TOPGIT REFS-----
		ebbc158db4c933fbc1b915c5da3aede2e1bfae30 refs/heads/base1
		46ba22545c6bed4b0a55a2426f2c4f6d1a9617bb refs/heads/base2
		fcc5e64345ed3758678342fc04bfa0aa803d8897 refs/heads/t/branch1
		067958167cc682564f55865c6056af4a7a71421c refs/heads/t/branch2
		bed0691bb40fbc621864b3d522ae905c77962f72 refs/heads/t/hold1
		569495b4c2ad34234744f48f0f9ae14a2350313d refs/heads/t/hold2
		3efadbea0c9156b1cf2ae484bc78d7a0ce7bdbcb refs/heads/t/holdboth
		ebbc158db4c933fbc1b915c5da3aede2e1bfae30 refs/top-bases/t/branch1
		46ba22545c6bed4b0a55a2426f2c4f6d1a9617bb refs/top-bases/t/branch2
		fcc5e64345ed3758678342fc04bfa0aa803d8897 refs/top-bases/t/hold1
		e6f05ae1f7586c2efc3816a2e6c806e109c9026a refs/top-bases/t/hold2
		fcc5e64345ed3758678342fc04bfa0aa803d8897 refs/top-bases/t/holdboth
		-----END TOPGIT REFS-----
	EOT
	tg tag --allow-any --refs --all >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'annihilated t/branch1'  '
	cd ann &&
	cat <<-EOT >expected &&
		-----BEGIN TOPGIT REFS-----
		fcc5e64345ed3758678342fc04bfa0aa803d8897 refs/heads/t/branch1
		ebbc158db4c933fbc1b915c5da3aede2e1bfae30 refs/top-bases/t/branch1
		-----END TOPGIT REFS-----
	EOT
	tg tag --refs t/branch1 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'unannihilated t/branch2'  '
	cd ann &&
	cat <<-EOT >expected &&
		-----BEGIN TOPGIT REFS-----
		46ba22545c6bed4b0a55a2426f2c4f6d1a9617bb refs/heads/base2
		067958167cc682564f55865c6056af4a7a71421c refs/heads/t/branch2
		46ba22545c6bed4b0a55a2426f2c4f6d1a9617bb refs/top-bases/t/branch2
		-----END TOPGIT REFS-----
	EOT
	tg tag --refs t/branch2 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'annihilated t/branch1 in t/hold1'  '
	cd ann &&
	cat <<-EOT >expected &&
		-----BEGIN TOPGIT REFS-----
		fcc5e64345ed3758678342fc04bfa0aa803d8897 refs/heads/t/branch1
		bed0691bb40fbc621864b3d522ae905c77962f72 refs/heads/t/hold1
		ebbc158db4c933fbc1b915c5da3aede2e1bfae30 refs/top-bases/t/branch1
		fcc5e64345ed3758678342fc04bfa0aa803d8897 refs/top-bases/t/hold1
		-----END TOPGIT REFS-----
	EOT
	tg tag --refs t/hold1 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'unannihilated t/branch2 in t/hold2'  '
	cd ann &&
	cat <<-EOT >expected &&
		-----BEGIN TOPGIT REFS-----
		46ba22545c6bed4b0a55a2426f2c4f6d1a9617bb refs/heads/base2
		067958167cc682564f55865c6056af4a7a71421c refs/heads/t/branch2
		569495b4c2ad34234744f48f0f9ae14a2350313d refs/heads/t/hold2
		46ba22545c6bed4b0a55a2426f2c4f6d1a9617bb refs/top-bases/t/branch2
		e6f05ae1f7586c2efc3816a2e6c806e109c9026a refs/top-bases/t/hold2
		-----END TOPGIT REFS-----
	EOT
	tg tag --refs t/hold2 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'un+annihilated t/branch2+1 in outdated t/holdboth'  '
	cd ann &&
	cat <<-EOT >expected &&
		-----BEGIN TOPGIT REFS-----
		46ba22545c6bed4b0a55a2426f2c4f6d1a9617bb refs/heads/base2
		fcc5e64345ed3758678342fc04bfa0aa803d8897 refs/heads/t/branch1
		067958167cc682564f55865c6056af4a7a71421c refs/heads/t/branch2
		3efadbea0c9156b1cf2ae484bc78d7a0ce7bdbcb refs/heads/t/holdboth
		ebbc158db4c933fbc1b915c5da3aede2e1bfae30 refs/top-bases/t/branch1
		46ba22545c6bed4b0a55a2426f2c4f6d1a9617bb refs/top-bases/t/branch2
		fcc5e64345ed3758678342fc04bfa0aa803d8897 refs/top-bases/t/holdboth
		-----END TOPGIT REFS-----
	EOT
	test_must_fail tg tag --refs t/holdboth &&
	tg tag --allow-outdated --refs t/holdboth >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'unannihilated nontgish base1 base2'  '
	cd ann &&
	cat <<-EOT >expected &&
		-----BEGIN TOPGIT REFS-----
		ebbc158db4c933fbc1b915c5da3aede2e1bfae30 refs/heads/base1
		46ba22545c6bed4b0a55a2426f2c4f6d1a9617bb refs/heads/base2
		-----END TOPGIT REFS-----
	EOT
	test_must_fail tg tag --refs base1 base2 &&
	tg tag --allow-any --refs base1 base2 >actual &&
	test_cmp actual expected
'

test_expect_success SETUP 'signed tags only under refs/tags' '
	cd ann &&
	test_must_fail tg tag --no-edit --sign refs/t/branch2 t/branch2 &&
	test_must_fail tg tag --no-edit --sign refs/remotes/foo t/branch2 &&
	test_must_fail tg tag --no-edit --sign refs/heads/blahblah t/branch2 &&
	test_must_fail tg tag --no-edit --sign refs/tgstash t/branch2 &&
	test_must_fail tg tag --no-edit --sign --stash t/branch2 &&
	test_must_fail tg tag --no-edit --sign --anonymous t/branch2
'

test_expect_success 'SETUP GPG' 'sign --all' '
	cd ann &&
	tggpg tag --no-edit --sign t/signall --all &&
	git tag --verify t/signall
'

test_expect_success 'SETUP GPG' 'sign holdboth' '
	cd ann &&
	test_must_fail tg tag --no-edit --sign t/signboth t/holdboth &&
	tggpg tag --no-edit --sign --allow-outdated t/signboth t/holdboth &&
	git tag --verify t/signboth
'

test_done
