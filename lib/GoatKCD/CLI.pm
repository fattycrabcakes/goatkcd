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

sub command {
	my ($self,$command,@args) = @_;

	my ($sub) = grep {$_->name eq $command && scalar(@{$_->attributes})} $self->meta->get_all_methods;
    if ($sub) {
    	$sub->execute($self,@args);
    } else {
    	$self->show_usage();
    }
}

sub main {
	my $self = shift;

	while (my $line = $self->term->readline("Command ")) {
		my ($command,@args) = split(/ /,$line);
		$self->command($command,@args);
	}
}

sub quit :Usage(quit) :Desc(Quit goatifying things and return to your usual routine of disgusting self-abuse) {
	exit;
}

sub show :Usage(show <file|url>) Desc(Display Goatified Image) {
	my ($self,$file) = @_;

	$self->summon($file)->Display();
}

sub save  :Usage(save <file|url> <output_file>) Desc(Save Goatified Image) {
	my ($self,$file,$output) = @_;

	my $img = $self->summon($file);	
	$img->Write($output);
	$img->Display();
}

sub beastmode :Usage(beastmode) Desc(Toggle Beast mode) {
	my $self = shift;
	my $flag = shift;

	$self->gkcd->beastmode($self->gkcd->beastmode^1);
}

sub debug :Usage(debug) Desc(Toggle debug messages) {
	my ($self) = @_;

	$self->gkcd->debug($self->gkcd->debug^1);
}

sub stinger :Usage(stinger <file>) Desc(Use another image instead of our dear Mr. Johnson)  {
	my ($self,$img) = @_;

	if (-f $img) {
		$self->gkcd->set_stinger($img);
	}
}

sub comic :Usage(Comic [<number>]) Desc(Scrape directly from xkcd. Leave blank for latest.) {
	my ($self,$id) = @_;

	$id||="";

	my $res = scraper {
		process 'div#comic img',img=>'@src';
	}->scrape(URI->new("https://xkcd.com/$id"));

	$self->summon($res->{img})->Display();
}

sub summon {
	my ($self,$what) = @_;

	return $self->gkcd->summon_the_goatman($what);
}

sub show_usage {
	my $self = shift;

	say "What? Here's whar you can do, schmendrick.";

	foreach my $method (grep {$_->can("attributes") && scalar(@{$_->attributes})} $self->meta->get_all_methods) {
		if ($method->can("attributes")) {
			my $attr= $method->attributes;
			say "  ".substr($attr->[0],6,-1);
			say "    ".substr($attr->[1],5,-1);
		}
	}
}	

__PACKAGE__->meta->make_immutable;

1;
