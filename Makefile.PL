use 5.008005;
use ExtUtils::MakeMaker 7.12; # for XSMULTI option


WriteMakefile(
  NAME           => 'GoatKCD',
  VERSION_FROM   => 'lib/GoatKCD/Extractor/OpenCV.pm',
  PREREQ_PM      => {
	'ExtUtils::MakeMaker' => '7.12',
	'LWP::UserAgent'=>0,
    'Try::Tiny'=>0,
    'Image::Magick'=>0,
    'Web::Scraper'=>0,
	'URI'=>0,
    'Data::Dumper'=>0,
    'Getopt::Long'=>0,
    'HTTP::Message'=>0,
    'List::Util'=> 1.47,
	'Moose'=>0,
	'Moose::Role'=>0,
	'MooseX::MethodAttributes'=>0,
	'Time::HiRes'=>0,
	'FindBin'=>0,
	'File::Copy'=>0,
	'Test::More'=>0,
	'Term::ReadLine'=>0,
  },
  ABSTRACT_FROM  => 'lib/GoatKCD/Extractor/OpenCV.pm',
  AUTHOR         => 'Fatty Crabcakes',
  CCFLAGS        => '-fPIC -lopencv_imgproc -lopencv_core -lopencv_highgui -Doff64_t=__off64_t -pthread -lopencv_imgcodecs',
  LIBS			=> ' -lopencv_imgproc -lopencv_core -lopencv_highgui',
  OPTIMIZE       => '-O3',
  LICENSE        => 'unlicensed',
  XSMULTI        => 1,
  TYPEMAPS		=>["lib/typemap"],
  "EXE_FILES"	=>["goatify"],
  dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
);
