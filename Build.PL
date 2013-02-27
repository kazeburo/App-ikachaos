use strict;
use warnings;
use Module::Build;
use Module::CPANfile;

my $file = Module::CPANfile->load("cpanfile");
my $prereq = $file->prereq_specs;

my $build = Module::Build->new(
    license              => 'perl',
    dynamic_config       => 0,
    configure_requires   => {
        'Module::Build' => '0.38',
        'Module::CPANfile' => '0.9010',
    },
    build_requires       => $prereq->{test}->{requires},
    requires             => $prereq->{runtime}->{requires},
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
