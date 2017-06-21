#!/usr/bin/env perl

# create-html-usage.pl -- insert usage lines into README
# Cpoyright (C) 2015,2017 Kyle J. McKay.
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

while (<>) {
	s/(?:\r\n|\n|\r)$//;
	# From the Perl camel book "Fluent Perl" section (slightly modified)
	s/(.*?)(\t+)/$1 . ' ' x (length($2) * 8 - length($1) % 8)/eg;
	s'^``(.*)``$'wrap(78, 4, $1)'e;
	s'^(\s*):`(.+?)`_:'"$1$2  "'e;
	s'^(\s*):(\w+?)_?:'"$1$2"'e;
	printf "%s\n", $_;
}
exit 0;
