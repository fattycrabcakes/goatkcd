use 5.008005;
use ExtUtils::MakeMaker 7.12; # for XSMULTI option
use FindBin;


WriteMakefile(
  NAME           => 'GoatKCD',
  VERSION_FROM   => 'lib/GoatKCD/Extractor.pm',
  PREREQ_PM      => {
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
  ABSTRACT_FROM  => 'lib/GoatKCD/Extractor.pm',
  AUTHOR         => 'Fatty Crabcakes',
  CCFLAGS        => '-I./src -fPIC -lopencv_imgproc -lopencv_core -lopencv_highgui -Doff64_t=__off64_t -pthread -lopencv_imgcodecs',
  LIBS			=> ' -lopencv_imgproc -lopencv_core -lopencv_highgui',
  OPTIMIZE       => '-O3',
  LICENSE        => 'unlicensed',
  XSMULTI        => 1,
  TYPEMAPS		=>["src/typemap"],
  "EXE_FILES"	=>["scripts/goatify"],
  "INC"			=> "-I$FindBin::Bin/src",
  dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
);
