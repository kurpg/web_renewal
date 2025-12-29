# sb::Admin::User - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Admin::User;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.00';
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
use sb::Admin::Entry ();
@ISA = qw( sb::Admin::Entry );
# ==================================================
# // declaration for constant value
# ==================================================
sub TEMPLATE        (){ 'user.html' };
sub MAX_LEVEL       (){ 2 };
sub LIST_COLUMN     (){ 8 };
sub DENIED_CHECK    (){ '-' };
sub DEFAULT_COLUMN  (){ '-' };
sub ORDER_LEFT      (){ '<input type="submit" name="up%d" value="&#9650;" class="updown" />' };
sub ORDER_RIGHT     (){ '<input type="submit" name="dn%d" value="&#9660;" class="updown" />' };
sub ORDER_COLUMN    (){ '%s</td><td>%s' };
sub TEXT_PASSWORD   (){ '[password]' };
sub TEXT_NAME       (){ '[account name]' };
# ==================================================
# // declaration for class member
# ==================================================
# ==================================================
# // public functions - for sub class
# ==================================================
sub check_user {
	my $self = shift;
	my %param = (
		'name'       => undef,
		'pass'       => undef,
		'conf'       => undef,
		'check_pass' => 1,
		'check_name' => 1,
		@_
	);
	my $lang = sb::Language->get;
	if ($param{'check_pass'}) {
		return( $lang->string('error_wrong_text') . TEXT_PASSWORD ) if ($param{'pass'} !~ /^\w+$/);
		return( $lang->string('error_difference') ) if ($param{'pass'} ne $param{'conf'});
	}
	if ($param{'check_name'}) {
		my $check = sb::Data->load('User','cond'=>{'name'=>$param{'name'}});
		return( $lang->string('error_wrong_text') . TEXT_NAME ) if ($param{'name'} !~ /^[a-zA-Z0-9_\-\.]+$/);
		return( $lang->string('error_exist_user') ) if ($check);
	}
	return( undef );
}
# ==================================================
# // public functions - callback
# ==================================================
sub callback { # コールバック
	my $self = shift;
	return ($self->{'regi'}) 
		? $self->_update_user(@_) 
		: $self->_display_user_list(@_);
}
# ==================================================
# // private functions - main routine
# ==================================================
sub _update_user {
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi = sb::Interface->get;
	my $lang = sb::Language->get;
	my $msg  = '';
	if ($cgi->value('__regi') eq 'add') { # 追加
		$msg = $self->check_user(
			'name' => $cgi->value('user_name'),
			'pass' => $cgi->value('user_pass'),
			'conf' => $cgi->value('user_passconf'),
		);
		if (!$msg) {
			my $level = int($cgi->value('user_stat'));
			$level = 2 if ($level <= 0 or $level > MAX_LEVEL);
			my %elem = (
				'name' => $cgi->value('user_name'),                     # サイト名
				'mail' => sb::Text->entitize($cgi->value('user_mail')), # メールアドレス
				'real' => sb::Text->entitize($cgi->value('user_real')), # フルネーム
				'stat' => $level,                                       # アカウントレベル
			);
			my $new = sb::Data->add('User',%elem);
			$new->pass($cgi->value('user_pass'));
			sb::Data->update($new);
			$msg = $lang->string('parts_new_comp');
		} else {
			$self->{'user_error'} = 1; # ユーザー作成失敗時のフラグ
		}
	} elsif ( $cgi->value('del') ne '' ) { # 削除
		my @sels = split("\0",$cgi->value('sel'));
		my @users = sb::Data->load('User','cond'=>{'id'=>\@sels});
		foreach my $user (@users) {
			next if ($user->id eq '0');
			$user->erase;
		}
		sb::Data->update(@users) if (@users);
		$msg = ($#users + 1) . $lang->string('parts_deleted');
	} else { # 並び替え
		my @ids = split("\0",$cgi->value('sel_id'));
		my @users = sb::Data->load('User','cond'=>{'id'=>\@ids});
		my $order = undef;
		foreach my $user (@users) {
			$order = $user if ($cgi->value('dn' . $user->id) ne '' or $cgi->value('up' . $user->id) ne '');
		}
		if ($order) {
			@users = $self->change_order(
				'data'      => [ sb::Data->load('User','sort'=>'order','order'=>1,'detail'=>'on') ],
				'target'    => $order,
				'direction' => ($cgi->value('up' . $order->id) ne '') ? +1 : -1,
			);
			sb::Data->update(@users) if (@users);
			$msg = $lang->string('parts_editcomp');
		}
	}
	$self->build_list('user_list');
	return $self->_display_user_list('message'=>$msg);
}
sub _display_user_list {
	my $self = shift;
	my %param = (
		'message' => '',
		'setup'   => $self->setup_list,
		@_
	);
	my $cgi = sb::Interface->get;
	my $cms = sb::TemplateManager->new($self->load_template('file'=>TEMPLATE));
	my $page = int($cgi->value('page'));
	$page = int($cgi->value('now_page')) + 1 if ( $cgi->value('next') ne '' );
	$page = int($cgi->value('now_page')) - 1 if ( $cgi->value('prev') ne '' );
	my @users = sb::Data->load('User',
		'sort'  => 'order',
		'num'   => $param{'setup'}->{'dispnum'},
		'bgn'   => $page * $param{'setup'}->{'dispnum'},
		'order' => 1,
	);
	my $mathed = sb::Data->matched;
	$cms->num(0);
	$cms->tag('page_now'=>$page);
	$cms->tag('sb_list_page'=>$self->display_pagelink( # ページリンク
			'mode'    => 'user',
			'column'  => LIST_COLUMN,
			'all'     => $mathed,
			'printed' => $#users + 1,
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
		'block'    => 'sb_user_list',
		'objects'  => \@users,
		'tags'     => {
			'sb_userlist_id'   => 'id',
			'sb_userlist_name' => 'name',
			'sb_userlist_real' => 'real',
			'sb_userlist_mail' => 'mail',
			'sb_userlist_stat' => \&_display_status_mark,
			'sb_userlist_del'  => \&_display_checkbox,
			'sb_site_cgi'      => sub { $self->get_script_path },
		},
	);
	my $end = int( $mathed / $param{'setup'}->{'dispnum'} );
	$end-- if ( $mathed % $param{'setup'}->{'dispnum'} == 0 and $mathed > 0);
	for (my $i=0;$i<@users;$i++) { # 並替用
		my $lcol = sprintf(ORDER_LEFT ,$users[$i]->id);
		my $rcol = sprintf(ORDER_RIGHT,$users[$i]->id);
		$lcol = DEFAULT_COLUMN if ($i == 0 and $page == 0);
		$rcol = DEFAULT_COLUMN if ($i == $#users and $page == $end );
		$cms->num($i);
		$cms->tag('sb_userlist_order'=>sprintf(ORDER_COLUMN,$lcol,$rcol));
	}
	if ($self->{'user_error'}) { # もしユーザー作成に失敗していたら
		$cms->num(0);
		$cms->tag('sb_user_name'=>sb::Text->entitize($cgi->value('user_name'))) if ($cgi->value('user_name') ne '');
		$cms->tag('sb_user_mail'=>sb::Text->entitize($cgi->value('user_mail'))) if ($cgi->value('user_mail') ne '');
		$cms->tag('sb_user_real'=>sb::Text->entitize($cgi->value('user_real'))) if ($cgi->value('user_real') ne '');
	}
	if ($param{'message'} ne '') { # 処理通知
		$cms->num(0);
		$cms->tag('sb_process_message'=>$param{'message'});
		$cms->block('sb_user_message'=>1);
	}
	$self->common_template_parts($cms);
	return sb::Interface->get->head('type'=>'text/html') . $self->set_main($cms->output);
}
# ==================================================
# // private functions - for user list
# ==================================================
sub _display_checkbox {
	my $self = shift;
	my $obj  = shift;
	return ( $obj->id ne '0' )
	? '<input type="checkbox" name="sel" value="' . $obj->id . '" onclick="switchList(this)" />'
	: DENIED_CHECK;
}
sub _display_status_mark {
	my $self = shift;
	my $obj  = shift;
	return ($obj->stat eq '1') ? sb::Language->get->string('parts_advuser') : '';
}
1;
__END__
