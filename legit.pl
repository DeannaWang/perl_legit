#!/usr/bin/perl

# Author: Xiyan Wang, z5151289

# subset 0, subset 1, subset 2 implemented
# challenge attempted, with two functions diff and patch working fine

#
# File structure: 
# - .legit (root folder)
#   - index (index folder)
#       - files
#   - branches (branches folder)
#       - master (branch log file)
#       - b1 (branch log file)
#       - ...
#   - commit (commit folder)
#       - 0 (commit no folder)
#           - files
#       - 1 (commit no folder)
#           - files
#       - ...
#   - head_file (one line file)
#

use strict;
use warnings;
use File::Copy;
use File::Compare;
use File::Spec::Functions;
use Getopt::Long qw(:config pass_through no_ignore_case no_auto_abbrev);
Getopt::Long::Configure ("bundling");

# tool function prototypes
sub die_error;
sub die_without_error_format;

# global constants and variables
my $ROOT_FOLDER = ".legit";                                 # root folder
my $INDEX_FOLDER = catfile $ROOT_FOLDER, "index";           # index folder
my $BRANCHES_FOLDER = catfile $ROOT_FOLDER, "branches";     # contains log_files of branches
my $COMMIT_FOLDER = catfile $ROOT_FOLDER, "commit";         # contains folders named commit_no
my $CURRENT_BRANCH = "master";                              # master branch
my $HEAD_FILE = catfile $ROOT_FOLDER, "head";               # current_branch_name (one line)
my $LOG_FILE = catfile $BRANCHES_FOLDER, $CURRENT_BRANCH;   # commit_no message
my $INTERNAL_ERROR = "internal error";                      # unknown error
$0 =~ s/.*\///;                                             # name of this file

my $LEGIT_USAGE = << "END USAGE";
Usage: $0 <command> [<args>]

These are the legit commands:
   init       Create an empty legit repository
   add        Add file contents to the index
   commit     Record changes to the repository
   log        Show commit log
   show       Show file at particular state
   rm         Remove files from the current directory and from the index
   status     Show the status of files in the current directory, index, and repository
   branch     list, create or delete a branch
   checkout   Switch branches or restore current directory files
   merge      Join two development histories together
END USAGE

main();

# main function
sub main {

    # setup function map
    my @commands = split " ", "add branch checkout commit diff init log merge rm show status";
    my %functions;
    $functions{$_} = \&$_ foreach @commands;

    # read branch_name from HEAD
    update_current_branch();

    # run command
    if (@ARGV > 0 && grep /^$ARGV[0]$/, @commands) {
        $functions {shift @ARGV} ();
    }
    else {
        if (@ARGV == 0) {
            die_without_error_format "$LEGIT_USAGE";
        }
        else {
            die_error "unknown command $ARGV[0]\n" . $LEGIT_USAGE;
        }
    }
}


#####################
#                   #
# Command Functions #
#                   #
#####################

sub init {

    # Check input
    my $usage = 'init';
    check_arg_usage($usage);

    # Check conflict and initialize
    die_error "$ROOT_FOLDER already exists" if -d $ROOT_FOLDER;
    mkdir $ROOT_FOLDER or die_error "could not create legit depository";
    mkdir $INDEX_FOLDER or die_error $INTERNAL_ERROR;
    mkdir $BRANCHES_FOLDER or die_error $INTERNAL_ERROR;
    mkdir $COMMIT_FOLDER or die_error $INTERNAL_ERROR;
    print "Initialized empty legit repository in .legit\n";
}

sub add {
    check_root_folder();

    # Check input
    my $usage = 'add <filenames>';
    check_arg_non_option($usage);
    die_without_error_format "usage: $0 $usage" if @ARGV == 0;

    # Check filenames
    for my $filename (@ARGV) {
        $filename =~ /^[a-zA-Z0-9][a-zA-Z0-9_\-\.]*$/ or die_error "invalid filename '$filename'";
        -f catfile($INDEX_FOLDER, $filename) || -O $filename or die_error "can not open '$filename'";
        check_filename_regular($filename);
    }

    # Copy files
    for my $filename (@ARGV) {
        cp($filename, catfile($INDEX_FOLDER, $filename));
    }
}

sub commit {
    check_root_folder();

    # Check input
    my $add = 0;
    my $usage = 'commit [-a] -m commit-message';
    GetOptions('m=s' => \my @messages, 'a' => \$add);
    my $message = $messages[-1];
    die_without_error_format "usage: $0 $usage" if grep /^-/, @messages;
    check_arg_value($usage, "-m");
    die_without_error_format "usage: $0 $usage" if @messages == 0;
    check_arg_usage($usage);
    die_without_error_format "usage: $0 $usage" if $message =~ m/^-/;
    die_error 'commit message can not contain a newline' if grep /[\r\n]/, $message;

    # Check commit content
    my $commit_no = get_commit_no();
    my $compare_dir = catfile($COMMIT_FOLDER, get_last_commit_no_of_branch($CURRENT_BRANCH));
    my $commit_dir = catfile($COMMIT_FOLDER, $commit_no);
    my @modified_files;
    my $unchanged = 1;
    for my $filename (get_filenames($INDEX_FOLDER, $compare_dir)) {
        my $src = catfile($INDEX_FOLDER, $filename);
        my $dst = catfile($commit_dir, $filename);
        my $cmp = catfile($compare_dir, $filename);
        if ($commit_no == 0 || 
            !(-f $src && -f $cmp && compare($src, $cmp) == 0) || 
            ($add && (! -f $filename || compare($src, $filename) != 0))) {
            $unchanged = 0;
        }
    }

    # No new content
    if ($unchanged) {
        print "nothing to commit\n";
    }

    # Commit
    else {
        mkdir $commit_dir;

        # Copy files
        for my $filename (get_filenames($INDEX_FOLDER)) {
            if ($add) {
                cp($filename, $INDEX_FOLDER);
                cp($filename, $commit_dir);
            }
            else {
                cp(catfile($INDEX_FOLDER, $filename), $commit_dir);
            }
        }

        # LOG_FILE: commit_no message
        open F, '>>', $LOG_FILE;
        print F "$commit_no $message\n";
        close F; 
        print "Committed as commit $commit_no\n";
    }
}

