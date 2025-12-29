# sb::Driver - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Driver;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.01';
# 0.01 [2006/02/03] added declaration of decrement_id
# 0.00 [2005/02/02] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Language ();
# ==================================================
# // declaration for private variables
# ==================================================
my $pObject = undef; # オブジェクト
# ==================================================
# // constructor
# ==================================================
sub get {
	my $class = join('::',@_);
	return($pObject) if ( defined($pObject) );
	eval("require $class;");
	die(sb::Language->get->string('error_unsuppoted') . '[file driver] ' . $@) if ($@);
	$pObject = $class->new();
	return($pObject);
}
sub new {
	&get; # 'new' is alias for 'get'
}
# ==================================================
# // destructor
# ==================================================
sub bye {
	my $class = shift;
	$pObject = undef;
}
sub DESTROY {
	my $self = shift;
	return();
}
# ==================================================
# // public functions
# ==================================================
sub load;
sub save;
sub new_id;
sub decrement_id;
sub matched_number;
1; # end of package
