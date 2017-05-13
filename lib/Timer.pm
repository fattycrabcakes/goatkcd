package Timer;
use Mouse::Role;
use Time::HiRes;
use feature qw(say);

sub time_op {
	my ($self,$l,$code) = @_;

	my $t = Time::HiRes::time;
	$code->();
	say "$l: ".(Time::HiRes::time - $t);
}
1;