sub show {
    check_root_folder();
    check_committed();

    # Check input
    my $usage = "show <commit>:<filename>";
    @ARGV == 1 or die_without_error_format "usage: $0 $usage";
    my ($arg) = @ARGV;
    $arg =~ m/:/ or die_error "invalid object $arg";
    my ($commit_no, $filename) = split ":", $arg, 2;
    $commit_no eq '' || ($commit_no =~ m/^\d+$/ && $commit_no < get_commit_no()) 
        or die_error "unknown commit '$commit_no'";

    # Find the file
    my $path;
    if ($commit_no eq '') {
        $path = catfile($INDEX_FOLDER, $filename);
        -f $path or die_error "'$filename' not found in index";
    }
    else {
        $path = catfile($COMMIT_FOLDER, $commit_no, $filename);
        -f $path or die_error "'$filename' not found in commit $commit_no";
    }

    # Show file
    print foreach (get_file_content($path));
}

sub rm {
    check_root_folder();
    check_committed();

    # Check input
    my $force = 0;
    my $cached = 0;
    my $usage = 'rm [--force] [--cached] <filenames>';
    GetOptions('force+' => \$force, 'cached+' => \$cached);
    check_arg_non_option($usage);
    die_without_error_format "usage: $0 $usage" if @ARGV == 0;

    # Check conflict
    for my $filename (@ARGV) {
        check_filename_valid($filename);
        -f catfile($INDEX_FOLDER, $filename) 
            or die_error "'$filename' is not in the legit repository";
        next if ! -e $filename;
        check_filename_regular($filename);

        my ($working_index_diff, $working_commit_diff, $index_commit_diff) = 
            get_status_info($filename);

        die_error "'$filename' in index is different to both working file and repository"
            if $working_index_diff && $index_commit_diff && ! $force;
        die_error "'$filename' has changes staged in the index"
            if $index_commit_diff && ! $force && ! $cached;
        die_error "'$filename' in repository is different to working file"
            if $working_commit_diff && ! $force && ! $cached;
    }

    # Remove files
    for my $filename (@ARGV) {
        if (!$cached) {
            unlink $filename;
        }
        unlink catfile($INDEX_FOLDER, $filename);
    }
}

sub branch {
    check_root_folder();
    check_committed();

    # check input format
    my $del = 0;
    my $usage = 'branch [-d] <branch>';
    GetOptions('d' => \$del);
    @ARGV <= 1 or die_without_error_format "usage: $0 $usage";
    die_error 'branch name required' if ($del && @ARGV == 0);
    my ($branch_name) = @ARGV;
    check_branch_name_valid($branch_name) if @ARGV == 1;

    # legit.pl branch
    if (@ARGV == 0) {
        print $_ . "\n" foreach (get_filenames($BRANCHES_FOLDER));
    }

    # legit.pl branch -d branch_name
    elsif ($del) {
        $branch_name ne 'master' or die_error "can not delete branch 'master'";
        my $branch = catfile($BRANCHES_FOLDER, $branch_name);
        -e $branch or die_error "branch '$branch_name' does not exist";
        my $commit_no = get_last_commit_no_of_branch($branch_name);
        my $seen = 0;
        # count how many times commit_no appear in branch log files
        $seen += grep /^$commit_no\s+/, get_file_content(catfile($BRANCHES_FOLDER, $_)) 
            foreach (get_filenames($BRANCHES_FOLDER));
        # if commit_no apprear only once then the branch cannot be deleted
        die_error "branch '$branch_name' has unmerged changes" 
            if $seen == 1;
        unlink $branch;
        print "Deleted branch '$branch_name'\n";
    }

    # legit.pl branch branch_name
    else {
        my $branch = catfile($BRANCHES_FOLDER, $branch_name);
        die_error "branch '$branch_name' already exists" if -e $branch;
        cp($LOG_FILE, $branch);
    }
}

