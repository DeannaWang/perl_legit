#!/bin/sh

# Author: Xiyan Wang, z5151289

# Test usage error for subset 2: branch, checkout, merge

# Test commands before init
legit.pl branch b1
legit.pl checkout b1
legit.pl merge b1

# init
legit.pl init

# Test commands before commit
legit.pl branch b1
legit.pl checkout b1
legit.pl merge b1

# commit
echo a > a
legit.pl add a
legit.pl commit -m 0

# Test branch usage
legit.pl branch b+
echo $?
legit.pl branch b/b
echo $?
legit.pl branch b1
echo $?
legit.pl branch b1 -d
echo $?
legit.pl branch -a b1
echo $?
legit.pl branch b1 b2
echo $?

# Test checkout usage
legit.pl branch b1
legit.pl checkout
echo $?
legit.pl checkout -a
echo $?
legit.pl checkout b1 b1
echo $?
legit.pl checkout -a b1
echo $?

# Test merge usage
echo a >> a
legit.pl checkout b1
legit.pl add a
legit.pl commit -m 1
legit.pl checkout master
legit.pl merge
echo $?
legit.pl merge -m 2 b1 b2
echo $?
legit.pl merge -m 2
echo $?
legit.pl merge b1 -m
echo $?
legit.pl merge -m b1
echo $?
legit.pl merge -m -b
echo $?
legit.pl merge b1
echo $?
legit.pl merge -m b1 2
echo $?
legit.pl merge -m 2 b1
echo $?
legit.pl log

# Clean up
rm a
rm -r --force .legit