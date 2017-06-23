package GoatKCD::CLI;

use GoatKCD;
use Modern::Perl;
use Data::Dumper;
use Term::ReadLine;
use Web::Scraper;
use URI;
use Try::Tiny;
use feature qw(say);
use Moo;

$Data::Dumper::Indent = 1;

has gkcd=>(is=>'ro',default=>sub { GoatKCD->new();});
has term=>(is=>'ro',default=>sub { Term::ReadLine->new()});
has cl=>(is=>'rw',default=>0);

sub command {
	my ($self,$command,@args) = @_;

	my ($sub) = $self->commandlist->{$command};
    if ($sub) {
    	$self->$command(@args);
    } else {
    	$self->show_usage();
    }
}

sub main {
	my $self = shift;

	while (1) {
		my $line = $self->term->readline("Command> ");
		if (length($line)) {
			my ($command,@args) = split(/ /,$line);
			$self->command($command,@args);
		}
	}
}

sub quit  {
	exit;
}

sub show {
	my ($self,$file) = @_;

	if (!$file) {
		return $self->show_usage("show");
	}

	my $img = $self->summon($file);
	if (!$img) {
		$self->gkcd->error_img()->Display();
		return 0;
	} 

	$img->Display();
	return 1;
}

sub save {
	my ($self,$file,$output) = @_;


	if (!$file && !$output) {
		return $self->show_usage("save");
	}
	my $img = $self->summon($file);	
	if ($img) {
			$self->gkcd->time_op("Save",sub {
				$self->gkcd->save($output);
			});
	} else {
		die "$file is not valid.";
	}
	return 1;
}

sub border {
	my ($self,$thickness) = @_;

	if (defined $thickness) {
		$self->gkcd->border($thickness);
	} else {
		return $self->show_usage("border");
	}
	return 1;
}

sub beastmode {
	my $self = shift;

	my $t = $self->gkcd->toggle("beastmode");
	say $t if (!$self->cl); 
	return 1;
	
}

sub debug {
	my ($self) = @_;

	my $t =  $self->gkcd->toggle("debug");
	say $t if (!$self->cl);
	return 1;
}

sub consolidate_rows {
    my ($self) = @_;

    my $t = $self->gkcd->processor->toggle("consolidate_rows");
	say $t if (!$self->cl);
	return 1;
}


sub stinger  {
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

sub comic {
	my ($self,$id) = @_;

	if (!length($id)) {
		return $self->show_usage("comic");
	}

	my $res;
	try {
		$res = scraper {
			process 'div#comic img',img=>'@src';
		}->scrape(URI->new(sprintf("https://xkcd.com/%s",($id)?$id:'')));
	} catch {
		say STDERR "Unable to load!";
	};
	if (!$res) {
		return 1;
	}
	
	$self->summon($res->{img})->Display();
	return 1;
}

sub latest {
	my($self) = @_;

	$self->comic(0);
}
	
sub random {
	 my ($self,$start,$end) = @_;

	if (!$start && !$end) {
        return $self->show_usage("rcomic");
    }
	my $id = $start+int(rand($end-$start));
	say "Loding comic $id" if (!$self->cl);
	$self->comic($id);
	return 1;
}

sub summon {
	my ($self,$what) = @_;

	return $self->gkcd->summon_the_goatman($what);
}

sub commandline {
	my ($self,@args) = @_;

	while (scalar(@args)) {
		my $cmd = shift @args;
   	if (exists $self->commandlist->{$cmd}) {
			my $command = $self->commandlist->{$cmd};
			my @a;
			if ($command->{args}) {
    		@a = splice(@args,0,$command->{args});
			}
			
    	if (scalar(@a)<$command->{args}) {
    		die $self->print_usage($cmd,$command);
    	} else {
    		my $ret = $self->command($cmd,@a);
      	die $self->print_usage($cmd,$command) if (!$ret);
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
	my $commands = $self->commandlist;
	foreach my $cmd (keys %$commands) {
		$self->print_usage($cmd,$commands->{$cmd});
	}
	return 0;
}	

sub command_desc {
	my ($self,$cmd) = @_;

	return ($cmd,$self->commandlist->{$cmd});
}


sub print_usage {
	my ($self,$cmd,$ch) = @_;
	
	say "\e[1m$cmd\e[0m \e[2m$ch->{usage}\e[0m";
    say "  ".$ch->{desc};
    say "";
	return "";
}

sub commandlist {
	return {
		'border' => {
  		'usage' => '<thickness>',
  		'desc' => 'Set panel border thickness',
  		'args' => '1'
  	},
  	'quit' => {
  		'desc' => 'Quit goatifying things ',
  		'args' => 0,
  		'usage' => '',
  	},
  	'stinger' => {
  		'desc' => 'Use another image instead of our dear Mr. Johnson',
  		'args' => '1',
  		'usage' => '<file>',
  	},
  	'random' => {
  		'desc' => 'Show random comic',
  		'args' => '2',
  		'usage' => '<start> <end>'
  	},
  	'save' => {
  		'usage' => '<file|url> <output_file>',
  		'desc' => 'Save Goatified Image',
  		'args' => '2',
  	},
  	'show' => {
  		'args' => '1',
  		'desc' => 'Display Goatified Image',
  		'usage' => '<file|url>'
  	},
  	'latest' => {
  		'desc' => 'Latest Comic',
  		'args' => 0,
  		'usage' => '',
  	},
  	'comic' => {
  		'desc' => 'Scrape directly from xkcd. 0 for latest',
  		'args' => '1',
  		'usage' => '<number>',
  	},
  	'beastmode' => {
  		'usage' => '',
  		'args' => 0,
  		'desc' => 'Replace every panel'
  	},
  	'debug' => {
  		'args' => 0,
  		'desc' => 'Toggle debug messages',
  		'usage' => ''
  	}
	};
}

__PACKAGE__->meta->make_immutable;

1;
