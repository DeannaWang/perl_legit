#!/bin/sh

# Author: Xiyan Wang, z5151289
# Overwritten conflict is detected in this project though not required

# Test merge with file change in working dir
legit.pl init
touch a b
echo a > a
legit.pl add a
legit.pl commit -m 0                # a: a
legit.pl branch b1
legit.pl add b
legit.pl commit -m 1                # a: a
legit.pl checkout b1
echo aa > a
legit.pl commit -a -m 2             # a: aa
echo aaa > a                        # working dir: aaa
# legit.pl add a                    # overwrite conflict if this line is uncommented
legit.pl merge -m 3 master
legit.pl show 3:a
cat a

# Test merge with file change in working dir when file not in src branch
legit.pl branch b2
rm a
legit.pl commit -a -m 4             # a not exist
legit.pl show :a
cat a
legit.pl checkout b2
legit.pl show :a
cat a
touch c
legit.pl add c
legit.pl commit -m 5
legit.pl checkout b1
legit.pl show :a
cat a
echo aaa > a
# legit.pl add a                    # overwrite conflict if this line is uncommented
legit.pl merge -m 6 b2
legit.pl show 6:a
legit.pl show :a

# Clean up
rm a b c
rm -r --force .legit