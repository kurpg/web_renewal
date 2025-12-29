# sb::Session - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Session;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.02';
# 0.02 [2009/05/27] modified id to generate random strings
# 0.01 [2005/04/18] changed how to check session
# 0.00 [2005/03/15] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Interface ();
use sb::Data ();
# ==================================================
# // declaration for constant value
# ==================================================
sub DEFAULT_EXPIRES (){ 1 };
sub COOKIENAME      (){ 'sb_session' };
sub HOURS_PER_DAY   (){ 24 };
sub SECS_PER_HOUR   (){ 3600 };
# ==================================================
# // constructor
# ==================================================
sub new { # constructor
	my $class = shift;
	my $self = {
		'key'    => undef,           # [required][CHAR] key for session
		'time'   => undef,           # [optional][NUM.] current time (UnixTime on GMT)
		'expire' => DEFAULT_EXPIRES, # [optional][NUM.] days for expires
		'name'   => COOKIENAME,      # [optional][CHAR] name for cookie
		'path'   => undef,           # [optional][URI.] path for cookie
		@_
	};
	$self->{'id'}     = undef; # session id
	$self->{'stored'} = undef; # stored session
	bless($self,$class);
	$self->_init;
	return $self;
}
# ==================================================
# // public functions
# ==================================================
sub id { # create session unique id
	my $self = shift;
	if ( !defined($self->{'id'}) ) {
		my @seeds = ('a'..'z','A'..'Z','0'..'9');
		$self->{'id'}  = $self->{'time'} . '_' . $$ . '_';
		$self->{'id'} .= join('',map { $seeds[ rand @seeds ] } 0 .. 20);
	}
	return $self->{'id'};
}
sub check { # check session
	my $self = shift;
	return( defined($self->{'stored'}) );
}
sub start { # start session
	my $self = shift;
	$self->_set_data($self->id);
	sb::Interface->get->set_cookie(
		'time'   => $self->{'time'},
		'name'   => $self->{'name'},
		'expire' => $self->{'expire'},
		'path'   => $self->{'path'},
		'data'   => {'id' => $self->id},
	);
	return();
}
sub finish { # finish session
	my $self = shift;
	$self->_set_data(0);
}
# ==================================================
# // private functions
# ==================================================
sub _init { # initialization
	my $self = shift;
	if ( defined($self->{'key'}) ) {
		$self->{'time'} ||= time(); # set the current time
		my $check_id = $self->_check_path || $self->_check_cookie;
		my $update_flag = undef;
		my @sessions = sb::Data->load('Session','cond'=>{'key'=>$self->{'key'}});
		foreach my $session ( @sessions ) {
			if ($check_id and $session->data eq $check_id) {
				$self->{'stored'} = $session;
			}
			if (!$session->check_expire('now'=>$self->{'time'},'duration'=>$self->_expire_time)) {
				$session->erase;
				$update_flag = 1;
			}
		}
		sb::Data->update(@sessions) if ($update_flag);
	} else {
		die("sb::Session : Need to set key\n");
	}
}
sub _expire_time { # calculate expire time [sec]
	my $self = shift;
	return( $self->{'expire'} * HOURS_PER_DAY * SECS_PER_HOUR );
}
sub _check_cookie { # read cookie data
	my $self = shift;
	my $cookie = sb::Interface->get->cookie('name'=>$self->{'name'});
	if ( $cookie->{'id'} ) {
		my $diff_time = $self->{'time'} - ( split('_',$cookie->{'id'}) )[0];
		return( undef ) if ( $diff_time > $self->_expire_time );
	}
	return( $cookie->{'id'} );
}
sub _check_path { # read path information
	my $self = shift;
	my $path = sb::Interface->get->value('_path');
	foreach my $dir ( split('\/',$path) ) {
		next if ($dir eq '');
		if ($dir =~ /^(\d+)_\d+$/) {
			my $diff_time = $self->{'time'} - $1;
			next if ( $diff_time > $self->_expire_time );
			return( $dir );
		}
	}
	return( undef );
}
sub _set_data { # update sb::Data::Session
	my $self = shift;
	my $data = shift;
	my $session = ( $self->{'stored'} ) 
	            ? $self->{'stored'} 
	            : sb::Data->add('Session','key'=>$self->{'key'});
	$session->data($data); # set data
	sb::Data->update($session);
}
1;
__END__
=head1 NAME

sb::Session - session management for sb

=head1 SYNOPSIS

	use sb::Session;
	my $session = sb::Session->new('key' => 'session_key');
	if ( $session->check ) {
		# session is valid
		$session->finish; # finishing session
	} else {
		# session is invalid
		$session->start; # starting session
	}

=head1 DESCRIPTION

sb::Session requires sb::Data::Session.
Session data is stored as sb::Data::Object.
Need to set 'key' to create session.
'key' indicates each session, so sb::Session allows multiple sessions.

=head1 AUTHOR

Takuya Otani http://serenebach.net/

=head1 LICENSE

Copyright (C) 2004- T.Otani@SimpleBoxes and SerendipityNZ

=cut
