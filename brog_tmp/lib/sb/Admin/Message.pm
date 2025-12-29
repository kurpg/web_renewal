# sb::Admin::Message - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Admin::Message;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.04';
# 0.04 [2007/04/25] changed _change_message_status to implement adding refusal feature
# 0.03 [2007/02/09] changed _change_message_status to handle 'closed' status
# 0.02 [2005/08/06] changed _clip_for_comment and _display_entry to display list correctly
# 0.01 [2005/07/22] fixed a bug to change status correctly from detail screen
# 0.00 [2005/02/02] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Config ();
use sb::Language ();
use sb::Interface ();
use sb::TemplateManager ();
use sb::Data ();
use sb::Text ();
use sb::Admin::List ();
@ISA = qw( sb::Admin::List );
# ==================================================
# // declaration for constant value
# ==================================================
sub TEMPLATE     (){ 'message.html' };
sub ITEM_LENGTH  (){ 15 };
sub LIST_COLUMN  (){ 7 };
sub DENIED_CHECK (){ '-' };
sub NO_DATA      (){ '-' };
sub DATE_FORMAT  (){ '%YearShort%.%Mon%.%Day% %Hour%:%Min%' };
sub DATE_LANG    (){ 'en' };
# ==================================================
# // declaration for class member
# ==================================================
# ==================================================
# // public functions - callback
# ==================================================
sub callback
{
	my $self = shift;
	return ($self->{'regi'}) 
		? $self->_change_message_status(@_) 
		: $self->_display_message_list(@_);
}
# ==================================================
# // private functions - main routine
# ==================================================
sub _change_message_status
{
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi = sb::Interface->get;
	my $lang = sb::Language->get;
	my @sels = ($cgi->value('mid') ne '') ? ($cgi->value('mid')) : split("\0",$cgi->value('sel'));
	my @coms = sb::Data->load('Message','cond'=>{'id'=>\@sels},'detail'=>'on');
	my @eids = ();
	ACTION_SWITCH: {
		$_ = $cgi->value('regi_action');
		/^del$|^refuse$/ && do { # delete
			my $flag = ($_ eq 'refuse');
			my @list = split("\n",sb::Config->get->value('conf_ip_ban'));
			foreach my $com (@coms)
			{
				push(@list,$com->host) if ($flag);
				push(@eids,$com->eid);
				$com->erase;
			}
			if ($flag)
			{ # register IPs for refusal
				my %cnt;
				@list = grep(!$cnt{$_}++, @list);
				sb::Config->get->value('conf_ip_ban' => join("\n",@list));
				sb::Config->get->store();
			}
			last ACTION_SWITCH;
		};
		/^stat(\-1|\d)$/ && do { # change status
			my $new = $1;
			foreach my $com (@coms)
			{
				push(@eids,$com->eid);
				$com->stat($new);
			}
			last ACTION_SWITCH;
		};
	};
	sb::Data->update(@coms) if (@coms);
	$self->update_entry_attachment(@eids);
	$self->build_list('recent_comment_list');
	return ($cgi->value('regi_action') eq 'del' or $cgi->value('regi_action') eq 'refuse')
		? $self->_display_message_list('message'=>($#coms + 1) . $lang->string('parts_deleted'))
		: $self->_display_message_list('message'=>$lang->string('parts_editcomp'));
}
sub _display_message_list
{
	my $self = shift;
	my %param = (
		'message' => '',
		'setup'   => $self->setup_list,
		'mid'     => undef,
		@_
	);
	my $cgi = sb::Interface->get;
	my $cms = sb::TemplateManager->new($self->load_template('file'=>TEMPLATE));
	my $dispsort = ( $cgi->value('dispsort') ne '' ) ? $cgi->value('dispsort') : 'date';
	my $page = int($cgi->value('page'));
	$page = int($cgi->value('now_page')) + 1 if ( $cgi->value('next') ne '' );
	$page = int($cgi->value('now_page')) - 1 if ( $cgi->value('prev') ne '' );
	$self->{'mid'} = ( $cgi->value('mid') ne '' and $cgi->value('regi_action') ne 'del') 
	               ? $cgi->value('mid') 
	               : undef;
	my @com = sb::Data->load('Message',
		'sort'  => $dispsort,
		'order' => 1,
		'id'    => $self->{'mid'},
		'num'   => $param{'setup'}->{'dispnum'},
		'bgn'   => $page * $param{'setup'}->{'dispnum'},
		'cond'  => $self->_generate_condition,
	);
	$cms->num(0);
	$cms->tag('sb_list_page'=>$self->display_pagelink( # pagelink
			'mode'    => 'comment',
			'column'  => LIST_COLUMN,
			'all'     => sb::Data->matched,
			'printed' => $#com + 1,
			'num'     => $param{'setup'}->{'dispnum'},
			'params'  => ['dispsort','disptype','dispword','dispdate','dispnum'],
		)
	);
	$self->dispnum_selector( # selector for number
		'cms' => $cms,
		'now' => $param{'setup'}->{'dispnum'},
	);
	$self->monthly_selector( # selector for month
		'cms'  => $cms,
		'tag'  => 'sb_message_dispdate',
		'data' => 'Message',
	);
	foreach my $key ('dispsort','disptype')
	{ # selector for options
		$self->select_option(
			'cms'      => $cms,
			'tag'      => 'sb_' . $key . '_',
			'selected' => ($key eq 'dispsort') ? $dispsort : $cgi->value($key),
		);
	}
	$self->listmain(
		'template' => $cms,
		'block'    => 'sb_message_list',
		'objects'  => \@com,
		'tags'     => {
			'sb_com_id'        => 'id',
			'sb_com_author'    => \&_clip_for_comment,
			'sb_com_entry'     => \&_display_entry,
			'sb_com_date'      => 'date',
			'sb_com_ip'        => 'host',
			'sb_com_status'    => \&_display_message_status,
			'sb_com_statclass' => 'stat',
			'sb_com_sel'       => \&_display_checkbox,
		},
	);
	if ( $self->{'mid'} ne '' and $com[0] )
	{
		$cms->num(0);
		my $date = sb::Time->format(
			'time' => $com[0]->date,
			'form' => DATE_FORMAT,
			'zone' => $com[0]->tz,
			'lang' => DATE_LANG,
		);
		my $entry = sb::Data->load('Entry','id'=>$com[0]->eid);
		$cms->tag('sb_com_one_id'     => $com[0]->id);
		$cms->tag('sb_com_one_author' => $com[0]->auth ? $com[0]->auth : NO_DATA);
		$cms->tag('sb_com_one_mail'   => $com[0]->mail ? $com[0]->mail : NO_DATA);
		$cms->tag('sb_com_one_url'    => $com[0]->url  ? $com[0]->url  : NO_DATA);
		$cms->tag('sb_com_one_body'   => $com[0]->formated_body);
		$cms->tag('sb_com_one_date'   => $date);
		$cms->tag('sb_com_one_icon'   => $com[0]->icon_image);
		$cms->tag('sb_com_one_host'   => $com[0]->host);
		$cms->tag('sb_com_one_entry'  => $self->clip_text(
			'text'   => $entry->subj,
			'length' => length($entry->subj),
			'base'   => '?__mode=edit&amp;eid=' . $entry->id,
			'user'   => $entry->auth,)
		);
	}
	$cms->num(0);
	$cms->tag('sb_dispword'=>sb::Text->entitize($cgi->value('dispword'))) if ($cgi->value('disptype') ne '');
	$cms->block('sb_message_select'=>($self->{'mid'} eq '') ? 1 : 0);
	$cms->block('sb_message_one'=>($self->{'mid'} eq '') ? 0 : 1);
	$self->common_template_parts($cms);
	if ($param{'message'} ne '')
	{ # display message
		$cms->num(0);
		$cms->tag('sb_process_message'=>$param{'message'});
		$cms->block('sb_process_message'=>1);
	}
	return sb::Interface->get->head('type'=>'text/html') . $self->set_main($cms->output);
}
# ==================================================
# // private functions - for message list
# ==================================================
sub _generate_condition
{
	my $self = shift;
	my %cond = ();
	my $cgi  = sb::Interface->get;
	if ($cgi->value('dispword') ne '' and $cgi->value('disptype') ne '') {
		$cond{$cgi->value('disptype')} = '/' . $cgi->value('dispword') . '/';
	}
	if ($cgi->value('dispdate') ne '') {
		$cond{'date'} = $self->create_date_condition($cgi->value('dispdate'));
		$cond{'__range'} = { 'date' => 'tz' };
	}
	return \%cond;
}
sub _display_entry
{
	my $self = shift;
	my $obj  = shift;
	my $entry = sb::Data->load('Entry','id'=>$obj->eid);
	return $self->clip_text(
		'text'   => ($entry->subj eq '') ? sb::Language->get->string('parts_notitle') : $entry->subj,
		'length' => ITEM_LENGTH,
		'base'   => '?__mode=edit&amp;eid=' . $entry->id . '#comment',
		'user'   => $entry->auth,
	);
}
sub _display_message_status
{
	my $self = shift;
	return $self->SUPER::_display_message_status(@_);
}
sub _clip_for_comment
{
	my $self = shift;
	my $obj  = shift;
	my $entry = sb::Data->load('Entry','id'=>$obj->eid);
	return $self->clip_text(
		'text'   => ($obj->auth eq '') ? sb::Language->get->string('parts_noname') : $obj->auth,
		'length' => ITEM_LENGTH,
		'base'   => '?__mode=comment&amp;mid=' . $obj->id,
		'user'   => $entry->auth,
	);
}
sub _display_checkbox
{
	my $self = shift;
	my $obj  = shift;
	my $entry = sb::Data->load('Entry','id'=>$obj->eid);
	return ( $self->check_permission('user'=>$entry->auth) and $self->{'mid'} eq '' )
	? '<input type="checkbox" name="sel" value="' . $obj->id . '" onclick="switchList(this)" />'
	: DENIED_CHECK;
}
1;
__END__
