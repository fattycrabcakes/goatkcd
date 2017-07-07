use strict;
use warnings FATAL => 'all';
use Module::Build;

my $builder = Module::Build->new(
	module_name    => 'GoatKCD',
   	license        => 'perl',
   	dist_author    => ['Fatty Crabcakes'],
   	needs_compiler => 1,
   	configure_requires => {
   		'Config::AutoConf'   => '0.14',
   		'ExtUtils::CBuilder' => '0.27',
   		'ExtUtils::LibBuilder' => '0.01',
   		'Module::Build'      => '0.3603',
   	},
	requires => {
		'ExtUtils::MakeMaker' => '7.12',
    	'LWP::UserAgent'=>0,
    	'Image::Magick'=>0,
    	'Web::Scraper'=>0,
    	'URI'=>0,
    	'HTTP::Message'=>0,
    	'List::Util'=> 1.47,
    	'Moo'=>0,
    	'Mouse'=>0,
    	'Moose'=>0,
    	'Moose::Role'=>0,
    	'MooseX::MethodAttributes'=>0,
    	'Time::HiRes'=>0,
    	'File::Copy'=>0,
    	'Test::More'=>0,
    	'Term::ReadLine'=>0,
    	'JSON::XS'=>0,
    	'File::Type'=>0,
	},
	libdir   => "./lib",
    extra_compiler_flags => '-I/usr/local/include', # We're going to assume everyone is at least that modern
	extra_linker_flags=>[qw(-lopencv_imgproc -lopencv_core -lopencv_highgui)],
	config=>{cc => 'gcc', ld => 'gcc'},
    include_dirs => '../src/',
    c_source     => ['../src/goatkcd_extractor.c'],
);

$builder->create_build_script();

