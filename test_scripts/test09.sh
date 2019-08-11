#!/bin/sh

# Author: Xiyan Wang, z5151289

# Other tests

# Successfully delete merged branch
legit.pl init
touch a
legit.pl add a
legit.pl commit -m 0
legit.pl branch b1
touch b
legit.pl add b
legit.pl commit -m 1
legit.pl checkout b1
echo a > a
legit.pl commit -a -m 2
legit.pl checkout master
legit.pl merge -m 3 b1              # a: a
legit.pl branch -d b1

# Checkout when commit files not equal but working file consist with target commit file
legit.pl branch b1
rm a
legit.pl commit -a -m 4             # a not exist
legit.pl show :a
cat a
echo aa > a
legit.pl add a
legit.pl checkout b1                # conflict
echo a > a
legit.pl add a
legit.pl checkout b1                # success
legit.pl show :a
cat a

# Clean up
rm a b
rm -r --force .legit