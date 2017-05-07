package GoatKCD::Extractor;

use strict;
use Data::Dumper;
use feature qw(say);
use Moose;
use GoatKCD::Extractor::OpenCV;
use Math::Trig;
use List::Util qw(min max uniqnum);
use Cv;

has min_line_length => (is=>'rw',isa=>'Int',default=>sub { 20; });
has max_line_gap => (is=>'rw',isa=>'Int',default=>sub { 25; });
has min_rect_thickness =>(is=>'rw',isa=>'Int',default=>sub { 15; });
has collapse_proximity=>(is=>'rw',isa=>'Int',default=>sub { 7.5; });
has parent=>(is=>'ro',isa=>'GoatKCD');


sub extract {
	my ($self,$imgpath) = @_;

	my $lines = GoatKCD::Extractor::OpenCV::getlines($imgpath,$self->min_line_length);

	my $minX = min map {$_->[0]} @$lines;
	my $maxX = max map {$_->[2]} @$lines;
	my $minY = min map {$_->[1]} @$lines;
    my $maxY = max map {$_->[3]} @$lines;

	my $last=0;
	my @v;
	foreach my $line (sort {$a->[0]<=>$b->[0]} grep {$_->[0]==$_->[2]} @$lines) {
		if ($line->[3]>$line->[1]) {
            $line = [$line->[0],$line->[3],$line->[0],$line->[1]];
        }

		if ($line->[0]-$last>=3) {
			$line->[1] = $minY;
			$line->[3] = $maxY;
			push(@v,$line);
		}
		$last = $line->[0];
	}

	$last = 0;
	my @h;
	foreach my $line (sort {$a->[1]<=>$b->[1]} grep {$_->[1]==$_->[3]} @$lines) {
		 if ($line->[2]>$line->[0]) { 
            $line = [$line->[2],$line->[1],$line->[0],$line->[3]];
        }
        if ($line->[1]-$last>=3) {
            $line->[0] = $minX;
            $line->[2] = $maxX;
            push(@h,$line);
        }

        $last = $line->[1];
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

	$self->parent->log("Before Collapse",[@rows]);

	@rows = $self->collapse_columns(@rows);
	@rows = $self->collapse_rows(@rows);

	return [@rows];
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
                    #if (abs($column->[2]-$next_column->[0])<$self->min_rect_thickness) {
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

    return @rows;

}


__PACKAGE__->meta->make_immutable;

1;
