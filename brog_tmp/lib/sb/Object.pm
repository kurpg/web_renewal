# sb::Object
# == Author(s) : Takuya Otani <takuya.otani@gmail.com> ==
# == Copyright (C) 2005 SimpleBoxes/SerendipityNZ Ltd. ==

# ======================================
package sb::Object;
use strict;
use vars qw( $VERSION );
$VERSION = '0.02';
# 0.02 [2006/03/17] changed bracket rule
# 0.01 [2006/03/16] changed sb::RequestObject to run on mod_perl2
# 0.00 [2005/10/09] created
# --------------------------------------
# // constructor
sub new
{
	my $class = shift;
	my $self = bless {}, $class;
	return $self->initialize(@_);
}
sub get
{
	my $class = shift;
	return $class->new(@_);
}
# --------------------------------------
# // destructor
sub DESTROY
{
	my $self = shift;
	undef;
}
# --------------------------------------
# // initializer
sub initialize
{
	my $self = shift;
	my %param = @_;
	while (my ($name,$value) = each(%param) )
	{
		$self->{$name} = $value;
	}
	return $self;
}
# --------------------------------------
# // public functions - class method
sub load_module
{
	my $class = shift;
	my $module = &module_name($class,@_);
	$module =~ s!::!/!g;
	eval { require "$module\.pm" };
	# eval("require $module;");
	return ($@) ? undef : 1;
}
sub module_name
{
	return join('::',@_);
}
sub generate_accessor
{
	my $self = shift;
	my @members = @_;
	my $class = ref($self) || $self;
	if ($class ne '')
	{
		no strict 'refs';
		foreach my $member ( @members )
		{
			unless ( defined(&{$class . '::' . $member}) )
			{
				*{$class . '::' . $member} = sub {
					my $self = shift;
					$self->{$member} = shift if @_;
					$self->{$member};
				};
			} # end of unless ( defined(&{$class . '::' . $member}) )
		} # end of foreach my $member ( @members )
	} # end of if ($class ne '')
	return $self;
}
# ======================================
package sb::SingleObject;
use base qw( sb::Object );
sub SINGLE_OBJECT_TAG (){ '_sb_instance' };
# --------------------------------------
# // constructor
sub new
{ # from Class::Singleton 1.03 / Copyright (C) 1998 Canon Research Centre Europe Ltd. 
	my $class = shift;
	no strict 'refs';
	my $object = $class . '::' . SINGLE_OBJECT_TAG;
	$$object = $class->SUPER::new(@_) unless ( defined( $$object ) );
	return $$object;
}
# ======================================
package sb::RequestObject;
use vars qw( $MODPERL );
use base qw( sb::Object );
sub REQUEST_OBJECT_TAG (){ 'sb_req_object_' };
# --------------------------------------
# // initializer
BEGIN
{ # RequestObject works as same as SingleObject under non-mod_perl.
	no strict 'refs';
	if ($ENV{'MOD_PERL'})
	{ # -- mod_perl environment
		eval{ require mod_perl2; };
		if (!$@)
		{ # Apache2 + mod_perl2
			require Apache2::RequestUtil;
			$MODPERL = 2;
		}
		else
		{ # Apache + mod_perl
			eval{ require mod_perl; };
			die('mod_perl or mod_perl2 is required to run:' . $@) if ($@);
			require Apache;
			$MODPERL = 1;
		}
		*sb::RequestObject::new = \&_construct_for_request;
	}
	else
	{
		*sb::RequestObject::new = \&sb::SingleObject::new;
	}
}
# --------------------------------------
# // constructor
sub _construct_for_request
{ # from Apache::Singleton 0.07 / Copyright (C) 2001-2004 Tatsuhiko Miyagawa
	my $class = shift;
	my $req = ($MODPERL == 2) 
		? Apache2::RequestUtil->request
		: Apache->request;
	my $key = REQUEST_OBJECT_TAG . $class;
	my $object = $req->pnotes($key);
	unless (defined $object)
	{
		$object = $class->SUPER::new(@_);
		$req->pnotes($key => $object);
	}
	return $object;
}
1; # end of module
__END__

=head1 NAME

sb::Object - base object

=head1 SYNOPSIS

 use sb::Object;
 my $obj = sb::Object->new;

=head1 DESCRIPTION

sb::Object provides simple base class of objects.

sb::Object contains sb::SingleObject and sb::RequestObject.

=head1 AUTHOR

Class::Singleton / Copyright (C) 1998 Canon Research Centre Europe Ltd.

Apache::Singleton / Copyright (C)  2001-2004 Tatsuhiko Miyagawa.

Code by Takuya Otani E<lt>takuya.otani@gmail.comE<gt> http://serennz.cool.ne.jp/snz/

=head1 LICENSE

Copyright (C) 2005 Takuya Otani@SimpleBoxes / SerendipityNZ Ltd.

=head1 SEE ALSO

L<Class::Singleton>, L<Apache::Singleton>

=cut
