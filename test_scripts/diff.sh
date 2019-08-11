#!/bin/sh

# Author: Xiyan Wang, z5151289

# Diff the result of a test file with the result of the reference implementation
# Usage: ./diff.sh test0[0-9].sh

if [ $# -ne 1 ]; then
    >&2 echo "Usage: $0 testfile"
    exit 1
fi

# Format filenames
filename=`echo "$1" | sed 's|^\./||; s|\.[^\.]*$||'`
tmp_filename=".$$"_"$filename"_tmp.sh
cmp1=".$$"_"$filename"_cmp1
cmp2=".$$"_"$filename"_cmp2
cmp3=".$$"_"$filename"_cmp3
cmp4=".$$"_"$filename"_cmp4

# Replace ./legit.pl with 2041 legit in the test file and write the result to a tmp file
sed 's|^legit.pl|2041 legit|g' "$1" > "$tmp_filename"

# Execute the test file and the tmp file respectively and diff the result
chmod 755 "$tmp_filename"
./"$1" > "$cmp1" 2>"$cmp3"
./"$tmp_filename" > "$cmp2" 2>"$cmp4"
diff "$cmp1" "$cmp2"
diff "$cmp3" "$cmp4"

# Clean up
rm "$tmp_filename"
rm "$cmp1" "$cmp2" "$cmp3" "$cmp4"