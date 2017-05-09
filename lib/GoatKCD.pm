#5!/usr/bin/env perl

package GoatKCD;

use strict;
use GoatKCD::Extractor;
use GoatKCD::Extractor::OpenCV;
use LWP::UserAgent;
use HTTP::Message;
use Image::Magick;
use URI;
use Web::Scraper;
use Data::Dumper;
use Try::Tiny;
use List::Util;
use Getopt::Long;
use Moose;
use Time::HiRes;
use Web::Scraper;
use feature qw(say);

our $VERSION = "1.0.0";
$Data::Dumper::Indent = 0;
$Data::Dumper::Terse=1;

has 'beastmode'=>(is=>'rw',isa=>'Bool',default=>sub { 0; });
has 'tmpfile'=>(is=>'rw',isa=>'Str',default=>sub { sprintf("%d-%d.png",$$,time()); });
has 'debug'=>(is=>'rw',isa=>'Int',default=>sub { 0; });
has 'canvas'=>(is=>'rw',isa=>'Image::Magick');
has 'rows'=>(is=>'rw',isa=>'Any',default=>sub { []; });
has 'stinger'=>(is=>'rw',isa=>'Image::Magick',default=>sub {__PACKAGE__->load_img("/usr/share/goatkcd/hello.jpg");});
has 'pad_by'=>(is=>'rw',isa=>'Int',default=> sub { 20; });
has tmpdir=>(is=>'rw',isa=>'Str',default=>sub { "/tmp/"; });
has processor=>(is=>'rw',isa=>'GoatKCD::Extractor',default=>sub {GoatKCD::Extractor->new(parent=>shift);});
has auto_goatify=>(is=>'rw',isa=>'Str',default=>sub { 1; });
has maxheight=>(is=>'rw',isa=>'Int',default=>sub { 640; });

sub summon_the_goatman {
	my ($self,$path) = @_;

	$self->reset();
	my $canvas = $self->load_canvas($path);

	my $rows;
	my $y_offset = 0;

	$rows = $self->extract_rows($canvas,1);
	return if (!defined $rows);

	$self->log("Rows from extractor:",$rows);
	$self->rows($rows);
	
	if (scalar(@$rows)>1) {
		
		my $average_columns = (List::Util::sum map {scalar(@$_)} @$rows)/scalar(@$rows);
	
		my $bottom_edge = $canvas->Get("height");
		if ($self->average_columns>1) {
			my $rowcount = scalar(@$rows);

			# Each row may not have identical panel count/dimension. Process each one indivually.
			ROWLOOP: for (my $i=scalar(@$rows)-1;$i>=0;$i--) {
				my $last_row = $rows->[$i]->[0];
				my $nexttolast_row = $rows->[$i-1]->[0];

				if ($i<1) {
					$y_offset = 0;
				} else {
					$y_offset = $nexttolast_row->[3] + int(($last_row->[1]-$nexttolast_row->[3])/2);
				}
				my $row_height = $last_row->[3] - $last_row->[1];
				my $bottom_padding = $bottom_edge - ($y_offset+$row_height);

				my $canvas_tmp = $canvas->Clone();
				$canvas_tmp->Crop(width=>$canvas->Get("width"),height=>$row_height+$bottom_padding,x=>0,y=>$y_offset);
				$bottom_edge = $y_offset;

				my ($just_this_row) = $self->extract_rows($canvas_tmp);
				if ($just_this_row) {
					foreach my $column (@$just_this_row) {
						$column->[1]+=$y_offset;
						$column->[3]+=$y_offset;
					}
					$rows->[$i] = $just_this_row;
				}
			}
		}
	}
	#$self->cleartmp();

	# consolidate touching columns
	$self->log("Rows after row processing",$rows);

	$self->rows($rows);

	if ($self->auto_goatify) {
		return $self->goatify();
	} else {	
		return 1;
	}
}

sub goatify {
	my $self = shift;


	my @panels = $self->panels;
	my $canvas = $self->canvas->Clone();

	foreach my $rect (@panels) {
		my $stinger_tmp = $self->stinger->Clone();
		$stinger_tmp->Resize(geometry=>($rect->[2]-$rect->[0])."x".($rect->[3]-$rect->[1]."!"));
		$canvas->Composite(image=>$stinger_tmp,x=>$rect->[0],y=>$rect->[1],compose=>"Over",gravity=>"NorthWest");
		$canvas->Draw(primitive=>"rectangle",stroke=>"#000000",fill=>"#00000000",,strokewidth=>'2',points=>join(",",@$rect));
		undef $stinger_tmp;
	}

	# unpad canvas
	#$canvas->Crop(width=>$canvas->Get("width")-20,height=>$canvas->Get("height")-20,x=>10,y=>10);
	return $canvas;
}

