package GoatKCD::ExtractorC;

BEGIN {
	print STDERR "YAMS\n";
};

use 5.022001;
use strict;
use warnings;
our $VERSION="6.6.6";

require XSLoader;
XSLoader::load('ExtractorC', $VERSION);

1;
