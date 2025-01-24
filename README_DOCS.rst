=========================================
TopGit -- A Different Patch Queue Manager
=========================================


DESCRIPTION
-----------

TopGit aims to make handling of large amounts of interdependent topic
branches easier. In fact, it is designed especially for the case where
you maintain a queue of third-party patches on top of another (perhaps
Git-controlled) project and want to easily organize, maintain and submit
them -- TopGit achieves that by keeping a separate topic branch for each
patch and providing some tools to maintain the branches.

See also:

	:REQUIREMENTS_:	     Installation requirements
	:SYNOPSIS_:          Command line example session
	:USAGE_:             Command line details
	:`NO UNDO`_:         Where's the undo!!!
	:CONVENTIONS_:       Suggestions for organizing your TopGit branches
	:`EXTRA SETTINGS`_:  Various possible "topgit.*" config settings
	:ALIASES_:           Git-like TopGit command aliases
	:NAVIGATION_:        Getting around with "next" and "prev"
	:`WAYBACK MACHINE`_: Turn back the clock and then come back
	:GLOSSARY_:          All the TopGit vocabulary in one place
	:TECHNICAL_:         How it works behind the scenes
	:`TESTING TOPGIT`_:  How to run the TopGit test suite


REQUIREMENTS
------------

TopGit is a collection of POSIX shell scripts so a POSIX-compliant shell is
required along with some standard POSIX-compliant utilities (e.g. sed, awk,
cat, etc.).  Git version 1.9.2 or later is also required.

To use TopGit with linked working trees (the ``git worktree add`` command),
at least Git version 2.5.0 (obviously, since that's when the ``git worktree``
command first appeared) is needed in which case linked working trees are then
fully supported for use with TopGit.

The scripts need to be preprocessed and installed.  The Makefile that does
this requires a POSIX make utility (using "``make``" and "``make install``")
and some version of ``perl`` in the ``PATH`` somewhere (the ``perl`` binary
is needed for correct help text file generation prior to the actual install).

Once installed, TopGit uses only POSIX-compliant utilities (except that it
also requires, obviously, Git).

Running the tests (see `TESTING TOPGIT`_) has the same requirements as for
installation (i.e. POSIX plus Perl).

It is possible to use the DESTDIR functionality to install TopGit to a
staging area on one machine, archive that and then unarchive it on another
machine to perform an install (provided the build prefix and other options are
compatible with the final installed location).


INSTALLATION
------------

See the file ``INSTALL``.


GIT REPOSITORY
--------------

The TopGit git repository can be found at <https://repo.or.cz/topgit/pro>.


RATIONALE
---------

Why not use something like StGIT or Guilt or ``rebase -i`` for maintaining
your patch queue?  The advantage of these tools is their simplicity;
they work with patch *series* and defer to the reflog facility for
version control of patches (reordering of patches is not
version-controlled at all).  But there are several disadvantages -- for
one, these tools (especially StGIT) do not actually fit well with plain
Git at all: it is basically impossible to take advantage of the index
effectively when using StGIT.  But more importantly, these tools
horribly fail in the face of a distributed environment.

TopGit has been designed around three main tenets:

	(i) TopGit is as thin a layer on top of Git as possible.  You
	still maintain your index and commit using Git; TopGit will only
	automate a few indispensable tasks.

	(ii) TopGit is anxious about *keeping* your history.  It will
	never rewrite your history, and all metadata is also tracked
	by Git, smoothly and non-obnoxiously.  It is good to have a
	*single* point when the history is cleaned up, and that is at
	the point of inclusion in the upstream project; locally, you
	can see how your patch has evolved and easily return to older
	versions.

	(iii) TopGit is specifically designed to work in a
	distributed environment.  You can have several instances of
	TopGit-aware repositories and smoothly keep them all
	up-to-date and transfer your changes between them.

As mentioned above, the main intended use-case for TopGit is tracking
third-party patches, where each patch is effectively a single topic
branch.  In order to flexibly accommodate even complex scenarios when
you track many patches where many are independent but some depend on
others, TopGit ignores the ancient Quilt heritage of patch series and
instead allows the patches to freely form graphs (DAGs just like Git
history itself, only "one level higher").  For now, you have to manually
specify which patches the current one depends on, but TopGit might help
you with that in the future in a darcs-like fashion.

A glossary_ plug: The union (i.e. merge) of patch dependencies is called
a *base* of the patch (topic branch).

Of course, TopGit is perhaps not the right tool for you:

	(i) TopGit is not complicated, but StGIT et al. are somewhat
	simpler, conceptually.  If you just want to make a linear
	purely-local patch queue, deferring to StGIT instead might
	make more sense.

	(ii) When using TopGit, your history can get a little hairy
	over time, especially with all the merges rippling through.
	;-)


SYNOPSIS
--------

::

	## Create and evolve a topic branch
	$ tg create t/gitweb/pathinfo-action
	tg: automatically marking dependency on master
	tg: creating t/gitweb/pathinfo-action base from master...
	$ ..hack..
	$ git commit
	$ ..fix a mistake..
	$ git commit

	## Create another topic branch on top of the former one
	$ tg create t/gitweb/nifty-links
	tg: automatically marking dependency on t/gitweb/pathinfo-action
	tg: creating t/gitweb/nifty-links base from t/gitweb/pathinfo-action...
	$ ..hack..
	$ git commit

	## Create another topic branch on top of master and submit
	## the resulting patch upstream
	$ tg create t/revlist/author-fixed master
	tg: creating t/revlist/author-fixed base from master...
	$ ..hack..
	$ git commit
	$ tg patch -m
	tg: Sent t/revlist/author-fixed
	From: pasky@suse.cz
	To: git@vger.kernel.org
	Cc: gitster@pobox.com
	Subject: [PATCH] Fix broken revlist --author when --fixed-string

	## Create another topic branch depending on two others non-trivially
	$ tg create t/whatever t/revlist/author-fixed t/gitweb/nifty-links
	tg: creating t/whatever base from t/revlist/author-fixed...
	tg: Topic branch t/whatever created.
	tg: Running tg update to merge in dependencies.
	tg: Updating t/whatever base with t/gitweb/nifty-links changes...
	Automatic merge failed; fix conflicts and then commit the result.
	tg: Please commit merge resolution and call `tg update --continue`
	tg: (use `tg status` to see more options)
	$ ..resolve..
	$ git commit
	$ tg update --continue
	$ ..hack..
	$ git commit

	## Update a single topic branch and propagate the changes to
	## a different one
	$ git checkout t/gitweb/nifty-links
	$ ..hack..
	$ git commit
	$ git checkout t/whatever
	$ tg info
	Topic Branch: t/whatever (2/1 commits)
	Subject: [PATCH] Whatever patch
	Base: 3f47ebc1
	Depends: t/revlist/author-fixed
		 t/gitweb/nifty-links
	Needs update from:
		t/gitweb/nifty-links (1/1 commit)
	$ tg update
	tg: Updating t/whatever base with t/gitweb/nifty-links changes...
	Automatic merge failed; fix conflicts and then commit the result.
	tg: Please commit merge resolution and call `tg update --continue`
	tg: (use `tg status` to see more options)
	$ ..resolve..
	$ git commit
	$ tg update --continue
	tg: Updating t/whatever against new base...
	Automatic merge failed; fix conflicts and then commit the result.
	tg: Please commit merge resolution and call `tg update --continue`
	tg: (use `tg status` to see more options)
	$ ..resolve..
	$ git commit
	$ tg update --continue

	## Update a single topic branch and propagate the changes
	## further through the dependency chain
	$ git checkout t/gitweb/pathinfo-action
	$ ..hack..
	$ git commit
	$ git checkout t/whatever
	$ tg info
	Topic Branch: t/whatever (1/2 commits)
	Subject: [PATCH] Whatever patch
	Base: 0ab2c9b3
	Depends: t/revlist/author-fixed
		 t/gitweb/nifty-links
	Needs update from:
		t/gitweb/pathinfo-action (<= t/gitweb/nifty-links) (1/1 commit)
	$ tg update
	tg: Recursing to t/gitweb/nifty-links...
	==> [t/gitweb/nifty-links]
	tg: Updating t/gitweb/nifty-links base with t/gitweb/pathinfo-action changes...
	Automatic merge failed; fix conflicts and then commit the result.
	tg: Please commit merge resolution and call `tg update --continue`
	tg: (use `tg status` to see more options)
	$ ..resolve..
	$ git commit
	$ tg update --continue
	==> [t/gitweb/nifty-links]
	tg: Updating t/gitweb/nifty-links against new base...
	Automatic merge failed; fix conflicts and then commit the result.
	tg: Please commit merge resolution and call `tg update --continue`
	tg: (use `tg status` to see more options)
	$ ..resolve..
	$ git commit
	$ tg update --continue
	tg: Updating t/whatever base with t/gitweb/nifty-links changes...
	tg: Updating t/whatever against new base...

	## Clone a TopGit-controlled repository
	$ git clone URL repo
	$ cd repo
	$ tg remote --populate origin
	...
	$ git fetch
	$ tg update

	## Add a TopGit remote to a repository and push to it
	$ git remote add foo URL
	$ tg remote foo
	$ tg push -r foo

	## Update from a non-default TopGit remote
	$ git fetch foo
	$ tg -r foo summary
	$ tg -r foo update


CONVENTIONS
-----------

When using TopGit there are several common conventions used when working with
TopGit branches.  None of them are enforced, they are only suggestions.

There are three typical uses for a TopGit branch:

    1. [PATCH]
       Normal TopGit branches that represent a single patch.  These are known
       as "patch" TopGit branches.
    2. [BASE]
       Empty TopGit branches with no dependencies (an empty ``.topdeps`` file)
       that represent a base upon which other "normal" TopGit branches depend.
       These are known as "base" TopGit branches (not to be confused with
       the refs/top-bases/... refs).  When such a branch is created on an
       unborn branch (meaning the base has no parent commit), it will typically
       be named [ROOT] instead of [BASE].  When the base refers to the release
       of some external dependency these branches are sometimes named [RELEASE]
       instead of [BASE].
    3. [STAGE]
       Empty TopGit branches that serve as a staging area to bring together
       several other TopGit branches into one place so they can be used/tested
       all together.  These are known as "stage" TopGit branches and are
       sometimes named [RELEASE] instead of [STAGE].

An "empty" TopGit branch is one that does not have any changes of its own -- it
may still have dependencies though ("stage" branches do, "base" branches do
not).  The ``tg summary`` output shows empty branches annotated with a ``0`` in
the output.  Branches which have not been annihilated (but which still might be
"empty") such as normal "patch" branches, "base" and "stage" branches are shown
in the ``tg summary`` output by default.  Annihilated branches are normally
omitted from the ``tg summary`` output but can be shown if given explicitly as
an argument to the ``tg summary`` command.  However, the message line will be
unavailable since an annihilated branch has no ``.topmsg`` file of its own.

A "patch" branch name typically starts with ``t/`` whereas "base" and "stage"
branch names often do not.

A "base" branch is created by using the ``--base`` option of ``tg create``
(aka ``--no-deps``) which will automatically suggest a "[BASE]" message prefix
rather than "[PATCH]".  A "stage" branch is created like a normal patch branch
except that the only changes that will ever be made to it are typically to
add/remove dependencies.  Its subject prefix must be manually changed to
"[STAGE]" to reflect its purpose.

Since both "base" and "stage" branches typically only have a use for the
"Subject:" line from their ``.topmsg`` file, they are quite easily created
using the ``--topmsg`` option of ``tg create``.

Use of "stage" and "base" branches is completely optional.  However, without
use of a "stage" branch it will be difficult to test multiple independent
patches together all at once.  A "base" branch is merely a convenience that
provides more explicit control over when a common base for a set of patches
gets updated as well as providing a branch that shows in ``tg summary`` output
and participates in ``tg remote --populate`` setup.

