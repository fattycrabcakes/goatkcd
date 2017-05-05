#5!/usr/bin/env perl

package GoatKCD;

use strict;
use GoatKCD::Extractor;
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
use feature qw(say);

our $VERSION = "1.0.0";
$Data::Dumper::Indent = 0;
$Data::Dumper::Terse=1;

has 'beastmode'=>(is=>'rw',isa=>'Bool',default=>sub { 0; });
has 'tmpfile'=>(is=>'rw',isa=>'Str',default=>sub { sprintf("%d-%d.png",$$,time()); });
has 'debug'=>(is=>'rw',isa=>'Str',default=>sub { 0; });
has 'canvas'=>(is=>'rw',isa=>'Image::Magick');
has 'rows'=>(is=>'rw',isa=>'Any',default=>sub { []; });
has 'stinger'=>(is=>'rw',isa=>'Image::Magick',default=>sub {__PACKAGE__->load_img("/usr/share/goatkcd/hello.jpg");});
has 'debug_data'=>(is=>'rw',isa=>'Any',default=>sub { []; });
has error=>(is=>'rw');
has 'pad_by'=>(is=>'rw',isa=>'Int',default=> sub { 20; });
has tmpdir=>(is=>'rw',isa=>'Str',default=>sub { "/tmp/"; });
has auto_goatify=>(is=>'rw',isa=>'Str',default=>sub { 1; });

sub summon_the_goatman {
	my ($self,$path) = @_;
	
	$self->reset();
	my $canvas = $self->load_canvas($path);
	$self->error(undef);

	my $rows;
	my $y_offset = 0;

	$rows = $self->extract_rows($canvas);
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
	$self->cleartmp();

	# consolidate touching columns
	$self->log("Rows after row processing",$rows);

	$rows = $self->collapse_columns($rows);
	$rows = $self->collapse_rows($rows);

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
	$canvas->Crop(width=>$canvas->Get("width")-20,height=>$canvas->Get("height")-20,x=>10,y=>10);
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



sub collapse_columns {
	my ($self,$rows) = @_;

	while (1) {
        my $changed=0;
        foreach my $row (@$rows) {
            my @row_tmp;
            for (my $i=0;$i<scalar(@$row);$i++) {
                my $column = $row->[$i];
                next if (!defined $column);
                my $next_column = $row->[$i+1];
                if ($next_column) {
                    if ($column->[2]==$next_column->[0]) {
                        $changed = 1;
                        $column->[2] = $next_column->[2];
                        $row->[$i+1] = undef;
                    }
                }
                push(@row_tmp,$column);
            }
            $row = [@row_tmp];
        }
        last if (!$changed);
    }
	return $rows;
}

sub collapse_rows {
	my ($self,$rows) = @_;

	while (1) {
        my @row_tmp;
        my $changed = 0;
        for (my $i=0;$i<scalar(@$rows);$i++) {
            my $row = $rows->[$i];
            my $next_row = $rows->[$i+1];
            next if (!$row);
            if (!$next_row) {
                push(@row_tmp,$row);
                last;
            }
            if (scalar(@$row)==scalar(@$next_row)) { # same number of columns.
                for (my $j=0;$j<scalar(@$row);$j++) {
                    if ($row->[$j]->[3]==$next_row->[$j]->[1]) {
                        $row->[$j]->[3] = $next_row->[$j]->[3];
                        $rows->[$i+1]=undef;
                        $changed=1;
                    }
                }
            }
            push(@row_tmp,$row);
        }
        $rows = [@row_tmp];
        last if (!$changed);
    }
	
	return $rows;

}


sub log {
	my ($self,$label,$stuff) = @_;

	if ($self->debug) {
		if (ref($stuff)) {
			$stuff = Dumper($stuff);
		}
		say STDERR "$label: ".$stuff;
		push(@{$self->debug_data},[$label,$stuff]);
	}
}

sub load_img {
	my ($self,$data) = @_;

	my $img = Image::Magick->new();

	if (ref($data) eq "CODE") {
		$img->ReadImage($data->($self));
	} elsif (-f $data) {
		$img->ReadImage($data);
	} elsif ($data=~/^http/i) {
		# url handling
	} else {
		$img->BlobToImage($data);
	}
	return $img;
}

sub load_canvas {
	my $self = shift;
	my $img = shift;

	my $tmp = $self->load_img($img);
	my ($w,$h) = $tmp->Get("width","height");

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
	$self->error(undef);
}

sub extract_rows {
	my ($self,$img) = @_;

	my $rows=[];
	my $tmpf = $self->mktmp($img);

	try {
		$rows = GoatKCD::Extractor::areas($tmpf);
	} catch {
		$self->error("Unable to detect rows: ".$@);
	};

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

	
