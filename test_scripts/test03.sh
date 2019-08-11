#!/bin/sh

# Author: Xiyan Wang, z5151289

# Test merge by commit number

# Merge
legit.pl init
touch a b c d e f
legit.pl add a
legit.pl commit -m 0
legit.pl branch b1
legit.pl checkout b1
legit.pl add b
legit.pl commit -m 1
legit.pl checkout master
legit.pl add c
legit.pl commit -m 2
legit.pl checkout b1
legit.pl add d
legit.pl commit -m 3
legit.pl add e
legit.pl commit -m 4
legit.pl log
legit.pl checkout master
legit.pl log
legit.pl merge -m 5 2         # Already up to date
legit.pl merge -m 5 3         # Successful merge
legit.pl log
legit.pl checkout b1
legit.pl log

# Fast forward
legit.pl branch b2
legit.pl add f
legit.pl commit -m 6
legit.pl checkout b2
legit.pl merge -m 6 6         # Fast forward
legit.pl log

# Clean up
rm a b c d e f
rm -r --force .legit