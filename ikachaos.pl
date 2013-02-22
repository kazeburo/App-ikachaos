#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long qw/:config posix_default no_ignore_case bundling/;
use Pod::Usage qw/pod2usage/;
use File::Which;
use Log::Minimal;
use IO::Select;
use Proc::Wait3;
use LWP::UserAgent;
use HTTP::Request::Common;

my $check_interval = 5;
my $retry_interval = 1;
my $notification_interval = 30;
my $max_check_attempts = 3;
my $command_timeout = 30;

GetOptions(
    'h|help' => \my $help,
    'api-url=s'  => \my $api_url,
    'channel=s@' => \my @channel,
    'check-interval=i' => \$check_interval,
    'retry-interval=i' => \$retry_interval,
    'notification-interval=i' => \$notification_interval,
    'max-check-attempts=i' => \$max_check_attempts,
) or pod2usage(1);

pod2usage(-verbose=>2,-exitval=>0) if $help;
my @cmd = @ARGV;
pod2usage(-verbose=>1,-exitval=>1) unless $api_url;
pod2usage(-verbose=>1,-exitval=>1) unless @channel;
pod2usage(-verbose=>1,-exitval=>1) unless @cmd;

my $check_interval_sec = $check_interval * 60;
my $retry_interval_sec = $retry_interval * 60;
my $notification_interval_sec = $notification_interval * 60;

my $stop = 1;
local $SIG{TERM} = $SIG{INT}  = sub { $stop = 0 };
my $next = time;
$next = $next - ( $next % $check_interval_sec) + $check_interval_sec + int(rand($check_interval_sec));; #next + random

my @status;
my $last_notify = 0;

while ( $stop ) {
    local $Log::Minimal::AUTODUMP = 1;
    my $current = time();
    my $next_interval = $check_interval_sec;
    if ( @status && is_error_status($status[0])) {
        $next_interval = $retry_interval_sec;
    }
    while ( $next < $current ) {
        $next = $next + $next_interval;
    }
    while ( $stop ) {
        last if time() >= $next;
        select undef, undef, undef, 0.1; ## no critic;
    }
    last if !$stop;
    $next = $next + $next_interval;
    debugf("exec command");
    my ($result, $exit_code);
    eval {
        ($result, $exit_code) = cap_cmd(\@cmd, $command_timeout);
    };
    if ($@) {
        $result = $@;
        $exit_code = 255;
    }
    $result = '-' if ! defined $result;
    debugf("command finished code:%s message:%s",$exit_code,$result);

    push @status, [$result,$exit_code];
    pop @status if @status > $max_check_attempts;
    
    my @errors = grep { is_error_status($_) } @status;
    if ( @errors == $max_check_attempts ) {
        # ikachan
        debugf("ERROR STATE: %s", @status);
        if ( time - $last_notify >= $notification_interval_sec   ) {
            $last_notify = time;
            my $message = sprintf '*ikachaos* Alerts: command is %s. %s / %s', code_to_text($exit_code), join(" ", @cmd), $result;
            my $ua = LWP::UserAgent->new;
            for my $channel ( @channel ) {
                debugf("SEND NOTIFY to channel:%s message:%s", $channel, $message);
                my $res = $ua->request(POST $api_url,
                  [ "channel"=>$channel,"message"=>$message]);
                warnf("failed to sending notify: %s", $res->status_line) unless $res->is_success;
            }
        }
    }
    # next..
}

sub is_error_status {
    my $status = shift;
    $status->[1] != 0;
}

sub code_to_text {
    my $code = shift;
    if ( $code == 0 ) {
        return "OK";
    }
    elsif ( $code == 1 ) {
        return "WARNING";
    }
    elsif ( $code == 2 ) {
        return "CRITICAL";
    }
    return "UNKNOWN";
}

sub cap_cmd {
    my ($cmdref, $timeout) = @_;

    my $bash = which('bash');
    my @cmd = @$cmdref;;
    if ( @cmd == 1 && $bash ) {
        @cmd = ($bash,'-c', $cmd[0]);
    }

    local $Log::Minimal::AUTODUMP = 1;
    my $timeout_at = $timeout + time;
    my $s = IO::Select->new();
    pipe my $logrh, my $logwh
        or die "Died: failed to create pipe:$!";
    my $pid = fork;
    if ( ! defined $pid ) {
        die "Died: fork failed: $!";
    } 

    elsif ( $pid == 0 ) {
        #child
        close $logrh;
        open STDOUT, '>&', $logwh
            or die "Died: failed to redirect STDOUT";
        close $logwh;
        exec @cmd;
        exit(255);
    }
    close $logwh;
    my $result;
    $s->add($logrh);
    my $haserror=0;
    while ( 1 ) {
        my @ready = $s->can_read(1);
        if ( time > $timeout_at ) {
            $haserror = "exec timeout";
            last;
        }
        next unless @ready;
        my $ret = sysread($logrh, my $buf, 65536);
        if ( ! defined $ret ) {
            $haserror = "failed to read pipe: $!";
            last;
        }
        last if $ret == 0;
        $result .= $buf;
    }
    if ( $haserror ) {
        kill 'TERM', $pid;
    }
    close $logrh;
    my @wait = wait3(1); #block;
    if ( $haserror ) {
        return ($haserror, 255);
    }
    my $exit_code = $wait[1];
    $exit_code = $exit_code >> 8;
    return ($result, $exit_code);
}

__END__

=encoding utf8

=head1 NAME

ikachaos.pl - tinytiny monitoring tool

=head1 SYNOPSIS

  $ ikachaos.pl -h

=head1 DESCRIPTION

ikachaos.pl is tinytiny monitoring tool. exec a command and check exit code. If detects error status, send notify via <ikachan>

=head1 ARGUMENTS

=over 4

=item -h, --help

Display help message

=item --api-url: URL

API endpoint of ikachan

=item --channel: Strings

channel names to send notify

=item --check-interval: Integer(minute)

minute between regularly scheduled checks. default 5min

=item --retry-interval: Integer(minute)

minute to wait before scheduling a re-check. default 1min

=item --notification-interval: Integer(minute)

minute to wait before re-sending notify. default 30min

=item --max-check-attempts: Integer 

the number of times that this system retry the host check command

=item COMMAND

service check command.
If exit code isn't "0", ikachaos treat it as failed. makes alert level with exit code, for example 0 = OK, 
1 = WARNING, 2 = CRITICAL and other = UNKNOWN. This behavior is same as Nagios

=back

=head1 SEE ALSO

<ikachan>

=head1 AUTHOR

Masahiro Nagano E<lt>kazeburo@gmail.comE<gt>

=head1 LICENSE

Copyright (C) Masahiro Nagano

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

