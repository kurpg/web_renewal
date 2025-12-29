# sb::Lock - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Lock;

use strict;
require 5.006;

# ==================================================
# // Module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.01';
# 0.01 [2005/03/01] added locked_open, new as constructor / changed lock
# 0.00 [2005/02/04] porting from sblock.pl

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Config ();
# ==================================================
# // declaration for constant value
# ==================================================
sub LOCK_SH (){ 1 }
sub LOCK_EX (){ 2 }
sub LOCK_NB (){ 4 }
sub LOCK_UN (){ 8 }
# ==================================================
# // constructor
# ==================================================
sub new {
	my $class = shift;
	my $self  = {
		'dir'       => sb::Config->get->value('dir_lock'),
		'basename'  => sb::Config->get->value('file_lock'),
		'timeout'   => 20,
		'trytime'   => 10,
		@_,
	};
	return bless($self,$class);
}
sub lock {
	my $class = shift;
	my $self  = $class->new(@_) if ( !ref($class) );
	return($self->_global_lock);
}
# ==================================================
# // destructor
# ==================================================
sub unlock {
	# from Perl memo http://www.din.or.jp/%7Eohzaki/perl.htm
	# Copyright (C) 1999-2004 OHZAKI Hiroki
	my $self = shift;
	rename($self->{'current'}, $self->{'path'});
	$self = undef; # DESTORY
}
# ==================================================
# // public functions
# ==================================================
sub locked_open {
	my $self   = shift;
	my $file   = shift;
	my $resize = shift;
	my $handle; # my $handle = local *FILE; # for before Perl 5.005
	open($handle, "+<$file") or return( undef );
	binmode($handle);
	eval{ flock($handle, LOCK_EX); };
	if ($@) {
		# If your platform does not support flock, please implement another EXCLUSIVE LOCK here.
		# However, this module is already implemented another lock as _global_lock.
		# So probably there is nothing to do anymore.
	}
	truncate($handle, 0) if (!$resize);
	return($handle);
}
# ==================================================
# // private functions
# ==================================================
sub _global_lock {
	# from Perl memo http://www.din.or.jp/%7Eohzaki/perl.htm
	# Copyright (C) 1999-2004 OHZAKI Hiroki
	my $self = shift;
	my $name = $self->{'basename'};
	$self->{'path'} = $self->{'dir'} . $self->{'basename'};
	for (my $i = 0; $i < $self->{'trytime'}; $i++, sleep 1) {
		return $self if (rename($self->{'path'}, $self->{'current'} = $self->{'path'} . time));
	}
	opendir(LOCKDIR, $self->{'dir'});
	my @filelist = readdir(LOCKDIR);
	closedir(LOCKDIR);
	foreach (@filelist) {
		if (/^$name(\d+)/) {
			return $self if (
				time - $1 > $self->{'timeout'} 
				and rename($self->{'dir'} . $_, $self->{'current'} = $self->{'path'} . time)
			);
			last;
		}
	}
	return( undef );
}
1;
__END__
=head1 NAME

sb::Lock - file lock module for sb

=head1 SYNOPSIS

	use sb::Lock;
	my $lock = sb::Lock->lock('dir'=>'./lock/','basename'=>'lock');
	# something to do....
	$lock->unlock;

=head1 AUTHOR

Takuya Otani http://serenebach.net/
Original Script by OHZAKI Hiroki http://www.din.or.jp/~ohzaki/perl.htm

=head1 LICENSE

Copyright (C) 1999-2004 OHZAKI Hiroki
Copyright (C) 2004- T.Otani@SimpleBoxes and SerendipityNZ

=cut
