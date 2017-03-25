#!/usr/bin/perl

use strict;
use warnings;

my ($b, $o, $t, $s, $r);

foreach $b (0, 1, 2) {
	foreach $o (0, 1, 2) {
		foreach $t (0, 1, 2) {
			foreach $s ('r', 't', 'o', 'm') {
				$r = -1;
				my $mr = -1;
				if ($o eq $t) {
					$mr = $o;
				} elsif ($b eq $o) {
					$mr = $t;
				} elsif ($b eq $t) {
					$mr = $o;
				} else {
					$mr = 3;
				}
				$s eq 'm' and $r = $mr;
				$s eq 'o' and $r = $o;
				$s eq 't' and $r = $t;
				$s eq 'r' and $r = 0;
				print "$b $o $t $s $r $mr\n";
			}
		}
	}
}
