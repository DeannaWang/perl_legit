#!/bin/sh

# Author: Xiyan Wang, z5151289

# Test usage error for subset 0: init, add, commit (without -a), log, show

# Without valid command
legit.pl
echo $?
legit.pl unknown_command
echo $?

# Test init
legit.pl init unknown
echo $?

# Test other commands before init
echo a > a
legit.pl add a
echo $?
legit.pl commit -m 0
echo $? 
legit.pl log
echo $?
legit.pl show :a
echo $?
legit.pl add unknown
echo $?
legit.pl commit unknown
echo $?
legit.pl log unknown
echo $?
legit.pl show unknown
echo $?

# successful init
legit.pl init

# repeatedly init
legit.pl init
echo $?

# Test add usage
# legit.pl add                     # This one is an internal error for the reference
# echo $?
legit.pl add -unknown_opt          # Unknown option
echo $?
legit.pl add non_exist_file        # Not existing file
echo $?
legit.pl add a non_exist_file      # Partly not existing file
echo $?
legit.pl add a/a                   # File not local (the reference only check if filename is valid)
echo $?
legit.pl add a+                    # Invalid filename
echo $?
legit.pl status                    # No file should be successfully added
legit.pl add a
legit.pl status                    # Successfully added
rm a
legit.pl add a                     # Use add command to remove a file
legit.pl show :a
echo $?
legit.pl status
mkdir a
legit.pl add a                     # Not a regular file
echo $?
rm -r a

# Test commit usage
legit.pl commit -m 0 0
echo $?
legit.pl commit -m 0
echo $?

# Test commands before there is a commit
legit.pl log
echo $?
legit.pl show :a
echo $?

# Test commit usage
echo a > a
legit.pl add a
legit.pl commit                    # Without -m
echo $?
legit.pl commit -m 0 0             # Invalid arg
echo $?
legit.pl commit -m                 # Without message
echo $?
legit.pl commit -b -m 0            # Invalid option
echo $?
legit.pl commit -m -b              # Will -b be considered an option or a message? An option.
echo $?
legit.pl commit -m -m -m 0
echo $?
legit.pl commit -m 1 -m 0
echo $?
legit.pl log

# Make a valid commit
legit.pl commit -m 0

# Test log usage
legit.pl log unknown
echo $?

# Test show usage
legit.pl show
echo $?
legit.pl show unknown
echo $?
legit.pl show unknown:a
echo $?
legit.pl show :unknow
echo $?
legit.pl show 0:unknow
echo $?

# Test valid commands
legit.pl status
legit.pl log
legit.pl show 0:a

# Clean up
rm a
rm -r --force .legit