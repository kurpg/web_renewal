# sb::Admin::Help - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Admin::Help;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.01';
# 0.01 [2005/07/11] changed config variable "srv_cgi" to "conf_srv_cgi"
# 0.00 [2005/04/09] generate

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Config ();
use sb::Language ();
use sb::Interface ();
use sb::App::Admin ();
@ISA = qw( sb::App::Admin );
# ==================================================
# // public functions - callback
# ==================================================
sub callback {
	my $self = shift;
	my $cgi = sb::Interface->get;
	my $conf = sb::Config->get;
	my $mode = $cgi->value('help');
	$mode =~ s/^_//;
	my $srv = ($conf->value('srv_doc') ne '') 
	        ? $conf->value('srv_doc') 
	        : $conf->value('conf_srv_cgi') . 'doc/';
	$srv .= sb::Language->get->code . '.html';
	return $cgi->head('location'=>($mode ne '') ? $srv . '#' . $mode : $srv);
}
1;
__END__
