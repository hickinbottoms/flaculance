#!/usr/bin/perl

# Script (C) Stuart Hickinbottom 2005 (stuart@hickinbottom.demon.co.uk).
# You are free to use and modify this script as you like, but please leave in
# my credit. Thank you.

# FLACulance - script to find all FLAC files, then compute and store album and
# track "Replay Gain" (http://en.wikipedia.org/wiki/Replay_Gain) tags for
# each album.
# 
# The assumption here is that there is one album per directory (ie you don't
# mix FLAC files from multiple albums in the same directory).

# Pick up more errors
use warnings;
use strict;

# Import some facilities
use Getopt::Long;
use Pod::Usage;
use File::Find;

# Exit more cleanly from signals (ensure destructors/atexits called)
use sigtrap qw(die INT QUIT);
use sigtrap qw(die untrapped normal-signals stack-trace any error-signals);

# Global definitions - change these if you like.
use constant METAFLAC_COMMAND => "metaflac --add-replay-gain %s";
use constant MUSIC_DIR        => "/mnt/music";
use constant EXT_FLAC         => "flac";

# Prototype definitions
sub find_dir();
sub process_flac($);

# Process command-line arguments
my $verbose = "";
my $dir = MUSIC_DIR;
GetOptions("verbose" => \$verbose,
			"directory=s" => \$dir,
			"version" => sub { versionMessage(); },
			"help|?" => sub { pod2usage(-verbose => 3) })
	or die "Failed to understand command options";

print "Processing directory tree: $dir\n" if $verbose;

# Recurse through directories. We process all FLACs in each.
our %flac_dirs;
find { wanted => \&process_flac, follow => 0 }, $dir;
my $total_dirs = scalar(keys %flac_dirs);
my $success_dirs = 0;
print "Found $total_dirs album(s). Beginning processing\n";

# Go through each directory we found FLAC files in.
for my $process_dir (keys %flac_dirs) {
	print "Applying Replay Gain in: $process_dir\n";

	# Build up an arguments list for the metaflac command.
	my $file_list = "";
	for my $file (@{$flac_dirs{$process_dir}}) {
		$file_list = $file_list . " \"" . $file . "\"";
	}

	# Build the command
	my $metaflac_command = sprintf METAFLAC_COMMAND, $file_list;

	# Try to run the command. If this does't work tell the user, but
	# carry on processing.
	chdir $process_dir;
	unless (system($metaflac_command) == 0) {
		print STDERR "WARNING: applying tags failed in: $process_dir\n";
	} else {
		$success_dirs++;
	}
}

print "Successfully processed $success_dirs out of $total_dirs album(s)\n";

# We've finished, so exit.
exit 0;

# Process a single directory. We process all FLACs and MP3s in each
# directory in turn.
sub process_flac($)
{
	my $file = $_;
	my $dir = $File::Find::dir;
	our %flac_dirs;

	# Match FLAC files
	my $tag_regexp = "\." . EXT_FLAC;
	if (-f $file && ($file =~ m/$tag_regexp$/)) {
		$file =~ s/\"/\\\"/g;

		# Add FLAC filename to an array, hashed by the directory
		# containing that file.
		print "Processing file $file (in $dir)\n" if $verbose;

#		if (!exists($flac_dirs{$dir})) { $flac_dirs{$dir} = (); }
		push @{$flac_dirs{$dir}}, $file;
	}
}

# The help text
__END__

=head1 NAME

FLACulance.pl [options]

=head1 SYNOPSIS

Script to find all FLAC files, then compute and store album and track
"Replay Gain" (http://en.wikipedia.org/wiki/Replay_Gain) tags for each album.

=head1 OPTIONS

=over 15

=item --help

Show this help description

=item --verbose

Output far more progress messages during processing - useful when trying to
track down problems

=item --directory

Override default location of input directory. If no directory is specified then
a default music directory will be used instead

=back

=head1 EXAMPLE

FLACulance.pl --verbose --directory="c:\my music"

=cut
