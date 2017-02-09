#!/usr/bin/env perl

# create-html-usage.pl -- insert usage lines into README
# Cpoyright (C) 2015 Kyle J. McKay.  All rights reserved.
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
		$usage =~ s/^(Usage|\s+Or):\s*//mig;
		return split "\n", $usage;
	} elsif ($name eq "help") {
		return "tg help [-w] [<command>]";
	} elsif ($name eq "status") {
		return "tg status [-v] [--exit-code]";
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

my $textmode;
$textmode=1, shift if defined($ARGV[0]) && $ARGV[0] eq '--text';
my $tab = ' ' x 8;
while (my $line = <>) {
	chomp $line;
	1 while $line =~ s/\t+/" " x (($+[0] - $-[0]) * 8 - $-[0] % 8)/e;
	$line =~ s'^``(.*)``$'wrap(78, 4, $1)'e if $textmode;
	$line =~ s'^(\s*):`(.+?)`_:'"$1$2 "'e if $textmode;
	if (defined($last)) {
		printf "%s\n",  $last;
		if ($line =~ /^[~]+$/ && $last =~ /^tg ([^\s]+)$/) {
			my @usage = get_tg_usage($1);
			if (@usage) {
				printf "%s\n", $line;
				if ($textmode) {
					printf "%s", join("",map({wrap(78, 12, "$tab$_")."\n"} @usage));
				} else {
					printf "%s", join("",map({"$tab| ".'``'.$_.'``'."\n"} @usage));
				}
				$line = "";
			}
		}
	}
	$last = $line;
}

printf "%s\n", $last if defined($last);
exit 0;
