# sb::Admin::Link - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Admin::Link;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.03';
# 0.03 [2005/07/20] changed _update_link to change group correctly, changed _is_editable to enter group screen
# 0.02 [2005/07/09] fixed a bug to display description of a link correctly
# 0.01 [2005/06/29] now, links can be grouped
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
sub TEMPLATE        (){ 'link.html' };
sub LIST_COLUMN     (){ 7 };
sub DENIED_CHECK    (){ '-' };
sub DEFAULT_COLUMN  (){ '-' };
sub DEFAULT_TARGET  (){ '_blank' }
sub LIST_GROUP_FORM (){ '<strong>%s</strong> (%d)' };
sub LIST_SITE_FORM  (){ '<a href="%s" target="_blank">%s</a>' };
sub ORDER_LEFT      (){ '<input type="submit" name="up%d" value="&#9650;" class="updown" />' };
sub ORDER_RIGHT     (){ '<input type="submit" name="dn%d" value="&#9660;" class="updown" />' };
sub ORDER_COLUMN    (){ '%s</td><td>%s' };
# ==================================================
# // declaration for class member
# ==================================================
# ==================================================
# // public functions - callback
# ==================================================
sub callback { # コールバック
	my $self = shift;
	return ($self->{'regi'}) 
		? $self->_update_link(@_) 
		: $self->_display_link_list(@_);
}
# ==================================================
# // private functions - main routine
# ==================================================
sub _update_link {
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi = sb::Interface->get;
	my $lang = sb::Language->get;
	my $msg  = '';
	if ($cgi->value('__regi') eq 'site' or $cgi->value('__regi') eq 'group') { # リンク・グループの追加/編集
		my %elem = ();
		my $target = undef;
		$target = sb::Data->load('Link','id'=>$cgi->value('lid')) if ($cgi->value('lid') ne '');
		if ($cgi->value('__regi') eq 'site') {
			%elem = (
				'name'   => sb::Text->entitize($cgi->value('link_name')),   # サイト名
				'url'    => $cgi->value('link_url'),                        # アドレス
				'text'   => sb::Text->entitize($cgi->value('link_text')),   # 説明
				'target' => sb::Text->entitize($cgi->value('link_target')), # ターゲット指定
				'user'   => ( $self->{'user'} ) ? $self->{'user'}->id : 0,  # 作成者
				'type'   => $cgi->value('link_type'),                       # リンクタイプ
			);
		} else {
			%elem = (
				'name'   => sb::Text->entitize($cgi->value('link_group_name')), # グループ名
				'url'    => '',                                                 # アドレス
				'text'   => sb::Text->entitize($cgi->value('link_group_text')), # 説明
				'target' => '',                                                 # ターゲット指定
				'user'   => ( $self->{'user'} ) ? $self->{'user'}->id : 0,      # 作成者
				'type'   => '',                                                 # リンクタイプ
			);
		}
		if ($target) {
			foreach my $key (keys(%elem)) {
				$target->$key($elem{$key});
			}
			$msg = $lang->string('parts_editcomp');
		} else {
			$target = sb::Data->add('Link',%elem);
			$msg = $lang->string('parts_new_comp');
		}
		if ($target) {
			$target->set_as_group if ($cgi->value('__regi') eq 'group');
			sb::Data->update($target);
		} else {
			$msg = $lang->string('error_unknown');
		}
	} elsif ($cgi->value('action') ne '') { # リンク情報の一括変更
		my @sels = split("\0",$cgi->value('sel'));
		my @links = sb::Data->load('Link','cond'=>{'id'=>\@sels});
		my @del_group = ();
		ACTION_SWITCH: {
			$_ = $cgi->value('regi_action');
			/^del$/ && do { # 削除
				foreach my $lnk (@links) {
					push(@del_group,$lnk->id) if ($lnk->is_group);
					$lnk->erase;
				}
				last ACTION_SWITCH;
			};
			/^disp(\d)$/ && do { # 表示
				my $new = $1;
				foreach my $lnk (@links) {
					$lnk->disp($new);
				}
				last ACTION_SWITCH;
			};
			/^group(\d*)$/ && do { # グループ変更
				my $new = $1;
				foreach my $lnk (@links) {
					next if ($lnk->is_group);
					$lnk->type($new);
				}
				last ACTION_SWITCH;
			};
		};
		sb::Data->update(@links) if (@links);
		if (@del_group) { # グループが削除された場合
			my @change = sb::Data->load('Link','cond'=>{'type'=>\@del_group});
			foreach my $lnk (@change) {
				$lnk->type('');
			}
			sb::Data->update(@change) if (@change);
		}
		$msg = ($cgi->value('regi_action') eq 'del')
		     ? ($#links + 1) . $lang->string('parts_deleted')
		     : $lang->string('parts_editcomp');
	} else { # 並べ替え
		my @ids = split("\0",$cgi->value('sel_id'));
		my @links = sb::Data->load('Link','cond'=>{'id'=>\@ids});
		my @buf = sb::Data->load('Link','sort'=>'order','order'=>1); # 全リンクデータ読込み
		my @all = ();
		my $target = undef;
		$target = sb::Data->load('Link','id'=>$cgi->value('lid')) if ($cgi->value('lid') ne '');
		if (!$target) { # id が指定されていない場合(デフォルト)
			foreach my $lnk (@buf) {
				push(@all,$lnk) if ($lnk->type !~ /^\d+$/);
			}
		} elsif ($target->is_group) { # グループが指定されている場合
			foreach my $lnk (@buf) {
				push(@all,$lnk) if ($lnk->type eq $target->id);
			}
		} else { # 個別リンクが指定されてしまっている
			return $self->_display_link_list('message'=>$lang->string('error_unknown'));
		}
		my $order = undef;
		foreach my $lnk (@links) {
			$order = $lnk if ($cgi->value('dn' . $lnk->id) ne '' or $cgi->value('up' . $lnk->id) ne '');
		}
		if ($order) {
			@links = $self->change_order(
				'data'      => \@all,
				'target'    => $order,
				'direction' => ($cgi->value('up' . $order->id) ne '') ? +1 : -1,
			);
		}
		sb::Data->update(@links) if (@links);
		$msg = $lang->string('parts_editcomp');
	}
	$self->build_list('link_list');
	return $self->_display_link_list('message'=>$msg);
}
sub _display_link_list {
	my $self = shift;
	my %param = (
		'message' => '',
		'setup'   => $self->setup_list,
		@_
	);
	$self->{'group'} = {};
	my $cgi = sb::Interface->get;
	my $cms = sb::TemplateManager->new($self->load_template('file'=>TEMPLATE));
	my @all = sb::Data->load('Link','sort'=>'order','order'=>1); # 全リンクデータ読込み
	my @links = ();
	my @group = ();
	my $target = undef;
	$target = sb::Data->load('Link','id'=>$cgi->value('lid')) if ($cgi->value('lid') ne '');
	foreach my $lnk (@all) { # グループの抜き出し処理
		push(@group,$lnk) if ($lnk->is_group);
		$self->{'group'}->{$lnk->type}++ if ($lnk->type =~ /^\d+$/);
	}
	if (!$target) { # id が指定されていない場合(デフォルト)
		foreach my $lnk (@all) {
			push(@links,$lnk) if ($lnk->type !~ /^\d+$/);
		}
	} elsif ($target->is_group) { # グループが指定されている場合
		foreach my $lnk (@all) {
			push(@links,$lnk) if ($lnk->type eq $target->id);
		}
	}
	if (!$target or $target->is_group) { # リスト表示
		my $mathed = @links;
		my $page = int($cgi->value('page'));
		$page = int($cgi->value('now_page')) + 1 if ( $cgi->value('next') ne '' );
		$page = int($cgi->value('now_page')) - 1 if ( $cgi->value('prev') ne '' );
		@links = splice(@links,$page * $param{'setup'}->{'dispnum'},$param{'setup'}->{'dispnum'});
		$cms->num(0);
		$cms->tag('page_now'=>$page);
		$cms->tag('sb_list_page'=>$self->display_pagelink( # ページリンク
				'mode'    => 'link',
				'column'  => LIST_COLUMN,
				'all'     => $mathed,
				'printed' => $#links + 1,
				'num'     => $param{'setup'}->{'dispnum'},
				'params'  => ['dispnum'],
			)
		);
		$self->dispnum_selector( # 表示数セレクタ
			'cms'  => $cms,
			'now'  => $param{'setup'}->{'dispnum'},
		);
		$self->listmain(
			'template' => $cms,
			'block'    => 'sb_link_list',
			'objects'  => \@links,
			'tags'     => {
				'sb_link_id'        => 'id',
				'sb_link_name'      => \&_display_name,
				'sb_link_edit'      => \&_is_editable,
				'sb_link_dispstat'  => \&_display_status,
				'sb_link_disp'      => 'disp',
				'sb_link_sel'       => \&_display_checkbox,
			},
		);
		my $end = int( $mathed / $param{'setup'}->{'dispnum'} );
		$end-- if ( $mathed % $param{'setup'}->{'dispnum'} == 0 and $mathed > 0);
		for (my $i=0;$i<@links;$i++) { # 並替用
			my $lcol = sprintf(ORDER_LEFT ,$links[$i]->id);
			my $rcol = sprintf(ORDER_RIGHT,$links[$i]->id);
			$lcol = DEFAULT_COLUMN if ($i == 0 and $page == 0);
			$rcol = DEFAULT_COLUMN if ($i == $#links and $page == $end );
			$cms->num($i);
			$cms->tag('sb_link_order'=>sprintf(ORDER_COLUMN,$lcol,$rcol));
		}
		if ($target) { # グループ表示
			$cms->num(0);
			$cms->tag('sb_link_groupname'=>$target->name);
			$cms->tag('sb_link_grouptext'=>$target->text);
			$cms->tag('sb_link_groupid'=>$target->id);
			$cms->tag('sb_link_navi'=>$target->name);
			$cms->tag('sb_link_typesel'=>$self->_group_selector('group'=>\@group,'now'=>$target->id));
			$cms->block('sb_link_oldgroup'=>1);
			if ($self->check_permission('user'=>$target->user)) {
				$cms->block('sb_link_oldgroup_button'=>1);
				$cms->block('sb_link_group_edit'=>1);
			}
		} else {
			$cms->num(0);
			$cms->tag('sb_link_typesel'=>$self->_group_selector('group'=>\@group));
			$cms->block('sb_link_newgroup'=>1);
			$cms->block('sb_link_group_edit'=>1);
		}
		$cms->num(0);
		$cms->tag('sb_link_typechange'=>$self->_group_selector('group'=>\@group,'label'=>'group'));
		$cms->tag('sb_link_sitetarget'=>DEFAULT_TARGET);
		$cms->block('sb_link_newsite'=>1);
		$cms->block('sb_link_group'=>1);
	} else { # 個別表示
		my $member = undef;
		my $navigation = '';
		if ($target->type =~ /^\d+$/) {
			foreach my $grp (@group) {
				if ($grp->id eq $target->type) {
					$navigation .= '<a href="' . $self->get_script_path . '?__mode=link&amp;';
					$navigation .= 'lid=' . $grp->id . '">' . $grp->name . '</a> &gt; ';
				}
			}
		}
		$cms->num(0);
		$cms->tag('sb_link_navi'       => $navigation . $target->name);
		$cms->tag('sb_link_sitename'   => $target->name);
		$cms->tag('sb_link_siteurl'    => $target->entitize('url'));
		$cms->tag('sb_link_sitetext'   => $target->text);
		$cms->tag('sb_link_sitetarget' => $target->target);
		$cms->tag('sb_link_typesel'    => $self->_group_selector('group'=>\@group,'now'=>$target->type));
		$cms->tag('sb_link_siteid'     => $target->id);
		$cms->block('sb_link_oldsite'=>1);
	}
	if ($param{'message'} ne '') { # 処理通知
		$cms->num(0);
		$cms->tag('sb_process_message'=>$param{'message'});
		$cms->block('sb_link_message'=>1);
	}
	$self->common_template_parts($cms);
	return sb::Interface->get->head('type'=>'text/html') . $self->set_main($cms->output);
}
# ==================================================
# // private functions - for link list
# ==================================================
sub _group_selector {
	my $self = shift;
	my %param = (
		'group' => undef,
		'now'   => undef,
		'label' => '',
		@_
	);
	return( undef ) if (!$param{'group'});
	my $selector = '';
	foreach my $group ( @{$param{'group'}} ) {
		$selector .= '<option value="' . $param{'label'} . $group->id . '"';
		$selector .= ' selected="selected"' if ($param{'now'} eq $group->id);
		$selector .= '>' . $group->name . '</option>' . "\n";
	}
	return($selector);
}
sub _is_editable {
	my $self = shift;
	my $obj  = shift;
	my $url  = $self->get_script_path . '?__mode=link&amp;lid=' . $obj->id;
	return ($self->check_permission('user'=>$obj->user) or $obj->is_group) 
		? '<a href="' . $url . '">' . sb::Language->get->string('parts_tempedit') . '</a>' 
		: DENIED_CHECK;
}
sub _display_name {
	my $self = shift;
	my $obj  = shift;
	if ($obj->is_group) {
		return sprintf(LIST_GROUP_FORM,$obj->name,int($self->{'group'}->{$obj->id}));
	} else {
		return ($obj->url) ? sprintf(LIST_SITE_FORM,$obj->url,$obj->name) : $obj->name;
	}
}
sub _display_status {
	my $self = shift;
	my $obj  = shift;
	return $self->list_status(
		'stat'   => $obj->disp,
		'string' => sb::Language->get->string('setup_link_stat'),
	);
}
sub _display_checkbox {
	my $self = shift;
	my $obj  = shift;
	return ( $self->check_permission('user'=>$obj->user) )
	? '<input type="checkbox" name="sel" value="' . $obj->id . '" onclick="switchList(this)" />'
	: DENIED_CHECK;
}
1;
__END__
