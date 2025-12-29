# sb::Admin::Refusal - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Admin::Refusal;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.02';
# 0.02 [2007/02/16] changed _open_refusal_setting to show conf_spamstat always
# 0.01 [2006/09/10] changed _save_refusal_setting and _open_refusal_setting to handle conf_spamstat
# 0.00 [2005/04/09] generate

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Data ();
use sb::Config ();
use sb::Interface ();
use sb::App::Admin ();
@ISA = qw( sb::App::Admin );
# ==================================================
# // declaration for constant value
# ==================================================
sub TEMPLATE (){ 'refusal.html' };
# ==================================================
# // public functions - callback
# ==================================================
sub callback
{
	my $self = shift;
	return ( $self->{'regi'} ) 
		? $self->_save_refusal_setting(@_)
		: $self->_open_refusal_setting(@_);
}
# ==================================================
# // private functions - main routine
# ==================================================
sub _save_refusal_setting
{
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $blog = sb::Data->load('Weblog','id'=>0);
	my $conf = sb::Config->get;
	my $cgi  = sb::Interface->get;
	my $lang = sb::Language->get;
	my @list = split("\n",$conf->value('conf_ip_ban'));
	SWITCH_MODE: {
		$_ = $self->{'regi'};
		/^spam$/ && do {
			$conf->value('conf_spamlevel'=>int($cgi->value('refuse_level')));
			$conf->value('conf_spamid'=>$cgi->value('refuse_cookie')) if ($cgi->value('refuse_cookie') ne '');
			if ($cgi->value('refuse_word') ne '')
			{
				$conf->value('conf_spamword'=>sb::Text->entitize($cgi->value('refuse_word')));
			}
			$conf->value('conf_spamstat' => ($cgi->value('refuse_status') eq '') ? 0 : 1 );
			$conf->value('conf_spamtb' => ($cgi->value('refuse_tb') eq '') ? 0 : 1 );
			last SWITCH_MODE;
		};
		/^addip$/ && do {
			if ($cgi->value('refuse_ip') ne '')
			{
				my $flag = undef;
				foreach (@list)
				{
					$flag = 1 if ($_ eq $cgi->value('refuse_ip'));
					last if ($flag);
				}
				unshift(@list,$cgi->value('refuse_ip')) if (!$flag);
				$conf->value('conf_ip_ban' => join("\n",@list));
			}
			last SWITCH_MODE;
		};
		/^delip$/ && do {
			my @new_list = ();
			foreach my $ip (@list)
			{
				my $flag = undef;
				foreach my $del ( split("\0",$cgi->value('sel')) )
				{
					$flag = 1 if ($ip eq $del);
					last if ($flag);
				}
				push(@new_list,$ip) if (!$flag);
			}
			$conf->value('conf_ip_ban' => join("\n",@new_list));
			last SWITCH_MODE;
		};
	}
	$conf->store;
	return $self->_open_refusal_setting('message'=>$lang->string('parts_confcomp'));
}
sub _open_refusal_setting
{
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi  = sb::Interface->get;
	my $cms  = sb::TemplateManager->new($self->load_template('file'=>TEMPLATE));
	my $conf = sb::Config->get;
	my @list = split("\n",$conf->value('conf_ip_ban'));
	my $path = $self->get_script_path . '?__mode=comment&amp;disptype=host&amp;dispword=';
	my $level = $conf->value('conf_spamlevel');
	$self->_count_comments;
	for (my $i=0;$i<@list;$i++)
	{
		my $chk = $list[$i];
		my $cnt = 0;
		foreach my $ip ( keys(%{$self->{'cnt'}}) )
		{
			$cnt += $self->{'cnt'}->{$ip} if ($ip =~ /^$chk/);
		}
		$cms->num($i);
		$cms->tag('sb_refuse_ip'=>$chk);
		$cms->tag('sb_refuse_com'=>($cnt > 0) ? '<a href="' . $path . $chk . '">' . $cnt . '</a>' : $cnt);
		$cms->tag('sb_list_class'=>($i % 2) ? 'odd' : 'even');
	}
	$cms->block('sb_refuse_list'=>($#list + 1));
	$cms->num(0);
	$cms->tag('sb_refuse_level_' . $level => 'selected="selected"');
	if ($level > -1)
	{
		$cms->tag('sb_refuse_status'=>'checked="checked"') if ($conf->value('conf_spamstat'));
		$cms->block('sb_refuse_status'=>1);
	}
	if ($level >= 3)
	{
		$cms->tag('sb_refuse_trackback'=>'checked="checked"') if ($conf->value('conf_spamtb'));
		$cms->block('sb_refuse_tb'=>1);
	}
	if ($level == 2)
	{
		$cms->tag('sb_refuse_cookie'=>sb::Text->entitize($conf->value('conf_spamid')));
		$cms->block('sb_refuse_cookie'=>1);
	}
	if ($level >= 4)
	{
		$cms->tag('sb_refuse_word'=>$conf->value('conf_spamword'));
		$cms->block('sb_refuse_word'=>1);
	}
	if ($param{'message'} ne '')
	{ # message
		$cms->num(0);
		$cms->tag('sb_process_message'=>$param{'message'});
		$cms->block('sb_refuse_message'=>1);
	}
	$self->common_template_parts($cms);
	return sb::Interface->get->head('type'=>'text/html') . $self->set_main($cms->output);
}
# ==================================================
# // private functions - for refusal setting
# ==================================================
sub _count_comments
{
	my $self = shift;
	$self->{'cnt'} = {};
	my @coms = sb::Data->load('Message');
	foreach my $com (@coms)
	{
		$self->{'cnt'}->{$com->host}++ if ($com->host ne '');
	}
	return;
}
1;
__END__