sub checkout {
    check_root_folder();
    check_committed();

    # check input format
    my $usage = 'checkout <branch>';
    @ARGV == 1 or die_without_error_format "usage: $0 $usage";
    die_without_error_format "usage: $0 $usage" if $ARGV[0] =~ m/^-/;
    -e catfile($BRANCHES_FOLDER, $ARGV[0]) or die_error "unknown branch '$ARGV[0]'";
    (print "Already on '$ARGV[0]'\n" and exit 0) if $ARGV[0] eq $CURRENT_BRANCH;
    my $branch_name = $ARGV[0];

    # record conflict files
    my @conflict_filenames;

    # conflict if not working = index = commit, and src_commit != dst_commit
    my $commit_dir = get_last_commit_folder_of_branch($CURRENT_BRANCH);
    for my $filename (get_filenames($commit_dir)) {
        my ($working_index_diff, $working_commit_diff) = get_status_info($filename);
        push @conflict_filenames, $filename if ($working_commit_diff || $working_commit_diff) && 
            check_commit_diff($filename, $CURRENT_BRANCH, $branch_name);
    }

    # uncommitted files should not conflict with targit_commit files
    my $target_commit_dir = get_last_commit_folder_of_branch($branch_name);
    my @uncommitted_filenames = get_uncommitted_filenames($CURRENT_BRANCH, $branch_name);
    for my $filename (@uncommitted_filenames) {
        push @conflict_filenames, $filename if 
            # file committed in target branch
            -f catfile($target_commit_dir, $filename) && 
            # different commit version
            check_commit_diff($filename, $CURRENT_BRANCH, $branch_name) && (
                # file in working dir or index dir diff from file in target branch
                compare($filename, catfile($target_commit_dir, $filename)) || 
                compare(catfile($INDEX_FOLDER, $filename), catfile($target_commit_dir, $filename)));
    }

    # output error if conflict
    die_error "Your changes to the following files would be overwritten by checkout:\n"
        . join "\n", sort @conflict_filenames if @conflict_filenames > 0;

    # update working files and index files
    for my $filename (get_filenames($target_commit_dir)) {
        my $target_filename = catfile($target_commit_dir, $filename);
        (cp($target_filename, ".") and cp($target_filename, $INDEX_FOLDER)) if 
            # file committed in current branch and diff from target branch
            # or file not committed in current branch
            check_commit_diff($filename, $CURRENT_BRANCH, $branch_name);
    }

    # remove files which are not committed in target branch but committed in current branch
    for my $filename (glob "*") {
        unlink $filename if (-f $filename && 
            ! grep(/^$filename$/, @uncommitted_filenames) && 
            ! -f catfile($target_commit_dir, $filename));
    }
    for my $filename (get_filenames($INDEX_FOLDER)) {
        unlink catfile($INDEX_FOLDER, $filename) if (
            ! grep(/^$filename$/, @uncommitted_filenames) && 
            ! -f catfile($target_commit_dir, $filename));
    }

    # switch branch
    open F, '>', $HEAD_FILE;
    print F $ARGV[0];
    close F;
    print "Switched to branch '$ARGV[0]'\n";
}

sub log {
    check_root_folder();
    check_committed();

    # Check input
    my $usage = "log";
    check_arg_usage($usage);

    my @lines = get_file_content($LOG_FILE);
    
    # Output: commit_no message (commit_no descending order)
    print foreach (reverse @lines);
}

