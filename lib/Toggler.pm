package Toggler;
use Mouse::Role;
use Time::HiRes;
use feature qw(say);

sub toggle {
	my ($self,$attr) = @_;

	if ($self->can($attr)) {
		$self->$attr($self->$attr^1);
	}
	return ucfirst($attr)." ".(($self->$attr==1)?"On":"Off");
}

1;
