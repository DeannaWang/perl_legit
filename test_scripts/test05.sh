#!/bin/sh

# Author: Xiyan Wang, z5151289

# Test merge when file does not exist in base_commit

# merge while file not in base
legit.pl init
touch a b c
legit.pl add a
legit.pl commit -m 0                # a (d does not exist in base commit)
legit.pl branch b1
echo d > d
legit.pl add b d
legit.pl commit -m 1                # a b d (d: d)
legit.pl checkout b1
echo d > d
echo d >> d
legit.pl add c d
legit.pl commit -m 2                # a c d (d: d\nd)
legit.pl merge -m 3 master          # conflict (different version of d in commit 1 and 2)
legit.pl rm d
echo d > d
legit.pl add d
legit.pl commit -m 3                # a c d (d: d)
legit.pl merge -m 4 master          # a b c d (same version of d in commit 1 and 3)
legit.pl log
legit.pl show 4:a
legit.pl show 4:b
legit.pl show 4:c
legit.pl show 4:d

# merge with empty file while file not in base
legit.pl branch b2
touch e f
legit.pl add e
legit.pl add f
legit.pl commit -m 5                # f is empty
legit.pl checkout b2
echo f > f
legit.pl add f
legit.pl commit -m 6                # f: f
legit.pl merge -m 7 b1
legit.pl log
legit.pl show 7:f

# Clean up
rm a b c d e f
rm -r --force .legit