use Module::Build;

my $build = Module::Build->new(
	module_name => 'GoatKCD',
	dist_name=>"Auto Goatkcd",
	license  => 'perl',
	requires => {
		'LWP::UserAgent'=>0,
		'Inline::Python'=>0,
		'Try::Tiny'=>0,
		'Image::Magick'=>0,
		'Web::Scraper'=>0,
		'Data::Dumper'=>0,
		'Getopt::Long'=>0,
		'HTTP::Message'=>0,
	},
);
$build->dispatch("installdeps");
$build->dispatch("test",verbose=>1);
