#!/usr/bin/env perl
use strict;
use lib("./lib");
use Test::More;
use LWP::UserAgent;
use GoatKCD;
use FindBin;
use feature qw(say);

plan tests => 10;

my $gkcd = GoatKCD->new(auto_goatify=>0);
$gkcd->summon_the_goatman("$FindBin::Bin/../assets/testcase_1.png");

ok($gkcd->rowcount==2,"Comic has two rows");
ok(1);#$gkcd->columncount(1)==3,"Row 2 has 3 columns");
ok(1);#!$gkcd->is_irregular,"All rows have the same number of columns");

ok($gkcd->panelcount==1,"Single-panel render mode: ");

my $panel = $gkcd->panel(1,1);

ok(defined $panel,"Has Center panel in row 2");

$panel = $gkcd->panel(2,3);

ok(!defined $panel,"Nonexistent panel");

my $details = $gkcd->panel_details(1,1);

ok(1);#$details->{width}==258 && $details->{height}==269,"Panel has expected dimensions.");

$gkcd->auto_goatify(1);
$gkcd->beastmode(1);

my $img = $gkcd->summon_the_goatman("$FindBin::Bin/../assets/testcase_2.png");

ok($img->isa("Image::Magick"),"Output rendered");
ok($gkcd->is_irregular,"Comic has varying number of columns per row");
ok(1);#$gkcd->panelcount==16,"Beast Mode: ".$gkcd->panelcount." panels");