sub merge {
    check_root_folder();
    check_committed();

    # Check input
    my $usage = 'merge <branch|commit> -m message';
    GetOptions('m=s' => \my @messages);
    my $message = $messages[-1];
    die_without_error_format "usage: $0 $usage" if grep /^-/, @messages;
    check_arg_value($usage, "-m");
    @ARGV == 1 or die_without_error_format "usage: $0 $usage";
    die_error 'empty commit message' if @messages == 0;
    my ($branch_name, $base_commit_no, $branch_last_commit_no);

    # Merge commit no
    if (grep /^\d+$/, @ARGV) {
        $branch_last_commit_no = shift @ARGV;
        -e catfile($COMMIT_FOLDER, $branch_last_commit_no) 
            or die_error "unknown commit '$branch_last_commit_no'";
        $base_commit_no = get_base_commit_no($CURRENT_BRANCH, $branch_last_commit_no);
        $branch_name = get_branch_by_commit_no($branch_last_commit_no);
    }

    # Merge branch
    else {
        $branch_name = shift @ARGV;
        -f catfile($BRANCHES_FOLDER, $branch_name) 
            or die_error "unknown branch '$branch_name'";
        $base_commit_no = get_base_commit_no($CURRENT_BRANCH, $branch_name);
        $branch_last_commit_no = get_last_commit_no_of_branch($branch_name);
    }
    my $current_last_commit_no = get_last_commit_no_of_branch($CURRENT_BRANCH);
    my $base_commit_dir = catfile $COMMIT_FOLDER, $base_commit_no;
    my $current_commit_dir = catfile $COMMIT_FOLDER, $current_last_commit_no;
    my $branch_commit_dir = catfile $COMMIT_FOLDER, $branch_last_commit_no;
    (print "Already up to date\n" and exit 0) if $base_commit_no == $branch_last_commit_no;

    # Fast forward
    if ($base_commit_no == $current_last_commit_no) {
        for my $filename (get_filenames($branch_commit_dir)) {
            if (! -f catfile($current_commit_dir, $filename)) {
                cp(catfile($branch_commit_dir, $filename), ".");
                cp(catfile($branch_commit_dir, $filename), $INDEX_FOLDER);
            }
        }
        my @branch_log_lines = get_file_content(catfile($BRANCHES_FOLDER, $branch_name));
        my @current_log_lines = get_file_content($LOG_FILE);
        for my $line (@branch_log_lines) {
            my $line_commit_no = (split /\s+/, $line)[0];
            push @current_log_lines, $line 
                if ! (grep /^$line_commit_no\s+/, @current_log_lines) && 
                $line_commit_no <= $branch_last_commit_no;
        }
        write_file($LOG_FILE, 
            sort {(split /\s+/, $a)[0] <=> (split /\s+/, $b)[0]} @current_log_lines);
        print "Fast-forward: no commit created\n";
    }

    # Merge
    else {
        my $tmp_folder = catfile($ROOT_FOLDER, ".tmp");
        mkdir $tmp_folder if ! -d $tmp_folder;
        my @conflict_filenames;
        my @merge_filenames;
        my @overwritten_changed_filenames;
        my @overwritten_untracked_filenames;
        my @changed_working_filenames;

        for my $filename (get_filenames($branch_commit_dir)) {
            my $base_file = catfile($base_commit_dir, $filename);
            my $current_file = catfile($current_commit_dir, $filename);
            my $branch_file = catfile($branch_commit_dir, $filename);
            my $tmp_file = catfile($tmp_folder, $filename);

            # Files in both branch_commit_dir and current_commit_dir
            if (-f $current_file) {
                next if !compare($current_file, $branch_file);

                # Working file or index file changed
                (push @overwritten_changed_filenames, $filename and next)
                    if grep /^file changed.*changes staged for commit$/, get_status($filename);
                push @changed_working_filenames, $filename 
                    if grep /^file changed/, get_status($filename);

                # Base file not exist
                if (! -f $base_file) {
                    if (is_empty_file($current_file)) {
                        cp($branch_file, $tmp_file);
                        push @merge_filenames, $filename;
                    }
                    elsif (is_empty_file($branch_file)) {
                        cp($current_file, $tmp_file);
                        push @merge_filenames, $filename;
                    }
                    else {
                        push @conflict_filenames, $filename;
                    }
                    next;
                }

                # Only one file changed compared with base file
                (cp($branch_file, $tmp_file) and next) if !compare($base_file, $current_file);
                (cp($current_file, $tmp_file) and next) if !compare($base_file, $branch_file);

                # Merge
                my ($success, @merge_res) = merge_files($base_file, $current_file, $branch_file);
                if ($success) {
                    write_file($tmp_file, @merge_res);
                    push @merge_filenames, $filename;
                }
                else {
                    push @conflict_filenames, $filename;
                }
            }

            # Files in branch_commit_dir but not in current_commit_dir
            else {
                # If base_file not exist, then working file should be consistent to branch_file
                (push @overwritten_untracked_filenames, $filename and next) 
                    if ! -f $base_file && -f $filename && compare($filename, $branch_file);
                # File should not exist in index folder
                (push @overwritten_changed_filenames, $filename and next) 
                    if -f catfile($INDEX_FOLDER, $filename);
                # Merge files (current_file not exist)
                cp($branch_file, $tmp_folder) if ! -f $base_file || compare($base_file, $branch_file);
                # Do not update working dir if there is no conflict with working file
                push @changed_working_filenames, $filename if -f $filename;
            }
        }

        @overwritten_untracked_filenames == 0 or die_error "The following untracked working tree files " . 
            "would be overwritten by merge:\n" . join "\n", sort @overwritten_untracked_filenames;
        @overwritten_changed_filenames == 0 or die_error "Your local changes to the following files " . 
            "would be overwritten by merge:\n" . join "\n", sort @overwritten_changed_filenames;
        @conflict_filenames == 0 or die_error "These files can not be merged:\n" . 
            join "\n", sort @conflict_filenames;

        # Update index dir and working dir
        unlink $_ foreach (glob catfile($INDEX_FOLDER, "*"));
        cp($_, $INDEX_FOLDER) foreach (glob catfile($current_commit_dir, "*"));
        cp($_, $INDEX_FOLDER) foreach (glob catfile($tmp_folder, "*"));
        for my $filename (get_filenames($tmp_folder)) {
            cp(catfile($tmp_folder, $filename), ".") 
                if ! grep /^$filename$/, @changed_working_filenames;
        }
        unlink $_ foreach (glob catfile($tmp_folder, "*"));

        # Pring message and commit
        print "Auto-merging $_\n" foreach (@merge_filenames);

        # Commit
        my $commit_no = get_commit_no();
        my $commit_dir = catfile($COMMIT_FOLDER, $commit_no);
        mkdir $commit_dir;
        cp(catfile($INDEX_FOLDER, $_), $commit_dir) foreach (get_filenames($INDEX_FOLDER));

        # LOG_FILE: commit_no message
        open F, '>>', $LOG_FILE;
        print F "$commit_no $message\n";
        close F; 
        print "Committed as commit $commit_no\n";

        # Update log file
        my @current_log = get_file_content($LOG_FILE);
        my $branch_log_filepath = catfile($BRANCHES_FOLDER, $branch_name);
        my @branch_log = get_file_content($branch_log_filepath);
        for my $log (@branch_log) {
            push @current_log, $log if (split /\s+/, $log)[0] > $base_commit_no && 
                                       (split /\s+/, $log)[0] <= $branch_last_commit_no;
        }
        write_file($LOG_FILE, 
            sort {(split /\s+/, $a)[0] <=> (split /\s+/, $b)[0]} @current_log);
    }
}

sub status {
    check_root_folder();
    check_committed();

    # Check input
    my $usage = 'status';
    check_arg_usage($usage);

    my $commit_folder = get_last_commit_folder_of_branch($CURRENT_BRANCH);
    my @filenames = get_filenames(".", $INDEX_FOLDER, $commit_folder);
    print $_ . " - " . get_status($_) . "\n" foreach (@filenames);
}


