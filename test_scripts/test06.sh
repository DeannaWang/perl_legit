#!/bin/sh

# Author: Xiyan Wang, z5151289

# Test merge files (one line file; one branch = base; empty file)

legit.pl init

# merge one line files (conflict)
echo a > a
legit.pl add a
legit.pl commit -m 0
legit.pl branch b1
echo aa > a
legit.pl commit -a -m 1
legit.pl checkout b1
echo aaa > a
legit.pl commit -a -m 2
legit.pl merge -m 3 master            # One line files (conflict)

# merge one line files (one branch equal to base)
echo a > a
touch b
legit.pl add b
legit.pl commit -a -m 3               # a is the same as in base commit (commit 0)
legit.pl merge -m 4 master            # No Auto-merging message
legit.pl show 4:a
legit.pl log

# merge with empty file (one branch equal to base)
legit.pl branch b2
touch c
legit.pl add c
legit.pl commit -m 5
legit.pl checkout b2
echo b > b
legit.pl add b
legit.pl commit -m 6
legit.pl merge -m 7 b1                # merge with empty file (b empty in base and b1)
legit.pl show 7:b
legit.pl log

# Clean up
rm a b c
rm -r --force .legit