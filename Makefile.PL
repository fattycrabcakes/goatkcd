use 5.008005;
use ExtUtils::MakeMaker 7.12; # for XSMULTI option
use File::ShareDir::Install;
use Module::Build;

install_share => 'share';


WriteMakefile(
  NAME           => 'GoatKCD',
  VERSION_FROM   => 'lib/GoatKCD/Extractor/OpenCV.pm',
  PREREQ_PM      => {
	'ExtUtils::MakeMaker' => '7.12',
	'LWP::UserAgent'=>0,
    'Inline::Python'=>0,
    'Try::Tiny'=>0,
    'Image::Magick'=>0,
    'Web::Scraper'=>0,
    'Data::Dumper'=>0,
    'Getopt::Long'=>0,
    'HTTP::Message'=>0,
    'Inline::CPP'=>0,
    'List::Util'=> 1.47,
  },
  ABSTRACT_FROM  => 'lib/GoatKCD/Extractor/OpenCV.pm',
  AUTHOR         => 'Fatty Crabcakes',
  CCFLAGS        => '-fPIC -lopencv_imgproc -lopencv_core -lopencv_highgui -Doff64_t=__off64_t -pthread -lopencv_imgcodecs',
  LIBS			=> ' -lopencv_imgproc -lopencv_core -lopencv_highgui',
  OPTIMIZE       => '-O3',
  LICENSE        => 'unlicensed',
  XSMULTI        => 1,
  TYPEMAPS		=>["lib/typemap"],
  dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
);

package MY;
sub postamble {
	#print STDERR "#YAMS";
}
