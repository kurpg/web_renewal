# sb::App::Main - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::App::Main;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.08';
# 0.08 [2008/10/23] changed _check_mode to avoid unnecessary error screen for non-existed category
# 0.07 [2006/12/15] changed _check_mode to fix a bug
# 0.06 [2006/02/15] changed _check_mode to check chaging style correctly
# 0.05 [2005/10/19] changed _check_mode to check permission correctly
# 0.04 [2005/10/18] changed _check_mode to pass TemplateManager object instead of template contents.
# 0.03 [2005/08/23] changed _check_mode to change template correctly
# 0.02 [2005/07/11] changed config variable "srv_cgi" to "conf_srv_cgi"
# 0.01 [2005/07/08] changed run to set cookie correctly
# 0.00 [2005/02/01] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Interface ();
use sb::Config ();
use sb::Language ();
use sb::Data ();
use sb::TemplateManager ();
use sb::Content ();
use sb::Receipt ();
use sb::App ();
@ISA = qw( sb::App );
# ==================================================
# // public functions
# ==================================================
sub run { # main routine
	my $class = shift;
	my $self = $class->SUPER::new( @_ );
	my $conf = sb::Config->get();
	my $cgi  = sb::Interface->get;
	my ($mode,$base,$css,$id,$cond) = &_check_mode($cgi,$conf);
	if ($mode eq 'tb' or $mode eq 'com') { # receive a trackback or a comment
		print sb::Receipt->new(
			'mode' => $mode,
			'cgi'  => $cgi,
			'id'   => $id,
			'time' => $self->{'time'},
		)->issue;
	} else { # view mode
		my $cookie = $cgi->cookie('name'=>$conf->value('basic_cooktag'));
		$cookie->{'checkid'} = $conf->value('conf_spamid');
		$cgi->set_cookie(
			'time'   => $self->{'time'},
			'name'   => $conf->value('basic_cooktag'),
			'expire' => 8544, # 8544 = 365 days [memo] set the same as sb::Receipt temporarily
			'data'   => $cookie,
		);
		my $type = ($mode eq 'css') ? 'text/css' : 'text/html';
		my $page = int( $cgi->value('page') );
		print $cgi->head('type'=>$type);
		print sb::Content->output($base,
			'mode' => $mode,
			'css'  => $css,
			'id'   => $id,
			'page' => $page,
			'cond' => $cond,
			'time' => $self->{'time'},
		);
	}
}
# ==================================================
# // private functions
# ==================================================
sub _check_mode
{ # checking mode
	my ($cgi,$conf) = @_;            # input parameters
	my ($mode,$base,$css,$id,$cond); # output parameters
	my $ping = $cgi->value('tb');
	if ($cgi->value('_path') ne '')
	{
		$ping = $cgi->value('_path');
		$ping =~ s/.*[:\/\\](.*)/$1/;
	}
	$ping = '' if ($ping !~ /^\d+$/);
	my $cid = int($cgi->value('cid')) if ($cgi->value('cid') ne '');
	my $tid = int($cgi->value('tid')) if ($cgi->value('tid') ne '');
	$mode = 'ent'  if ($cgi->value('eid') =~ /^\d+$/);      # entry mode
	$mode = 'user' if ($cgi->value('pid') =~ /^\d+$/);      # profile mode
	$mode = 'cat'  if ($cid =~ /^\d+$/);                    # category mode
	$mode = 'arc'  if ($cgi->value('month') =~ /^\d+$/);    # monthly archive mode
	$mode = 'arc'  if ($cgi->value('day') =~ /^\d+$/);      # daily archive mode
	$mode = 'srch' if ($cgi->value('search') ne '');        # search
	$mode = 'css'  if ($cgi->value('css') =~ /^\d+$/);      # style sheet
	$mode = 'tb'   if ($ping ne '');                        # receiving a trackback
	$mode = 'com'  if ($cgi->value('entry_id') =~ /^\d+$/); # receiving a comment
	$mode = 'page' if ($mode eq '');                        # page mode (default)
	if ($mode eq 'tb' or $mode eq 'com')
	{
		$id = ($mode eq 'tb') ? $ping : int($cgi->value('entry_id'));
		return($mode,$base,$css,$id,$cond);
	}
	my $flag = 0; # flag for changing template
	if ( $mode eq 'ent' )
	{ # entry mode
		my $entry = sb::Data->load('Entry','id'=>$cgi->value('eid'));
		die(sb::Language->get->string('error_no_entry') . "\n") if (!$entry);
		$cid = $entry->cat;
		if ($entry->stat == 0)
		{
			my $cookie = $cgi->cookie('name'=>$conf->value('basic_logtag'));
			if ($cookie->{'check'} ne $conf->value('basic_cookiekey'))
			{
				die(sb::Language->get->string('error_no_entry') . "\n");
			}
		}
	}
	if ( $tid eq '' )
	{ # no specified template
		if ( $cid ne '' )
		{ # category mode
			my $category = sb::Data->load('Category','id'=>$cid);
			if ( !$category )
			{
				$mode = 'page';
				$cid = '';
			}
			elsif ( $category->temp ne '' and $category->temp > -1 )
			{
				$tid = $category->temp;
			}
		}
		if ( $tid eq '' )
		{ # archive or profile mode
			if ( ($mode eq 'srch' or $mode eq 'arc' or $mode eq 'cat') 
			 and $conf->value('conf_archive_temp') > -1)
			{
				$tid = $conf->value('conf_archive_temp');
			}
			elsif ($mode eq 'user' and $conf->value('conf_profile_temp') > -1)
			{
				$tid = $conf->value('conf_profile_temp');
			}
		}
		$tid = int($cgi->value('css')) if ( $mode eq 'css' );
		$flag = 1 if ($tid ne '');
	}
	my $temp = ($tid ne '') ? sb::Data->load('Template','id'=>$tid) : undef; # load template
	$temp = sb::Data->load('Template','id'=>sb::Data->load('Template','cond'=>{'use'=>1})->id) if (!$temp);
	die(sb::Language->get->string('error_unknown') . "\n") if (!$temp);
	# path of a css
	$css = $conf->value('conf_srv_base') . $conf->value('file_css');
	if ( $tid ne '' and (!$flag or $conf->value('conf_css_change')) )
	{
		$css = $conf->value('conf_srv_cgi') . $conf->value('basic_sb') . '?css=' . $tid;
	}
	# set a base
	if ($mode eq 'css')
	{
		$base = $temp->css;
	}
	else
	{
		$base = ($mode eq 'ent' and $temp->entry ne '') ? $temp->entry : $temp->main;
	}
	# id for entry, user, or category
	if ($mode eq 'ent')
	{
		$id = int($cgi->value('eid'));
	}
	elsif ($mode eq 'user')
	{
		$id = int($cgi->value('pid'));
	}
	elsif ($mode eq 'cat')
	{
		$id = int($cgi->value('cid'));
	}
	# condition for search or archive
	if ($mode eq 'arc')
	{
		$cond = ($cgi->value('month') ne '') ? int($cgi->value('month')) : int($cgi->value('day'));
	}
	elsif ($mode eq 'srch')
	{
		$cond = sb::Text->entitize($cgi->value('search'));
	}
	my $cms = sb::TemplateManager->new($base);
	return($mode,$cms,$css,$id,$cond);
}
1;
__END__
