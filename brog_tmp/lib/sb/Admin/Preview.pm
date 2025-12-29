# sb::Admin::Preview - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Admin::Preview;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.00';
# 0.00 [2005/04/09] generate

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Config ();
use sb::Interface ();
use sb::App::Admin ();
@ISA = qw( sb::App::Admin );
# ==================================================
# // public functions - callback
# ==================================================
sub callback {
	my $self = shift;
	return sb::Interface->get->head('location'=>sb::Config->get->value('conf_srv_base'));
}
1;
__END__
