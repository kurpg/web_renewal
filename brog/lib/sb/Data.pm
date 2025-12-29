# sb::Data - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Data;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.05';
# 0.05 [2006/11/07] changed load_as_hash to make it faster
# 0.04 [2006/11/04] changed add and reduce to check class before loading / changed bracket rule
# 0.03 [2006/10/27] changed load to check class before loading
# 0.02 [2006/10/06] changed load to check class before loading
# 0.01 [2006/02/03] added reduce
# 0.00 [2005/02/02] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Language ();
use sb::Driver ();
# ==================================================
# // declaration for class member
# ==================================================
# ==================================================
# // public functions
# ==================================================
sub load
{
	my $class = shift() . '::' . shift();
	my $obj = &_alloc($class);
	return() if (!$obj);
	my %param = ( # input parameters
		'cond'   => {},     # condition to load
		'id'     => undef,  # indicated id => it will return data object with details
		'logic'  => 'and',  # logic for condition
		'bgn'    => 0,      # offset for range
		'num'    => -1,     # number of range
		'sort'   => 'id',   # sorting term
		'order'  => 0,      # sorting order [ descend or ascend ]
		'detail' => undef,  # flag for loading data objects with details
		'table'  => ['id'], # content table [ used for internal ]
		@_
	);
	$param{'table'} = [$obj->elements]; # initialize content table
	my @array = sb::Driver->get->load($class,%param);
	return  ($#array == 0) ?  $array[0] : @array;
}
sub load_as_hash
{
	my $class = shift;
	return map { $_->id => $_ } $class->load(@_);
}
sub matched
{
	return sb::Driver->get->matched_number;
}
sub update
{
	my $class = shift;
	my @objs  = @_; # objects to save
	sb::Driver->get->save(@objs);
}
sub add
{
	my $class = shift() . '::' . shift();
	my %param = @_;
	my $obj = &_alloc($class);
	return( undef ) if (!$obj);
	$param{'id'} = sb::Driver->get->new_id($class);
	$obj->add_new(%param);
	return( $obj );
}
sub reduce
{
	my $class = shift() . '::' . shift();
	if ($class->isa('sb::Data::Object'))
	{
		sb::Driver->get->decrement_id($class);
	}
	else
	{
		eval("require $class;");
		sb::Driver->get->decrement_id($class) if (!$@);
	}
}
# ==================================================
# // private functions
# ==================================================
sub _alloc
{
	my $class = shift;
	if ($class->isa('sb::Data::Object'))
	{
		return( $class->alloc() );
	}
	else
	{
		eval("require $class;");
		return( $class->alloc() ) if (!$@);
	}
	return( undef );
}
1; # end of package
