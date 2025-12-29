# sb::Admin::Trackback - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Admin::Trackback;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.04';
# 0.04 [2007/04/25] changed _change_trackback_status to implement adding refusal feature
# 0.03 [2007/02/09] changed _change_trackback_status to handle 'closed' status
# 0.02 [2005/08/06] changed _clip_for_title and _display_entry to display list correctly
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
sub TEMPLATE     (){ 'trackback.html' };
sub ITEM_LENGTH  (){ 13 };
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
		? $self->_change_trackback_status(@_) 
		: $self->_display_trackback_list(@_);
}
# ==================================================
# // private functions - main routine
# ==================================================
sub _change_trackback_status
{
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi = sb::Interface->get;
	my $lang = sb::Language->get;
	my @sels = ($cgi->value('bid') ne '') ? ($cgi->value('bid')) : split("\0",$cgi->value('sel'));
	my @tbs = sb::Data->load('Trackback','cond'=>{'id'=>\@sels},'detail'=>'on');
	my @eids = ();
	ACTION_SWITCH: {
		$_ = $cgi->value('regi_action');
		/^del$|^refuse$/ && do { # delete
			my $flag = ($_ eq 'refuse');
			my @list = split("\n",sb::Config->get->value('conf_ip_ban'));
			foreach my $tb (@tbs)
			{
				push(@list,$tb->host) if ($flag);
				push(@eids,$tb->eid);
				$tb->erase;
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
			foreach my $tb (@tbs)
			{
				push(@eids,$tb->eid);
				$tb->stat($new);
			}
			last ACTION_SWITCH;
		};
	};
	sb::Data->update(@tbs) if (@tbs);
	$self->update_entry_attachment(@eids);
	$self->build_list('recent_trackback_list');
	return ($cgi->value('regi_action') eq 'del' or $cgi->value('regi_action') eq 'refuse')
		? $self->_display_trackback_list('message'=>($#tbs + 1) . $lang->string('parts_deleted'))
		: $self->_display_trackback_list('message'=>$lang->string('parts_editcomp'));
}
sub _display_trackback_list
{
	my $self = shift;
	my %param = (
		'message' => '',
		'setup'   => $self->setup_list,
		'bid'     => undef,
		@_
	);
	my $cgi = sb::Interface->get;
	my $cms = sb::TemplateManager->new($self->load_template('file'=>TEMPLATE));
	my $dispsort = ( $cgi->value('dispsort') ne '' ) ? $cgi->value('dispsort') : 'date';
	my $page = int($cgi->value('page'));
	$page = int($cgi->value('now_page')) + 1 if ( $cgi->value('next') ne '' );
	$page = int($cgi->value('now_page')) - 1 if ( $cgi->value('prev') ne '' );
	$self->{'bid'} = ( $cgi->value('bid') ne '' and $cgi->value('regi_action') ne 'del') 
	               ? $cgi->value('bid') 
	               : undef;
	my @tb = sb::Data->load('Trackback',
		'sort'  => $dispsort,
		'order' => 1,
		'id'    => $self->{'bid'},
		'num'   => $param{'setup'}->{'dispnum'},
		'bgn'   => $page * $param{'setup'}->{'dispnum'},
		'cond'  => $self->_generate_condition,
	);
	$cms->num(0);
	$cms->tag('sb_list_page'=>$self->display_pagelink( # pagelink
			'mode'    => 'trackback',
			'column'  => LIST_COLUMN,
			'all'     => sb::Data->matched,
			'printed' => $#tb + 1,
			'num'     => $param{'setup'}->{'dispnum'},
			'params'  => ['dispsort','disptype','dispword','dispdate','dispnum'],
		)
	);
	$self->dispnum_selector( # selector for number
		'cms' => $cms,
		'now' => $param{'setup'}->{'dispnum'},
	);
	$self->monthly_selector( # selector monthly
		'cms'  => $cms,
		'tag'  => 'sb_trackback_dispdate',
		'data' => 'Trackback',
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
		'block'    => 'sb_trackback_list',
		'objects'  => \@tb,
		'tags'     => {
			'sb_tb_id'        => 'id',
			'sb_tb_name'      => \&_clip_for_title,
			'sb_tb_subj'      => \&_clip_for_subj,
			'sb_tb_entry'     => \&_display_entry,
			'sb_tb_date'      => 'date',
			'sb_tb_status'    => \&_display_message_status,
			'sb_tb_statclass' => 'stat',
			'sb_tb_sel'       => \&_display_checkbox,
		},
	);
	if ( $self->{'bid'} ne '' and $tb[0] )
	{
		$cms->num(0);
		my $date = sb::Time->format(
			'time' => $tb[0]->date,
			'form' => DATE_FORMAT,
			'zone' => $tb[0]->tz,
			'lang' => DATE_LANG,
		);
		my $entry = sb::Data->load('Entry','id'=>$tb[0]->eid);
		$cms->tag('sb_tb_one_id'   => $tb[0]->id);
		$cms->tag('sb_tb_one_name' => $tb[0]->name);
		$cms->tag('sb_tb_one_subj' => $tb[0]->subj_with_url);
		$cms->tag('sb_tb_one_body' => $tb[0]->formated_body);
		$cms->tag('sb_tb_one_date' => $date);
		$cms->tag('sb_tb_one_host' => $tb[0]->host);
		$cms->tag('sb_tb_one_entry'  => $self->clip_text(
			'text'   => $entry->subj,
			'length' => length($entry->subj),
			'base'   => '?__mode=edit&amp;eid=' . $entry->id,
			'user'   => $entry->auth,)
		);
	}
	$cms->num(0);
	$cms->tag('sb_dispword'=>sb::Text->entitize($cgi->value('dispword'))) if ($cgi->value('disptype') ne '');
	$cms->block('sb_trackback_select'=>($self->{'bid'} eq '') ? 1 : 0);
	$cms->block('sb_trackback_one'=>($self->{'bid'} eq '') ? 0 : 1);
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
# // private functions - for trackback list
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
		'base'   => '?__mode=edit&amp;eid=' . $entry->id . '#trackback',
		'user'   => $entry->auth,
	);
}
sub _display_message_status
{
	my $self = shift;
	return $self->SUPER::_display_message_status(@_);
}
sub _clip_for_title
{
	my $self = shift;
	my $obj  = shift;
	my $entry = sb::Data->load('Entry','id'=>$obj->eid);
	return $self->clip_text(
		'text'   => ($obj->name eq '') ? sb::Language->get->string('parts_noname') : $obj->name,
		'length' => ITEM_LENGTH,
		'base'   => '?__mode=trackback&amp;bid=' . $obj->id,
		'user'   => $entry->auth,
	);
}
sub _clip_for_subj
{
	my $self = shift;
	my $obj  = shift;
	return $self->clip_text(
		'text'   => $obj->subj,
		'length' => ITEM_LENGTH,
		'base'   => $obj->url,
		'target' => '_blank',
	);
}
sub _display_checkbox
{
	my $self = shift;
	my $obj  = shift;
	my $entry = sb::Data->load('Entry','id'=>$obj->eid);
	return ( $self->check_permission('user'=>$entry->auth) and $self->{'bid'} eq '' )
	? '<input type="checkbox" name="sel" value="' . $obj->id . '" onclick="switchList(this)" />'
	: DENIED_CHECK;
}
1;
__END__
