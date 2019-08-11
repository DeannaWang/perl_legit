#!/bin/sh

# Author: Xiyan Wang, z5151289

# Test usage error for subset 1: rm, status
# Commented lines are not supported by reference implementation, but supported by this project

# Test commands before init
legit.pl rm a
legit.pl status

legit.pl init
echo a > a
legit.pl add a

# Test rm usage
legit.pl rm a                            # Before commit
echo $?
legit.pl commit -m 0
# legit.pl rm                            # The reference implementation shows internal error
# echo $?
# legit.pl rm --force                    # The reference implementation shows internal error
# echo $?
# legit.pl rm --cached                   # The reference implementation shows internal error
# echo $?
legit.pl rm --unknown_opt
echo $?
legit.pl rm -unknown_opt
echo $?
legit.pl rm non_exist_file
echo $?
legit.pl rm a non_exist_file
echo $?
legit.pl rm --f a
echo $?
legit.pl rm --cac a
echo $?
legit.pl rm -force a
echo $?
legit.pl status
legit.pl rm a+
echo $?
legit.pl rm a/a
echo $?
mkdir b
legit.pl rm b
echo $?
rm -r b

# Args do not have to be in certain order
# Not supported in reference implementation, but supported in this project

# legit.pl rm a --cache --force          
# echo $?                                  
# legit.pl status                        
# echo a > a
# legit.pl add a
# echo b > b
# legit.pl add b
# legit.pl rm a --cache b --force
# echo $?
# legit.pl show 0:a
# legit.pl show 0:b
# legit.pl status

# Test status usage
# This error is not detected by reference implementation

# legit.pl status unknown
# echo $?

# Test commit -a usage
legit.pl add a
echo a >> a
legit.pl commit -a -m 1
echo $?
legit.pl show 1:a
echo a >> a
legit.pl commit -m 2 -a
echo $?
legit.pl show 2:a
echo a >> a
legit.pl commit 3 -am
echo $?
legit.pl show 3:a
# echo a >> a                            # Bundled options
# legit.pl commit -am 4                  # Not supported by reference implementation
# echo $?                                # But available in this project
# legit.pl show 4:a                      # Uncomment this part to test

# Clean up
rm a b
rm -r --force .legit