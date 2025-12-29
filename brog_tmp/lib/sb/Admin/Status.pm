# sb::Admin::Status - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Admin::Status;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.01';
# 0.01 [2005/08/06] chnaged _clip_for_entry/comment/trackback to display list correctly
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
sub TEMPLATE    (){ 'status.html' };
sub ITEM_LENGTH (){ 12 };
sub STATUS_NUM  (){ 10 };
# ==================================================
# // declaration for class member
# ==================================================
# ==================================================
# // public functions - callback
# ==================================================
sub callback {
	my $self = shift;
	return $self->_open_status(@_);
}
# ==================================================
# // private functions - main routine
# ==================================================
sub _open_status {
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cms  = sb::TemplateManager->new($self->load_template('file'=>TEMPLATE));
	my $blog = sb::Data->load('Weblog','id'=>0);
	$cms->num(0);
	$cms->tag('sb_status_num'=>STATUS_NUM);
	$cms->tag('sb_blog_name'=>$blog->title);
	{ # エントリー[全体]
		$cms->num(0);
		sb::Data->load('Entry','cond'=>{'stat'=>0});
		$cms->tag('sb_entall_close'=>sb::Data->matched);
		my @entry = sb::Data->load('Entry',
			'sort'  => 'date',
			'order' => 1,
			'num'   => STATUS_NUM,
		);
		$cms->tag('sb_entall_num'=>sb::Data->matched);
		$self->listmain(
			'template' => $cms,
			'block'    => 'sb_status_entall_list',
			'objects'  => \@entry,
			'tags'     => {
				'sb_entall_subj' => \&_clip_for_entry,
				'sb_entall_date' => 'date',
				'sb_entall_stat' => \&_display_entry_status,
			},
		);
	}
	{ # エントリー[ユーザー]
		$cms->num(0);
		sb::Data->load('Entry','cond'=>{'auth'=>$self->{'user'}->id,'stat'=>0});
		$cms->tag('sb_entusr_close'=>sb::Data->matched);
		my @entry = sb::Data->load('Entry',
			'sort'  => 'date',
			'order' => 1,
			'cond'  => {'auth'=>$self->{'user'}->id},
			'num'   => STATUS_NUM,
		);
		$cms->tag('sb_entusr_num'=>sb::Data->matched);
		$self->listmain(
			'template' => $cms,
			'block'    => 'sb_status_entusr_list',
			'objects'  => \@entry,
			'tags'     => {
				'sb_entusr_subj' => \&_clip_for_entry,
				'sb_entusr_date' => 'date',
				'sb_entusr_stat' => \&_display_entry_status,
			},
		);
	}
	{ # コメント
		$cms->num(0);
		sb::Data->load('Message','cond'=>{'stat'=>0});
		$cms->tag('sb_com_close'=>sb::Data->matched);
		my @message = sb::Data->load('Message',
			'sort'  => 'date',
			'order' => 1,
			'num'   => STATUS_NUM,
		);
		$cms->tag('sb_com_num'=>sb::Data->matched);
		$self->listmain(
			'template' => $cms,
			'block'    => 'sb_status_com_list',
			'objects'  => \@message,
			'tags'     => {
				'sb_com_author' => \&_clip_for_comment,
				'sb_com_date'   => 'date',
				'sb_com_stat'   => \&_display_message_status,
			},
		);
	}
	{ # トラックバック
		$cms->num(0);
		sb::Data->load('Trackback','cond'=>{'stat'=>0});
		$cms->tag('sb_tb_close'=>sb::Data->matched);
		my @trackback = sb::Data->load('Trackback',
			'sort'  => 'date',
			'order' => 1,
			'num'   => STATUS_NUM,
		);
		$cms->tag('sb_tb_num'=>sb::Data->matched);
		$self->listmain(
			'template' => $cms,
			'block'    => 'sb_status_tb_list',
			'objects'  => \@trackback,
			'tags'     => {
				'sb_tb_name' => \&_clip_for_trackback,
				'sb_tb_date' => 'date',
				'sb_tb_stat' => \&_display_message_status,
			},
		);
	}
	return sb::Interface->get->head('type'=>'text/html') . $self->set_main($cms->output);
}
# ==================================================
# // private functions - for status screen
# ==================================================
sub _display_entry_status {
	my $self = shift;
	return $self->SUPER::_display_entry_status(@_);
}
sub _display_message_status {
	my $self = shift;
	return $self->SUPER::_display_message_status(@_);
}
sub _clip_for_entry {
	my $self = shift;
	my $obj  = shift;
	return $self->clip_text(
		'text'   => ($obj->subj eq '') ? sb::Language->get->string('parts_notitle') : $obj->subj,
		'length' => ITEM_LENGTH,
		'base'   => '?__mode=edit&amp;eid=' . $obj->id,
		'user'   => $obj->auth,
	);
}
sub _clip_for_comment {
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
sub _clip_for_trackback {
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
1;
__END__
