package DB;

$header = '$Header: //rlischner/local_user/lisch/src/perlprof/RCS/perldb.pl,v 1.1 1991/07/19 16:25:56 lisch Exp $';
#
# This file is automatically included if you do perl -m.
# It's probably not useful to include this yourself.
#
# Keep track of CPU time, elapsed time, and execution count for
# each source line and for each subroutine.  When the script finishes,
# dump all the numbers to a file, "perlmon.out".  A different
# filename can be specified by setting the environment variable,
# PERLMON.  A different version of this file can be substituted
# by setting the environment variable, PERLPROF.
#
# DB is called for each executable line.  sub is called for each
# subroutine call.
#
# Try to collect the information with a minimum of overhead; after all,
# DB'DB is called for every executable line.
#
# $Log: perldb.pl,v $
# Revision 1.1  1991/07/19  16:25:56  lisch
# Initial revision
#

sub DB {
    ($user, $system) = times;
    $time = time;

    ($package, $filename, $line) = caller;
    if ($filename ne '(eval)') {
	$n = $filename . "\0" . $line;
	++$count{$n};
	$cpu{$n} += ($user-$line_user) + ($system-$line_system);
	$clock{$n} += $time - $line_time;
	($line_time, $line_user, $line_system) = ($time, $user, $system);
    }
}

sub sub {
    ($sub_user, $sub_system) = times;
    $sub_time = time;
    if (wantarray) {
	@i = &$sub;
    } else {
	$i = &$sub;
    }
    ($user, $system) = times;
    $time = time;

    ++$sub_count{$sub};
    $sub_cpu{$sub} += ($user-$sub_user) + ($system-$sub_system);
    $sub_time{$sub} += ($time - $sub_time);

    if (wantarray) {
	@i;
    } else {
	$i;
    }
}

# Print the profile data in raw form.  This is called exactly once
# at then end of execution.  The format of the data is explained
# in pprof.perl.
sub profile
{
    ($total_user, $total_system) = times;
    $end = time;

    $perlmon = $ENV{'PERMON'} || "perlmon.out";
    $cpu = ($total_user - $start_user) + ($total_system - $start_system);
    $time = $end - $start;

    open(OUT, ">$perlmon") || die "$0: cannot write $perlmon: $!\n";

    print OUT $cpu, "\n", $time, "\n";
    while (($k, $v) = each(%sub_count)) {
	print OUT "S ", $k, " ", $sub_cpu{$k}, " ", $sub_time{$k}, " ", $v,"\n";
    }
    $nfiles = 0;
    while (($k, $v) = each(%count)) {
	($filename, $line) = split("\0", $k);
	if (! ($n = $filenames{$filename})) {
	    $n = $filenames{$filename} = ++$nfiles;
	    print OUT "F ", $n, " ", $filename, "\n";
	}
	print OUT $line, " ", $n, " ", $v, " ", $cpu{$k}, " ", $clock{$k}, "\n";
    }
    close(OUT);
    print STDERR "wrote raw profile measurements to $perlmon\n";
}

$nfiles = $[-1;
$trace = 1;			# so it stops on every executable statement

if (-f '.perlprof') {
    do './.perlprof';
}
elsif (-f "$ENV{'LOGDIR'}/.perlprof") {
    do "$ENV{'LOGDIR'}/.perlprof";
}
elsif (-f "$ENV{'HOME'}/.perlprof") {
    do "$ENV{'HOME'}/.perlprof";
}

# save the starting times
($start_user, $start_system) = times;
$start = time;
($line_user, $line_system, $line_time) = ($start_user, $start_system, $start);

1;
