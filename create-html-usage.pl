#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename;

my $mydir = dirname($0);
my $last = undef;

sub get_tg_usage($)
{
	my $name = shift;
	if ( -x "$mydir/tg-$name" ) {
		my $usage = `"$mydir/tg-$name" -h 2>&1`;
		chomp $usage;
		$usage =~ s/^Usage:\s*//i;
		return $usage;
	} elsif ($name eq "help") {
		return "tg help [-w] [<command>]";
	}
	return undef;
}

while (my $line = <>) {
	if (defined($last)) {
		print $last;
		if ($line =~ /^[~]+$/ && $last =~ /^tg ([^\s]+)$/) {
			my $usage = get_tg_usage($1);
			if (defined($usage)) {
				print $line;
				print "\t", '``', $usage, '``', "\n";
				$line = "\n";
			}
		}
	}
	$last = $line;
}

print $last if defined($last);
exit 0;