Occasionally the functionality of a "base" branch is needed but it may not
be possible to add any ``.topdeps`` or ``.topmsg`` files to the desired branch
(perhaps it's externally controlled).  `BARE BRANCHES`_ can be used in this
case, but while TopGit allows them it deliberately does not provide assistance
in setting them up.

Another advantage to using a "stage" branch is that if a new "patch" branch
is created remotely and that new branch is added to a pre-existing "stage"
branch on the remote then when the local version of the "stage" branch is
updated (after fetching remote updates of course), that new dependency will
be merged into the local "stage" branch and the local version of the new remote
"patch" branch will be automatically set up at "tg update" time.

When using the ``tg tag`` command to create tags that record the current state
of one or more TopGit branches, the tags are often created with a name that
starts with ``t/``.

One last thing, you have enabled ``git rerere`` haven't you?


NO UNDO
-------

Beware, there is no "undo" after running a ``tg update``!

Well, that's not entirely correct.  Since ``tg update`` never discards commits
an "undo" operation is technically feasible provided the old values of all the
refs that were affected by the ``tg update`` operation can be determined and
then they are simply changed back to their previous values.

In practice though, it can be extremely tedious and error prone looking through
log information to try and determine what the correct previous values were.
Although, since TopGit tries to make sure reflogs are enabled for top-bases
refs, using Git's ``@{date}`` notation on all the refs dumped out by a
``tg tag --refs foo``, where "foo" is the branch that was updated whose update
needs to be undone, may work.

Alternatively, ``tg tag --stash`` can be used prior to the update and then
``tg revert`` used after the update to restore the previous state.  This
assumes, of course, that you remember to run ``tg tag --stash`` first.

The ``tg update`` command understands a ``--stash`` option that tells it to
automatically run ``tg tag --stash`` before it starts making changes (if
everything is up-to-date it won't run the stash command at all).

The ``--stash`` option is the default nowadays when running ``tg update``,
add the ``--no-stash`` option to turn it off.

There is a preference for this.  Setting the config value ``topgit.autostash``
to ``false`` will implicitly add the ``--no-stash`` option to any ``tg update``
command unless an explicit ``--stash`` option is given.

If you are likely to ever want to undo a ``tg update``, setting
``topgit.autostash`` to ``false`` is highly discouraged!

Note that if you have foolishly disabled the autostash functionality and
suddenly find yourself in an emergency "WHERE'S THE UNDO???" situation you
*may* be able to use the special ``TG_STASH`` ref.  But only if you're quick.
It's only set if you've foolishly disabled autostash and it always overwrites
the previous ``TG_STASH`` value if there was one (there's no reflog for it)
and it will most likely *not* survive a ``git gc`` (even an automatic one) no
matter what gc expiration values are used.  However, as a last gasp attempt
to save your butt, a previously existing ``TG_STASH`` will first be renamed
to ``ORIG_TG_STASH`` immediately before a new ``TG_STASH`` gets written
(stepping on any previously existing ``ORIG_TG_STASH`` at that point).

Note that the tags saved by ``tg tag --stash`` are stored in the
``refs/tgstash`` ref and its reflog.  Unfortunately, while Git is happy to
maintain the reflog (once it's been enabled which ``tg tag`` guarantees for
``refs/tgstash``), Git is unable to view an annotated/signed tag's reflog!
Instead Git dereferences the tag and shows the wrong thing.

Use the ``tg tag -g`` command to view the ``refs/tgstash`` reflog instead.


WAYBACK MACHINE
---------------

After reading about `NO UNDO`_ and the `tg tag`_ command used to provide a
semblance of undo in some cases, you have the foundation to understand the
wayback machine.

The "wayback machine" provides a way to go back to a previous ref state as
stored in a TopGit tag created by `tg tag`_.  It actually normally returns to a
hybrid state as it does not prune (unless you prefix the wayback tag with
a ``:``).  In other words, any refs that have been newly created since the
target tag was made will continue to exist in the "wayback" view of things
(unless you used a pruning wayback tag -- one prefixed with a ``:``).

Any operations that are read-only and do not require working tree files (e.g.
the ``-i`` or ``-w`` options of `tg patch`_) are allowed using the wayback
machine.  Simply add a global ``-w <tgtag>`` option to the command.

This functionality can be extremely useful for quickly examining/querying a
previous state recorded some time ago with a `tg tag`_.

As the wayback machine uses a separate caching area, expect initial operations
to be less speedy, but repeated wayback operations on the same wayback tag
should happen at normal speed.

One new command exists expressly for use with the wayback machine.

The `tg shell`_ command will spawn an interactive shell or run a specific shell
command in a temporary writable and non-bare repository that has its ref
namespace set to the (possibly pruned if it's a pruning wayback tag) wayback
tag's view of the world.  This pretty much lifts all wayback restrictions, but
read the description for `tg shell`_ for more details.  There is an option
available to specify the location where this "temporary" directory is created
thereby allowing it to persist, but the same warnings then apply as using the
``git clone --shared`` command.


EXTRA SETTINGS
--------------

TopGit supports various config settings:

	:`tg tag`_:             ``color.tgtag`` on/off color for ``tg tag -g``
	:`tg tag`_:             ``color.tgtag.commit`` reflog hash color
	:`tg tag`_:             ``color.tgtag.date`` reflog date line color
	:`tg tag`_:             ``color.tgtag.meta`` reflog object type color
	:`tg tag`_:             ``color.tgtag.time`` reflog time info color
	:`tg create`_:          ``format.signoff`` template Signed-off-by line
	:ALIASES_:              ``topgit.alias.*`` for Git-like command aliases
	:`tg update`_:          ``topgit.autostash`` automatic stash control
	:`tg create`_:          ``topgit.bcc`` default "Bcc:" value for create
	:`tg create`_:          ``topgit.cc`` default "Cc:" value for create
	:`tg patch`_:           ``topgit.from`` "From:" fixups by ``tg patch``
	:`tg export`_:          ``topgit.notesExport`` export ``---`` notes
	:`tg import`_:          ``topgit.notesImport`` import ``---`` notes
	:`tg push`_:            ``topgit.pushRemote`` default push remote
	:`REMOTE HANDLING`_:    ``topgit.remote`` TopGit's default remote
	:SEQUESTRATION_:        ``topgit.sequester`` for sequestration control
	:`tg update`_:          ``topgit.setAutoUpdate`` => ``rerere.autoUpdate``
	:`tg export`_:          ``topgit.subjectMode`` export [...] tag removal
	:`tg create`_:          ``topgit.subjectPrefix`` "[$prefix PATCH] foo"
	:`tg create`_:          ``topgit.to`` default "To:" value for create
	:`tg migrate-bases`_:   ``topgit.top-bases`` for refs bases location


ALIASES
-------

These work exactly like Git's aliases except they are stored under
``topgit.alias.*`` instead.  See the ``git help config`` output under
the ``alias.*`` section for details.  Do note that while alias nesting is
explicitly permitted, a maximum nesting depth of 10 is enforced to help
detect accidental aliasing loops and keep them from wedging the machine.

For example, to create an ``lc`` alias for the ``tg log --compact`` command
this command may be used:

::

	git config --global topgit.alias.lc "log --compact"

To make it specific to a particular repository just omit the ``--global``
option from the command.

There is one implicit universal alias as though this were set:

::

	git config topgit.alias.goto "checkout goto"

But only if no explicit alias has already been set for ``topgit.alias.goto``.


NAVIGATION
----------
From Previous to Next
~~~~~~~~~~~~~~~~~~~~~

For this section, consider the following patch series, to be applied
in numerical order as shown:

::

	0001-F_first-patch.diff
	0002-G_second-builds-on-F.diff
	0003-H_third-builds-on-G.diff
	0004-I_fourth-builds-on-H.diff
	0005-J_fifth-builds-on-I.diff
	0006-K_sixth-builds-on-J.diff
	0007-L_last-patch-needs-K.diff

If these were applied to some commit in a Git repository, say commit "A"
then a history that looks like this would be created:

::

	A---F---G---H---I---J---K---L

Where the parent of commit "F" is "A" and so on to where the parent of
commit "L" is commit "K".

If that commit history, from A through L, was then imported into TopGit, one
TopGit branch would be created corresponding to each of the commits F
through L.  This way, for example, if the fourth patch in the series
(``0004-I_...diff``) needs work, the TopGit branch corresponding to its patch
can be checked out and changes made and then a new version of its patch
created (using ``tg patch``) without disturbing the other patches in the series
and when ``tg update`` is run, the patches that "follow" the fourth patch
(i.e. 5, 6 and 7) will have their corresponding TopGit branches automatically
updated to take into account the changes made to the fourth patch.

Okay, enough with the review of TopGit systemology
``````````````````````````````````````````````````

Imagine then that you are working on the fourth patch (i.e. you have its
branch checked out into the working tree) and you want to move to the following
patch in the series because you have a nit to pick with it too.

If you can't remember the exact name you might have to fumble around or, you
can display the name of the following or "next" patch's branch with the, you
guessed it, ``tg next`` command.  Think of "next" as the "next" logical patch
in the series or the next following patch.  If the patches are numbered as in
the list above, "next" corresponds to the "+1" (plus one) patch.

You might have already guessed there's a corresponding ``tg prev`` command
which displays the "-1" (minus one) patch.  If these commands (``tg next``
and ``tg prev``) are not given a branch name to start at they start at the
patch corresponding to the current ``HEAD``.

Displaying, however, is not so helpful as actually going there.  That's where
the ``tg checkout`` command comes in.  ``tg checkout next`` does a
``git checkout`` of the ``tg next`` branch and, not surprisingly,
``tg checkout prev`` does a ``git checkout`` of the ``tg prev`` branch.  For
the lazy a single ``n`` or ``p`` can be used with ``tg checkout`` instead of
typing out the entire ``next`` or ``prev``.  Or, for the anal, ``previous``
will also be accepted for ``prev``.

Referring to the A...L commit graph shown above, I is the parent of J and,
conversely, J is the child of I.  (Git only explicitly records the child to
parent links, in other words a "child" points to zero or more "parents", but
parents are completely clueless about their own children.)

For historical reasons, the ``tg checkout`` command accepts ``child`` as a
synonym for ``next`` and ``parent`` as a synonym for ``prev``.  However, this
terminology can be confusing since Git has "parent" links but ``tg checkout``
is referring to the TopGit DAG, not Git's.  Best to just avoid using ``child``
or ``parent`` to talk about navigating the TopGit DAG and reserve them
strictly for discussing the Git DAG.

There may be more than one
``````````````````````````

In a simple linear history as shown above there's always only one "next" or
"prev" patch.  However, TopGit does not restrict one to only a linear
history (although that can make patch exports just a bushel of fun).

Suffice it to say that there is always a single linearized ordering for any
TopGit patch series since it's always a DAG (Directed Acyclic Graph), but it
may not be immediately obvious to the casual observer what that is.

The ``tg checkout`` command will display a list to choose from if ``next``
or ``prev`` would be ambiguous.

Use the ``tg info/checkout --series`` command
`````````````````````````````````````````````

To see the full, linearized, list of patches with their summary displayed in
order from first to last patch in the series, just run the ``tg info --series``
command.  It takes the name of any patch in the series automatically using
``HEAD`` if none is given.  It even provides a nice "YOU ARE HERE" mark in
the output list helpful to those who have been absent for a time engaging in
otherwise distracting activities and need to be reminded where they are.

Using ``tg checkout --series`` can take you there (picking from a list) if
you've forgotten the way back to wherever you're supposed to be.

Don't get pushy, there's just one more thing
````````````````````````````````````````````

For historical reasons, ``tg checkout`` with no arguments whatsoever behaves
like ``tg checkout next``.  For the same historical reasons, ``tg checkout ..``
behaves like ``tg checkout prev`` (think of ``..`` as the "parent" directory
and since "parent" means "prev" in this context it will then make sense).

Now, for that one more thing.  Consider that you have a pristine "upstream"
tarball, repository, source dump or otherwise obtained set of unmodified
source files that need to be patched.  View them like so:

::

	+-------------------------------+
	| Unmodified "upstream" source  |
	| files represented with "A"    |
	+-------------------------------+

Now, add the first patch, 0001, to them and view the result like so:

::

	+--------------------------+----+
	| Patch 0001 represented by "F" |
	+-------------------------------+
	| Unmodified "upstream" source  |
	| files represented with "A"    |
	+-------------------------------+

Not stopping there, "push" patches 2, 3 and 4 onto the stack as well like so:

::

	+--------------------------+----+
	| Patch 0004 represented by "I" |
	+--------------------------+----+
	| Patch 0003 represented by "H" |
	+--------------------------+----+
	| Patch 0002 represented by "G" |
	+--------------------------+----+
	| Patch 0001 represented by "F" |
	+-------------------------------+
	| Unmodified "upstream" source  |
	| files represented with "A"    |
	+-------------------------------+

In other words, to go to the "next" patch in the series it needs to be "push"ed
onto the stack.  ``tg checkout`` accepts ``push`` as an alias for ``next``.

Similarly to go to the "previous" patch in the series the current one needs
to be "pop"ped off the stack.  ``tg checkout`` accepts ``pop`` as an alias
for ``prev``.

Unfortunately for these aliases, in Git terminology a "push" has quite a
different meaning and the ``tg push`` command does something quite different
from ``tg checkout push``.  Then there's the matter of using a single letter
abbreviation for the lazy -- ``p`` would mean what exactly?

``tg checkout`` continues to accept the ``push`` and ``pop`` aliases for
``next`` and ``prev`` respectively,  but it's best to avoid them since
``push`` has an alternate meaning everywhere else in TopGit and Git and that
leaves ``pop`` all alone in the dark.


SEQUESTRATION
-------------

No, this is not a section about budget nonsense.  ;)

TopGit keeps its metadata in ``.topdeps`` and ``.topmsg`` files.  In an effort
to facilitate cherry-picking and other Git activities on the patch changes
themselves while ignoring the TopGit metadata, TopGit attempts to keep all
changes to ``.topdeps`` and ``.topmsg`` files limited to commits that do NOT
contain changes to any other files.

This is a departure from previous TopGit versions that made no such effort.

Primarily this affects ``tg create`` and ``tg import`` (which makes use of
``tg create``) as ``tg create`` will commit the initial versions of
``.topdeps`` and ``.topmsg`` for a new TopGit-controlled branch in their own
commit instead of mixing them in with changes to other files.

The ``pre-commit`` hook will also attempt to separate out any ``.topdeps`` and
``.topmsg`` changes from commits that include changes to other files.

It is possible to defeat these checks without much effort (``pre-commit`` hooks
can easily be bypassed, ``tg create`` has a ``--no-commit`` option, many Git
commands simply do not run the ``pre-commit`` hook, etc.).

If you really, really, really, really want to change the default back to the
old behavior of previous TopGit versions where no such sequestration took
place, then set the ``topgit.sequester`` config variable explicitly to the
value ``false``.  But this is not recommended.


AMENDING AND REBASING AND UPDATE-REF'ING
----------------------------------------

In a word, "don't".

It is okay to manually update a top-bases/... ref when a) it has no depedencies
(i.e. it was created with the ``tg create`` ``--base`` option) and b) the
old top-bases/... ref value can be fast-forwarded to the new top-bases/...
value OR the new value contains ALL of the changes in the old value through
some other mechanism (perhaps they were cherry-picked or otherwise applied to
the new top-bases/... ref).  The same rules apply to non-TopGit-controlled
dependencies.  Use the ``tg update --base <branch> <new-ref>`` command to
safely make such an update while making it easy to set the merge commit
message at the same time.

Ignoring this rule and proceeding anyway with a non-fast-forward update to a
top-bases/... ref will result in changes present in the new value being merged
into the branch (at ``tg update`` time) as expected (possibly with conflicts),
but any changes that were contained in the old version of the top-bases/... ref
which have been dropped (i.e. are NOT contained in the new version of the
top-bases/... ref) will continue to be present in the branch!  To get rid of
the dropped commits, one or more "revert" commits will have to be manually
applied to the tip of the new top-bases/... value (which will then be merged
into the branch at next ``tg update`` time).

The only time it's safe to amend, rebase, filter or otherwise rewrite commits
contained in a TopGit controlled branch or non-TopGit branch is when those
commits are NOT reachable via any other ref!

Furthermore, while it is safe to rewrite merge commits (provided they meet the
same conditions) the merge commits themselves and the branches they are merging
in must be preserved during the rewrite and that can be rather tricky to get
right so it's not recommended.

For example, if, while working on a TopGit-controlled branch ``foo``, a bad
typo is noticed, it's okay to ammend/rebase to fix that provided neither
``tg update`` nor ``tg create`` has already been used to cause some other ref
to be able to reach the commit with the typo.

If an amend or rewrite is done anyway even though the commit with the typo is
reachable from some other ref, the typo won't really be removed.  What will
happen instead is that the new version without the typo will ultimately be
merged into the other ref(s) (at ``tg update`` time) likely causing a conflict
that will have to be manually resolved and the commit with the typo will
continue to be reachable from those other refs!

Instead just make a new commit to fix the typo.  The end result will end up
being the same but without the merge conflicts.

See also the discussion in the `NO UNDO`_ section.


BARE BRANCHES
-------------

A "TopGit bare branch" (or just "bare branch" for short), refers to a TopGit
branch that has neither a ``.topdeps`` nor a ``.topmsg`` file stored in it.
And it's neither a new, still-empty empty branch nor an annihilated branch.

Such branches are not recommended but are reluctantly accomodated.

There are three situtations in which TopGit may encounter a TopGit branch
that has neither a ``.topdeps`` nor a ``.topmsg`` file.

	1. Branch creation with ``--no-commit``
		Before the initial commit is made, the branch will still be
		pointing to the same commit as its "top-bases" ref.  Branches
		in this condition (where the branch and top-bases ref point to
		the same commit) show up as having "No commits" in listings.

	2. Annihilated branches
		A branch is annihilated by making a new commit on the branch
		that makes its tree identical to the tree of its corresponding
		top-bases ref.  Although the trees will be the same, the
		commits will be different and annihilated branches are
		distinguished from "No commits" branches in this way.
		Annihilated branches are generally invisible and do not show up
		in listings or other status displays.  Intentionally so.

	3. Bare branches
		Any TopGit branch with neither a ``.topdeps`` file nor a
		``.topmsg`` file whose branch and top-bases trees differ falls
		into this category.  TopGit will not create such a branch
		itself nor does it provide any commands to do so.

Whenever possible, a TopGit "[BASE]" branch should be preferred to using a
"bare branch" because a) it can never be mistaken for an annihilated branch,
b) it has a nice subject attached (via its ``.topmsg`` file) that shows
up in listings and c) exactly when and which updates are taken can be planned.

Nevertheless, situations may arise where it's useful to have TopGit treat a
branch as a "TopGit branch" so that it fully participates in all update
activities (such as updating local branches based on their remote branches),
but it's not feasible to turn it into a real "TopGit branch" as it comes from
an external source and rather than controlling exactly when and what updates
are picked up from it by TopGit (the precise use case of a "[BASE]" branch),
all updates that appear on it are to be assimilated as soon as they occur.

For this reason, TopGit will accomodate such "bare branches" but it will not
create (nor provide the means to create) them itself.

In order to create a "bare branch" all that's required is to create the
necessary top-bases ref.  The choice of commit for the top-bases ref will
affect the output of the "files", "log" and "patch" commands most directly
(but all commands will be affected).

To work properly as a "bare branch", the commit the "bare branch"'s base points
to should be contained within the branch, be a different commit than the branch
tip itself and have a different tree than the branch tip.  Simply setting the
base to the parent commit of the "bare branch" will usually work, but should
that commit at the tip of the "bare branch" end up getting reverted as the next
commit, the trees would match and it would appear to be an annihilated branch
rather than a "bare branch".  That is one of the reasons these branches are not
recommended in the first place.

Setting the base to the root commit of the branch is more reliable and may
be accomplished like so for a local branch named "mybranch":

::

	git update-ref $(tg --top-bases)/mybranch \
	  $(git rev-list --first-parent --max-parents=0 mybranch) ""

Typically though it's more likely a remote bare branch will be needed.  For
a remote named "origin" and a remote branch name of "vendor" this will do it:

::

	git update-ref $(tg --top-bases -r origin)/vendor \
	  $(git rev-list --first-parent --max-parents=0 origin/vendor) ""

Such "bare branches" are not likely ever to receive any more direct support in
TopGit than acknowleging they can be useful in some situations and tolerating
their existence by functioning properly with them even to the point of the
``pre-commit`` hook tacitly allowing continued commits on such branches without
complaints about missing ``.topdeps`` and ``.topmsg`` files.

Note, however, that creating a regular TopGit branch that has no changes of its
own with the "bare branch" as its single dependency provides a means to supply
some kind of documentation if all other uses of the "bare branch" depend on
this "wrapper" branch instead of directly on the "bare branch".


SPEED AND CACHING
-----------------

TopGit needs to check many things to determine whether a TopGit branch is
up-to-date or not.  This can involve a LOT of git commands for a complex
dependency tree.  In order to speed things up, TopGit keeps a cache of results
in a ``tg-cache`` subdirectory in the ``.git`` directory.

Results are tagged with the original hash values used to get that result so
that items which have not been changed return their results quickly and items
which have been changed compute their new result and cache it for future use.

The ``.git/tg-cache`` directory may be removed at any time and the cache will
simply be recreated in an on-demand fashion as needed, at some speed penalty,
until it's fully rebuilt.

To force the cache to be fully pre-loaded, run the ``tg summary`` command
without any arguments.  Otherwise, normal day-to-day TopGit operations should
keep it more-or-less up-to-date.

While each TopGit command is running, it uses a temporary subdirectory also
located in the ``.git`` directory.  These directories are named
``tg-tmp.XXXXXX`` where the ``XXXXXX`` part will be random letters and digits.

These temporary directories should always be removed automatically after each
TopGit command finishes running.  As long as you are not in a subshell as a
result of a TopGit command stopping and waiting for a manual merge resolution,
it's safe to remove any of these directories that may have somehow accidentally
been left behind as a result of some failure that occurred while running a
TopGit command (provided, of course, it's not actually being used by a TopGit
command currently running in another terminal window or by another user on the
same repository).


USAGE
-----
``tg [global options] <command> [<command option/argument>...]``

Global options:

	``[-C <dir>]... [-r <remote> | -u] [-c <name>=<val>]... [--[no-]pager]``

	-C <dir>	Change directory to <dir> before doing anything more
	-r <remote>	Pretend ``topgit.remote`` is set to <remote>
	-u		Pretend ``topgit.remote`` is not set
	-c <name=val>	Pass config option to git, may be repeated
	-w <tgtag>      Activate `wayback machine`_ using the `tg tag`_ <tgtag>
	--no-pager	Disable all pagers (by both TopGit and Git aka ``-P``)
	--pager		Enable use of a pager (aka ``-p`` aka ``--paginate``)
	--top-bases	Show full ``top-bases`` ref prefix and exit
	--exec-path	Show path to command scripts location and exit
	--help		Show brief usage help and exit (aka ``-h``)

The ``tg`` tool has several commands:

	:`tg annihilate`_:    Mark a TopGit-controlled branch as defunct
	:`tg base`_:          Show base commit for one or more TopGit branches
	:`tg checkout`_:      Shortcut for git checkout with name matching
	:`tg contains`_:      Which TopGit-controlled branch contains the commit
	:`tg create`_:        Create a new TopGit-controlled branch
	:`tg delete`_:        Delete a TopGit-controlled branch cleanly
	:`tg depend`_:        Add a new dependency to a TopGit-controlled branch
	:`tg export`_:        Export TopGit branch patches to files or a branch
	:`tg files`_:         Show files changed by a TopGit branch
	:`tg help`_:          Show TopGit help optionally using a browser
	:`tg import`_:        Import commit(s) to separate TopGit branches
	:`tg info`_:          Show status information about a TopGit branch
	:`tg log`_:           Run git log limiting revisions to a TopGit branch
	:`tg mail`_:          Shortcut for git send-email with ``tg patch`` output
	:`tg migrate-bases`_: Transition top-bases to new location
	:`tg next`_:          Show next branch in the patch series
	:`tg patch`_:         Generate a patch file for a TopGit branch
	:`tg prev`_:          Show previous branch in the patch series
	:`tg push`_:          Run git push on TopGit branch(es) and depedencies
	:`tg rebase`_:        Auto continue git rebase if rerere resolves conflicts
	:`tg remote`_:        Set up remote for fetching/pushing TopGit branches
	:`tg revert`_:        Revert ref(s) to a state stored in a ``tg tag``
	:`tg shell`_:         Extended `wayback machine`_ mode
	:`tg status`_:        Show current TopGit status (e.g. in-progress update)
	:`tg summary`_:       Show various information about TopGit branches
	:`tg tag`_:           Create tag that records current TopGit branch state
	:`tg update`_:        Update TopGit branch(es) with respect to dependencies

tg help
~~~~~~~
	Our sophisticated integrated help facility.  Mostly duplicates
	what is below::

	 # to list commands:
	 $ tg help
	 # to get help for a particular command:
	 $ tg help <command>
	 # to get help for a particular command in a browser window:
	 $ tg help -w <command>
	 # to get help on TopGit itself
	 $ tg help tg
	 # to get help on TopGit itself in a browser
	 $ tg help -w tg

tg status
~~~~~~~~~
	Our sophisticated status facility.  Similar to Git's status command
	but shows any in-progress update that's awaiting a merge resolution
	or any other on-going TopGit activity (such as a branch creation).

	With a single ``--verbose`` (or ``-v``) option include a short status
	display for any dirty (but not untracked) files.  This also causes all
	non file status lines to be prefixed with "## ".

	With two (or more) ``--verbose`` (or ``-v``) options, additionally
	show full symbolic ref names and unabbreviated hash values.

	With the ``--exit-code`` option the exit code will be non-zero if any
	TopGit or Git operation is currently in progress or the working
	directory is unclean.

tg create
~~~~~~~~~
	Create a new TopGit-controlled topic branch of the given name
	(required argument) and switch to it.  If no dependencies are
	specified (by extra arguments passed after the first one), the
	current branch is assumed to be the only dependency.

	By default ``tg create`` opens an editor on the new ``.topmsg`` file
	and then commits the new ``.topmsg`` and ``.topdeps`` files
	automatically with a suitable default commit message.

	The commit message can be changed with the ``-m`` (or ``--message``) or
	``-F`` (or ``--file``) option.  The automatic commit can be suppressed
	by using the ``--no-commit`` (or ``-n``) option.  Running the editor on
	the new ``.topmsg`` file can be suppressed by using ``--no-edit``
	(which does *NOT* suppress the automatic commit unless ``--no-commit``
	is also given) or by providing an explicit value for the new
	``.topmsg`` file using the ``--topmsg`` or ``--topmsg-file`` option.
	In any case the ``.topmsg`` content will be automatically reformated to
	have a ``Subject:`` header line if needed.

	If the ``format.signoff`` config variable (see ``git help config``)
	has been set to true then the ``Signed-off-by:`` header line added to
	the end of the initial version of the ``.topmsg`` file will be
	uncommented by default.  Otherwise it will still be there but will be
	commented out and will be automatically stripped if no action is taken
	to remove the comment character.

	If more than one dependency is listed an automatic ``tg update`` runs
	after the branch has been created to merge in the additional
	dependencies and bring the branch up-to-date.  This can be suppressed
	with the ``--no-commit`` option (which also suppresses the initial
	commit) or the ``--no-update`` option (which allows the initial commit
	while suppressing only the update operation portion).

	Previous versions of TopGit behaved as though both the ``--no-edit``
	and ``--no-commit`` options were always given on the command line.

	The default behavior has been changed to promote a separation between
	commits that modify ``.topmsg`` and/or ``.topdeps`` and commits that
	modify other files.  This facilitates cleaner cherry picking and other
	patch maintenance activities.

	You should edit the patch description (contained in the ``.topmsg``
	file) as appropriate.  It will already contain some prefilled bits.
	You can set the ``topgit.to``, ``topgit.cc`` and ``topgit.bcc``
	git configuration variables (see ``git help config``) in order to
	have ``tg create`` add these headers with the given default values
	to ``.topmsg`` before invoking the editor.  If the configuration
	variable ``topgit.subjectPrefix`` is set its value will be inserted
	*between* the initial ``[`` and the word ``PATCH`` in the subject
	line (with a space added before the word ``PATCH`` of course).

	The main task of ``tg create`` is to set up the topic branch base
	from the dependencies.  This may fail due to merge conflicts if more
	than one dependency is given.	In that case, after you commit the
	conflict resolution, you should call ``tg update --continue`` to
	finish merging the dependencies into the new topic branch base.

	With the ``--base`` (aka ``--no-deps``) option at most one dependency
	may be listed which may be any valid committish (instead of just
	refs/heads/...) and the newly created TopGit-controlled branch will
	have an empty ``.topdeps`` file.  This may be desirable in order to
	create a TopGit-controlled branch that has no changes of its own and
	serves merely to mark the common dependency that all other
	TopGit-controlled branches in some set of TopGit-controlled branches
	depend on.  A plain, non-TopGit-controlled branch can be used for the
	same purpose, but the advantage of a TopGit-controlled branch with no
	dependencies is that it will be pushed with ``tg push``, it will show
	up in the ``tg summary`` and ``tg info`` output with the subject from
	its ``.topmsg`` file thereby documenting what it's for and finally it
	can be set up with ``tg create -r`` and/or ``tg remote --populate`` to
	facilitate sharing.

	For example, ``tg create --base t/release v2.1`` will create a TopGit-
	controlled ``t/release`` branch based off the ``v2.1`` tag that can then
	be used as a base for creation of other TopGit-controlled branches.
	Then when the time comes to move the base for an entire set of changes
	up to ``v2.2`` the command ``tg update --base t/release v2.2`` can be
	used followed by ``tg update --all``.

	Using ``--base`` it's also possible to use ``tg create`` on an
	unborn branch (omit the dependency name or specify ``HEAD``).  The
	unborn branch itself can be made into the new TopGit branch (rather
	than being born empty and then having the new TopGit branch based off
	that) by specifying ``HEAD`` as the new branch's name (which is
	probably what you normally want to do in this case anyway so you can
	just run ``tg create --base HEAD`` to accomplish that).

	In an alternative use case, if ``-r <rbranch>`` is given instead of a
	dependency list, the topic branch is created based on the given
	remote branch.  With just ``-r`` the remote branch name is assumed
	to be the same as the local topic branch being created.  Since no
	new commits are created in this mode (only two refs will be updated)
	the editor will never be run for this use case.  Note that no other
	options may be combined with ``-r`` although a global ``-r`` option
	can be used to alter which remote ``<rbranch>`` refers to.

	The ``--quiet`` (or ``-q``) option suppresses most informational
	messages.

tg delete
~~~~~~~~~
	Remove a TopGit-controlled topic branch of the given name
	(required argument). Normally, this command will remove only an
	empty branch (base == head) without dependents; use ``-f`` to
	remove a non-empty branch or a branch that is depended upon by
	another branch.

	The ``-f`` option is also useful to force removal of a branch's
	base, if you used ``git branch -D B`` to remove branch B, and then
	certain TopGit commands complain, because the base of branch B
	is still there.

	Normally ``tg delete`` will refuse to delete the current branch.
	However, giving ``-f`` twice (or more) will force it to do so but it
	will first detach your HEAD.

	IMPORTANT: Currently, this command will *NOT* remove the branch
	from the dependency list in other branches. You need to take
	care of this *manually*.  This is even more complicated in
	combination with ``-f`` -- in that case, you need to manually
	unmerge the removed branch's changes from the branches depending
	on it.

	The same ``--stash`` and ``--no-stash`` options are accepted with
	the same exact semantics as for `tg update`_.

	See also ``tg annihilate``.

	| TODO: ``-a`` to delete all empty branches, depfix, revert

tg annihilate
~~~~~~~~~~~~~
	Make a commit on the current or given TopGit-controlled topic
	branch that makes it equal to its base, including the presence or
	absence of .topmsg and .topdeps.  Annihilated branches are not
	displayed by ``tg summary``, so they effectively get out of your
	way.  However, the branch still exists, and ``tg push`` will
	push it (except if given the ``-a`` option).  This way, you can
	communicate that the branch is no longer wanted.

	When annihilating a branch that has dependents (i.e. branches
	that depend on it), those dependents have the dependencies of
	the branch being annihilated added to them if they do not already
	have them as dependencies.  Essentially the DAG is repaired to
	skip over the annihilated branch.

	Normally, this command will remove only an empty branch
	(base == head, except for changes to the .top* files); use
	``-f`` to annihilate a non-empty branch.

	After completing the annihilation itself, normally ``tg update``
	is run on any modified dependents.  Use the ``--no-update`` option
	to suppress running ``tg update``.

	The same ``--stash`` and ``--no-stash`` options are accepted with
	the same exact semantics as for `tg update`_.

tg depend
~~~~~~~~~
	Change the dependencies of a TopGit-controlled topic branch.
	This should have several subcommands, but only ``add`` is
	supported right now.

	The ``add`` subcommand takes an argument naming a topic branch to
	be added, adds it to ``.topdeps``, performs a commit and then
	updates your topic branch accordingly.  If you want to do other
	things related to the dependency addition, like adjusting
	``.topmsg``, use the option ``--no-commit``.  Adding the
	``--no-update`` (or ``--no-commit``) option will suppress the
	``tg update`` normally performed after committing the change.

	It is safe to run ``tg depend add`` in a dirty worktree, but the
	normally performed ``tg update`` will be suppressed in that case
	(even if neither ``--no-update`` nor ``--no-commit`` is given).

	You have enabled ``git rerere`` haven't you?

	| TODO: Subcommand for removing dependencies, obviously

tg files
~~~~~~~~
	List files changed by the current or specified topic branch.

tg info
~~~~~~~
	Show summary information about the current or specified topic
	branch.

	Numbers in parenthesis after a branch name such as "(11/3 commits)"
	indicate how many commits on the branch (11) and how many of those
	are non-merge commits (3).

	With ``--verbose`` (or ``-v``) include a list of dependents (i.e. other
	branches that depend on this one).  Another ``--verbose`` annotates
	them with "[needs merge]" if the current tip of branch for which info
	is being shown has not yet been merged into the base of the dependent.
	Two ``--verbose`` options also cause annihilated dependencies to be
	shown in the "Depends:" list.

	Alternatively, if ``--heads`` is used then which of the independent
	TopGit branch heads (as output by ``tg summary --topgit-heads``)
	logically contains the specified commit (which may be any committish --
	defaults to ``HEAD`` if not given).  Zero or more results will be
	output.  Note that "logically" means with regard to the TopGit
	dependency relationships as established by the ``.topdeps`` file(s).
	It's the answer that would be given when all the TopGit branches are
	up-to-date (even though they need not be to use this option) and the
	``git branch --contains`` command is run and the output then filtered
	to only those branches that appear in ``tg summary --topgit-heads``.
	This computation may require several seconds on complex repositories.

	If ``--leaves`` is used then the unique list of leaves of the current
	or specified topic branch is shown as one fully-qualified ref per line.
	Duplicates are suppressed and a tag name will be used when appropriate.
	A "leaf" is any dependency that is either not a TopGit branch or is
	the base of a non-annihilated TopGit branch with no non-annihilated
	dependencies.

	The ``--deps`` option shows non-annihilated TopGit dependencies of the
	specified branch (default is ``HEAD``).  (It can also be spelled out
	as ``--dependencies`` for the pedantically inclined.)

	The ``--dependents`` option shows non-annihilated TopGit dependents
	(i.e. branches that depend on the specified branch).  The default
	branch to operate on is again ``HEAD``.

	A linearized patch series can only be automatically created for a
	TopGit topic branch (including its recursive dependencies) when exactly
	one line is output by ``tg info --leaves <topic-branch>`` unless it's
	always possible to merge all the leaves using a trivial aggressive
	(exactly 2 leaves) or trivial aggressive octopus (3 or more leaves)
	merge with an empty tree as the common base (aka tree1).

	With ``--series`` the list of TopGit branches in the order they would
	be linearized into a patch series is shown along with the description
	of each branch.  If the branch name passed to ``tg info`` is not the
	last branch in the series a marker column will be provided to quickly
	locate it in the list.  This same option can be used with `tg checkout`_.

	Some patches shown in the list may not actually end up introducing any
	changes if exported and will therefore end up being omitted.  The ``0``
	indicator in ``tg summary`` output can help to identify some of these.

	The patches shown in the series in the order they are shown form the
	basis for the ``tg next`` and ``tg prev`` operations with the first
	patch shown being considered the first and so on up to the last.

tg patch
~~~~~~~~
	Generate a patch from the current or specified topic branch.
	This means that the diff between the topic branch base and head
	(latest commit) is shown, appended to the description found in
	the ``.topmsg`` file.

	The patch is simply dumped to stdout.  In the future, ``tg patch``
	will be able to automatically send the patches by mail or save
	them to files. (TODO)

	Options:
	  -i		base patch generation on index instead of branch
	  -w		base patch generation on working tree instead of branch
	  --binary	pass --binary to ``git diff-tree`` to enable generation
	  		of binary patches
	  --quiet	be quiet (aka ``-q``) about missing and unfixed From:
	  --from	make sure patch has a From: line, if not add one
	  --from=<a>	<a> or Signed-off-by value or ident value; ``git am``
	  		really gets unhappy with patches missing From: lines;
	  		will NOT replace an existing non-empty From: header
	  --no-from	leave all From: lines alone, missing or not (default)
	  --diff-opt	options after the branch name (and an optional ``--``)
	  		are passed directly to ``git diff-tree``

	In order to pass a sole explicit ``-w`` through to ``git diff-tree`` it
	must be separated from the ``tg`` options by an explicit ``--``.
	Or it can be spelled as ``--ignore-all-space`` to distinguuish it from
	``tg``'s ``-w`` option.

	If the config variable ``topgit.from`` is set to a boolean it can be
	used to enable or disable the ``--from`` option by default.  If it's
	set to the special value ``quiet`` the ``--quiet`` option is enabled
	and From: lines are left alone by default.  Any other non-empty value
	is taken as a default ``--from=<value>`` option.  The ``--no-from``
	option will temporarily disable use of the config value.

	If additional non-``tg`` options are passed through to
	``git diff-tree`` (other than ``--binary`` which is fully supported)
	the resulting ``tg patch`` output may not be appliable.

tg mail
~~~~~~~
	Send a patch from the current or specified topic branch as
	email(s).

	Takes the patch given on the command line and emails it out.
	Destination addresses such as To, Cc and Bcc are taken from the
	patch header.

	Since it actually boils down to ``git send-email``, please refer
	to the documentation for that for details on how to setup email
	for git.  You can pass arbitrary options to this command through
	the ``-s`` parameter, but you must double-quote everything.  The
	``-r`` parameter with a msgid can be used to generate in-reply-to
	and reference headers to an earlier mail.

	WARNING: be careful when using this command.  It easily sends
	out several mails.  You might want to run::

		git config sendemail.confirm always

	to let ``git send-email`` ask for confirmation before sending any
	mail.

	| TODO: ``tg mail patchfile`` to mail an already exported patch
	| TODO: mailing patch series
	| TODO: specifying additional options and addresses on command line

tg remote
~~~~~~~~~
	Register the given remote as TopGit-controlled. This will create
	the namespace for the remote branch bases and teach ``git fetch``
	to operate on them. However, from TopGit 0.8 onwards you need to
	use ``tg push``, or ``git push --mirror``, for pushing
	TopGit-controlled branches.

	``tg remote`` takes an optional remote name argument, and an
	optional ``--populate`` switch.  Use ``--populate`` for your
	origin-style remotes: it will seed the local topic branch system
	based on the remote topic branches.  ``--populate`` will also make
	``tg remote`` automatically fetch the remote, and ``tg update`` look
	at branches of this remote for updates by default.

	Using ``--populate`` with a remote name causes the ``topgit.remote``
	git configuration variable to be set to the given remote name.

tg summary
~~~~~~~~~~
	Show overview of all TopGit-tracked topic branches and their
	up-to-date status.  With a branch name limit output to that branch.
	Using ``--deps-only`` or ``--rdeps`` changes the default from all
	branches to just the current ``HEAD`` branch but using ``--all`` as
	the branch name will show results for all branches instead of ``HEAD``.

		``>``
			marks the current topic branch

		``0``
			indicates that it introduces no changes of its own

		``l``/``r``
			indicates respectively whether it is local-only
			or has a remote mate

		``L``/``R``
			indicates respectively if it is ahead or out-of-date
			with respect to its remote mate

		``D``
			indicates that it is out-of-date with respect to its
			dependencies

		``!``
			indicates that it has missing dependencies [even if
			they are recursive ones]

		``B``
			indicates that it is out-of-date with respect to
			its base

		``*``
			indicates it is ahead of (and needs to be merged into)
			at least one of its dependents -- only computed when
			showing all branches or using the (possibly implied)
			``--with-deps`` option.

	This can take a longish time to accurately determine all the
	relevant information about each branch; you can pass ``-t`` (or ``-l``
	or ``--list``) to get just a terse list of topic branch names quickly.
	Also adding ``--verbose`` (or ``-v``) includes the subjects too.
	Adding a second ``--verbose`` includes annihilated branches as well.

	Passing ``--heads`` shows independent topic branch names and when
	combined with ``--rdeps`` behaves as though ``--rdeps`` were run with
	the output of ``--heads``.

	The ``--heads-independent`` option works just like ``--heads`` except
	that it computes the heads using ``git merge-base --independent``
	rather than examining the TopGit ``.topdeps`` relationships.  If the
	TopGit branches are all up-to-date (as shown in ``tg summary``) then
	both ``--heads`` and ``--heads-independent`` should compute the same
	list of heads (unless some overlapping TopGit branches have been
	manually created).  If not all the TopGit branches are up-to-date then
	the ``--heads-independent`` results may have extra items in it, but
	occasionally that's what's needed; usually it's the wrong answer.
	(Note that ``--topgit-heads`` is accepted as an alias for ``--heads``
	as well.)

	Using ``--heads-only`` behaves as though the output of ``--heads`` was
	passed as the list of branches along with ``--without-deps``.

	Alternatively, you can pass ``--graphviz`` to get a dot-suitable output
	for drawing a dependency graph between the topic branches.

	You can also use the ``--sort`` option to sort the branches using
	a topological sort.  This is especially useful if each
	TopGit-tracked topic branch depends on a single parent branch,
	since it will then print the branches in the dependency order.
	In more complex scenarios, a text graph view would be much more
	useful, but that has not yet been implemented.

	The ``--deps`` option outputs dependency information between
	branches in a machine-readable format.  Feed this to ``tsort`` to
	get the output from --sort.

	The ``--deps-only`` option outputs a sorted list of the unique branch
	names given on the command line plus all of their recursive
	dependencies (subject to ``--exclude`` of course).  When
	``--deps-only`` is given the default is to just display information for
	``HEAD``, but that can be changed by using ``--all`` as the branch
	name.  Each branch name will appear only once in the output no matter
	how many times it's visited while tracing the dependency graph or how
	many branch names are given on the command line to process.

	The ``--rdeps`` option outputs dependency information in an indented
	text format that clearly shows all the dependencies and their
	relationships to one another.  When ``--rdeps`` is given the default is
	to just display information for ``HEAD``, but that can be changed by
	using ``--all`` as the branch name or by adding the ``--heads`` option.
	Note that ``tg summary --rdeps --heads`` can be particularly helpful in
	seeing all the TopGit-controlled branches in the repository and	their
	relationships to one another.

	Note that ``--rdeps`` has two flavors.  The first (and default) is
	``--rdeps-once`` which only shows the dependencies of a branch when
	it's first visited.  For example, if D depends on several other
	branches perhaps recursively and both branch A and B depend on D, then
	whichever of A or B is shown first will show the entire dependency
	chain for D underneath it and the other one will just show a line for
	D itself with a "^" appended to indicate that the rest of the deps for
	D can be found above.  This can make the output a bit more compact
	without actually losing any information which is why it's the default.
	However, using the ``--rdeps-full`` variant will repeat the full
	dependency chain every time it's encountered.

	Adding ``--with-deps`` replaces the given list of branches (which will
	default to ``HEAD`` if none are given) with the result of running
	``tg summary --deps-only --tgish`` on the list of branches.  This can
	be helpful in limiting ``tg summary`` output to only the list of given
	branches and their dependencies when many TopGit-controlled branches
	are present in the repository.  Use ``--without-deps`` to switch back
	to the old behavior.

	The ``--with-related`` option extends (and therefore implies)
	``--with-deps``.  First the list of branches (which will default to
	``HEAD`` if none are given) is replaced with the result of running
	``tg summary --heads`` (aka ``--topgit-heads``) and the result is then
	processed as though it had been specified using ``--with-deps``.

	When it would be allowed, ``--with-deps`` is now the default.  But,
	if in addition, exactly one branch is specified (either explicitly
	or implicitly) and it's spelled *exactly* as ``HEAD`` or ``@`` then
	the default ``--with-deps`` will be promoted to a default
	``--with-related`` instead.  Since duplicate branches are removed
	before processing, explicitly listing ``@`` twice provides an easy way
	to defeat this automatic promotion and ask for ``--with-deps`` on the
	``HEAD`` symbolic ref with minimal typing when ``--with-related`` isn't
	really wanted and typing the full ``--with-deps`` option is too hard.

	With ``--exclude branch``, branch can be excluded from the output
	meaning	it will be skipped and its name will be omitted from any
	dependency output.  The ``--exclude`` option may be repeated to omit
	more than one branch from the output.  Limiting the output to a single
	branch that has been excluded will result in no output at all.

	The ``--tgish-only`` option behaves as though any non-TopGit-controlled
	dependencies encountered during processing had been listed after an
	``--exclude`` option.

	Note that the branch name can be specified as ``HEAD`` or ``@`` as a
	shortcut for the TopGit-controlled branch that ``HEAD`` is a
	symbolic ref to.  The ``tg summary @`` and ``tg summary @ @`` commands
	can be quite useful.

tg contains
~~~~~~~~~~~
	Search all TopGit-controlled branches (and optionally their remotes)
	to find which TopGit-controlled branch contains the specified commit.

	This is more than just basic branch containment as provided for by the
	``git branch --contains`` command.  While the shown branch name(s)
	will, indeed, be one (or more) of those output by the
	``git branch --contains`` command, the result(s) will exclude any
	TopGit-controlled branches from the result(s) that have one (or more)
	of their TopGit dependencies (either direct or indirect) appearing in
	the ``git branch --contains`` output.

	Normally the result will be only the one, single TopGit-controlled
	branch for which the specified committish appears in the ``tg log``
	output for that branch (unless the committish lies outside the
	TopGit-controlled portion of the DAG and ``--no-strict`` was used).

	Unless ``--annihilated-okay`` (or ``--ann`` or ``--annihilated``) is
	used then annihilated branches will be immediately removed from the
	``git branch --contains`` output before doing anything else.  This
	means a committish that was originally located in a now-annihilated
	branch will show up in whatever branch picked up the annihilated
	branch's changes (if there is one).  This is usually the correct
	answer, but occasionally it's not; hence this option.  If this option
	is used together with ``--verbose`` then annihilated branches will
	be shown as "[:annihilated:]".

	In other words, if a ``tg patch`` is generated for the found branch
	(assuming one was found and a subsequent commit in the same branch
	didn't then revert or otherwise back out the change), then that patch
	will include the changes introduced by the specified committish
	(unless, of course, that committish is outside the TopGit-controlled
	portion of the DAG and ``--no-strict`` was given).

	This can be very helpful when, for example, a bug is discovered and
	then after using ``git bisect`` (or some other tool) to find the
	offending commit it's time to commit the fix.  But because the
	TopGit merging history can be quite complicated and maybe the one
	doing the fix wasn't the bug's author (or the author's memory is just
	going), it can sometimes be rather tedious to figure out which
	TopGit branch the fix belongs in.  The ``tg contains`` command can
	quickly tell you the answer to that question.

	With the ``--remotes`` (or ``-r``) option a TopGit-controlled remote
	branch name may be reported as the result but only if there is no
	non-remote branch containing the committish (this can only happen
	if at least one of the TopGit-controlled local branches are not yet
	up-to-date with their remotes).

	With the ``--verbose`` option show which TopGit DAG head(s) (one or
	more of the TopGit-controlled branch names output by
	``tg summary --heads``) have the result as a dependency (either direct
	or indirect).  Using this option will noticeably increase running time.

	With the default ``--strict`` option, results for which the base of the
	TopGit-controlled branch contains the committish will be suppressed.
	For example, if the committish was deep-down in the master branch
	history somewhere far outside of the TopGit-controlled portion of
	the DAG, with ``--no-strict``, whatever TopGit-controlled branch(es)
	first picked up history containing that committish will be shown.
	While this is a useful result it's usually not the desired result
	which is why it's not the default.

	To summarize, even with ``--remotes``, remote results are only shown
	if there are no non-remote results.  Without ``--no-strict`` (because
	``--strict`` is the default) results outside the TopGit-controlled
	portion of the DAG are never shown and even with ``--no-strict`` they
	will only be shown if there are no ``--strict`` results.  Finally,
	the TopGit head info shown with ``--verbose`` only ever appears for
	local (i.e. not a remote branch) results.  Annihilated branches are
	never considered possible matches without ``--annihilated-okay``.

tg checkout
~~~~~~~~~~~
	Switch to a topic branch.  You can use ``git checkout <branch>``
	to get the same effect, but this command helps you navigate
	the dependency graph, or allows you to match the topic branch
	name using a regular expression, so it can be more convenient.

	The ``--branch`` (or ``-b`` or ``--branch=<name>``) option changes
	the default starting point from ``HEAD`` to the specified branch.

	For the "next" and "previous" commands, the ``<steps>`` value may
	be ``--all`` (or ``-a``) to take "As many steps As possible" or
	"step ALL the way" or "ALL steps at once" (or make something better
	up yourself).

	The following subcommands are available:

	    ``tg checkout next [<steps>]``
				Check out a subsequent branch in the
				dependency graph (see ``tg info --series``).
				Move ``<steps>`` (default 1) step(s) in
				the "next" direction (AKA ``n``).

	    ``tg checkout prev [<steps>]``
				Check out a preceding branch in the
				dependency graph (see ``tg info --series``).
				Move ``<steps>`` (default 1) step(s) in the
				"previous" direction (AKA ``p`` or ``previous``).

	    ``tg checkout [goto] [--] <pattern>``
				Check out a topic branch that
				matches ``<pattern>``.  ``<pattern>``
				is used as a grep BRE pattern to filter
				all the topic branches.  Both ``goto`` and
				``--`` may be omitted provided ``<pattern>``
				is not ``-a``, ``--all``, ``-h``, ``--help``,
				``goto``, ``--``, ``n``, ``next``, ``push``,
				``child``, ``p``, ``prev``, ``previous``,
				``pop``, ``parent``, ``+``, ``-`` or ``..``.

	    ``tg checkout [goto] [--] --series[=<head>]``
				Check out a topic branch that belongs to
				the current (or ``<head>``) patch series.
				A list with descriptions (``tg info --series``)
				will be shown to choose from if more than one.

	    ``tg checkout + [<steps>]``
				An alias for ``next``.

	    ``tg checkout push [<steps>]``
				An alias for ``next``.

	    ``tg checkout child [<steps>]``
				Deprecated alias for ``next``.

	    ``tg checkout``
				Semi-deprecated alias for ``next``.

	    ``tg checkout - [<steps>]``
				An alias for ``prev``.

	    ``tg checkout pop [<steps>]``
				An alias for ``prev``.

	    ``tg checkout parent [<steps>]``
				Deprecated alias for ``prev``.

	    ``tg checkout .. [<steps>]``
				Semi-deprecated alias for ``prev``.

	If any of the above commands can find more than one possible
	branch to switch to, you will be presented with the matches
	and asked to select one of them.

	Note that unless overridden by an explicit alias (see ALIASES_),
	``tg goto`` is an implicit alias for ``tg checkout goto``.

	If the ``--ignore-other-worktrees`` (or ``--iow``) option is given and
	the current Git version is at least 2.5.0 then the full
	``--ignore-other-worktrees`` option will be passed along to the
	``git checkout`` command when it's run (otherwise the option will be
	silently ignored and not passed to Git as it would cause an error).

	The ``--force`` (or ``-f``) option, when given, gets passed through to
	the ``git checkout`` command.

	The ``--merge`` (or ``-m``) option, when given, gets passed through to
	the ``git checkout`` command.

	The ``--quiet`` (or ``-q``) option, when given, gets passed through to
	the ``git checkout`` command.

	The ``<pattern>`` of ``tg checkout goto`` is not optional and is
	intepreted as a BRE pattern (basic regular expression).  To select
	from all the available topic branches, supply ``.`` as the pattern.
	(In other words ``tg checkout goto .``)

	Normally, the ``next`` and ``prev`` commands move one step in
	the dependency graph of the topic branches.  The ``-a`` option
	causes them (and their aliases) to move as far as possible.
	That is, ``tg checkout next -a`` moves to the final topic branch
	in the dependency graph (see ``tg info --series``) for the
	current branch.  ``tg checkout prev -a`` moves to the first
	topic branch in the dependency graph (see ``tg info --series``)
	for the current branch.  If there is more than one
	possibility, you will be prompted for your selection.

	See also NAVIGATION_.

tg export
~~~~~~~~~
	Export a tidied-up history of the current topic branch and its
	dependencies, suitable for feeding upstream.  Each topic branch
	corresponds to a single commit or patch in the cleaned up
	history (corresponding basically exactly to ``tg patch`` output
	for the topic branch).

	The command has three possible outputs now -- either a Git branch
	with the collapsed history, a Git branch with a linearized
	history, or a quilt series in new directory.

	In the case where you are producing collapsed history in a new
	branch, you can use this collapsed structure either for
	providing a pull source for upstream, or for further
	linearization e.g. for creation of a quilt series using git log::

		git log --pretty=email -p --topo-order origin..exported

	To better understand the function of ``tg export``, consider this
	dependency structure::

	 origin/master - t/foo/blue - t/foo/red - master
	              `- t/bar/good <,----------'
	              `- t/baz      ------------'

	(where each of the branches may have a hefty history). Then::

	 master$ tg export for-linus

	will create this commit structure on the branch ``for-linus``::

	 origin/master - t/foo/blue -. merge - t/foo/red -.. merge - master
	              `- t/bar/good <,-------------------'/
	              `- t/baz      ---------------------'

	In this mode, ``tg export`` works on the current topic branch, and
	can be called either without an option (in that case,
	``--collapse`` is assumed), or with the ``--collapse`` option, and
	with one mandatory argument: the name of the branch where the
	exported result will be stored.

	Both the ``--collapse`` and ``--linearize`` modes also accept a
	``-s <mode>`` option to specify subject handling behavior for the
	freshly created commits.  There are five possible modes:

		:keep:          Like ``git mailinfo -k``
		:mailinfo:      Like ``git mailinfo``
		:patch:         Remove first [PATCH*] if any
		:topgit:        Remove first [PATCH*], [BASE], [ROOT] or [STAGE]
		:trim:          Trim runs of spaces/tabs to a single space

	The ``topgit`` (aka ``tg``) mode is the default (quelle surprise) and
	like the ``patch`` mode will only strip the first square brackets tag
	(if there is one) provided it's a TopGit-known tag (the ``patch``
	variation will only strip a "[PATCH*]" tag but still just the first
	one).  Note that TopGit does understand "[RELEASE]" in ``topgit`` mode.
	With ``trim`` (aka ``ws``) internal runs of spaces/tabs are converted
	to a single space, but no square brackets tags are removed.  The ``ws``
	mode should generally be preferred instead of using ``keep`` mode.
	All modes always remove leading/trailing spaces and tabs and if the
	``topgit.subjectPrefix`` value (see `tg create`_) has been set both the
	``topgit`` and ``patch`` modes will match tags with that prefix too.

	Setting the config variable ``topgit.subjectMode`` to one of the mode
	values shown above will change the default to that mode.

	Both the ``--collapse`` and ``--linearize`` modes also accept a
	``--notes[=<ref>]`` option to export the portion of the .topmsg file
	following a ``---`` separator line to the specified notes ref.  If
	``<ref>`` is omitted then ``refs/notes/commits`` will be used.  If
	``<ref>`` does not start with ``refs/notes/`` then ``refs/notes/``
	will be prepended unless it starts with ``notes/`` in which case
	only ``refs/`` will be prepended.

	Setting the config variable ``topgit.notesExport`` to a boolean or
	to a ``<ref>`` name will set the default for the ``--notes`` option
	(with no config or ``--notes[=<ref>]`` option the ``---`` comment is
	discarded by default).  To override a ``topgit.notesExport`` option
	and discard any ``---`` comments, use ``--no-notes``.

	When using the linearize mode::

	 master$ tg export --linearize for-linus

	you get a linear history respecting the dependencies of your
	patches in a new branch ``for-linus``.  The result should be more
	or less the same as using quilt mode and then reimporting it
	into a Git branch.  (More or less because the topological order
	can usually be extended in more than one way into a total order,
	and the two methods may choose different ones.)  The result
	might be more appropriate for merging upstream, as it contains
	fewer merges.

	Note that you might get conflicts during linearization because
	the patches are reordered to get a linear history.  If linearization
	would produce conflicts then using ``--quilt`` will also likely result
	in conflicts when the exported quilt series is applied.  Since the
	``--quilt`` mode simply runs a series of ``tg patch`` commands to
	generate the patches in the exported quilt series and those patches
	will end up being applied linearly, the same conflicts that would be
	produced by the ``--linearize`` option will then occur at that time.

	To avoid conflicts produced by ``--linearize`` (or by applying the
	``--quilt`` output), use the default ``--collapse`` mode and then use
	``tg rebase`` (or ``git rebase -m`` directly) on the collapsed branch
	(with a suitable <upstream>) followed by ``git format-patch`` on the
	rebased result to produce a conflict-free patch set.  A suitable
	upstream may be determined with the ``tg info --leaves`` command (if
	it outputs more than one line, linearization will be problematic).

	You have enabled ``git rerere`` haven't you?

	When using the quilt mode::

	 master$ tg export --quilt for-linus

	would create the following directory ``for-linus``::

	 for-linus/t/foo/blue.diff
	 for-linus/t/foo/red.diff
	 for-linus/t/bar/good.diff
	 for-linus/t/baz.diff
	 for-linus/series:
		t/foo/blue.diff -p1
		t/bar/good.diff -p1
		t/foo/red.diff -p1
		t/baz.diff -p1

	With ``--quilt``, you can also pass the ``-b`` parameter followed
	by a comma-separated explicit list of branches to export, or
	the ``--all`` parameter (which can be shortened to ``-a``) to
	export them all.  The ``--binary`` option enables producing Git
	binary patches.  These options are currently only supported
	with ``--quilt``.

	In ``--quilt`` mode the patches are named like the originating
	topgit branch.  So usually they end up in subdirectories of the
	output directory.  With the ``--flatten`` option the names are
	mangled so that they end up directly in the output dir (slashes
	are replaced with underscores).  With the ``--strip[=N]`` option
	the first ``N`` subdirectories (all if no ``N`` is given) get
	stripped off.  Names are always ``--strip``'d before being
	``--flatten``'d.  With the option ``--numbered`` (which implies
	``--flatten``) the patch names get a number as prefix to allow
	getting the order without consulting the series file, which
	eases sending out the patches.

	Note that ``tg export`` is fully compatible with the `wayback machine`_
	and when used with the ``--collapse`` or ``--linearize`` options will
	"push" the resulting branch back into the main repository when used in
	wayback mode.

	| TODO: Make stripping of non-essential headers configurable
	| TODO: ``--mbox`` option to export instead as an mbox file
	| TODO: support ``--all`` option in other modes of operation
	| TODO: For quilt exporting, export the linearized history created in
	        a temporary branch--this would allow producing conflict-less
	        series

tg import
~~~~~~~~~
	Import commits within the given revision range(s) into TopGit,
	creating one topic branch per commit. The dependencies are set
	up to form a linear sequence starting on your current branch --
	or a branch specified by the ``-d`` parameter, if present.

	The branch names are auto-guessed from the commit messages and
	prefixed by ``t/`` by default; use ``-p <prefix>`` to specify an
	alternative prefix (even an empty one).

	Each "<range>" must be of the form <rev1>..<rev2> where either
	<rev1> or <rev2> can be omitted to mean HEAD.  Additionally the
	shortcut <rev>^! (see ``git help revisions``) is permitted as a
	"<range>" to select the single commit <rev> but only if the
	commit <rev> has *exactly* one parent.  This is really just a
	shortcut for <rev>^..<rev> but somewhat safer since it will fail
	if <rev> has other than one parent.

	Alternatively, you can use the ``-s NAME`` parameter to specify
	the name of the target branch; the command will then take one
	more argument describing a *single* commit to import which must
	not be a merge commit.

	Use the ``--notes[=<ref>]`` option to import the ``git notes``
	associated with the commit being imported to the .topmsg file -- if
	non-empty notes are present, they will be appended to the generated
	.topmsg file preceded by a ``---`` separator line.  If ``<ref>`` is
	omitted then ``refs/notes/commits`` will be used.  If ``<ref>``
	does not start with ``refs/notes/`` then ``refs/notes/`` will be
	prepended unless it starts with ``notes/`` in which case only
	``refs/`` will be prepended.

	Setting the config variable ``topgit.notesImport`` to a boolean or
	to a ``<ref>`` name will set the default for the ``--notes`` option
	(with no config or ``--notes[=<ref>]`` option no ``---`` comment is
	added to the generated .topmsg file by default).  To override a
	``topgit.notesImport`` option and not add any ``---`` comments, use
	``--no-notes``.

tg update
~~~~~~~~~
	Update the current, specified or all topic branches with respect
	to changes in the branches they depend on and remote branches.
	This is performed in two phases -- first, changes within the
	dependencies are merged to the base, then the base is merged
	into the topic branch.  The output will guide you on what to do
	next in case of conflicts.

	You have enabled ``git rerere`` haven't you?

	Remember the default expiration time for resolved merge conflicts is
	only 60 days.  Increase their longevity by setting the Git
	configuration variable ``gc.rerereResolved`` to a higher number such
	as ``9999`` like so::

		git config --global gc.rerereResolved 9999

	The ``--[no-]auto[-update]`` options together with the
	``topgit.setAutoUpdate`` config item control whether or not TopGit
	will automatically temporarily set ``rerere.autoUpdate`` to true while
	running ``tg update``.  The default is true.  Note that this does not
	enable Git's ``rerere`` feature, it merely makes it automatically stage
	any previously resolved conflicts.  The ``rerere.enabled`` setting must
	still be separately enabled (i.e. set to ``true``) for the ``rerere``
	feature to do anything at all.

	Using ``--auto[-update]`` makes ``tg update`` always temporarily set
	``rerere.autoUpdate`` to ``true`` while running ``tg update``.  The
	``--no-auto[-update]`` option prevents ``tg update`` from changing the
	``rerere.autoUpdate`` setting, but if ``rerere.autoUpdate`` has already
	been enabled in a config file, ``tg update`` never disables it even
	with ``--no-auto``.  If ``topgit.setAutoUpdate`` is unset or set to
	``true`` then ``tg update`` implicitly does ``--auto``, otherwise it
	does ``--no-auto``.  An explicit command line ``--[no-]auto[-update]``
	option causes the ``topgit.setAutoUpdate`` setting to be ignored.

	When both ``rerere.enabled`` and ``rerere.autoUpdate`` are set to true
	then ``tg update`` will be able to automatically continue an update
	whenever ``git rerere`` resolves all the conflicts during a merge.
	This can be such a huge time saver.  That's why the default is to have
	TopGit automatically set ``rerere.autoUpdate`` to true while
	``tg update`` is running (but remember, unless ``rerere.enabled`` has
	been set to ``true`` it won't make any difference).

	When ``-a`` (or ``--all``) is specified, updates all topic branches
	matched by ``<pattern>``'s (see ``git help for-each-ref`` for details),
	or all if no ``<pattern>`` is given.  Any topic branches with missing
	dependencies will be skipped entirely unless ``--skip-missing`` is
	specified.

	When ``--skip-missing`` is specified, an attempt is made to update topic
	branches with missing dependencies by skipping only the dependencies
	that are missing.  Caveat utilitor.

	When ``--stash`` is specified (or the ``topgit.autostash`` config
	value is set to ``true``), a ref stash will be automatically created
	just before beginning updates if any are needed.  The ``--no-stash``
	option may be used to disable a ``topgit.autostash=true`` setting.
	See the ``tg tag`` ``--stash`` option for details.

	After the update, the branch which was current at the beginning of the
	update is returned to.

	If your dependencies are not up-to-date, ``tg update`` will first
	recurse into them and update them.

	If a remote branch update brings in dependencies on branches
	that are not yet instantiated locally, you can either bring
	in all the new branches from the remote using
	``tg remote --populate``, or only pick out the missing ones using
	``tg create -r`` (``tg summary`` will point out branches with incomplete
	dependencies by showing an ``!`` next to them).  TopGit will attempt to
	instantiate just the missing ones automatically for you, if possible,
	when ``tg update`` merges in the new dependencies from the remote.

	Using the alternative ``--base`` mode, ``tg update`` will update
	the base of a specified ``[BASE]`` branch (which is a branch created
	by ``tg create`` using the ``--base`` option) to the specified
	committish (the second argument) and then immediately merge that into
	the branch itself using the specified message for the merge commit.
	If no message is specified on the command line, an editor will open.
	Unless ``--force`` is used the new value for the base must contain
	the old value (i.e. be a fast-forward update).  This is for safety.

	This mode makes updates to ``[BASE]`` branches quick and easy.

	When ``tg update`` has stopped as a result of a merge conflict,
	there are four possible ways to handle this situation:

	    ``tg update --continue``
				Once the merge conflict has been resolved
				and committed, this will resume the
				``tg update`` operation that was interrupted
				by encountering the merge conflict.

	    ``tg update --abort``
				This aborts the entire ``tg update``
				operation that led to the merge conflict
				and undoes everything that's been changed
				since that ``tg update`` started.  In other
				words, after ``tg update --abort`` it's as
				though the ``tg update`` that led to the
				merge conflict was never executed at all.

	    ``tg update --skip``
				This will attempt to resume the ``tg update``
				operation that was interrupted by encountering
				the merge conflict by skipping the current
				branch that's being updated that encountered
				the merge conflict.  The branch causing the
				merge conflict will still be out-of-date (since
				it's skipped by this command) and can still be
				updated by a future ``tg update`` command.

	    ``tg update --stop``
				This stops the ``tg update`` that's been
				interrupted by the merge conflict by simply
				removing the tg-update-in-progress state.
				Everything else will be *left as-is!*  In other
				words, if there's a current unresolved merge
				conflict, it will still be present.  The
				``HEAD`` state may be detached, etc. etc.
				Use of ``tg update --stop`` is not generally
				helpful except in unusual circumstances.

	| TODO:	``tg update -a -c`` to autoremove (clean) up-to-date branches

tg push
~~~~~~~
	If ``-a`` or ``--all`` was specified, pushes all non-annihilated
	TopGit-controlled topic branches, to a remote repository.
	Otherwise, pushes the specified topic branches -- or the
	current branch, if you don't specify which.  By default, the
	remote gets all the dependencies (both TopGit-controlled and
	non-TopGit-controlled) and bases pushed to it too.  If
	``--tgish-only`` was specified, only TopGit-controlled
	dependencies will be pushed, and if ``--no-deps`` was specified,
	no dependencies at all will be pushed.

	All TopGit branches to be pushed must be up-to-date unless the
	``--allow-outdated`` option is given.  Branches *are* checked against
	the configured TopGit remote (``topgit.remote``) if it's set (as
	modified by the global ``-u`` and ``-r <remote>`` options).

	The ``--dry-run``, ``--force``, ``--atomic``, ``--follow-tags``,
	``--no-follow-tags``, ``--signed[=...]``, ``-4`` and ``-6`` options
	are passed through directly to ``git push`` if given.

	The push remote may be specified with the ``-r`` option. If no remote
	was specified, the configured default TopGit push remote will be
	used (``topgit.pushRemote``) or if that's unset the regular remote
	(``topgit.remote``).

	Note that when pushing to a configured Git remote (i.e. it appears in
	the ``git remote`` output) that appears to have local tracking branches
	set up for the remote TopGit branches and/or TopGit bases, ``tg push``
	will attempt to make sure the local tracking branches are updated to
	reflect the result of a successful ``tg push``.  This is the same as
	the normal Git behavior except that ``tg push`` will always attempt to
	make sure that *both* the local tracking branches for the remote TopGit
	branches *and* their bases are always updated together even if the
	configured Git remote only has a ``fetch`` refspec for one of them.  If
	the remote branches are being tracked by the configured Git remote in a
	non-standard local tracking branch location, it may be necessary to
	issue a subsequent ``git fetch`` on that remote after a successful
	``tg push`` in order for them to be updated to reflect the ``tg push``.

	Use something like this to push to an ``origin`` remote when it's set
	as ``topgit.remote`` while only checking for local out-of-dateness:

	    ``tg -u push -r origin <optional-branch-names-here>``

tg base
~~~~~~~
	Prints the base commit of each of the named topic branches, or
	the current branch if no branches are named.  Prints an error
	message and exits with exit code 1 if the named branch is not
	a TopGit branch.

tg log
~~~~~~
	Prints the git log of the named topgit branch -- or the current
	branch, if you don't specify a name.

	This is really just a convenient shortcut for:

	    ``git log --first-parent --no-merges $(tg base <name>)..<name>``

	where ``<name>`` is the name of the TopGit topic branch (or omitted
	for the current branch).

	However, if ``<name>`` is a ``[BASE]`` branch the ``--no-merges``
	option is omitted.

	If ``--compact`` is used then ``git log-compact`` will be used instead
	of ``git log``.  The ``--command=<git-alias>`` option can be used to
	replace "log" with any non-whitespace-containing command alias name,
	``--compact`` is just a shortcut for ``--command=log-compact``.  The
	``git-log-compact`` tool may be found on its project page located at:

	    https://mackyle.github.io/git-log-compact

	Note that the ``--compact`` or ``--command=`` option must be used
	before any ``--`` or ``git log`` options to be recognized.

	NOTE: if you have merged changes from a different repository, this
	command might not list all interesting commits.

tg tag
~~~~~~
	Creates a TopGit annotated/signed tag or lists the reflog of one.

	A TopGit annotated tag records the current state of one or more TopGit
	branches and their dependencies and may be used to revert to the tagged
	state at any point in the future.

	When reflogs are enabled (the default in a non-bare repository) and
	combined with the ``--force`` option a single tag name may be used as a
	sort of TopGit branch state stash.  The special branch name ``--all``
	may be used to tag the state of all current TopGit branches to
	facilitate this function and has the side-effect of suppressing the
	out-of-date check allowing out-of-date branches to be included.

	As a special feature, ``--stash`` may be used as the tag name in which
	case ``--all`` is implied if no branch name is listed (instead of the
	normal default of ``HEAD``), ``--force`` and ``--no-edit`` (use
	``--edit`` to change that) are automatically activated and the tag will
	be saved to ``refs/tgstash`` instead of ``refs/tags/<tagname>``.
	The ``--stash`` tag name may also be used with the ``-g``/``--reflog``
	option.

	The mostly undocumented option ``--allow-outdated`` will bypass the
	out-of-date check and is implied when ``--stash`` or ``--all`` is used.

	A TopGit annotated/signed tag is simply a Git annotated/signed tag with
	a "TOPGIT REFS" section appended to the end of the tag message (and
	preceding the signature for signed tags).  PEM-style begin and end
	lines surround one line per ref where the format of each line is
	full-hash SP ref-name.  A line will be included for each branch given
	on the command line and each ref they depend on either directly or
	indirectly.

	Note that when specifying branch names, if a given name is ambiguous
	but prefixing the branch name with ``refs/heads/`` successfully
	disambiguates it, then that will be the interpretation used.

	If more than one TopGit branch is given on the command line, a new
	commit will be created that has an empty tree and all of the given
	TopGit branches as parents and that commit will be tagged.  If a single
	TopGit branch is given, then it will be tagged.  If the ``--tree``
	option is used then it will be used instead of an empty tree (a new
	commit will be created if necessary to guarantee the specified tree is
	what's in the commit the newly created tag refers to).  The argument to
	the ``--tree`` option may be any valid treeish.

	If exactly one of the branches to be tagged is prefixed with a tilde
	(``~``) it will be made the first parent of a consolidation commit if
	it is not already the sole commit needing to be tagged.  If ``--tree``
	is NOT used, its tree will also be used instead of the empty tree for
	any new consolidation commit if one is created.  Note that if
	``--tree`` is given explicitly its tree is always used but that does
	not in any way affect the choice of first parent.  Beware that the
	``~`` may need to be quoted to prevent the shell from misinterpreting
	it into something else.

	All the options for creating a tag serve the same purpose as their Git
	equivalents except for two.  The ``--refs`` option suppresses tag
	creation entirely and emits the "TOPGIT REFS" section that would have
	been included with the tag.  If the ``--no-edit`` option is given and
	no message is supplied (via the ``-m`` or ``-F`` option) then the
	default message created by TopGit will be used without running the
	editor.

	With ``-g`` or ``--reflog`` show the reflog for a tag.  With the
	``--reflog-message`` option the message from the reflog is shown.
	With the ``--commit-message`` option the first line of the tag's
	message (if the object is a tag) or the commit message (if the object
	is a commit) falling back to the reflog message for tree and blob
	objects is shown.  The default is ``--reflog-message`` unless the
	``--stash`` (``refs/tgstash``) is being shown in which case the	default
	is then ``--commit-message``.  Just add either option explicitly to
	override the default.

	When showing reflogs, non-tag entries are annotated with their type
	unless ``--no-type`` is given.  Custom colors can be set with these
	git config options:

	  :``color.tgtag``:         enable/disable color, default is ``color.ui``
	  :``color.tgtag.commit``:  hash color, dflt ``color.diff.commit``/yellow
	  :``color.tgtag.date``:    date line color, default is bold blue
	  :``color.tgtag.meta``:    object type "color", default is bold
	  :``color.tgtag.time``:    time info color, default is green

	TopGit tags are created with a reflog if core.logallrefupdates is
	enabled (the default for non-bare repositories).  Unfortunately Git
	is incapable of showing an annotated/signed tag's reflog (using either
	``git log -g`` or ``git reflog show``).  Git can, however, show
	reflogs for lightweight tags just fine but that's not helpful here.
	Use ``tg tag`` with the ``-g`` or ``--reflog`` option to see the
	reflog for an actual tag object.  This also works on non-TopGit
	annotated/signed tags as well provided they have a reflog.

	Note that the time and date shown for reflog entries by ``tg tag -g``
	is the actual time and date recorded in that reflog entry itself which
	usually is the time and date that entry was added to the reflog, *not*
	the time and date of the commit it refers to.  Git itself will only
	ever show the time and date recorded in a reflog entry when given just
	the right arguments to ``git log``, but then the reflog entry's time
	and date are always shown *in place of* its index number.

	By contrast, ``tg tag -g`` always shows the reflog entry's time and
	date *together with* its reflog entry index number.

	The number of entries shown may be limited with the ``-n`` option.  If
	the tagname is omitted then ``--stash`` is assumed.

	The ``--delete`` option is a convenience option that runs the
	``git update-ref --no-deref -d`` command on the specified tag removing
	it and its reflog (if it has one).  Note that `HEAD` cannot be removed.

	The ``--clear`` option clears all but the most recent (the ``@{0}``)
	reflog entry from the reflog for the specified tag.  It's equivalent
	to dropping all the higher numbered reflog entries.

	The ``--drop`` option drops the specified reflog entry and requires the
	given tagname to have an ``@{n}`` suffix where ``n`` is the reflog
	entry number to be dropped.   This is really just a convenience option
	that runs the appropriate ``git reflog delete`` command.  Note that
	even dropping the ...@{0} entry when it's the last entry of a
	non-symbolic ref will NOT delete the ref itself (unless the ref was
	already somehow set to an invalid object hash); but dropping @{0} of
	a non-symbolic ref may have the side effect of removing some stale
	reflog entries that were present in the reflog.

	Note that when combined with ``tg revert``, a tag created by ``tg tag``
	can be used to transfer TopGit branches.  Simply create the tag, push
	it somewhere and then have the recipient run ``tg revert`` to recreate
	the TopGit branches.  This may be helpful in situations where it's not
	feasible to push all the refs corresponding to the TopGit-controlled
	branches and their top-bases.

tg rebase
~~~~~~~~~
	Provides a ``git rebase`` rerere auto continue function.  It may be
	used as a drop-in replacement front-end for ``git rebase -m`` that
	automatically continues the rebase when ``git rerere`` information is
	sufficient to resolve all conflicts.

	You have enabled ``git rerere`` haven't you?

	If the ``-m`` or ``--merge`` option is not present then ``tg rebase``
	will complain and not do anything.

	When ``git rerere`` is enabled, previously resolved conflicts are
	remembered and can be automatically staged (see ``rerere.autoUpdate``).

	However, even with auto staging, ``git rebase`` still stops and
	requires an explicit ``git rebase --continue`` to keep going.

	In the case where ``git rebase -m`` is being used to flatten history
	(such as after a ``tg export --collapse`` prior to a
	``git format-patch``), there's a good chance all conflicts have already
	been resolved during normal merge maintenance operations so there's no
	reason ``git rebase`` could not automatically continue, but there's no
	option to make it do so.

	The ``tg rebase`` command provides a ``git rebase --auto-continue``
	function.

	All the same rebase options can be used (they are simply passed through
	to Git unchanged).  However, the ``rerere.autoUpdate`` option is
	automatically temporarily enabled while running ``git rebase`` and
	should ``git rebase`` stop, asking one to resolve and continue, but all
	conflicts have already been resolved and staged using rerere
	information, then ``git rebase --continue`` will be automatically run.

tg revert
~~~~~~~~~
	Provides the ability to revert one or more TopGit branches and their
	dependencies to a previous state contained within a tag created using
	the ``tg tag`` command.  In addition to the actual revert mode
	operation a list mode operation is also provided to examine a tag's ref
	contents.

	The default mode (``-l`` or ``--list``) shows the state of one or more
	of the refs/branches stored in the tag data.  When no refs are given on
	the command line, all refs in the tag data are shown.  With the special
	ref name ``--heads`` then the indepedent heads contained in the tag
	data are shown.  The ``--deps`` option shows the specified refs and all
	of their dependencies in a single list with no duplicates.  The
	``--rdeps`` option shows a display similar to ``tg summary --rdeps``
	for each ref or all TopGit heads if no ref is given on the command
	line.  The standard ``--no-short``, ``--short=n`` etc. options may be
	used to override the default ``--short`` output.  With ``--hash`` (or
	``--hash-only``) show only the hash in ``--list`` mode in which case
	the default is ``--no-short``.   The ``--hash`` option can be used much
	like the ``git rev-parse --verify`` command to extract a specific hash
	value out of a TopGit tag.

	Note that unlike `tg summary`_, here ``--heads`` actually does mean the
	``git merge-base --independent`` heads of the stored refs from the tag
	data.  To see only the independent TopGit topic branch heads stored in
	the tag data use the ``--topgit-heads`` option instead.  The default
	for the ``--rdeps`` option is ``--topgit-heads`` but ``--heads`` can
	be given explicitly to change that.  (Note that ``--heads-independent``
	is accepted as an alias for ``--heads`` as well.)

	The revert mode has three submodes, dry-run mode (``-n`` or
	``--dry-run``), force mode (``-f`` or ``--force``) and interactive mode
	(``-i`` or ``--interactive``).  If ``--dry-run`` (or ``-n``) is given
	no ref updates will actually be performed but what would have been
	updated is shown instead.  If ``--interactive`` (or ``-i``) is given
	then the editor is invoked on an instruction sheet allowing manual
	selection of the refs to be updated before proceeding.  Since revert is
	potentially a destructive operation, at least one of the submodes must
	be specified explicitly.  If no refs are listed on the command line
	then all refs in the tag data are reverted.  Otherwise the listed refs
	and all of their dependencies (unless ``--no-deps`` is given) are
	reverted.  Unless ``--no-stash`` is given a new stash will be created
	using ``tg tag --stash`` (except, of course, in dry-run mode) just
	before actually performing the updates to facilitate recovery from
	accidents.

	Both modes accept fully-qualified (i.e. starts with ``refs/``) ref
	names as well as unqualified names (which will be assumed to be located
	under ``refs/heads/``).  In revert mode a tgish ref will always have
	both its ``refs/heads/`` and ``refs/top-bases/`` values included no
	matter how it's listed unless ``--no-deps`` is given and the ref is
	fully qualified (i.e. starts with ``refs/``) or one or the other of its
	values was removed from the instruction sheet in interactive mode.  In
	list mode a tgish ref will always have both its ``refs/heads/`` and
	``refs/top-bases/`` values included only when using the ``--deps`` or
	``--rdeps`` options.

	The ``--tgish-only`` option excludes non-tgish refs (i.e. refs that do
	not have a ``refs/heads/<name>``, ``refs/top-bases/<name>`` pair).

	The ``--exclude`` option (which can be repeated) excludes specific
	refs.  If the name given to ``--exclude`` is not fully-qualified (i.e.
	starts with ``refs/``) then it will exclude both members of a tgish ref
	pair.

	The ``--quiet`` (or ``-q``) option may be used in revert mode to
	suppress non-dry-run ref change status messages.

	The special tag name ``--stash`` (as well as with ``@{n}`` suffixes)
	can be used to refer to ``refs/tgstash``.

	The ``tg revert`` command supports tags of tags that contains TopGit
	refs.  So, for example, if you do this::

		tg tag newtag --all
		git tag -f -a -m "tag the tag" newtag newtag

	Then ``newtag`` will be a tag of a tag containing a ``TOPGIT REFS``
	section.  ``tg revert`` knows how to dereference the outermost
	tag to get to the next (and the next etc.) tag to find the
	``TOPGIT REFS`` section so after the above sequence, the tag ``newtag``
	can still be used successfully with ``tg revert``.

	NOTE:  If HEAD points to a ref that is updated by a revert operation
	then NO WARNING whatsoever will be issued, but the index and working
	tree will always be left completely untouched (and the reflog for
	the pointed-to ref can always be used to find the previous value).

tg shell
~~~~~~~~
	Enter extended `wayback machine`_ mode.

	The global ``-w <tgtag>`` option must be specified (but as a special
	case for the ``shell`` command a <tgtag> destination of ``:`` may be
	used to get a shell with no wayback ref changes).

	The "<tgtag>" value must be the name of a tag created by (or known to)
	`tg tag`_.  However, it may also have a ``:`` prefixed to it to
	indicate that it should prune (making it into a "pruning wayback tag").
	Use of a "pruning wayback tag" results in a repository that contains
	exclusively those refs listed in the specified tag.  Otherwise the
	wayback repository will just revert those refs while keeping the others
	untouched (the default behavior).

	The `wayback machine`_ activates as normal for the specified
	destination but then a new ``${SHELL:-/bin/sh}`` is spawned in a
	temporary non-bare repository directory that shares all the same
	objects from the repository but has its own copy of the ref namespace
	where the refs specified in the wayback destination have all been
	changed to have their wayback values.

	If any arguments are given a POSIX shell will be spawned instead
	concatenating all the arguments together with a space and passing
	them to it via a ``-c`` option.  If ``-q`` (or ``--quote``) is given
	then each argument will first be separately "quoted" to protect it from
	the shell allowing something like this::

		tg -w <tgtag> shell -q git for-each-ref --format="%(refname)"

	to work without needing to manually add the extra level of quoting that
	would otherwise be required due to the parentheses.

	Most of the repository configuration will be inherited, but some
	will be overridden for safety and for convenience.  All "gc" activity
	within the wayback repository will be suppressed to avoid accidents
	(i.e. no auto gc will run and "gc" commands will complain and not run).
	
	Override and/or bypass this safety protection at your own peril!
	Especially *do not run* the ``git prune`` plumbing command in the
	wayback repository!  If you do so (or bypass any of the other safeties)
	be prepared for corruption and loss of data in the repository.
	Just *don't do that* in the first place!

	Using ``git wayback-tag`` will show the tag used to enter the wayback
	machine.  Using ``git wayback-updates`` will show ref changes that have
	occurred since the wayback tag was created (it will not show refs that
	have since been created unless a pruning wayback tag was used).
	Finally, ``git wayback-repository`` will show the home repository but
	so will ``git remote -v`` in the output displayed for the ``wayback``
	remote.

	The special ``wayback`` remote refers to the original repository and
	can be used to push ref changes back to it.  Note, however, that all
	default push refspecs are disabled for safety and an explicit refspec
	will need to be used to do so.

	Unlike the normal `wayback machine`_ mode, ``HEAD`` will be detached
	to a new commit with an empty tree that contains the message and author
	from the wayback tag used.  This prevents ugly status displays while
	avoiding the need to checkout any files into the temporary working
	tree.  The parent of this commit will, however, be set to the wayback
	tag's commit making it easy to access if desired.

	Also unlike the normal `wayback machine`_ mode, there are no
	limitations on what can be done in the temporary repository.
	And since it will be non-bare and writable, commands that may not have
	been allowed in the original repository will work too.

	When the shell spawned by this command exits, the temporary wayback
	repository and all newly created objects and ref changes made in it, if
	any, *will be lost*.  If work has been done in it that needs to be
	saved, it must be pushed somewhere (even if only back to the original
	repository using the special ``wayback`` remote).

	Lastly there's the ``--directory`` option.  If the ``--directory``
	option is used the temporary "wayback repository" will be created at
	the specified location (which must either not exist or must be an empty
	directory -- no force option available this time as too many things
	could easily go wrong in that case).  If the ``--directory`` option is
	used then the "wayback repository" *will persist* after ``tg shell``
	completes allowing it to continue to be used!  Be warned though, all
	the same warnings that apply to ``git clone --shared`` apply to such
	a repository.  If it's created using a ``tgstash`` tag those warnings
	are especially salient.  Use a single argument of either ``:`` (to
	just create with no output) or ``pwd`` (to show the full absolute path
	to the new "wayback repository") when using the ``--directory`` option
	if the sole purpose is just to create the wayback repository for use.
	Note that the ``--directory`` option *must* be listed as the first
	option after the ``shell`` command name if used.

tg prev
~~~~~~~
	Output the "previous" branch(es) in the patch series containing the
	current or named branch.  The "previous" branch(es) being one step
	away by default.

	Options:
	  -i		use dependencies from index instead of branch
	  -w		use dependencies from working tree instead of branch
	  -n <steps>	take ``<steps>`` "previous" steps (default 1)
	  --all		take as many "previous" steps as possible (aka ``-a``)
	  --verbose	show containing series name(s) (aka ``-v``)

	The ``-n`` option may also be given as ``--count`` or ``--count=<n>``.

	To list all dependencies of a branch see the ``--deps`` option of
	the `tg info`_ command.

	See also NAVIGATION_ for full details on "previous" steps.

tg next
~~~~~~~
	Output the "next" branch(es) in the patch series containing the current
	or named branch.  The "next" branch(es) being one step away by default.

	Options:
	  -i		use dependencies from index instead of branch
	  -w		use dependencies from working tree instead of branch
	  -n <steps>	take ``<steps>`` "next" steps (default 1)
	  --all		take as many "next" steps as possible (aka ``-a``)
	  --verbose	show containing series name(s) (aka ``-v``)

	The ``-n`` option may also be given as ``--count`` or ``--count=<n>``.

	To list all dependents of a branch see the ``--dependents`` option of
	the `tg info`_ command.

	See also NAVIGATION_ for full details on "next" steps.

tg migrate-bases
~~~~~~~~~~~~~~~~
	Transition top-bases from old location to new location.

	Beginning with TopGit release 0.19.4, TopGit has the ability to store
	the top-bases refs in either the old ``refs/top-bases/...`` location or
	the new ``refs/heads/{top-bases}/...`` location.  Starting with TopGit
	release 0.20.0, the default is the new location.

	By storing the top-bases under heads, Git is less likely to complain
	when manipulating them, hosting providers are more likely to provide
	access to them and Git prevents them from pointing at anything other
	than a commit object.  All in all a win for everyone.

	TopGit attempts to automatically detect whether the new or old location
	is being used for the top-bases and just do the right thing.  However,
	by explicitly setting the config value ``topgit.top-bases`` to either
	``refs`` for the old location or ``heads`` for the new location the
	auto-detection can be bypassed.  If no top-bases refs are present in
	the repository the default prior to TopGit release 0.20.0 is to use the
	old location but starting with TopGit release 0.20.0 the default is to
	use the new location.

	The ``tg migrate-bases`` command may be used to migrate top-bases refs
	from the old location to the new location (or, by using the
	undocumented ``--reverse`` option, vice versa).

	With few exceptions (``tg create -r`` and ``tg revert``), all top-bases
	refs (both local *and* remote refs) are expected to be stored in the
	same location (either new or old).  A repository's current location for
	storing top-bases refs may be shown with the ``tg --top-bases`` command.

TODO: tg rename
~~~~~~~~~~~~~~~

IMPLEMENTATION
--------------

TopGit stores all the topic branches in the regular ``refs/heads/``
namespace (so we recommend distinguishing them with the ``t/`` prefix).
Apart from that, TopGit also maintains a set of auxiliary refs in
``refs/top-*``.  Currently, only ``refs/top-bases/`` is used, containing the
current *base* of the given topic branch -- this is basically a merge of
all the branches the topic branch depends on; it is updated during ``tg update``
and then merged to the topic branch, and it is the base of a
patch generated from the topic branch by ``tg patch``.

All the metadata is tracked within the source tree and history of the
topic branch itself, in ``.top*`` files; these files are kept isolated
within the topic branches during TopGit-controlled merges and are of
course omitted during ``tg patch``.  The state of these files in base
commits is undefined; look at them only in the topic branches
themselves.  Currently, two files are defined:

	``.topmsg``:
	    Contains the description of the topic branch in a
	    mail-like format, plus the author information, whatever
	    Cc headers you choose or the post-three-dashes message.
	    When mailing out your patch, basically only a few extra
	    mail headers are inserted and then the patch itself is
	    appended.  Thus, as your patches evolve, you can record
	    nuances like whether the particular patch should have
	    To-list / Cc-maintainer or vice-versa and similar
	    nuances, if your project is into that.  ``From`` is
	    prefilled from your current ``GIT_AUTHOR_IDENT``; other
	    headers can be prefilled from various optional
	    ``topgit.*`` git config options.

	``.topdeps``:
	    Contains the one-per-line list of branches this branch
	    depends on, pre-seeded by ``tg create``. A (continuously
	    updated) merge of these branches will be the *base* of
	    your topic branch.

IMPORTANT: DO NOT EDIT ``.topdeps`` MANUALLY!!! If you do so, you need to
know exactly what you are doing, since this file must stay in sync with
the Git history information, otherwise very bad things will happen.

TopGit also automagically installs a bunch of custom commit-related
hooks that will verify whether you are committing the ``.top*`` files in a
sane state. It will add the hooks to separate files within the ``hooks/``
subdirectory, and merely insert calls to them to the appropriate hooks
and make them executable (but will make sure the original hook's code is
not called if the hook was not executable beforehand).

Another automagically installed piece is a ``.git/info/attributes``
specifier for an ``ours`` merge strategy for the files ``.topmsg`` and
``.topdeps``, and the (intuitive) ``ours`` merge strategy definition in
``.git/config``.


REMOTE HANDLING
---------------

There are two remaining issues with accessing topic branches in remote
repositories:

	(i) Referring to remote topic branches from your local repository
	(ii) Developing some of the remote topic branches locally

There are two somewhat contradictory design considerations here:

	(a) Hacking on multiple independent TopGit remotes in a single
	    repository
	(b) Having a self-contained topic system in local refs space

To us, (a) does not appear to be very convincing, while (b) is quite
desirable for ``git log topic`` etc. working, and increased conceptual
simplicity.

Thus, we choose to instantiate all the topic branches of given remote
locally; this is performed by ``tg remote --populate``. ``tg update``
will also check if a branch can be updated from its corresponding remote
branch.  The logic needs to be somewhat involved if we are to "do the
right thing".  First, we update the base, handling the remote branch as
if it was the first dependency; thus, conflict resolutions made in the
remote branch will be carried over to our local base automagically.
Then, the base is merged into the remote branch and the result is merged
to the local branch -- again, to carry over remote conflict resolutions.
In the future, this order might be adjustable on a per-update basis, in
case local changes happen to be diverging more than the remote ones.
(See the details in `The Update Process`_ for more in depth coverage.)

All commands by default refer to the remote that ``tg remote --populate``
was called on the last time (stored in the ``topgit.remote`` git
configuration variable). You can manually run any command with a
different base remote by passing ``-r REMOTE`` *before* the command
name or passing ``-u`` *before* the command to run without one.


TESTING TOPGIT
--------------

Running the TopGit test suite only requires POSIX compatible utilities (just
a POSIX compatible ``make`` will do) AND a ``perl`` binary.

It is *not* necessary to install TopGit in order to run the TopGit test suite.

To run the TopGit test suite, simply execute this from the top-level of a
TopGit checkout or expanded release tarball:

::

	make test

Yup, that's it.  But you're probably thinking, "Why have a whole section just
to say 'run make test'?"  Am I right?

The simple ``make test`` command produces a lot of output and while it is
summarized at the end there's a better way.

Do you have the ``prove`` utility available?  You need ``perl`` to run the
tests and ``prove`` comes with ``perl`` so you almost cerainly do.

Try running the tests like so:

::

	make DEFAULT_TEST_TARGET=prove test


(For reference, the default value of ``DEFAULT_TEST_TARGET`` is ``test`` which
can be used to override a setting that's been altered using the instructions
shown later on below.)

If that works (you can interrupt it with ``Ctrl-C``), try this next:

::

	make DEFAULT_TEST_TARGET=prove TESTLIB_PROVE_OPTS="-j 4 --timer" test

If that one works (again, you can interrupt it with ``Ctrl-C``) that may end
up being the keeper for running the tests.

However, if you don't have ``prove`` for some reason even though you do have
``perl``, there's still an alternative for briefer output.  Try this:

::

	make TESTLIB_TEST_OPTS=-q test

Much of the normal testing output will be suppressed and there's still a
summary at the end.  If you're stuck with this version but your make supports
parallel operation (the ``-j`` *<n>*) option, then you might try this:

::

	make -j 4 TESTLIB_TEST_OPTS=-q test

If your make *does* support the parallel ``-j`` option but still seems to be
only running one test at a time try it like this instead:

::

	make TESTLIB_MAKE_OPTS="-j 4" TESTLIB_TEST_OPTS=-q test

The difference is that ``make -j 4`` relies on make to properly pass down the
parallel job option all the way down to the sub-make that runs the individual
tests when not using prove.  Putting the options in ``TESTLIB_MAKE_OPTS``
passes them directly to that (and only that) particular invocation of make.

The final bit of advice for running the tests is that any of those ``make``
variable settings can be enabled by default in a top-level ``config.mak`` file.

For example, to make the ``prove -j 4 --timer`` (my personal favorite) the
default when running the tests, add these lines (creating the file if it does
not already exist) to the ``config.mak`` file located in the top-level of the
TopGit checkout (or expanded release tarball):

::

	# config.mak file
	# comments are allowed (if preceded by '#')
	# so are blank lines

	DEFAULT_TEST_TARGET = prove
	TESTLIB_PROVE_OPTS = -j 4 --timer
	#TESTLIB_TEST_OPTS = --color # force colorized test output

Now simply doing ``make test`` will use those options by default.

There is copious documentation on the testing library and other options in
the various ``README`` files located in the ``t`` subdirectory.  The
``Makefile.mak`` file in the ``t`` subdirectory contains plenty of comments
about possible makefile variable settings as well.


TECHNICAL
---------

A familiarity with the terms in the GLOSSARY_ is helpful for understanding the
content of this section.  See also the IMPLEMENTATION_ section.

The Update Process
~~~~~~~~~~~~~~~~~~

When a branch is "updated" using the ``tg update`` command the following steps
are taken:

	1) The branch and all of its dependencies (and theirs recursively)
	   are checked to see which ones are *out-of-date*.  See glossary_.

	2) Each of the branch's direct dependencies (i.e. they are listed in
	   the branch's ``.topdeps`` file) which is out of date is updated
	   before proceeding (yup, this is a recursive process).  If the
	   branch has a corresponding remote branch and that remote branch
	   has removed one or more direct dependencies, then those
	   remote-removed dependencies are automatically skipped at this
	   stage even though the remote branch's .topdeps file will not
	   actually be merged into the local branch until step (5).

	3) Each of the branch's direct dependencies (i.e. they are listed in
	   the branch's ``.topdeps`` file) that was updated in the previous
	   step is now merged into the branch's corresponding base.  If a
	   remote is involved, and the branch's corresponding base does NOT
	   contain the remote branch's corresponding base that remote base
	   is also merged into the branch's base at this time as well (it
	   will be the first item merged into the branch's base).  As with
	   the previous step, any remote-removed dependencies, if any, are
	   automatically skipped at this stage.

	4) If the branch has a corresponding remote branch and the branch
	   does not already contain it, the branch's base (which was possibly
	   already updated in step (3) to contain the remote branch's base but
	   not the remote branch itself) is merged into the remote branch on a
	   detached HEAD.  Yup, this step can be a bit confusing and no, the
	   updated base from step (3) has not yet been merged into the branch
	   itself yet either.  If there is no remote branch this step does not
	   apply.  Using a detached HEAD allows the contents of the base to be
	   merged into the remote branch without actually perturbing the base's
	   or remote branch's refs.

	5) If there is a remote branch present then use the result of step (4)
	   otherwise use the branch's base and merge that into the branch
	   itself.

That's it!  Simple, right? ;)

Unless the auto stash option has been disabled (see `no undo`_, `tg update`_
and `tg tag`_), a copy of all the old refs values will be stashed away
immediately after step (1) before starting step (2), but only if anything is
actually found to be out-of-date.

Merge Strategies
~~~~~~~~~~~~~~~~

The ``tg update`` command regularly performs merges while executing an update
operation.  In order to speed things up, it attempts to do in-index merges
where possible.  It accomplishes this by using a separate, temporary index
file and the ``git read-tree -m --aggressive`` command possibly assisted by
the ``git merge-index`` and ``git merge-file`` commands.  This combination may
be repeated more than once to perform an octopus in-index merge.  If this
fails, the files are checked out and a normal ``git merge`` three-way merge is
performed (possibly multiple times).  If the normal ``git merge`` fails then
user intervention is required to resolve the merge conflict(s) and continue.

Since the ``tg annihilate``, ``tg create`` and ``tg depend add`` commands may
end up running the ``tg update`` machinery behind the scenes to complete their
operation they may also result in any of these merge strategies being used.

In addition to the normal Git merge strategies (if the in-index merging fails),
there are four possible TopGit merge strategies that may be shown.  Since they
all involve use of the ``git read-tree -m --aggressive`` command they are all
variations of a "trivial aggressive" merge.  The "trivial" part because all of
the merges done by ``git read-tree -m`` are described as "trivial" and the
"aggressive" part because the ``--aggressive`` option is always used.

	1) "trivial aggressive"
		Only two heads were involved and all merging was completed by
		the ``git read-tree -m --aggressive`` command.

	2) "trivial aggressive automatic"
		Only two heads were involved but after the
		``git read-tree -m --aggressive`` command completed there were
		still unresolved items and ``git merge-index`` had to be run
		(using the ``tg index-merge-one-file`` driver) which ultimately
		ran ``git merge-file`` at least once to perform a simple
		automatic three-way merge.  Hence the "automatic" description
		and the "Auto-merging ..." output line(s).

	3) "trivial aggressive octopus"
		This is the same as a "trivial aggressive" merge except that
		more than two heads were involved and after merging the first
		two heads, the ``git read-tree -m --aggressive`` step was
		repeated again on the result for each additional head.  All
		merging was completed via multiple
		``git read-tree -m --aggressive`` commands only.
		This beast is relatively rare in the wild.

	4) "trivial aggressive automatic octopus"
		This is very similar to the "trivial aggressive octopus"
		except that at least one of the ``git read-tree -m --aggressive``
		commands left unresolved items that were handled the same way
		as the "trivial aggressive automatic" strategy.  This species
		is commonly seen in the wild.


GLOSSARY
--------

	.topmsg
		Version-controlled file stored at the root level of each
		TopGit branch that contains the patch header for a TopGit
		branch.  See also IMPLEMENTATION_.

	.topdeps
		Version-controlled file stored at the root level of each
		TopGit branch that lists the branch's dependencies one per
		line omitting the leading ``refs/heads/`` part.  See also
		IMPLEMENTATION_.

	3-way merge
		See three-way merge.

	branch containment
		Given two Git commit identifiers (e.g. hashes) C1 and C2,
		commit C1 "contains" commit C2 if either they are the same
		commit or C2 can be reached from C1 by following one or more
		parent links from C1 (perhaps via one or more intermediate
		commits along the way).  In other words, if C1 contains C2
		then C2 is an ancestor of C1 or conversely C1 is a descendant
		of C2.  Since a TopGit branch name is also the name of a Git
		branch (something located under the ``refs/heads`` Git
		namespace) and similarly for a TopGit base, they can both be
		resolved to a Git commit identifier and then participate in
		a branch containment test.  An easy mnemonic for this is
		"children contain the genes of their parents."

	BRE pattern
		A Basic Regular Expression (BRE) pattern.  These are older
		style regular expressions but have the advantage that all
		characters other than ``\``, ``.``, ``*`` and ``[``
		automatically match themselves without need for backslash
		quoting (well actually, ``^`` and ``$`` are special at the
		beginning and end respectively but otherwise match themselves).

	contains
		See branch containment.

	ERE pattern
		An Extended Regular Expression (ERE) pattern.  These are newer
		style regular expressions where all the regular expression
		"operator" characters "operate" when NOT preceded by a
		backslash and are turned into normal characters with a ``\``.
		The backreference atom, however, may not work, but ``?``, ``+``
		and ``|`` "operators" do; unlike BREs.

	TopGit
		Excellent system for managing a history of changes to one
		or more possibly interrelated patches.

	TopGit branch
		A Git branch that has an associated TopGit base.  Conceptually
		it represents a single patch that is the difference between
		the associated TopGit base and the TopGit branch.  In other
		words ``git diff-tree <TopGit base> <TopGit branch>`` except
		that any ``.topdeps`` and/or ``.topmsg`` files are excluded
		from the result and the contents of the ``.topmsg`` file from
		the TopGit branch is prefixed to the result.

	TopGit bare branch
		A Git branch whose tree does NOT contain any ``.topdeps`` or
		``.topmsg`` entries at the top-level of the tree.  It *does*
		always have an associated "TopGit base" ref (otherwise it would
		not be a "TopGit" branch).  See also `BARE BRANCHES`_.

	bare branch
		In TopGit context, "bare branch" almost always refers to a
		"TopGit bare branch" and should be understood to mean such even
		if the leading "TopGit" has been left off.

	TopGit base
		A Git branch that records the base upon which a TopGit branch's
		single conceptual "patch" is built.  The name of the Git branch
		is derived from the TopGit branch name by stripping off the
		leading ``refs/heads/`` and prepending the correct prefix where
		all TopGit bases are stored (typically either
		``refs/top-bases/`` or ``refs/heads/{top-bases}/`` -- the
		prefix for any given repository can be shown by using the
		``tg --top-bases`` command and updated using the
		``tg migrate-bases`` command).

		All of a TopGit branch's dependencies are merged into the
		corresponding TopGit base during a ``tg update`` of a branch.

	base
		See TopGit base.

	TopGit ``[PATCH]`` branch
		A TopGit branch whose subject starts with ``[PATCH]``.  By
		convention these TopGit branches contain a single patch
		(equivalent to a single patch file) and have at least one
		dependency (i.e. their ``.topdeps`` files are never empty).

	TopGit ``[BASE]`` branch
		A TopGit branch whose subject starts with ``[BASE]``.  By
		convention these TopGit branches do not actually contain
		any changes and their ``.topdeps`` files are empty.  They
		are used to control a base dependency that another set of
		branches depends on.  Sometimes these are named ``[RELEASE]``
		instead because the base dependency they represent is actually
		the formal release of something.

	TopGit ``[ROOT]`` branch
		A TopGit branch whose subject starts with ``[ROOT]``.  By
		convention these TopGit branches do not actually contain
		any changes and their ``.topdeps`` files are empty.  They
		are ``[BASE]`` branches where the base commit has no parent.
		In other words, the base commit is a ``root`` commit.

	TopGit ``[STAGE]`` branch
		A TopGit branch whose subject starts with ``[STAGE]``.  By
		convention these TopGit branches do not actually contain any
		changes of their own but do have one or (typically) more
		dependencies in their ``.topdeps`` file.  These branches are
		used to bring together one or (typically) more independent
		TopGit ``[PATCH]`` branches into a single branch so that
		testing and/or evaluation can be performed on the result.
		Sometimes these are named ``[RELEASE]`` when a full release
		is being made from the result.

	merge conflict
		When merging two (or more) heads that touch the same lines in
		the file but in different ways the result is a merge conflict
		that requires manual intervention.  If a merge conflict occurs
		with more than two heads (an octopus merge) it's generally
		replaced by multiple three-way merges so that by the time a
		user sees a merge conflict needing manual resolution, there
		will be only two heads involved.

	merge strategy
		A Git merge strategy (see the "MERGE STRATEGIES" section of
		``git help merge``) or one of the TopGit `merge strategies`_
		used to merge two or more heads.

	TopGit merge strategy
		See the `Merge Strategies`_ section above for details but
		basically these are just in-index merges done using the
		``git read-tree -m --aggressive`` command one or more times
		possibily assisted by the ``git merge-index`` and the
		``git merge-file`` commands.

	next branch
		In TopGit context the "next" branch refers to the branch that
		corresponds to the next (aka following) patch in an ordered
		(aka linearized) list of patches created by exporting the
		TopGit branches in patch application order.

	octopus merge
		A merge involving more than two heads.  Note that if there are
		less than three independent heads the resulting merge that
		started out as an octopus will end up not actually being an
		octopus after all.

	out-of-date branch
		A TopGit branch is considered to be "out-of-date" when ANY of
		the following are true:

			a) The TopGit branch does NOT contain its
			   corresponding base.

			b) The TopGit branch does NOT contain its
			   corresponding remote branch (there may not be
			   a remote branch in which case this does not apply).

			c) The TopGit branch's base does NOT contain its
			   corresponding remote branch's base (there may not be
			   a remote branch in which case this does not apply).

			d) Any of the TopGit branches listed in the branch's
			   ``.topdeps`` file are NOT contained by the branch's
			   base (see "branch containment" above).

			e) Any of the TopGit branches listed in the branch's
			   ``.topdeps`` file are out-of-date.

		Note that if a remote branch is present and is NOT out-of-date
		then it will contain its own base and (c) is mostly redundant.

	previous branch
		In TopGit context the "previous" (or "prev") branch refers to
		the branch that corresponds to the previous (aka preceding)
		patch in an ordered (aka linearized) list of patches created by
		exporting the TopGit branches in patch application order.

	remote TopGit branch
		A Git branch with the same branch name as a TopGit branch
		but living under ``refs/remotes/<some remote>/`` instead
		of just ``refs/heads/``.

	remote TopGit base
		The TopGit base branch corresponding to a remote TopGit branch,
		which lives under ``refs/remotes/`` somewhere (depending on
		what the output of ``tg --top-bases`` is for that remote).

	three-way merge
		A three-way merge takes a common base and two heads (call them
		A and B) and creates a new file that is the common base plus
		all of the changes made between the common base and head A
		*AND* all of the changes made between the common base and
		head B.  The technique used to accomplish this is called a
		"merge strategy".


REFERENCES
----------

The following references are useful to understand the development of
topgit and its commands.

* tg depend:
  https://lore.kernel.org/git/36ca99e90904091034m4d4d31dct78acb333612e678@mail.gmail.com/T/#u


THIRD-PARTY SOFTWARE
--------------------

The following software understands TopGit branches:

* `Magit <https://github.com/magit/magit>`_ - a git mode for emacs
  with the `Magit TopGit mode <https://github.com/greenrd/magit-topgit>`_
  that may, perhaps, be a bit outdated.

IMPORTANT: Magit requires its topgit mode to be enabled first, as
described in its documentation, in the "Activating extensions"
subsection.  If this is not done, it will not push TopGit branches
correctly, so it's important to enable it even if you plan to mostly use
TopGit from the command line.
