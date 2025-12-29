# sb::Data::Session - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Data::Session;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.03';
# 0.03 [2007/07/04] removed @mStruct and added elements
# 0.02 [2005/07/22] changed data structure to array
# 0.01 [2005/04/18] added check_expire
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
		'id',   # id
		'key',  # key for session
		'data', # session data
	);
}
# ==================================================
# // public functions
# ==================================================
sub check_expire
{
	my $self = shift;
	my %param = (
		'now'      => undef,
		'duration' => undef,
		@_
	);
	if ( $param{'now'} and $param{'duration'} )
	{
		my $diff_time = $param{'now'} - ( split('_',$self->data) )[0];
		return( $diff_time <= $param{'duration'} );
	}
	return( undef );
}
sub initialize
{
	my $self  = shift;
	my %param = @_;
	$self->SUPER::initialize(%param);
}
1;
__END__
