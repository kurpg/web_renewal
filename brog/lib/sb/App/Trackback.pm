# sb::App::Trackback - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::App::Trackback;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.00';
# 0.00 [2005/07/25] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Interface ();
use sb::Receipt ();
use sb::App ();
@ISA = qw( sb::App );
# ==================================================
# // public functions
# ==================================================
sub run { # main routine
	my $class = shift;
	my $self = $class->SUPER::new( @_ );
	my $cgi  = sb::Interface->get;
	print sb::Receipt->new(
		'mode' => 'tb',
		'cgi'  => $cgi,
		'id'   => &_check_mode($cgi),
		'time' => $self->{'time'},
	)->issue;
}
# ==================================================
# // private functions
# ==================================================
sub _check_mode { # checking mode
	my $cgi = shift;
	my $id = undef;
	$id = $cgi->value('tb');
	if ($cgi->value('_path') ne '') {
		$id = $cgi->value('_path');
		$id =~ s/.*[:\/\\](.*)/$1/;
	}
	$id = undef if ($id !~ /^\d+$/);
	return($id);
}
1;
__END__
