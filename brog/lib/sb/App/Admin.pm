# sb::App::Admin - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::App::Admin;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.06';
# 0.06 [2006/02/03] changed %mAdminMode to enable rebuild menu for normal user
# 0.05 [2005/08/12] chnaged _check_mode to create session instance with name
# 0.04 [2005/08/11] changed _check_mode to check permission at proper timing
# 0.03 [2005/07/12] changed %mAdminMode to display help
# 0.02 [2005/07/11] changed config variable "srv_cgi" to "conf_srv_cgi"
# 0.01 [2005/06/07] changed set_main/_set_title/_set_menu to implement bookmarklet
# 0.00 [2004/02/01] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Interface ();
use sb::Language ();
use sb::Config ();
use sb::Plugin ();
use sb::TemplateManager ();
use sb::Session ();
use sb::Lock ();
use sb::App ();
@ISA = qw( sb::App );
# ==================================================
# // declaration for constant value
# ==================================================
sub JS_NAME         (){ 'script.js' };
sub TEMPLATE        (){ 'main.html' };
sub PROCESS_TEMP    (){ 'process.html' };
sub COOKIE_USER     (){ 'user' };
sub COOKIE_FOR_LOG  (){ 365 };
sub CATEGORY_OPTION (){ '%Main% &gt; %Sub%' };
sub EXTRA_CSSPREFIX (){ 'ext_' };
sub EXTRA_STYLE     (){ '<link rel="stylesheet" type="text/css" href="%s" title="default" media="screen,tv" />' };
# ==================================================
# // declaration for class member
# ==================================================
my @mMenuStructure = ('head','edit','manage','setup','util');
my %mAdminMode = (
	'new'       => {'module'=>'Entry',      'level'=>0,'help'=>'_entry',},
	'edit'      => {'module'=>'Entry',      'level'=>0,'help'=>'_entry',},
	'list'      => {'module'=>'List',       'level'=>0,'help'=>'_entry',},
	'category'  => {'module'=>'Category',   'level'=>1,'help'=>'_category',},
	'upload'    => {'module'=>'Upload',     'level'=>0,'help'=>'_menu4',},
	'amazon'    => {'module'=>'Amazon',     'level'=>0,'help'=>'_aws',},
	'link'      => {'module'=>'Link',       'level'=>1,'help'=>'_menu6',},
	'profile'   => {'module'=>'Profile',    'level'=>0,'help'=>'_menu7',},
	'comment'   => {'module'=>'Message',    'level'=>0,'help'=>'_comment',},
	'trackback' => {'module'=>'Trackback',  'level'=>0,'help'=>'_comment',},
	'refuse'    => {'module'=>'Refusal',    'level'=>1,'help'=>'_comment3',},
	'user'      => {'module'=>'User',       'level'=>2,'help'=>'_menu11',},
	'rebuild'   => {'module'=>'Rebuild',    'level'=>0,'help'=>'_menu12',},
	'template'  => {'module'=>'Template',   'level'=>1,'help'=>'_menu13',},
	'editor'    => {'module'=>'Editor',     'level'=>0,'help'=>'_menu14',},
	'config'    => {'module'=>'Config',     'level'=>1,'help'=>'_menu15',},
	'status'    => {'module'=>'Status',     'level'=>0,'help'=>'_',},
	'help'      => {'module'=>'Help',       'level'=>0,'help'=>'_',},
	'bm'        => {'module'=>'Bookmarklet','level'=>0,'help'=>'_',},
	'view'      => {'module'=>'Preview',    'level'=>0,'help'=>'_',},
	'login'     => {'module'=>'Login',      'level'=>0,'help'=>'_',},
	'logout'    => {'module'=>'Login',      'level'=>0,'help'=>'_',},
	'edittemp'  => {'module'=>'Template',   'level'=>1,'help'=>'_menu13',},
	'edituser'  => {'module'=>'Profile',    'level'=>2,'help'=>'_menu7',},
);
my %mAdminMenu = (
	$mMenuStructure[0] => ['edittemp','status','logout',],
	$mMenuStructure[1] => ['new','list','category','upload','amazon','link','profile',],
	$mMenuStructure[2] => ['comment','trackback','refuse','user','rebuild'],
	$mMenuStructure[3] => ['template','editor','config',],
	$mMenuStructure[4] => [],
);
# ==================================================
# // constructor
# ==================================================
sub new { # 管理画面初期化
	my $class = shift;
	my $self  = {
		'time'    => undef, # [required][NUM.] 現時刻
		'users'   => {},    # [required][HASH] ユーザーデータ
		'mode'    => undef, # [required][CHAR] モード名
		'user'    => undef, # [optional][CHAR] カレントユーザー
		'regi'    => undef, # [optional][SEL.] 登録モード
		'session' => undef, # [optional][CHAR] セッション ID
		@_
	};
	if ($self->{'regi'}) {
		$self->{'lock'} = sb::Lock->lock or die(sb::Language->get->string('error_file_lock'));
	} else {
		$self->{'lock'} = undef;
	}
	return bless($self,$class);
}
# ==================================================
# // destructor
# ==================================================
sub bye { # 終了処理
	my $self = shift;
	$self->{'lock'}->unlock if ($self->{'lock'});
	$self = undef;
	return;
}
# ==================================================
# // public functions - main routine
# ==================================================
sub run { # 管理画面メインルーチン
	my $class = shift;
	my $self = $class->SUPER::new(
		'users'   => { sb::Data->load_as_hash('User') },
		'user'    => undef,
		'mode'    => undef,
		'regi'    => undef,
		'session' => undef,
		@_
	);
	sb::Plugin->load_admin_module('mode'=>\%mAdminMode,'menu'=>\%mAdminMenu);
	my $error = $self->_check_mode;
	my $admin = $self->_load_callback;
	if ( $admin ) {
		my $output;
		eval {
			$output = $admin->callback('message'=>$error);
		};
		$output = $self->_default_callback('message'=>$@) if ($@);
		print $output;
		$admin->bye;
	} else {
		print $self->_default_callback('message'=>sb::Language->get->string('error_unknown'));
	}
}
# ==================================================
# // public functions - utilities
# ==================================================
sub callback { # デフォルトコールバック
	my $self = shift;
	return $self->_default_callback(@_);
}
# ==================================================
# // public functions - template parts
# ==================================================
sub get_script_path { # 管理画面パス
	my $self = shift;
	my $path = sb::Config->get->value('conf_srv_cgi') . sb::Config->get->value('basic_admn');
	return($path);
}
sub get_parts_dir { # パーツディレクトリ
	my $self = shift;
	return( sb::Config->get->value('dir_temp') . sb::Language->get->code . '/' );
}
sub load_template { # テンプレートの読込み
	my $self = shift;
	my %param = (
		'file' => TEMPLATE,
		'dir'  => $self->get_parts_dir,
		@_
	);
	$self->SUPER::load_template(%param);
}
sub common_template_parts { # 共通パーツ設定
	my $self = shift;
	my $cms  = shift;
	return if (!$cms or !$self);
	$self->SUPER::common_template_parts($cms);
	$cms->tag('sb_site_cgi'=>$self->get_script_path);
	$cms->tag('sb_site_js'=>sb::Config->get->value('srv_temp') . sb::Language->get->code . '/' . JS_NAME);
	if ($self->{'user'} and $self->{'user'}->ad_css ne '') {
		my $ext = sb::Config->get->value('srv_temp') . sb::Language->get->code . '/' . EXTRA_CSSPREFIX;
		$cms->tag('sb_extra_style'=>"\n" . sprintf(EXTRA_STYLE,$ext . $self->{'user'}->ad_css . '.css'));
	}
	return;
}
sub process_message { # 処理通知画面
	my $self = shift;
	my $message = shift;
	my $cms = sb::TemplateManager->new($self->load_template('file'=>PROCESS_TEMP));
	$cms->num(0);
	$cms->tag('sb_process_message'=>$message);
	return sb::Interface->get->head('type'=>'text/html') . $self->set_main($cms->output);
}
sub set_main { # 管理画面共通パート出力
	my $self = shift;
	my $body = shift;
	my $cms = sb::TemplateManager->new($self->load_template);
	my $mode = $self->{'mode'};
	$mode = 'bm' if ($self->{'mode'} ne 'bm' and sb::Interface->get->value('bm') eq 'on');
	$self->common_template_parts($cms);
	$self->_set_menu($cms);
	$self->_set_title($cms);
	$cms->num(0);
	$cms->tag('sb_mainbody'=>$body);
	$cms->block('sb_mainbody'=>1) if ($mode ne 'bm');
	$cms->block('sb_bookmarklet'=>1) if ($mode eq 'bm');
	$cms->block('sb_login'=>0);
	return $cms->output;
}
sub create_category { # 新規カテゴリー追加
	my $self = shift;
	my %param = (
		'name' => undef, # [required][CHAR] カテゴリー名
		'main' => undef, # [optional][NUM.] 親カテゴリー
		'sub'  => undef, # [optional][SEL.] 子カテゴリとして作成？ 1 : yes
		'text' => undef, # [optional][CHAR] カテゴリー説明
		'num'  => 0,     # [optional][NUM.] 登録記事数の初期値
		@_
	);
	return( undef ) unless ( defined($param{'name'}) );
	my $chk_main = undef;
	if ($param{'sub'} and $param{'main'} ne '') {
		$chk_main = sb::Data->load('Category','id'=>$param{'main'});
		# $chk_main = undef if ($chk_main and $chk_main->main ne ''); # 二階層しか許さない場合
	}
	my @same_name = sb::Data->load('Category','cond'=>{'name'=>$param{'name'}});
	foreach my $chk_cat (@same_name) {
		return( $chk_cat ) if ($chk_main and $chk_cat->main eq $param{'main'}); # 同一子カテゴリー
		return( $chk_cat ) if (!$chk_main and $chk_cat->main eq ''); # 同一親カテゴリー
	}
	my $category = sb::Data->add('Category',
		'main' => ($chk_main) ? $chk_main->id : '',
		'name' => $param{'name'},
		'url'  => '',
		'text' => $param{'text'},
		'temp' => ($chk_main) ? $chk_main->temp : -1,   # 親カテゴリーの設定を引き継ぐ
		'dir'  => ($chk_main) ? $chk_main->dir : undef, # 親カテゴリーの設定を引き継ぐ
		'disp' => ($chk_main) ? $chk_main->disp : '',   # 親カテゴリーの設定を引き継ぐ
		'sub'  => '',
		'num'  => $param{'num'},
	);
	sb::Data->update($category);
	if ($chk_main) { # 子カテゴリーを作成するときは親カテゴリーも更新
		$chk_main->add_sub($category->id);
		sb::Data->update($chk_main);
	}
	return($category);
}
sub upload_image { # イメージアップロード
	my $self = shift;
	my %param = (
		'max'  => sb::Config->get->value('basic_max_img'),  # [optional][NUM.] 最大アップロード数
		'name' => sb::Config->get->value('conf_imagename'), # [optional][SEL.] flag for using fixed name
		'over' => undef,                                    # [optional][SEL.] flag for overwriting image
		@_
	);
	my $cgi = sb::Interface->get;
	my @upload = ();
	my @images = ();
	for (my $i=0;$i<$param{'max'};$i++) {
		push(@upload,$i) if ($cgi->value('upload_file' . $i) ne '');
	}
	my $id = ($self->{'user'}) ? $self->{'user'}->id : 0;
	my $img = sb::Data->add('Image','auth'=>$id);
	for (my $i=0;$i<=$#upload;$i++) {
		my $num = $upload[$i];
		my $check = $img->upload(
			'entity' => $cgi->value('upload_file' . $num),
			'label'  => 'upload_file' . $num,
			'dir'    => $cgi->value('upload_dir'),
			'thumb'  => $cgi->value('upload_thumb'),
			'header' => [ $cgi->content_list ],
			'name'   => $cgi->value('upload_name' . $num),
			'fixed'  => $param{'name'},
			'over'   => $param{'over'},
		);
		if ( $check ) {
			$img->date($self->{'time'});
			$img->tz(sb::Config->get->value('conf_timezone'));
			push(@images,$img);
		}
		$img = sb::Data->add('Image','auth'=>$id) if ($check and $i < $#upload);
	}
	sb::Data->update(@images) if ( @images );
	return( $#images + 1 );
}
# ==================================================
# // private functions - callback
# ==================================================
sub _default_callback { # デフォルトコールバック
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	return $self->error( $param{'message'} );
}
sub _load_callback { # 管理画面コールバック読込み
	my $self = shift;
	my $mode  = $mAdminMode{$self->{'mode'}}->{'module'};
	my $class = undef;
	if ( $mode ) {
		$class = 'sb::Admin::' . $mode;
		eval("require $class");
	} else {
		$class = $mAdminMode{$self->{'mode'}}->{'class'};
	}
	if ($class) {
		return $class->new(
			'time'    => $self->{'time'},
			'mode'    => $self->{'mode'},
			'regi'    => $self->{'regi'},
			'user'    => $self->{'user'},
			'users'   => $self->{'users'},
			'session' => $self->{'session'},
		);
	}
	return( undef );
}
# ==================================================
# // private functions - template parts
# ==================================================
sub _set_title { # タイトル表示
	my $self = shift;
	my $cms  = shift;
	return if (!$cms or !$self);
	my $product = $sb::PRODUCT;
	$product =~ s/[a-z ]//g;
	my $weblog = sb::Data->load('Weblog','id'=>0);
	my $name = '[' . $product . '] ' . $weblog->title  . ' | ';
	my $mode = $self->{'mode'};
	$cms->num(0);
	$mode = 'bm' if ($self->{'mode'} ne 'bm' and sb::Interface->get->value('bm') eq 'on');
	$cms->tag('sb_site_title'=>$name . sb::Language->get->string('mode_' . $mode));
	$cms->tag('sb_body_class'=>($mode ne 'bm') ? 'main' : 'bm');
	$cms->tag('sb_body_class'=>sb::Admin::Bookmarklet->set_onload) if ($self->{'mode'} eq 'bm');
	return();
}
sub _set_menu { # 管理画面メニュー
	my $self = shift;
	my $cms  = shift;
	my $path = $self->get_script_path;
	return() if ($self->{'mode'} eq 'bm' or sb::Interface->get->value('bm') eq 'on');
	foreach my $main ( @mMenuStructure ) {
		my @menus = @{$mAdminMenu{$main}};
		my $block = 'sb_' . $main . 'menu';
		my $num = 0;
		foreach my $menu ( @menus ) {
			next if (!$self->check_permission('level'=>$mAdminMode{$menu}->{'level'}));
			$cms->num($num);
			$cms->tag($block . '_on'=>($menu eq $self->{'mode'}) ? '_on' : '');
			$cms->tag($block . '_url'=>$path . '?__mode=' . $menu);
			$cms->tag($block . '_id'=>$menu);
			$cms->tag($block . '_name'=>sb::Language->get->string('mode_' . $menu));
			$num++;
		}
		$cms->block($block=>$num);
		$cms->block($block . '_body'=>1) if ($num > 0);
	}
	$cms->num(0);
	$cms->tag('sb_menu_view'=>$path . '?__mode=view');
	$cms->tag('sb_menu_help'=>$path . '?__mode=help&amp;help=' . $mAdminMode{$self->{'mode'}}->{'help'});
	$cms->block('sb_mainhead'=>1);
	return();
}
# ==================================================
# // private functions - others
# ==================================================
sub _check_mode { # ログインチェック
	my $self = shift;
	my $cgi  = sb::Interface->get;
	my $conf = sb::Config->get;
	my $lang = sb::Language->get;
	my $pass = $cgi->value('__pass');
	my $cookie = $cgi->cookie('name'=>$conf->value('basic_admntag') . COOKIE_USER);
	$self->{'mode'} = $cgi->value('__mode');
	$self->{'regi'} = $cgi->value('__regi');
	if ( $self->{'regi'} ne '' and $conf->value('basic_ref_check') ) { # リファラチェック
		$self->{'mode'} = 'login' if (index($cgi->value('_refe'),$self->get_script_path) == -1);
	}
	$self->{'mode'} = 'login' if ( !$self->{'mode'} ); # モードが空の場合
	return() if ( $self->{'mode'} eq 'login' and $pass eq '');
	my $name = ( $cgi->value('__user') ) ? $cgi->value('__user') : $cookie->{'user'};
	$cgi->set_cookie(
		'time'   => $self->{'time'},
		'name'   => $conf->value('basic_admntag') . COOKIE_USER,
		'expire' => $conf->value('basic_admn_expire'),
		'path'   => $conf->value('conf_srv_cgi'),
		'data'   => {'user' => $name},
	);
	my @usernames = keys( %{$self->{'users'}} );
	foreach my $id ( keys( %{$self->{'users'}} ) ) {
		my $user = $self->{'users'}->{$id};
		next if ( $user->name ne $name );
		my $session = sb::Session->new(
			'time'   => $self->{'time'},
			'key'    => $user->id,
			'path'   => $self->get_script_path,
			'name'   => $conf->value('basic_sessiontag'),
			'expire' => $conf->value('basic_admn_expire'),
		);
		$self->{'session'} = $session->id;
		$self->{'user'} = sb::Data->load('User','id'=>$user->id);
		if (!$self->check_permission('level'=>$mAdminMode{$self->{'mode'}}->{'level'}) ) { # 権限チェック
			$session->finish;
			$self->{'mode'} = 'login';
			return( $lang->string('error_not_allow') );
		}
		if ( $pass ne '' and $user->check_pass($pass) ) { # ログイン処理
			$session->start;
			$self->{'mode'} = 'status' if ($self->{'mode'} eq 'login' or $self->{'mode'} eq 'logout');
			$cgi->set_cookie(
				'time'   => $self->{'time'},
				'name'   => $conf->value('basic_logtag'),
				'expire' => COOKIE_FOR_LOG,
				'path'   => $conf->value('conf_srv_cgi'),
				'data'   => {'check' => $conf->value('basic_cookiekey')},
			);
			return();
		} elsif ( $pass ne '' ) {
			$session->finish;
			$self->{'mode'} = 'login';
			return( $lang->string('error_wrong_pass'));
		}
		if ( $self->{'mode'} eq 'logout' ) { # ログアウト処理
			$session->finish;
			$self->{'mode'} = 'login';
			return( $lang->string('parts_logout') );
		}
		if ( !$session->check ) { # 有効期間チェック
			$self->{'mode'} = 'login';
			return( $lang->string('error_expired') );
		}
		$session->start; # 有効期間の延長
		return();
	}
	$self->{'mode'} = 'login';
	$,="\n";
	return( $lang->string('error_no_user')."at Admin.pm:429\n".'mode='.$self->{'mode'}.', '.join(",",@usernames) );
}
1;
__END__
