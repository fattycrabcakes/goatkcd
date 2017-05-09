package GoatKCD::Extractor;

use strict;
use Data::Dumper;
use feature qw(say);
use Moose;
use GoatKCD::Extractor::OpenCV;
use Math::Trig;
use Math::Geometry::Planar;
use List::Util qw(min max uniqnum);
use Cv;

has min_line_length => (is=>'rw',isa=>'Int',default=>sub { 20; });
has max_line_gap => (is=>'rw',isa=>'Int',default=>sub { 25; });
has min_rect_thickness =>(is=>'rw',isa=>'Int',default=>sub { 35; });
has collapse_proximity=>(is=>'rw',isa=>'Int',default=>sub { 7; });

has rho=>(is=>"rw",isa=>"Int",default=>sub { 50; });
has theta=>(is=>"rw",isa=>"Int",default=>sub { 50; });
has threshold=>(is=>"rw",isa=>"Int",default=>sub { 10; });


has parent=>(is=>'ro',isa=>'GoatKCD');
has canvas=>(is=>'rw',isa=>'Image::Magick');


sub extract {
	my ($self,$imgpath,$canvas,$firstpass) = @_;

	$self->canvas($canvas);

	my $lines = GoatKCD::Extractor::OpenCV::getlines($imgpath,$self->min_line_length,$self->rho,$self->theta,$self->threshold);

	my $last=0;
	my $ct = $self->canvas->Clone;

	my @h;
	my @v;

	foreach my $line (@$lines) {
		if ($line->[1]>$line->[3]) {
        	$line = [$line->[0],$line->[3],$line->[2],$line->[1]];
        }
		if ($line->[0]>$line->[2]) {
            $line = [$line->[2],$line->[1],$line->[0],$line->[3]];
        }
	}


	foreach my $line (sort {$a->[0]<=>$b->[0]} grep {$_->[0]==$_->[2]} @$lines) {
		if ($line->[0]-$last>=2) {
			push(@v,$line);
		 	$ct->Draw(primitive=>"line",stroke=>"#ff0000",points=>"$line->[0],$line->[1] $line->[2],$line->[3]") if ($self->parent->debug);
		}
		$last = $line->[0];
	}

	$last = 0;
	ROWL: foreach my $line (sort {$a->[1]<=>$b->[1]} grep {$_->[1]==$_->[3]} @$lines) {
		if (abs($line->[1]-$last)>=2) {
			$ct->Draw(primitive=>"line",stroke=>"#00ff00",points=>"$line->[0],$line->[1] $line->[2],$line->[3]") if ($self->parent->debug);

           	push(@h,$line);
		}
		$last = $line->[3];
	}
		


	my @rects;
	for (my $i=0;$i<scalar(@h)-1;$i++) {
		my $top = $h[$i];
		my $bottom = $h[$i+1];
		for (my $j=0;$j<scalar(@v)-1;$j++) {
			my $left = $v[$j];
			my $right = $v[$j+1];
			if ($bottom->[1]-$top->[1]>$self->min_rect_thickness && $right->[0]-$left->[0] > $self->min_rect_thickness*1.25) {
				push (@rects,[$left->[0],$top->[1],$right->[2],$bottom->[3]]);
			} else {
				#say Dumper([$bottom->[1]-$top->[1],[$left->[0],$bottom->[1],$right->[0],$top->[1]]]);
			}
		}
	}

	my @rows;
	foreach my $y (sort {$a<=>$b} uniqnum map {$_->[1]} @rects) {
		push(@rows,[grep {$_->[1]==$y} @rects]);
	}

	

	$self->parent->log("rows",[@rows]);

	@rows = $self->collapse_columns(@rows);
	@rows = $self->collapse_rows(sort {$a->[0]->[1]<=>$b->[0]->[1]} @rows);

	my $lastrow = $rows[$#rows];
    my $lc = $lastrow->[scalar(@$lastrow)-1];
    $ct->Draw(primitive=>"rectangle",stroke=>"#ffff00",points=>"$lc->[0],$lc->[1] $lc->[2],$lc->[3]") if ($self->parent->debug);
    $ct->Display() if ($self->parent->debug);


	return [@rows];
}

sub between {
	my ($start,$end,$val) = @_;

	return ($val>$start && $val<$end);

}

sub collapse_columns {
    my ($self,@rows) = @_;

    while (1) {
        my $changed=0;
        foreach my $row (@rows) {
            my @row_tmp;
            for (my $i=0;$i<scalar(@$row);$i++) {
                my $column = $row->[$i];
                next if (!defined $column);
                my $next_column = $row->[$i+1];
                if ($next_column) {
					if (abs($column->[2]-$next_column->[0])<=$self->collapse_proximity) {
						my $xv = $next_column->[0]+int(($next_column->[2]-$next_column->[0])/2);
                    	my $yv = $column->[3];

                     	my @pa = $self->canvas->GetPixels(
                           	width=>1,
                           	height=>$self->collapse_proximity,
                           	x=>$next_column->[0]+int(($next_column->[2]-$next_column->[0])/2),
                           	y=>$yv-($self->collapse_proximity/2),
                        );

						my $avg = List::Util::sum(@pa)/scalar(@pa);
						$changed = 1;
                        $column->[2] = $next_column->[2];
                        $row->[$i+1] = undef;

						if (0) {
							if ($avg!=$pa[0]) {
                        		$changed = 1;
                        		$column->[2] = $next_column->[2];
                        		$row->[$i+1] = undef;
							} else {
								$next_column->[0]+=5;
								$next_column->[2]-=5;
							}
						}
						
                    }
                }
                push(@row_tmp,$column);
            }
            $row = [@row_tmp];
        }
        last if (!$changed);
    }
    return @rows;
}

sub collapse_rows {
    my ($self,@rows) = @_;

    while (1) {
        my @row_tmp;
        my $changed = 0;
        for (my $i=0;$i<scalar(@rows);$i++) {
            my $row = $rows[$i];
            my $next_row = $rows[$i+1];
            next if (!$row);
            if (!$next_row) {
                push(@row_tmp,$row);
                last;
            }
            if (scalar(@$row)==scalar(@$next_row)) { # same number of columns.
                for (my $j=0;$j<scalar(@$row);$j++) {
					$self->parent->log("what",abs($row->[$j]->[3]-$next_row->[$j]->[1]));
                    if (abs($row->[$j]->[3]-$next_row->[$j]->[1])<$self->collapse_proximity) {
                        $row->[$j]->[3] = $next_row->[$j]->[3];
                        $rows[$i+1]=undef;
                        $changed=1;
                    }
                }
            }
            push(@row_tmp,$row);
        }
        @rows = @row_tmp;
        last if (!$changed);
    }

    return sort {$a->[0]->[1]<=>$b->[0]->[1]} @rows;
}


__PACKAGE__->meta->make_immutable;

1;
