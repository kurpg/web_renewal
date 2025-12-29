# sb::Data::Object - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Data::Object;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.03';
# 0.03 [2007/07/04] changed alloc to use new elements
# 0.02 [2005/10/20] changed alloc
# 0.01 [2005/08/23] changed alloc to be fast
# 0.00 [2005/02/02] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Text ();
# ==================================================
# // declaration for constant value
# ==================================================
sub TRUE  (){ 1 }
sub FALSE (){ 0 }
# ==================================================
# // constructor
# ==================================================
sub alloc
{
	my $class = shift;
	my $self  = {
		'trash_can' => FALSE,
		@_
	};
	bless($self,$class);
	no strict 'refs';
	my @elems = $class->elements();
	my $check = $elems[1]; # $elems[0] is always 'id', so we need to check second one.
	# create accessor functions when the first object is allocated.
	if ( $check ne '' and !defined(&{$class . '::' . $check}) )
	{
		foreach my $member ( @elems )
		{
			next if ($member eq 'id' or $member eq 'url' or $member eq 'mail'); # reserved
			unless ( defined(&{$class . '::' . $member}) )
			{
				*{$class . '::' . $member} = sub {
					my $self = shift;
					$self->{$member} = shift if @_;
					$self->{$member};
				};
			} # end of unless ( defined(&{$class . '::' . $member}) )
		} # end of foreach my $member ( @{$self->{'content_list'}} )
	} # end of if ( $check ne '' and !defined(&{$class . '::' . $check}) )
	return($self);
}
sub add_new
{
	my $self  = shift;
	my %param = @_;
	$self->{'id'} = $param{'id'};
	$self->initialize(%param);
	return($self);
}
# ==================================================
# // public functions - common method
# ==================================================
sub existed
{
	my $self = shift;
	return( $self->{'id'} ne '' );
}
sub elements
{
	my $self = shift;
	my @default = ('id');
	return( @default );
}
sub erase
{
	my $self = shift;
	return if ( !$self->existed );
	foreach my $elem ( $self->elements() )
	{
		next if ($elem eq 'id');
		$self->{$elem} = undef;
	}
	$self->{'trash_can'} = TRUE;
}
sub erased
{
	my $self = shift;
	return( $self->{'trash_can'} );
}
sub initialize
{
	my $self = shift;
	my %param = @_;
	foreach my $key ( keys(%param) )
	{
		next if ( $key eq 'id' );
		next if ( !grep($key,$self->elements()) );
		$self->{$key} = $param{$key};
	}
	return();
}
# ==================================================
# // public functions - accessor
# ==================================================
sub id
{ # read only
	my $self = shift;
	return( $self->{'id'} );
}
sub url
{
	my $self = shift;
	$self->{'url'} = shift if (@_);
	return &_check_url($self->{'url'}) ? $self->{'url'} : undef;
}
sub mail
{
	my $self = shift;
	$self->{'mail'} = shift if (@_);
	return &_check_mail($self->{'mail'}) ? $self->{'mail'} : undef;
}
sub entitize
{
	my $self = shift;
	my $key  = shift;
	return( undef ) if (!$key);
	return sb::Text->entitize($self->{$key});
}
# ==================================================
# // private functions
# ==================================================
sub _check_url
{
	return( $_[0] =~ /s?https?:\/\/[-_.!~*\'()a-zA-Z0-9;\/?:\@&=+\$,%#]+/ );
}
sub _check_mail
{
	return( $_[0] =~ /[\w=+\$%*-]+\@[^\s()\[\]{}!\"\'<>:,\x7f-\xff]+\.\w+/ );
}
1;
__END__