##################
#                #
# Tool Functions #
#                #
##################

# output error
sub die_error {
    print STDERR "$0: error: $_[0]\n" and exit 1;
}

sub die_without_error_format {
    print STDERR "$_[0]\n" and exit 1;
}

# usage: check_root_folder()
sub check_root_folder {
    -e $ROOT_FOLDER or die_error "no $ROOT_FOLDER directory containing legit repository exists";
}

# usage: check_committed()
sub check_committed {
    die_error 'your repository does not have any commits yet' if get_commit_no() == 0;
}

# usage: check_filename_valid(filename)
sub check_filename_valid {
    my ($filename) = @_;
    $filename =~ /^[a-zA-Z0-9][a-zA-Z0-9_\-\.]*$/ or die_error "invalid filename '$filename'";
}

# usage: check_filename_regular(filename)
sub check_filename_regular {
    my ($filename) = @_;
    die_error "'$filename' is not a regular file" if -e $filename && ! -f $filename;
}

# usage: check_arg_usage(usage)
sub check_branch_name_valid {
    my ($branch_name) = @_;
    $branch_name =~ /^[a-zA-Z0-9][a-zA-Z0-9_\-\.]*$/  
        or die_error "invalid branch name '$branch_name'";
    die_error "invalid branch name '$branch_name'" if $branch_name =~ /^\d+$/;
}

# usage: check_arg_non_option(usage)
# description: if there are redundant options in @ARGV (anything start with '-')
sub check_arg_non_option {
    my ($usage) = @_;
    my @opts = grep(/^-.*/, @ARGV);
    if (@opts > 0) {
        die_without_error_format "usage: $0 $usage";
    }
}

# usage: check_arg_value(usage, option)
# description: if option is processed by Getopt:Long (option still in @ARGV)
sub check_arg_value {
    my ($usage, $opt) = @_;
    die_without_error_format "usage: $0 $usage" if grep /^$opt$/, @ARGV;
}

# usage: check_arg_usage(usage)
# description: if there are redundant args (@ARGV > 0)
sub check_arg_usage {
    if (@ARGV > 0) {
        my ($usage) = @_;
        die_without_error_format "usage: $0 $usage";
    }
}

# usage: check_commit_diff(filename, branch1, branch2)
# filename: should not contain slashes
# return 0: filename exists and identifies in both branch1 and branch2
# return 1: otherwise
sub check_commit_diff {
    my ($filename, $branch1, $branch2) = @_;
    my $branch1_filename = catfile(get_last_commit_folder_of_branch($branch1), $filename);
    my $branch2_filename = catfile(get_last_commit_folder_of_branch($branch2), $filename);
    return (-f $branch1_filename && -f $branch2_filename) ? 
        compare($branch1_filename, $branch2_filename) : 1;
}

# usage: update_current_branch()
# description: read branch_name from HEAD and update values of $CURRENT_BRANCH and $LOG_FILE
# output: none
sub update_current_branch {
    if (-O $HEAD_FILE) {
        $CURRENT_BRANCH = (get_file_content($HEAD_FILE))[-1];
        $LOG_FILE = catfile $BRANCHES_FOLDER, $CURRENT_BRANCH;
    }
}

# usage: get_commit_no()
# output: next commit number
sub get_commit_no {
    my $number = () = glob catfile($COMMIT_FOLDER, "*");
    return $number;
}

# usage: get_last_commit_no_of_branch(branch_name)
# output: last commit number of branch_name
sub get_last_commit_no_of_branch {
    # check input
    my ($branch_name) = @_;
    my $branch_path = catfile($BRANCHES_FOLDER, $branch_name);
    if (! -f $branch_path) {
        return -1;
    }
    # read commit log file of the branch and return the commit_no in last line
    # commit log file format: commit_no message
    return (split /\s+/, (get_file_content($branch_path))[-1])[0];
}

# usage: get_last_commit_folder_of_branch(branch_name)
# output: path of the last commit folder of branch_name
sub get_last_commit_folder_of_branch {
    my ($branch_name) = @_;
    my $last_commit_no = get_last_commit_no_of_branch($branch_name);
    return catfile($COMMIT_FOLDER, $last_commit_no);
}

# usage: get_status_info(filename)
# filename: should not contain slashes
# output: file diff information and filenames in different dirs
sub get_status_info {
    my ($filename) = @_;
    my $index_filename = catfile($INDEX_FOLDER, $filename);
    my $commit_filename = catfile(get_last_commit_folder_of_branch($CURRENT_BRANCH), $filename);
    my $working_index_diff = 
        -f $filename && -f $index_filename ? compare($filename, $index_filename) : 1;
    my $working_commit_diff = 
        -f $filename && -f $commit_filename ? compare($filename, $commit_filename) : 1;
    my $index_commit_diff = 
        -f $index_filename && -f $commit_filename ? compare($index_filename, $commit_filename) : 1;
    return ($working_index_diff, $working_commit_diff, $index_commit_diff, 
            $index_filename, $commit_filename);
}

