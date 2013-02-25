use strict;
use Test::More;
use Test::Requires {
    'Capture::Tiny' => '0.21'
};

my $stdout = Capture::Tiny::tee_stdout {
    my $pid = fork();
    if ( $pid == 0 ) {
        exec $^X, './ikachaos.pl','--dry-run','--', $^X, '-e', 'print "foobar";exit(1)';
        exit;
    }
    waitpid($pid,0);
};

like($stdout, qr/foobar/);

done_testing;
