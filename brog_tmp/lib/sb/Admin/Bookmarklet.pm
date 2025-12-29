# sb::Admin::Bookmarklet - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Admin::Bookmarklet;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.01';
# 0.01 [2005/06/07] implement bookmarklet
# 0.00 [2005/04/09] generate

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Config ();
use sb::Interface ();
use sb::Ping ();
use sb::Admin::Entry ();
@ISA = qw( sb::Admin::Entry );
# ==================================================
# // public functions - callback
# ==================================================
sub callback {
	my $self = shift;
	return ( $self->{'regi'} ) 
		? $self->_save_entry(@_)
		: $self->_open_entry(@_);
}
# ==================================================
# // public functions - class method
# ==================================================
sub set_onload {
	my $class = shift;
	my $cgi = sb::Interface->get;
	my $output = 'bm" onload="sbit(';
	$output .= "'" . $cgi->value('_t') . "',";
	$output .= "'" . $cgi->value('_u') . "',";
	$output .= "'" . $cgi->value('_b') . "')";
	return( $output );
}
# ==================================================
# // private functions - utilities
# ==================================================
1;
__END__