# usage: get_status(filename)
# filename: should not contain slashes
# output: status string of filename
sub get_status {
    my ($filename) = @_;
    my ($working_index_diff, $working_commit_diff, $index_commit_diff, 
        $index_filename, $commit_filename) = get_status_info($filename);
    if (!(-f $filename && -f $index_filename && -f $commit_filename)) {
        if (-f $filename) {
            if (-f $index_filename) {
                # in working dir, index dir but not committed
                return "added to index";
            }
            else {
                # in working dir, but not index dir
                return "untracked";
            }
        }
        else {
            if (-f $index_filename) {
                # not in working dir, but in index dir
                return "file deleted";
            }
            else {
                # not in either working dir or index dir, but in commit dir
                return "deleted";
            }
        }
    }
    else {
        if ($working_index_diff) {
            if ($index_commit_diff) {
                # working != index != commit
                return "file changed, different changes staged for commit";
            }
            else {
                # working != index = commit
                return "file changed, changes not staged for commit";
            }
        }
        else {
            if ($index_commit_diff) {
                # working = index != commit
                return "file changed, changes staged for commit";
            }
            else {
                # working = index = commit
                return "same as repo";
            }
        }
    }
}

# usage: get_filenames(dir1, dir2, ...)
# input: paths of folders
# output: array of sorted unique filenames in the input folders
sub get_filenames {
    my @filenames;      # store the filenames to return
    my @paths;          # store the paths of these files
    push @paths, glob(catfile $_, "*") foreach (@_);
    for my $filename (@paths) {
        next if ! -f $filename;
        $filename =~ s/.*\///;
        push @filenames, $filename if !(grep /^$filename$/, @filenames);
    }
    return sort @filenames;
}

# usage: get_uncommitted_filenames(src_branch, dst_branch)
# src_branch: the branch checking out of
# dst_branch: the branch checking out to
# output: array of names of uncommitted files
# 'uncommitted' is defined:
# not in last commit dir of src_branch
# or files which have the same version in commit dir of both branches 
# but changed in working dir or index dir
sub get_uncommitted_filenames {
    my ($src_branch, $dst_branch) = @_;
    my @uncommitted_filenames;
    for my $filename (get_filenames(".", $INDEX_FOLDER)) {
        # files in working or index dir but not in last commit dir of src_branch
        if (! grep(/^$filename$/, get_filenames(get_last_commit_folder_of_branch($src_branch)))) {
            push @uncommitted_filenames, $filename;
        }
        # files exist and identify in last commit dir of both src_branch and dst_branch
        elsif (! check_commit_diff($filename, $src_branch, $dst_branch)) {
            my ($working_index_diff, $working_commit_diff) = get_status_info($filename);
            # push if file changed in working dir or index dir
            push @uncommitted_filenames, $filename if ($working_index_diff || $working_commit_diff);
        }
    }
    return @uncommitted_filenames;
}

# usage: get_commit_no_array_of_branch(branch_name)
sub get_commit_no_array_of_branch {
    my ($branch_name) = @_;
    my @nums;
    push @nums, (split /\s+/, $_)[0] 
        foreach (get_file_content(catfile($BRANCHES_FOLDER, $branch_name)));
    return @nums;
}

# usage: get_branch_by_commit_no(commit_no)
sub get_branch_by_commit_no {
    my ($commit_no) = @_;
    my $branch;
    for my $filename (get_filenames($BRANCHES_FOLDER)) {
        my @lines = get_file_content(catfile($BRANCHES_FOLDER, $filename));
        ($branch = $filename and last) if grep /^$commit_no\s+/, @lines;
    }
    return $branch;
}

# usage: get_base_commit_no(branch1, branch2|commit_no)
sub get_base_commit_no {
    my ($branch1, $branch2, $branch2_commit_no);
    if (grep /^\d+$/, @_) {
        ($branch1, $branch2_commit_no) = @_;
        $branch2 = get_branch_by_commit_no($branch2_commit_no);
    }
    else {
        ($branch1, $branch2) = @_;
        $branch2_commit_no = get_last_commit_no_of_branch($branch2);
    }
    my @nums1 = get_commit_no_array_of_branch($branch1);
    my @nums2 = get_commit_no_array_of_branch($branch2);
    for my $num (reverse @nums1) {
        return $num if grep(/^$num$/, @nums2) && $num <= $branch2_commit_no;
    }
}

# usage: get_base_commit_folder(branch1, branch2)
sub get_base_commit_folder {
    my ($branch1, $branch2) = @_;
    my $base_commit_no = get_base_commit_no($branch1, $branch2);
    return catfile($COMMIT_FOLDER, $base_commit_no);
}

# usage: get_file_content(filepath)
sub get_file_content {
    my ($filepath) = @_;
    open F, '<', $filepath;
    my @content = <F>;
    close F;
    return @content;
}

# usage: is_empty_file(filepath)
sub is_empty_file {
    my ($filepath) = @_;
    my @lines = get_file_content($filepath);
    return 1 if @lines == 0;
    return 0;
}

