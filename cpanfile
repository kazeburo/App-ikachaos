requires 'perl'           => '5.008005';
requires 'Getopt::Long'   => '0';
requires 'Pod::Usage'     => '0';
requires 'File::Which'    => '1.09';
requires 'Log::Minimal'   => '0.14';
requires 'IO::Select'     => '1.17';
requires 'Proc::Wait3'    => '0.03';
requires 'LWP::UserAgent' => '6.02';
requires 'HTTP::Message'  => '6.04'; 

on 'test' => sub {
   requires 'Test::More'     => '0.98';
   requires 'Test::Requires' => '0.06';
};
