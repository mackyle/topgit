#!/usr/bin/env perl

# polish-help-txt.pl -- polish text format help (e.g. tg-tag.txt)
# Copyright (C) 2015,2017,2020,2021 Kyle J. McKay.
# All rights reserved.
# License GPLv2 or, at your option, any later version.

use strict;
use warnings;

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

while (<>) {
	s/(?:\r\n|\n|\r)$//;
	# From the Perl camel book "Fluent Perl" section (slightly modified)
	s/(.*?)(\t+)/$1 . ' ' x (length($2) * 8 - length($1) % 8)/eg;
	m'^```+$' and next;
	s'^``(.*)``$'wrap(78, 4, $1)'e;
	s'^(\s*):`(`.+?`)`: '"$1$2  "'e;
	s'^(\s*):`(.+?)`_: '"$1\"$2\"  "'e;
	s'^(\s*):(\w+?)_?: '"$1\"$2\""'e;
	s'`([^`]+?)`_'"\"".maybe_uc($1)."\""'ge;
	s'`(`[^`]+?`)`'"$1"'ge;
	s'"(`[^`]+?`)"'"$1"'ge;
	s' ([A-Za-z]+?)_(?![A-Za-z])'" \"".maybe_uc($1)."\""'ge;
	s'::$':';
	printf "%s\n", $_;
}
exit 0;