sub panels {
	my ($self) = @_;

	my @rows = @{$self->rows};
	if ($self->beastmode) {
        return (map {@$_} @rows);

    } else {
        my $last_row = $rows[$#rows];
        return ($last_row->[-1]);
    }
}

sub panelcount {
	my $self = shift;

	my @panels = $self->panels;
	return scalar(@panels);
}

sub log {
	my ($self,$label,$stuff) = @_;

	if ($self->debug) {
		if (ref($stuff)) {
			$stuff = Dumper($stuff);
		}
		say STDERR "$label: ".$stuff;
	}
}

sub error_img {
	my $self = shift;

	my $img = Image::Magick->new();
	$img->ReadImage("/usr/share/goatkcd/error.png");
	
	return $img;
}

sub load_img {
	my ($self,$data) = @_;
	my $img = Image::Magick->new();

	say STDERR "LOADING $data\n";
	
	if (!defined $data) {
		return $self->error_img();
	} elsif (ref($data) eq "CODE") {
		$img->ReadImage($data->($self));
	} elsif (-f $data) {
		$img->ReadImage($data);
	} elsif ($data=~/^(?:http|\/\/)/i) {
		try {
			if ($data=~/^\/\//) {
				$data="http:";
			}
			my $ua = LWP::UserAgent->new();
			my $res = $ua->get($data);
			if (!$res->is_success) {
				say STDERR $res->status_line;
				return $self->error_img();
			} else {
				$img->BlobToImage($res->content);
			}

		} catch {
			say STDERR Dumper([@_]);
			return $self->error_img();
		}
	} else {
		$img->BlobToImage($data);
	}
	if (!$img) {
		$self->log("error",$@);
		return $self->error_img();
	}

	return $img;
}

sub load_canvas {
	my $self = shift;
	my $img = shift;

	my $tmp = $self->load_img($img);
	my ($w,$h) = $tmp->Get("width","height");

	if ($w>1000) {
		my $rsb = 1000/$w;
		$w*=$rsb;
		$h*=$rsb;
		$tmp->Resize(geometry=>"$w"."x".$h);
	}

	my $canvas = Image::Magick->new();
    $canvas->Set(size=>($w+$self->pad_by)."x".($h+$self->pad_by));
    $canvas->Read('xc:white');
    $canvas->Composite(image=>$tmp,compose=>"over",gravity=>"Center");
	$self->canvas($canvas);

	return $self->canvas;
}

sub mktmp {
	my ($self,$img) = @_;


	my $p = join("/",$self->tmpdir,$self->tmpfile);	

	$img->Write($p);
	return $p;
}


sub cleartmp {
	my $self = shift;

	unlink(join("/",$self->tmpdir,$self->tmpfile));
}

sub reset {
	my $self = shift;

	$self->rows([]);
}

sub extract_rows {
	my ($self,$img,$firstpass) = @_;

	my $rows=[];
	my $tmpf = $self->mktmp($img);
	$rows = $self->processor->extract($tmpf,$img,$firstpass);
	return wantarray?@$rows:$rows;
}

sub rowcount {
	my $self = shift;
	
	return scalar(@{$self->rows});
}

sub columncount {
	my ($self,$row) = @_;

	return scalar(@{$self->row($row)});
}



sub row {
	my ($self,$y) = @_;

	return $self->rows->[$y]||[];
}

	

sub panel {
	my ($self,$x,$y) = @_;

	return $self->row($y)->[$x];
}

sub panel_details {
	my ($self,$x,$y) =  @_;

	my $panel = $self->panel($x,$y);

	if (defined $panel) {
		return {x=>$panel->[0],y=>$panel->[1],width=>abs$panel->[2]-$panel->[0],height=>$panel->[3]-$panel->[1]};
	}
	return {x=>0,y=>0,width=>0,height=>0};
}

sub average_columns {
	my $self = shift;
	
	return  int((List::Util::sum map {scalar(@$_)} @{$self->rows})/scalar(@{$self->rows}));
}

sub is_irregular {
	my $self = shift;

	my $avg = $self->average_columns;
	for(my $i=0;$i<$self->rowcount;$i++) {
		return 1 if ($self->columncount($i)!=$avg);
	}
	return 0;
}

__PACKAGE__->meta->make_immutable;
1;

	
