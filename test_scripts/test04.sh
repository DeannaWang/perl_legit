#!/bin/sh

# Author: Xiyan Wang, z5151289

# Test merge files with modification at the beginning or at the end of file

legit.pl init
seq 1 7 > a
legit.pl add a
legit.pl commit -m 0
legit.pl branch b1
seq 3 7 > a                     # Modified at the beginning
legit.pl commit -a -m 1
legit.pl checkout b1
seq 1 6 > a
seq 6 >> a                      # Modified at the end
legit.pl commit -a -m 2
legit.pl merge -m 3 master
legit.pl log
legit.pl show 3:a
legit.pl checkout master
legit.pl log

# Clean up
rm a
rm -r --force .legit