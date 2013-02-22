use strict;
use warnings;
use Module::Build;

my $build = Module::Build->new(
    license              => 'perl',
    dynamic_config       => 0,

    build_requires       => {
        'Test::More' => '0.98',
        'Test::Requires' => 0,
    },
    configure_requires   => { 'Module::Build' => '0.38' },
    requires             => {
        perl => '5.008005',
        'Getopt::Long'                        => '0',
        'Pod::Usage'                          => '0',
        'File::Which'                         => '1.09',
        'Log::Minimal'                        => '0.14',
        'IO::Select'                          => '1.17',
        'Proc::Wait3'                         => '0.03',
        'LWP::UserAgent'                      => '6.02',
        'HTTP::Message'                       => '6.04' 
    },

    no_index    => { 'directory' => [ 'inc' ] },
    name        => 'App-ikachaos',
    module_name => 'App::ikachaos',

    script_files => ['ikachaos.pl'],

    test_files => (-d '.git' || $ENV{RELEASE_TESTING}) ? 't/ xt/' : 't/',
    recursive_test_files => 1,
   
    create_readme  => 1,
    create_license => 1,
);
$build->create_build_script();
