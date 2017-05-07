#!/usr/bin/env perl

use feature qw(say);
use FindBin;
use File::Copy;

mkdir("/usr/share/goatkcd");
say "WHAT $FindBin::Bin";
say "$FindBin::Bin/assets/testcase_1.png";
say copy("$FindBin::Bin/assets/hello.jpg","/usr/share/goatkcd/hello.jpg");
copy("$FindBin::Bin/assets/testcase_1.png","/usr/share/goatkcd/test.jpg");


