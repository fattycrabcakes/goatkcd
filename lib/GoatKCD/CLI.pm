package GoatKCD::CLI;

use GoatKCD;
use Data::Dumper;
use Term::ReadLine;
use Web::Scraper;
use URI;
use Try::Tiny;
use Math::Geometry::Planar qw(SegmentIntersection);
use feature qw(say);
use Moose;
use MooseX::MethodAttributes;

$Data::Dumper::Indent = 1;

has gkcd=>(is=>'ro',isa=>'GoatKCD',default=>sub { GoatKCD->new(); });
has term=>(is=>'ro',default=>sub { Term::ReadLine->new(); });
has cli=>(is=>'rw',default=>sub { 0; });

sub command {
	my ($self,$command,@args) = @_;

	my ($sub) = $self->commandlist($command);
    if ($sub) {
    	$self->$command(@args);
    } else {
    	$self->show_usage();
    }
}

sub main {
	my $self = shift;

	while (1) {
		my $line = $self->term->readline("Command ");
		if (length($line)) {
			my ($command,@args) = split(/ /,$line);
			$self->command($command,@args);
		}
	}
}

sub quit :Usage() :Desc(Quit goatifying things and return to your usual routine of disgusting self-abuse) {
	exit;
}

sub show :Usage(<file|url>) Desc(Display Goatified Image) Args(1) {
	my ($self,$file) = @_;

	if (!$file) {
		return $self->show_usage("show");
	}

	$self->summon($file)->Display();
	return 1;
}

sub save  :Usage(<file|url> <output_file>) Desc(Save Goatified Image) Args(2) {
	my ($self,$file,$output) = @_;


	if (!$file && !$output) {
		return $self->show_usage("save");
	}

	$self->summon($file);	
	$self->gkcd->save($output);
	return 1;
}

sub border :Usage(<thickness>) Desc(Set panel border thickness) Args(1) {
	my ($self,$thickness) = @_;

	if (defined $thickness) {
		$self->gkcd->border($thickness);
	} else {
		return $self->show_usage("border");
	}
	return 1;
}

sub beastmode :Usage() Desc(Toggle Beast mode) {
	my $self = shift;

	say $self->gkcd->toggle("beastmode");
	return 1;
	
}

sub debug :Usage() Desc(Toggle debug messages) {
	my ($self) = @_;

	say $self->gkcd->toggle("debug");
	return 1;
}

sub consolidate_rows :Usage() Desc(Toggle Row consolidation) {
    my ($self) = @_;

    say $self->gkcd->processor->toggle("consolidate_rows");
	return 1;
}


sub stinger :Usage(<file>) Desc(Use another image instead of our dear Mr. Johnson) Args(1)  {
	my ($self,$img) = @_;

	if (!$img) {
		return $self->show_usage("stinger");
	}

	if (-f $img) {
		$self->gkcd->set_stinger($img);
	} else {
		return 0;
	}
	return 1;
}

sub comic :Usage([<number>|<range_start> <range_end>]) Desc(Scrape directly from xkcd. 0 for latest) Args(1) {
	my ($self,$id) = @_;

	if (!length($id) && $id!~/^\d+$/) {
		return $self->show_usage("comic");
	}

	my $res = scraper {
		process 'div#comic img',img=>'@src';
	}->scrape(URI->new(sprintf("https://xkcd.com/%d",($id)?$id:'')));

	$self->summon($res->{img})->Display();
	return 1;
}

sub rcomic :Usage(<start> <end>) Desc(Show random comic) Args(2) {
	 my ($self,$start,$end) = @_;

	if (!$start && !$end) {
        return $self->show_usage("rcomic");
    }
	my $id = $start+int(rand($end-$start));
	$self->comic($id);
	return 1;
}


sub summon {
	my ($self,$what) = @_;

	return $self->gkcd->summon_the_goatman($what);
}

sub commandlist {
	my ($self,$cmd) = @_;

	my @methods;
    if ($cmd) {
        @methods = grep {$_->name eq $cmd} $self->meta->get_all_methods;
    } else {
        @methods = grep {$_->can("attributes") && scalar(@{$_->attributes})} $self->meta->get_all_methods;
    }
	my @ret = ();
	foreach my $method (sort {$a->name cmp $b->name} @methods) {
        if ($method->can("attributes")) {
			my $rh = {
				name=>$method->name,
			};
			foreach my $attr (@{$method->attributes}) {
				my ($name,$value)  = ($attr=~/(Desc|Usage|Args)[(](.*?)[)]/i);
				$rh->{lc($name)} = $value;
			}
			$rh->{args}||=0;
			push(@ret,$rh);
		}
	}
	return @ret;
}

sub arg_options {
	my $self = shift;

	return map {("$_->{name}"=>$_)} $self->commandlist;
}

sub commandline {
	my ($self,@args) = @_;

	my %options = $self->arg_options;
    while (scalar(@args)) {
        my $cmd = $args[0];
        if (exists $options{$cmd}) {
            my ($cmd,@a) = splice(@args,0,$options{$cmd}->{args}+1);
			if (scalar(@a)<$options{$cmd}->{args}) {
				die $self->print_usage($options{$cmd});
			} else {
				my $ret = $self->command($cmd,@a);
				die $self->print_usage($options{$cmd}) if (!$ret);
			} 
        } else {
			die "'$cmd' is not a valid command.";
		}
    }
}


sub show_usage {
	my $self = shift;
	my $name = shift;

	say "What?\n";

	foreach my $cmd ($self->commandlist($name)) {
		$self->print_usage($cmd);
	}
	return 0;
}	

sub print_usage {
	my ($self,$cmd) = @_;
	
	say "\e[1m$cmd->{name}\e[0m \e[2m$cmd->{usage}\e[0m";
    say "  ".$cmd->{desc};
    say "";
	return "";
}

__PACKAGE__->meta->make_immutable;

1;
