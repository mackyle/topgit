#!/usr/bin/env perl

# create-html-usage.pl -- insert usage lines into README_DOCS.rst
# Copyright (C) 2015,2017,2020,2021 Kyle J. McKay.  All rights reserved.
# License GPLv2 or, at your option, any later version.

use strict;
use warnings;

use File::Basename;

my $mydir = dirname($0);
my $last = undef;

sub get_tg_usage($)
{
	my $name = shift;
	my $xname;
	for ("$mydir/tg-$name", "$mydir/tg--$name") {
		-x $_ and $xname=$_, last;
	}
	if (defined $xname) {
		my $usage = `"$xname" -h 2>&1`;
		chomp $usage;
		$usage =~ s/^(Usage|\s+Or):\s*/: /mig;
		$usage =~ s/[ \t]*\n[ \t]+/ /gs;
		$usage =~ s/^: //mig;
		return split "\n", $usage;
	} elsif ($name eq "help") {
		return "tg help [-w] [<command>]";
	} elsif ($name eq "status") {
		my $tgsthelp = $ENV{TG_STATUS_HELP_USAGE} || "status";
		return "tg $tgsthelp";
	}
	return undef;
}

sub wrap
{
	my ($w, $i, $s) = @_;
	my $h = ' ' x $i;
	my $ans = '';
	while (length($s) > $w && $s =~ /^(.{1,$w})(?<=\w)\b[ \t]+(.+)$/s) {
		$ans .= $1."\n";
		$s = "$h$2";
	}
	$ans .= $s if $s !~ /^\s*$/;
	return $ans;
}

sub maybe_uc
{
	my $l = shift;
	$l =~ /^tg / and return $l;
	return uc($l);
}

my $textmode;
$textmode=1, shift if defined($ARGV[0]) && $ARGV[0] eq '--text';
my $tab = ' ' x 8;
my $discard = 0;
while (<>) {
	chomp;
	# From the Perl camel book "Fluent Perl" section (slightly modified)
	s/(.*?)(\t+)/$1 . ' ' x (length($2) * 8 - length($1) % 8)/eg;
	if ($textmode) {
		$discard and do {$discard = 0; next};
		/^::\s*$/ and do {$discard = 1; next};
		m'^```+$' and next;
		s'^``([^``\n].*)``$'wrap(78, 4, $1)'e;
		s'^(\s*):`(`.+?`)`: '"$1$2  "'e;
		s'^(\s*):`(.+?)`_: '"$1\"$2\"  "'e;
		s'^(\s*):(\w+?)_?: '"$1\"$2\""'e;
		s'`([^`]+?>)`_'"$1"'ge;
		s'`([^`]+?)`_'"\"".maybe_uc($1)."\""'ge;
		s'`(`[^`]+?`)`'"$1"'ge;
		s'"(`[^`]+?`)"'"$1"'ge;
		s' ([A-Za-z]+?)_(?![A-Za-z])'" \"".maybe_uc($1)."\""'ge;
		s'::$':';
	}
	if (defined($last)) {
		printf "%s\n",  $last;
		if (/^[~]+$/ && $last =~ /^tg ([^\s]+)$/) {
			my @usage = get_tg_usage($1);
			if (@usage) {
				printf "%s\n", $_;
				if ($textmode) {
					printf "%s", join("",map({wrap(78, 12, "$tab$_")."\n"} @usage));
				} else {
					printf "%s", join("",map({"$tab| ".'``'.$_.'``'."\n"} @usage));
				}
				$_ = "";
			}
		}
	}
	$last = $_;
}

printf "%s\n", $last if defined($last);
exit 0;
