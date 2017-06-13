#!/bin/sh

failed_tests=
fixed=0
success=0
failed=0
broken=0
total=0

while read file
do
	while read type value
	do
		case $type in
		'')
			continue ;;
		fixed)
			fixed=$(($fixed + $value)) ;;
		success)
			success=$(($success + $value)) ;;
		failed)
			failed=$(($failed + $value))
			if test $value != 0
			then
				testnum="${file#test-results/}"
				testnum="${testnum%.counts}"
				case "$testnum" in t[0-9]*)
					testnum_="${testnum#t}"
					testnum="t${testnum_%%[!0-9]*}"
				esac
				failed_tests="$failed_tests $testnum"
			fi
			;;
		broken)
			broken=$(($broken + $value)) ;;
		total)
			total=$(($total + $value)) ;;
		esac
	done <"$file"
done

if test -n "$failed_tests"
then
	printf "\nfailed test(s):$failed_tests\n\n"
fi

printf "%-8s%d\n" fixed $fixed
printf "%-8s%d\n" success $success
printf "%-8s%d\n" failed $failed
printf "%-8s%d\n" broken $broken
printf "%-8s%d\n" total $total
