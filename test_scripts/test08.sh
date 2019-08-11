#!/bin/sh

# Author: Xiyan Wang, z5151289

# merge with commit no, check log file
legit.pl init
touch a
legit.pl add a
legit.pl commit -m 0           # 0 a
legit.pl branch b1
echo a >> a
legit.pl commit -a -m 1        # 1 a
legit.pl checkout b1
echo a >> a
legit.pl commit -a -m 2        # 1 a
legit.pl checkout master
echo a >> a
legit.pl commit -a -m 3        # 2 a
legit.pl checkout b1
echo a >> a
legit.pl commit -a -m 4        # 2 a
legit.pl checkout master
echo a >> a
legit.pl commit -a -m 5        # 3 a
legit.pl checkout b1
echo a >> a
legit.pl commit -a -m 6        # 3 a
legit.pl checkout master
echo a >> a
legit.pl commit -a -m 7        # 4 a
legit.pl checkout b1
echo a >> a
legit.pl commit -a -m 8        # 4 a
legit.pl checkout master
echo a >> a
legit.pl commit -a -m 9        # 5 a
legit.pl checkout b1
echo a >> a
legit.pl commit -a -m 10       # 5 a
legit.pl log
legit.pl checkout master
legit.pl log
legit.pl merge 4 -m 11         # conflict
legit.pl checkout b1
legit.pl merge 5 -m 11         # conflict
legit.pl merge 9 -m 11         # success
legit.pl log
legit.pl checkout master

# legit.pl merge 10 -m 12      # the reference implementation does not fast forward for this
                               # seems although we merged the log
                               # a separate history timeline still should be maintained
                               # which is not implemented in this project
                               # and here the commit numbers in log are not in order

legit.pl merge 11 -m 12        # fast forward
                               # but it is weird that commits before the base commit
                               # are also merged to the log file
                               # though this project is adjusted to be consistent 
                               # with the reference implementation
legit.pl log
legit.pl show :a

# Clean up
rm a
rm -r --force .legit