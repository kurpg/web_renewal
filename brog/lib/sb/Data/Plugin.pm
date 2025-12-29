# sb::Data::Plugin - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Data::Plugin;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.02';
# 0.02 [2007/07/04] removed @mStruct and added elements
# 0.01 [2005/07/22] changed data structure to array
# 0.00 [2005/03/15] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Data::Object ();
@ISA = qw( sb::Data::Object );
# ==================================================
# // declaration for constant value
# ==================================================
# ==================================================
# // declaration for data structure
# ==================================================
sub elements
{
	return(
		'id',      # id
		'wid',     # wid
		'name',    # name
		'data',    # data
		'text',    # text
		'setting', # setting
		'date',    # date
		'url',     # url
		'mail',    # mail
		'extra',   # extra field
	);
}
# ==================================================
# // public functions
# ==================================================
sub initialize
{
	my $self  = shift;
	my %param = @_;
	$param{'wid'} ||= 0;
	$self->SUPER::initialize(%param);
}
1;
__END__
