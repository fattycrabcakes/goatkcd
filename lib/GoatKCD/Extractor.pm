package GoatKCD::Extractor;

use strict;
use Data::Dumper;
use feature qw(say);
use Moo;

with 'Timer';
with 'Toggler';

use GoatKCD::Extractor::OpenCV;
use List::Util qw(min max uniqnum);

has min_line_length => (is=>'rw',,default=>sub { 20; });
has max_line_gap => (is=>'rw',,default=>sub { 25; });
has min_rect_thickness =>(is=>'rw',,default=>sub { 35; });
has collapse_proximity=>(is=>'rw',,default=>sub { 3; });

has parent=>(is=>'ro',,weak_ref=>1);
has cvImage=>(is=>'rw');
has x=>(is=>'rw');
has y=>(is=>'rw');
has width=>(is=>'rw');
has height=>(is=>'rw');
has consolidate_rows=>(is=>'rw',default=>sub { 0; });


sub load {
	my ($self,$imgpath) = @_;

	$self->cvImage(GoatKCD::Extractor::OpenCV::load_img($imgpath));
}

sub reset {
	my ($self) = @_;

	if ($self->cvImage) {
		#GoatKCD::Extractor::OpenCV::release_img($self->cvImage);
	}
}

sub extract {
	my ($self,$rect) = @_;

	$self->x($rect->[0]);
	$self->y($rect->[1]);
	$self->width($rect->[2]-$rect->[0]);
	$self->height($rect->[3]-$rect->[1]);


	#my $data = GoatKCD::Extractor::OpenCV::getlines($imgpath,$self->min_line_length,$self->rho,$self->theta,$self->threshold);
	my $data;
	$data = GoatKCD::Extractor::OpenCV::getlines($self,$self->cvImage,{
		x=>$self->x,
		y=>$self->y,
		width=>$self->width,
		height=>$self->height,
		mode=>$self->parent->is_color
	});

	my $lines = $data->{lines};
	my $checklines = {};
	foreach my $check_y (sort {$a<=>$b} uniqnum map {$_->[0]} @{$data->{checklines}}) {
		$checklines->{$check_y} = scalar(grep {$_->[0]==$check_y} @{$data->{checklines}});
	}
	
	

	my $last=0;

	my @h;
	my @v;

	foreach my $line (@$lines) {
		if ($line->[1]>$line->[3]) {
        	$line = [$line->[0],$line->[3],$line->[2],$line->[1]];
        }

		if ($line->[0]>$line->[2]) {
            $line = [$line->[2],$line->[1],$line->[0],$line->[3]];
        }

		if ($line->[1]<0) {
                $line->[1]=0;
                $line->[3] = $line->[3] = $self->height;
        }
        if ($line->[0]<0) {
            $line->[0]=0;
            $line->[2]=$self->width;
        }

	}

	$self->parent->log("lines",$lines);

	my $open=0;
	foreach my $line (sort {$a->[0]<=>$b->[0]} grep {abs($_->[0]-$_->[2])<=3} @$lines) {
		if (!$open) {
			push(@v,$line);
		} else {
			if ($line->[0]-$last>=2) {
                push(@v,$line);
			}
		}
		$open^=1;
		$last = $line->[0];
	}

	$last = 0;
	ROWL: foreach my $line (sort {$a->[1]<=>$b->[1]} grep {abs($_->[1]-$_->[3])<=5} @$lines) {
		if (abs($line->[1]-$last)>=2 || $last==0) {
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
			if (abs($bottom->[1]-$top->[1])>=$self->min_rect_thickness && abs($right->[0]-$left->[0]) >= $self->min_rect_thickness) {
				push (@rects,[$left->[0],$top->[1],$right->[2],$bottom->[3]]);
			}
		}
	}

	my @rows;
	foreach my $y (sort {$a<=>$b} uniqnum map {$_->[1]} @rects) {
		push(@rows,[grep {$_->[1]==$y} @rects]);
	}

	$self->parent->log("rows",[@rows]);

	#@rows = $self->collapse_columns(@rows);
	if ($self->consolidate_rows) {
		@rows = $self->collapse_rows(sort {$a->[0]->[1]<=>$b->[0]->[1]} @rows);
	}
	
 	my $lastrow = $rows[$#rows];
  my $lc = $lastrow->[scalar(@$lastrow)-1];


	return [@rows];
}

sub between {
	my ($start,$end,$val) = @_;

	return ($val>$start && $val<$end);

}

sub collapse_columns {
    my ($self,@rows) = @_;

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

               		#my @pa = $self->canvas->GetPixels(
                   		#width=>32,
                  		#height=>2,
                   		#x=>$next_column->[0]+10,
                   		#y=>$yv
                  	#);
					#my $avg = List::Util::sum(@pa)/scalar(@pa);

					my $avg = 30;
				
					# TODO: Figure out a better way to do this.			

					if ($avg>=32500) {
                   		$column->[2] = $next_column->[2];
                   		$row->[$i+1] = undef;
					} else {
						#$next_column->[0]+=1;
						#$next_column->[2]-=1;
					}
				}
				
            }
   			push(@row_tmp,$column);
		}
    	$row = [@row_tmp];
	}
    return @rows;
}

sub collapse_rows {
    my ($self,@rows) = @_;

    my @row_tmp;
    my $changed = 0;
    for (my $i=0;$i<scalar(@rows);$i++) {
    	my $row = $rows[$i];
        my $next_row = $rows[$i+1];
        next if (!$row);
        if (!$next_row) {
			if ($i>0) {
				# TODO: if this last row is a straggler, comsolidate with last row. Poops.
				#if ($row->[0]->[3]-$row->[$i]->[1]<$self->collapse_proximity) {	
					#$row->[$i-1]->[3] = $row->[$i]->[3];
				}
			#} else {
        		push(@row_tmp,$row);
			#}
            last;
        }

		# TODO: Check column count AND width for match.

        if (scalar(@$row)==scalar(@$next_row)) {
        	for (my $j=0;$j<scalar(@$row);$j++) {
            	if (abs($row->[$j]->[3]-$next_row->[$j]->[1])<=$self->collapse_proximity) {
					$self->parent->log("collapser","collapsing column at row $i x $j");
					if ($row->[$j]->[2]-$row->[$j]->[0] == $next_row->[$j]->[2]-$next_row->[$j]->[0]) {
                    	$row->[$j]->[3] = $next_row->[$j]->[3];
                    	$rows[$i+1]=undef;
                    	$changed=1;
					}
                }
            }
        }

        push(@row_tmp,$row);
    }
    @rows = @row_tmp;
    return sort {$a->[0]->[1]<=>$b->[0]->[1]} @rows;
}

__PACKAGE__->meta->make_immutable;

1;
