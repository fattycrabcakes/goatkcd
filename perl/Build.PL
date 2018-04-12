use strict;
use warnings FATAL => 'all';
use Module::Build;

my $builder = Module::Build->new(
	module_name    => 'GoatKCD',
   	license        => 'perl',
   	dist_author    => ['Fatty Crabcakes'],
	dist_version_from => "lib/GoatKCD/Extractor.pm",
   	needs_compiler => 1,
   	configure_requires => {
   		'Config::AutoConf'   => '0.14',
   		'ExtUtils::CBuilder' => '0.27',
   		'ExtUtils::LibBuilder' => '0.01',
   		'Module::Build'      => '0.3603',
   	},
	requires => {
    	'LWP::Curl'=>0,
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
	'Image::ExifTool'=>0,
	},

	libdir   => "./lib",
    extra_compiler_flags => '-I/usr/local/include -O4 -g', 
	extra_linker_flags=>[qw(-lopencv_imgproc -lopencv_core -lopencv_highgui)],

	config=>{cc => 'gcc', ld => 'gcc'},
    include_dirs => '../src/',
    c_source     => ['../src/'],
	scripts => ["scripts/goatify"],
	install_path=>{"asset"=>"/usr/share/goatkcd","script"=>"/usr/local/bin"},
	asset_files=>{"../assets/hello.jpg"=>"asset/hello.jpg"},
);
$builder->add_build_element("asset");
$builder->create_build_script();

