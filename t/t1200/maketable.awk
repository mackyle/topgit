#!/usr/bin/awk -f

BEGIN {exit}
END {
	sn = split("r t o m", sv, " ")
	for (b = 0; b <= 2; ++b) {
		for (o = 0; o <= 2; ++o) {
			for (t = 0; t <= 2; ++t) {
				for (si = 1; si <= sn; ++si) {
					s = sv[si]
					r = -1
					mr = -1
					if (o == t) {
						mr = o
					} else if (b == o) {
						mr = t
					} else if (b == t) {
						mr = o
					} else {
						mr = 3
					}
					if (s == "m") r = mr
					if (s == "o") r = o
					if (s == "t") r = t
					if (s == "r") r = 0
					print b " " o " " t " " s " " r " " mr
				}
			}
		}
	}
}
