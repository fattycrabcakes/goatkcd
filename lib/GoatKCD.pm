#5!/usr/bin/env perl

package GoatKCD;

use strict;
use GoatKCD::Extractor;
use GoatKCD::Extractor::OpenCV;
use LWP::UserAgent;
use HTTP::Message;
use File::Type;
use Image::Magick;
use URI;
use Web::Scraper;
use Data::Dumper;
use Try::Tiny;
use List::Util;
use Image::ExifTool;
use JSON;
use Moose;

with 'Timer';
with 'Toggler';
use Time::HiRes;

use feature qw(say);

our $VERSION = "1.0.0";
$Data::Dumper::Indent = 0;
$Data::Dumper::Terse=1;

has 'beastmode'=>(is=>'rw',isa=>'Bool',default=>sub { 0; });
has 'tmpfile'=>(is=>'rw',isa=>'Str',default=>sub { sprintf("%d-%d.jpg",$$,time()); });
has 'debug'=>(is=>'rw',isa=>'Int',default=>sub { 0; });
has 'canvas'=>(is=>'rw',isa=>'Image::Magick');
has 'rows'=>(is=>'rw',isa=>'Any',default=>sub { []; });
has 'stinger'=>(is=>'rw',isa=>'Image::Magick',default=>sub {__PACKAGE__->load_img("/usr/share/goatkcd/hello.jpg");});
has 'pad_by'=>(is=>'rw',isa=>'Int',default=> sub { 20; });
has tmpdir=>(is=>'rw',isa=>'Str',default=>sub { "/tmp/"; });
has processor=>(is=>'rw',isa=>'GoatKCD::Extractor',default=>sub {GoatKCD::Extractor->new(parent=>shift);});
has auto_goatify=>(is=>'rw',isa=>'Str',default=>sub { 1; });
has maxheight=>(is=>'rw',isa=>'Int',default=>sub { 640; });
has border=>(is=>'rw',isa=>'Int',default=>sub { 1; });
has error=>(is=>'rw',isa=>'Int',default=>sub { 0; });

sub summon_the_goatman {
	my ($self,$path) = @_;

	$self->reset();
	my $canvas = $self->load_canvas($path);
	return undef if (!$canvas);

	my $rows;
	my $y_offset = 0;

	$rows = $self->extract_rows([0,0,$canvas->Get("width"),$canvas->Get('height')],1);
	$self->log("rows",$rows);
	return if (!defined $rows);

	$self->log("Rows from extractor:",$rows);
	$self->rows($rows);
	
	if (scalar(@$rows)>1) {
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

				#my $canvas_tmp = $canvas->Clone();
				#$canvas_tmp->Crop(width=>$canvas->Get("width"),height=>$row_height+$bottom_padding,x=>0,y=>$y_offset);

				$bottom_edge = $y_offset;
				my $x_offset = 0;

				my ($just_this_row) = $self->extract_rows([0,$y_offset,$canvas->Get("width"),$y_offset+$row_height+$bottom_padding]);


				# TODO: Irregular values in beastmode.
				if (defined $just_this_row && scalar(@$just_this_row)>1) {
					my $jlp = $just_this_row->[scalar(@$just_this_row)-1];

					#$canvas_tmp->Crop(width=>$jlp->[2]-$jlp->[0],height=>$jlp->[3]-$jlp->[1],x=>$jlp->[0],y=>$jlp->[1]);
					my $last_column = $self->extract_rows($jlp);
					$self->log("hey now",$last_column);
					$jlp = $last_column->[0];
				}

				if ($just_this_row) {
					foreach my $column (@$just_this_row) {
						$column->[1]+=$y_offset;
						$column->[3]+=$y_offset;
					}
					$rows->[$i] = $just_this_row;
				}	
				
				# final sanity check on last column


				unless ($self->beastmode) {
					last ROWLOOP;
				}
			}
		}
	}
	$self->cleartmp();
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

	if ($self->error) {
		return undef;
	}


	my @panels = $self->panels;
	my $unpad=1;

	if (!defined $panels[0]) {
		$self->log("what what","");
		$unpad=0;
		$panels[0] = [8,8,$self->canvas->Get("width")-8,$self->canvas->Get("height")-8];

	}

	foreach my $rect (@panels) {
		my $stinger_tmp = $self->stinger->Clone();
		$stinger_tmp->Resize(geometry=>($rect->[2]-$rect->[0])."x".($rect->[3]-$rect->[1]."!"));
		$self->canvas->Composite(image=>$stinger_tmp,x=>$rect->[0],y=>$rect->[1],compose=>"Over",gravity=>"NorthWest");
		if ($self->border>0) {
			$self->canvas->Draw(primitive=>"rectangle",stroke=>"#000000",fill=>"#00000000",,strokewidth=>$self->border,points=>join(",",@$rect));
		}
		undef $stinger_tmp;
	}

	# unpad canvas
	$self->canvas->Crop(width=>$self->canvas->Get("width")-20,height=>$self->canvas->Get("height")-20,x=>10,y=>10) if ($unpad);
	return $self->canvas;
}

