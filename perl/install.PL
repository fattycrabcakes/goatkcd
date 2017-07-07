#!/usr/bin/env perl

use feature qw(say);
use FindBin;
use File::Copy;


if (-w "/usr/share") {
	mkdir("/usr/share/goatkcd");
	copy("$FindBin::Bin/../assets/hello.jpg","/usr/share/goatkcd/hello.jpg");
	copy("$FindBin::Bin/../assets/error.png","/usr/share/goatkcd/error.png");
}