# usage: lcs (file1path, filepath2, filepath3)
# description: calculate longest common subsequence of three files (dynamic programming)
# output: a string containing the line numbers of the longest common subsequence in the files
sub lcs {

    # read files
    my ($f1, $f2, $f3) = @_;
    my @l1 = get_file_content($f1);
    my @l2 = get_file_content($f2);
    my @l3 = get_file_content($f3);

    # calculate the longest common subsequence of three files
    my %res;
    for my $i (-1..$#l1) {
        for my $j (-1..$#l2) {
            for my $k (-1..$#l3) {
                if ($i == -1 || $j == -1 || $k == -1) {
                    $res{$i}{$j}{$k} = 0;
                }
                else {
                    my $lst = $res{$i - 1}{$j - 1}{$k - 1};
                    if ($l1[$i] eq $l2[$j] && $l2[$j] eq $l3[$k]) {
                        $lst += 1;
                    }
                    $res{$i}{$j}{$k} = (sort {$b <=> $a} 
                        ($res{$i - 1}{$j}{$k}, $res{$i}{$j - 1}{$k}, $res{$i}{$j}{$k - 1}, 
                         $res{$i}{$j - 1}{$k - 1}, $res{$i - 1}{$j}{$k - 1}, 
                         $res{$i - 1}{$j - 1}{$k}, $lst))[0];
                }
            }
        }
    }

    # get the line numbers (indexes) of the lines in the subsequence
    my ($i, $j, $k, @idx1, @idx2, @idx3) = ($#l1, $#l2, $#l3, (), (), ());
    while ($i >= 0 && $j >= 0 && $k >= 0) {
        if ($l1[$i] eq $l2[$j] && $l2[$j] eq $l3[$k]) {
            push @idx1, $i;
            push @idx2, $j;
            push @idx3, $k;
            ($i, $j, $k) = ($i - 1, $j - 1, $k - 1);
        }
        else {
            my $break = 0;
            for my $x (reverse 0..1) {
                for my $y (reverse 0..1) {
                    for my $z (reverse 0..1) {
                        if ($res{$i}{$j}{$k} == $res{$i - $x}{$j - $y}{$k - $z}) {
                            ($i, $j, $k) = ($i - $x, $j - $y, $k - $z);
                            $break = 1;
                            last;
                        }
                    }
                    last if $break;
                }
                last if $break;
            }
        }
    }

    # output format: join the index in ascending order with a space
    #                join the result strings with #
    return join "#", (join(" ", reverse @idx1), join(" ", reverse @idx2), join(" ", reverse @idx3));
}

# usage: merge_files (base_filepath, f1_filepath, f2_filepath)
# description: three-way merge
# output: the success code and the lines of the merged content
sub merge_files {
    my ($base_filepath, $f1_filepath, $f2_filepath) = @_;
    my ($idx1_str, $idx2_str, $idx3_str) = 
        split "#", lcs($base_filepath, $f1_filepath, $f2_filepath);

    # index of lcs lines in three files
    my @idx1 = split " ", $idx1_str;
    my @idx2 = split " ", $idx2_str;
    my @idx3 = split " ", $idx3_str;

    # lines of base file, lines of file 1, lines of file 2
    my @lb = get_file_content($base_filepath);
    my @l1 = get_file_content($f1_filepath);
    my @l2 = get_file_content($f2_filepath);

    # cursors
    my ($crsr1, $crsr2, $crsr3) = (-1, -1, -1);

    # add end of file
    push @idx1, $#lb;
    push @idx2, $#l1;
    push @idx3, $#l2;

    # merge result
    my @merge_res;

    for my $i (0..$#idx1) {

        # three files identical
        if ($idx1[$i] - $crsr1 == 1 && $idx2[$i] - $crsr2 == 1 && 
            $idx3[$i] - $crsr3 == 1 && $i != $#idx1) {
            push @merge_res, @lb[$idx1[$i]];
        }

        # base file lines deleted
        elsif ($idx2[$i] - $crsr2 == 1 && $idx3[$i] - $crsr3 == 1 && $i != $#idx1) {
            push @merge_res, @l1[$idx2[$i]];
        }
        else {

            # diff info
            my ($base_f1_diff, $base_f2_diff, $f1_f2_diff) = (0, 0, 0);
            if ($idx1[$i] - $crsr1 != $idx2[$i] - $crsr2) {
                $base_f1_diff = 1 ;
            }
            else {
                for my $j (1..($idx1[$i] - $crsr1)) {
                    $base_f1_diff = 1 if $lb[$crsr1 + $j] ne $l1[$crsr2 + $j];
                }
            }
            if ($idx1[$i] - $crsr1 != $idx3[$i] - $crsr3) {
                $base_f2_diff = 1 ;
            }
            else {
                for my $j (1..($idx1[$i] - $crsr1)) {
                    $base_f2_diff = 1 if $lb[$crsr1 + $j] ne $l2[$crsr3 + $j];
                }
            }
            if ($idx2[$i] - $crsr2 != $idx3[$i] - $crsr3) {
                $f1_f2_diff = 1 ;
            }
            else {
                for my $j (1..($idx2[$i] - $crsr2)) {
                    $f1_f2_diff = 1 if $l1[$crsr2 + $j] ne $l2[$crsr3 + $j];
                }
            }
            return 0 if $base_f1_diff && $base_f2_diff && $f1_f2_diff;

            # add line if not conflict
            if ($base_f1_diff) {
                push @merge_res, $l1[$crsr2 + $_] foreach (1..($idx2[$i] - $crsr2));
            }
            else {
                push @merge_res, $l2[$crsr3 + $_] foreach (1..($idx3[$i] - $crsr3));
            }
        }
        ($crsr1, $crsr2, $crsr3) = ($idx1[$i], $idx2[$i], $idx3[$i]);
    }
    return (1, @merge_res);
}

# usage: write_file (filepath, lines)
# description: write lines to filepath
# output: none
sub write_file {
    my ($filepath, @lines) = @_;
    open F, '>', $filepath;
    print F $_ foreach (@lines);
    close F;
}

# usage: cp(src, dst)
# src: file path
# dst: file path or folder path
# description: copy file to dst if src exists, otherwise delete the dst file
# output: none
sub cp {
    my ($src, $dst) = @_;
    if (-f $src) {
        copy($src, $dst) or die_error $INTERNAL_ERROR;
    }
    else {
        if (-d $dst) {
            unlink catfile($dst, $src);
        }
        else {
            unlink $dst;
        }
    }
}

sub diff {
    my ($base_filepath, $filepath) = @_;
    my ($idx1_str, $idx2_str, $idx3_str) = 
        split "#", lcs($base_filepath, $base_filepath, $filepath);

    # index of lcs lines in three files
    my @idx1 = split " ", $idx1_str;
    my @idx2 = split " ", $idx2_str;
    my @idx3 = split " ", $idx3_str;

    # lines of base file, lines of file 1, lines of file 2
    my @lb = get_file_content($base_filepath);
    my @l1 = get_file_content($base_filepath);
    my @l2 = get_file_content($filepath);
    push @lb, "";
    push @l1, "";
    push @l2, "";

    # cursors
    my ($crsr1, $crsr2, $crsr3) = (-1, -1, -1);

    # add end of file
    push @idx1, $#lb;
    push @idx2, $#l1;
    push @idx3, $#l2;

    # merge result
    my @merge_res;

    for my $i (0..$#idx1) {

        # three files identical
        if ($idx1[$i] - $crsr1 == 1 && $idx2[$i] - $crsr2 == 1 && 
            $idx3[$i] - $crsr3 == 1 && $i != $#idx1) {
        }

        # base file lines deleted
        elsif ($idx2[$i] - $crsr2 == 1 && $idx3[$i] - $crsr3 == 1 && $i != $#idx1) {
            push @merge_res, $crsr1 . " - " . $idx1[$i] - $crsr1 - 1 . "\n";
        }
        else {

            # diff info
            my ($base_f1_diff, $base_f2_diff, $f1_f2_diff) = (0, 0, 0);
            if ($idx1[$i] - $crsr1 != $idx2[$i] - $crsr2) {
                $base_f1_diff = 1 ;
            }
            else {
                for my $j (1..($idx1[$i] - $crsr1)) {
                    $base_f1_diff = 1 if $lb[$crsr1 + $j] ne $l1[$crsr2 + $j];
                }
            }
            if ($idx1[$i] - $crsr1 != $idx3[$i] - $crsr3) {
                $base_f2_diff = 1 ;
            }
            else {
                for my $j (1..($idx1[$i] - $crsr1)) {
                    $base_f2_diff = 1 if $lb[$crsr1 + $j] ne $l2[$crsr3 + $j];
                }
            }
            if ($idx2[$i] - $crsr2 != $idx3[$i] - $crsr3) {
                $f1_f2_diff = 1 ;
            }
            else {
                for my $j (1..($idx2[$i] - $crsr2)) {
                    $f1_f2_diff = 1 if $l1[$crsr2 + $j] ne $l2[$crsr3 + $j];
                }
            }
            return 0 if $base_f1_diff && $base_f2_diff && $f1_f2_diff;

            # add line if not conflict
            if ($base_f1_diff) {
                for my $idx (1..($idx2[$i] - $crsr2 - 1)) {
                    my $no_new_line = "<<<no_new_line>>>";
                    $no_new_line = "" if grep /\n$/, $l1[$crsr2 + $idx];
                    chomp $l1[$crsr2 + $idx];
                    push @merge_res, $crsr1 . " + " . $l1[$crsr2 + $idx] . $no_new_line . "\n";
                }
                push @merge_res, $crsr1 . " - " . ($idx1[$i] - $crsr1 - 1) . "\n"
                    if $idx1[$i] - $crsr1 - 1 > 0;
            }
            else {
                for my $idx (1..($idx3[$i] - $crsr3 - 1)) {
                    my $no_new_line = "<<<no_new_line>>>";
                    $no_new_line = "" if grep /\n$/, $l2[$crsr3 + $idx];
                    chomp $l2[$crsr3 + $idx];
                    push @merge_res, $crsr1 . " + " . $l2[$crsr3 + $idx] . $no_new_line . "\n";
                }
                push @merge_res, $crsr1 . " - " . ($idx1[$i] - $crsr1 - 1) . "\n" 
                    if $idx1[$i] - $crsr1 - 1 > 0;
            }
        }
        ($crsr1, $crsr2, $crsr3) = ($idx1[$i], $idx2[$i], $idx3[$i]);
    }
    return (1, @merge_res);
}

sub patch {
    my ($diff_filepath, @lines) = @_;
    my @diff = get_file_content($diff_filepath);
    my @res;
    my $crsr = -1;
    for my $diff_line (@diff) {
        my ($idx, $op, $content) = split " ", $diff_line, 3;
        chomp $content;
        if ($crsr != $idx) {
            push @res, $lines[$_] foreach (($crsr + 1)..$idx);
            $crsr = $idx;
        }
        if ($op eq "+") {
            my $no_new_line = grep /<<<no_new_line>>>$/, $content;
            $content =~ s/<<<no_new_line>>>$//;
            push @res, $content;
            if (!$no_new_line) {
                push @res, "\n";
            }
        }
        else {
            $crsr += $content;
        }
    }
    if ($crsr < $#lines) {
        push @res, $lines[$_] foreach (($crsr + 1)..$#lines);
    }
    return @res;
}