sub save {
	my ($self,$path) = @_;

	$self->canvas->Write($path);
	my $exif = Image::ExifTool->new();
	$exif->ExtractInfo($path);

	$exif->SetNewValue("Description"=>JSON::encode_json({rows=>[$self->rows]}));
	#https://www.google.com/maps/place/Dildo+Island/@47.5663175,-53.5933158,17z/data=!4m13!1m7!3m6!1s0x4b7339fde3e5c105:0x52a18dbee73dd5e4!2sDildo+Island!3b1!8m2!3d47.5661422!4d-53.5911019!3m4!1s0x4b7339fde3e5c105:0x52a18dbee73dd5e4!8m2!3d47.5661422!4d-53.5911019
	$exif->SetNewValue('GPSLatitudeRef'=>'N');
	$exif->SetNewValue('GPSLongitudeRef'=>'W');
	$exif->SetNewValue('GPSLatitude'=>47.5663175);
    $exif->SetNewValue('GPSLongitude'=>53.5933158);
	$exif->SetNewValue('ProcessingSoftware'=>'GoatKCD.pm v6.6.6');
	$exif->WriteInfo($path);
	
}
	

sub panels {
	my ($self,$force) = @_;

	my @rows = @{$self->rows};
	if ($self->beastmode || $force) {
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


	if (!defined $data) {
		$self->error(1);
	} elsif (File::Type->new()->checktype_contents($data)=~/^image/i) {
		$img->BlobToImage($data);
	} elsif ($data=~/^(?:http|https|\/\/)/i) {
		try {
			if ($data=~/^\/\//) {
				$data="http:";
			}
			my $ua = LWP::UserAgent->new();
			$ua->agent('Mozilla/5.0 (X11; U; Linux x86_64; en-US) AppleWebKit/532.0 (KHTML, like Gecko) Chrome/4.0.202.0 Safari/532.0');
    		my $res = $ua->get($data,'Accept-Encoding'=>HTTP::Message::decodable);

			if (!$res->is_success) {
				$self->error(1);
				$self->log("error",$res->status_line);
			} else {
				if (File::Type->new()->checktype_contents($res->decoded_content)=~/^image/i) {
					$img->BlobToImage($res->decoded_content);
				}
			}
		} catch {
			$self->error(1);
			$self->log("error",[@_]);
		};
	} elsif (ref($data) eq "CODE") {
        $img->ReadImage($data->($self));
    } elsif (-f $data) {
        $img->ReadImage($data);
	} else {
		$self->log("error","Unsupported or bad data");
	}
	if ($img && !scalar(@$img)) {
		undef $img;
		#$self->error(1);
	}

	return $img;
}

sub load_canvas {
	my $self = shift;
	my $img = shift;

	my $tmp = $self->load_img($img);
	return undef if (!$tmp);
	my ($w,$h) = $tmp->Get("width","height");

	if ($w>1000) {
		my $rsb = 1000/$w;
		$w*=$rsb;
		$h*=$rsb;
		$tmp->Resize(geometry=>"$w"."x".$h);
	} elsif ($h>700) {
		 my $rsb = 700/$w;
        $w*=$rsb;
        $h*=$rsb;
        $tmp->Resize(geometry=>"$w"."x".$h);
	}

	my $canvas = Image::Magick->new();

   	$canvas->Set(size=>($w+$self->pad_by)."x".($h+$self->pad_by));
   	$canvas->Read('xc:white');
   	$canvas->Composite(image=>$tmp,compose=>"over",gravity=>"Center");

	$self->processor->load($self->mktmp($canvas));
	$self->canvas($canvas);


	return $canvas;
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
	
	$self->processor->reset();
	$self->rows([]);
}

sub extract_rows {
	my ($self,$rect) = @_;

	my $rows=[];
	#my $tmpf = $self->mktmp($img);
	$rows = $self->processor->extract($rect);#$tmpf,$img,$firstpass);
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

sub dismember {
	my ($self) = @_;

	my @ret;
	foreach my $panel ($self->panels(1)) {
		my ($w,$h) = ($panel->[2]-$panel->[0],$panel->[3]-$panel->[1]);
		my $img = $self->canvas->Clone();
		$img->Crop(
			width=>$w,
			height=>$h,
			x=>$panel->[0],
			y=>$panel->[1],
		);
		push(@ret,$img);
	}
	return @ret;
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

sub set_stinger {
	my ($self,$file) = @_;

	$self->stinger($self->load_img($file));
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

	
