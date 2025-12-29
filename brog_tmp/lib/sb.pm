# sb - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb;

use strict;

# ==================================================
# // Module version
# ==================================================
use vars qw( $VERSION $WEBPAGE $PRODUCT $BUILDNO @ISA );
$PRODUCT = 'Serene Bach';
$WEBPAGE = 'http://serenebach.net/';
$VERSION = '2.25R';
$BUILDNO = 'SB225_20170626';
# 2.24R [2012/06/03] fixed a bug in sb::Interface
# 2.23R [2010/05/23] fixed a bug in lib/resource for IE8
# 2.22R [2010/05/09] fixed a bug in sb::Aws
# 2.21R [2009/06/06] fixed a bug in sb::Session
# 2.20R [2008/11/01] fixed a bug in sb::App::Main
# 2.19R [2007/11/02] fixed a bug in sb::Admin::help
# 2.18R [2007/10/28] fixed a bug in sb::Aws
# 2.17R [2007/07/27] fixed a bug in sb::Aws
# 2.16D [2007/07/23] fixed a bug in sb::Mailer / applied ECS4.0 for sb::Aws
# 2.15D [2007/07/04] changed sb::Data::Object structure / added sb::Object
# 2.14D [2007/05/04] changed template package spec.
# 2.13D [2007/04/20] fixed some bugs
# 2.12R [2007/03/16] fixed some bugs
# 2.11R [2007/03/09] fixed some bugs
# 2.11D [2007/03/05] fixed some bugs
# 2.10D [2007/02/09] implemented some new features
# 2.09R [2007/01/02] fixed some bugs
# 2.08D [2006/11/17] fixed some bugs / optimized text-driver a bit
# 2.07D [2006/10/11] fixed some bugs
# 2.06D [2006/09/30] fixed some bugs / modified spam-checking feature
# 2.05R [2006/07/29] changed $WEBPAGE to apply new site address
# 2.04R [2006/02/16] fixed some bugs and added $BUILDNO
# 2.03R [2005/10/22] fixed some bugs
# 2.02R [2005/10/16] fixed some bugs
# 2.01R [2005/08/12] fixed some bugs
# 2.00R [2005/07/30] the first release version of Serene Bach!!
# 2.00b [2005/07/20] changed check_module to check install status
# 2.00b [2005/07/19] changed check_module to handle rebuild process on Admin
# 2.00b [2005/07/14] changed new to ignore loading Driver and Plugin during setup
# 2.00a [2005/06/06] fixed a bug to change app correctly
# 2.00a [2005/05/12] added INIT_FILE as constant value
# 2.00a [2005/04/28] added DESTROY to clean up
# 2.00a [2005/03/02] added $PRODUCT, $WEBPAGE
# 2.00a [2005/02/05] added new as constructor to use stand-alone application
# 2.00a [2005/02/01] added check_module
# 2.00a [2004/11/17] generated ... oh, it's my birthday.

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Config ();
use sb::Language ();
use sb::Interface ();
use sb::Plugin ();
use sb::Driver ();
use sb::App ();
# ==================================================
# // declaration for constant value
# ==================================================
sub TEMPFILE1 (){ 'install.tmp' };
sub TEMPFILE2 (){ 'upgrade.tmp' };
sub INIT_FILE (){ 'init.cgi' }; # default config file is 'init.cgi'
# ==================================================
# // constructor
# ==================================================
sub new
{
	my $class = shift;
	my $self = { 'config' => INIT_FILE, @_ };                # set config file
	my $conf = sb::Config->new('config'=>$self->{'config'}); # load config module
	sb::Language->new($conf->value('conf_lang'));            # load language module
	if ($self->{'app'} ne 'Install')
	{
		sb::Driver->new($conf->value('conf_dbtype'));        # load file driver
		sb::Plugin->new('dir'=>$conf->value('dir_plugin'));  # load plugin manager
	}
	return bless($self,$class);
}
# ==================================================
# // destructor
# ==================================================
sub DESTROY
{ # cleaning up ...
	my $self = shift;
	sb::Interface->bye;
	sb::Plugin->bye;
	sb::Driver->bye;
	sb::Language->bye;
	sb::Config->bye;
	return();
}
# ==================================================
# // public functions - class method
# ==================================================
sub run
{ # running the application as CGI
	my $class = shift;
	my %param = ( 'app' => 'Main', @_ ); # default running module is 'Main'
	my $now   = time(); # store current GMT time
	my $app   = ref($class) ? $class : $class->new(%param);
	my $cgi   = sb::Interface->new('max_data'=>sb::Config->get->value('basic_max_data'));
	eval
	{ # main routine
		$app->check_module($cgi);
		my $module = 'sb::App::' . $app->{'app'};
		eval("require $module;") if (!$module->isa('sb::App'));
		$module->run('time'=>$now);
	};
	print sb::App->error($@) if ($@);
	return();
}
# ==================================================
# // public functions - instance method
# ==================================================
sub check_module
{ # module checker
	my $self = shift;
	my $cgi  = shift;
	if ($self->{'app'} eq 'Admin')
	{
		if ($cgi->value('__rebuild') ne '')
		{
			$self->{'app'} = 'Builder';
		}
		elsif ($cgi->xmlflag)
		{
			$self->{'app'} = 'Xmlrpc';
		}
	}
	elsif ($self->{'app'} eq 'Main')
	{
		if (sb::Config->get->value('basic_mobswitch') ne '')
		{
			my $ua_check = sb::Config->get->value('basic_mobswitch');
			$self->{'app'} = 'Mobile' if ($cgi->value('_agnt') =~ /^$ua_check/);
		}
		$self->{'app'} = 'Feed' if ($cgi->value('feed') ne '');
		$self->{'app'} = 'Rsd' if ($cgi->value('rsd') eq 'on');
	}
	if ($self->{'app'} ne 'Install')
	{
		my $dir = sb::Config->get->value('dir_data');
		die("not installed yet\n") if (-e $dir . TEMPFILE1 or -e $dir . TEMPFILE2);
	}
}
1;
__END__
