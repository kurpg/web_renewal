# sb::Admin::Entry - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Admin::Entry;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.21';
# 0.21 [2007/05/04] changed _save_entry to check user 'imagetag' option uploading a file
# 0.20 [2007/02/15] changed _save_entry to output error message correctly
# 0.19 [2007/02/15] changed _save_entry to fix a bug
# 0.18 [2007/02/14] changed _save_entry to output ping error
# 0.17 [2006/02/16] changed _save_entry to update entry correctly
# 0.16 [2006/02/15] changed _save_entry to update entry correctly to avoid over-writing.
# 0.15 [2006/02/03] changed _save_entry to remain correct status of entry after uploading an image
# 0.14 [2006/02/01] changed _save_entry to check trackbak url and change sending trackabck timing properly
# 0.13 [2005/12/09] changed image_selector to display a list correctly
# 0.12 [2005/10/19] chnaged _clip_for_trackback/message to display list correctly
# 0.11 [2005/09/28] changed _save_entry to send trackback ping correctly
# 0.10 [2005/07/28] changed _save_entry to add text uploading file correctly
# 0.09 [2005/07/25] changed _open_entry to change opening related category field
# 0.08 [2005/07/17] changed _save_entry to change handling related categories
# 0.07 [2005/07/16] changed _build_files to change the order of building files
# 0.06 [2005/07/11] changed config variable "srv_cgi" to "conf_srv_cgi"
# 0.05 [2005/07/08] changed _save_entry to update "ping" correctly
# 0.04 [2005/06/29] changed image_selector to add new option
# 0.03 [2005/06/08] changed _open_entry to handle category addition form
# 0.02 [2005/06/07] changed _open_entry to implement bookmarklet
# 0.01 [2005/06/01] update instance variable after creating category
# 0.00 [2005/02/02] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Config ();
use sb::Language ();
use sb::Interface ();
use sb::Plugin ();
use sb::TemplateManager ();
use sb::Ping ();
use sb::Data ();
use sb::Build ();
use sb::Admin::List ();
@ISA = qw( sb::Admin::List );
# ==================================================
# // declaration for constant value
# ==================================================
sub TEMPLATE     (){ 'entry.html' };
sub ITEM_LENGTH  (){ 10 };
sub IMAGE_PREV   (){ '_parts/arrow_l.gif" width="20" height="10" alt="&lt;&lt;"' };
sub IMAGE_NEXT   (){ '_parts/arrow_r.gif" width="20" height="10" alt="&gt;&gt;"' };
sub IMAGE_BLANK  (){ '_parts/blank.gif" width="20" height="10" alt=""' };
sub DENIED_CHECK (){ '-' };
sub ZONE_LABEL   (){ 'UTC ' };
sub DATE_NAME    (){ 'entry_date' };
sub BODYROW_STD  (){ 15 };
sub BODYROW_EXT  (){ 25 };
sub TOOL1_ITEMS  (){ 9 };
sub TOOL2_ITEMS  (){ 16 };
sub TOOLSET_FILE (){ 'default_toolset.cgi' };
# ==================================================
# // declaration for class member
# ==================================================
my %mToolIcons = (
	'icons'   => [],
	'default' => {
		'opt' => '0000000001111111111111111111',
		'set' => "strong:strong\nem:em\np:p\nblockquote:quote\nul:ul\nli:li\np[class=&quot;note&quot;]:cust1\n:cust2\n:cust3",
		'img' => 'cust1',
	},
	'first'   => TOOL1_ITEMS,
	'second'  => TOOL2_ITEMS,
);
my @mScriptsForEntries = (
	'latest_entry_list','category_list','archives_list','calendar','calendar2','calendar_vertical','calendar_horizontal',
);
# ==================================================
# // public functions - for sub class
# ==================================================
sub default_tooloption {
	my $self = shift;
	return( $mToolIcons{$_[0]} );
}
sub display_toolicons { # ツールアイコン
	my $self = shift;
	my %param = (
		'cms'  => undef,
		'opt'  => $mToolIcons{'default'}->{'opt'},
		'set'  => $mToolIcons{'default'}->{'set'},
		'mode' => undef,
		'more' => undef,
		@_
	);
	$mToolIcons{'icons'} = [ $self->_load_toolset ];
	return( undef ) unless (defined($param{'cms'}));
	my sb::TemplateManager $cms = $param{'cms'};
	my @opts = split(//,$param{'opt'});
	my @sets = split(/\n/,$param{'set'});
	my $url = shift(@opts); # リンクボタン
	my $ent = shift(@opts); # 実体参照変換ボタン
	my $hig = shift(@opts); # 領域拡大縮小ボタン
	if ($param{'mode'} ne 'conf') {
		$cms->block('sb_entry_toolurl_body'=>($url == 0) ? 1 : 0);
		$cms->block('sb_entry_toolent_body'=>($ent == 0) ? 1 : 0);
		$cms->block('sb_entry_toolhig_body'=>($hig == 0) ? 1 : 0);
		if ($param{'more'}) {
			$cms->block('sb_entry_toolurl_more'=>($url == 0) ? 1 : 0);
			$cms->block('sb_entry_toolent_more'=>($ent == 0) ? 1 : 0);
			$cms->block('sb_entry_toolhig_more'=>($hig == 0) ? 1 : 0);
		}
	} else {
		$cms->num(0);
		$cms->tag('sb_entry_toolurl_check'=>($url == 0) ? 'checked="checked"' : '');
		$cms->tag('sb_entry_toolent_check'=>($ent == 0) ? 'checked="checked"' : '');
		$cms->tag('sb_entry_toolhig_check'=>($hig == 0) ? 'checked="checked"' : '');
	}
	my $num = 0;
	for (my $i=0;$i<$mToolIcons{'first'} + $mToolIcons{'second'};$i++) {
		my $label = ($i < $mToolIcons{'first'}) ? 'sb_entry_tool' : 'sb_entry_extool';
		my ($elem,$img) = split(':',$sets[$i],2);
		my $attr = '';
		if ($elem =~ /^(.*?)\[(.*?)\]$/) {
			$elem = $1;
			$attr = $2;
		}
		$img = $mToolIcons{'default'}->{'img'} if ($img eq '');
		$opts[$i] = 1 if ($param{'mode'} ne 'conf' and $elem eq '' and $attr eq '');
		$cms->num($num);
		$cms->tag($label . '_img'  => $img);
		$cms->tag($label . '_elem' => $elem);
		$cms->tag($label . '_opt'  => $attr);
		if ($param{'mode'} ne 'conf') {
			$cms->tag($label . '_alt'=>($attr eq '') 
				? '&lt;' . $elem . '&gt;' 
				: '&lt;' . $elem . ' ' . $attr . '&gt;'
			);
		} else {
			$cms->tag($label . '_num'=>$num);
			$cms->tag($label . '_check'=>($opts[$i] == 0) ? 'checked="checked"' : '');
			my $selector = '';
			for (my $j=0;$j<@{$mToolIcons{'icons'}};$j++) {
				$selector .= '<option value="' . $mToolIcons{'icons'}->[$j] . '"';
				$selector .= ' selected="selected"' if ($mToolIcons{'icons'}->[$j] eq $img);
				$selector .= '>' . $mToolIcons{'icons'}->[$j] . '</option>';
			}
			$cms->tag($label . 'icon_selector'=>$selector);
		}
		$num++ if ($opts[$i] == 0 or $param{'mode'} eq 'conf');
		if (  $i == $mToolIcons{'first'} - 1
		   or $i == $mToolIcons{'first'} + $mToolIcons{'second'} - 1) {
			if ($param{'mode'} ne 'conf') {
				$cms->block($label . '_body'=>$num);
				$cms->block($label . '_more'=>($param{'more'}) ? $num : 0);
				$cms->unifyFor('sb_site_template',$label . '_body');
			} elsif ($i == $mToolIcons{'first'} - 1) { # config mode 1st line
				$cms->block('sb_editor_tool_set'=>$num);
				$cms->unifyFor('sb_site_template','sb_editor_tool_set');
			} else { # config mode 2nd line
				$cms->block('sb_editor_extool_set'=>$num);
				$cms->unifyFor('sb_site_template','sb_editor_extool_set');
			}
			$num = 0;
		}
	}
}
sub timezone_selector { # タイムゾーンセレクタ
	my $self = shift;
	my %param = (
		'cms'     => undef,
		'tag'     => undef,
		'current' => sb::Config->get->value('conf_timezone'),
		@_
	);
	return( undef ) if (!defined($param{'cms'}) or !defined($param{'tag'}));
	my $cms = $param{'cms'};
	my ($hour,$min) = ( $param{'current'} =~ /([\+-]\d\d)(\d\d)/ );
	my $sel_hour = '';
	foreach my $tz_hour ( @{sb::Config->get->value('setup_tz_hour')} ) {
		$sel_hour .= '<option value="' . $tz_hour . '"';
		$sel_hour .= ' selected="selected"' if ($hour eq $tz_hour);
		$sel_hour .= '>' . ZONE_LABEL . $tz_hour . '</option>' . "\n";
	}
	my $sel_min = '';
	foreach my $tz_min ( @{sb::Config->get->value('setup_tz_min')} ) {
		$sel_min .= '<option value="' . $tz_min . '"';
		$sel_min .= ' selected="selected"' if ($min eq $tz_min);
		$sel_min .= '>' . $tz_min . '</option>' . "\n";
	}
	$cms->num(0);
	$cms->tag($param{'tag'} . '_hour'=>$sel_hour);
	$cms->tag($param{'tag'} . '_min'=>$sel_min);
}
sub image_selector { # イメージセレクタ
	my $self = shift;
	my %param = (
		'cms'    => undef,
		'num'    => 0,
		'option' => 0,
		@_
	);
	return( undef ) unless (defined($param{'cms'}));
	my $cms = $param{'cms'};
	my $selector = '';
	my $num = 0;
	my @images = sb::Data->load('Image',
		'num'   => $param{'num'},
		'sort'  => 'date',
		'order' => 1,
		'cond'  => {'stat'=>0},
	);
	my $option = ('file','thumb','link','link')[$param{'option'}];
	foreach my $img ( @images ) {
		my $type = '';
		my $flag = $img->is_image;
		my $text = sb::Text->entitize(
			$img->get_as_tag('type'=> $flag ? $option : 'link')
		);
		if ($flag and $option ne 'file' and $img->thumb ne '') {
			$type = ($param{'option'} == 1)
			      ? sb::Language->get->string('parts_thumb')
			      : sb::Language->get->string('parts_withlink');
		} elsif (!$flag) {
			$type = sb::Language->get->string('parts_withlink');
		}
		if ($flag and $option eq 'link' and $param{'option'} == 3 and $img->thumb ne '') {
			my $orig = sb::Text->entitize($img->get_as_tag('type'=>'file'));
			$selector .= '<option value="' . $orig . '">' . $img->name . '</option>' . "\n";
		}
		$selector .= '<option value="' . $text . '">' . $img->name . $type . '</option>' . "\n";
		$num++;
		last if ($param{'num'} > 0 and $num == $param{'num'});
	}
	$cms->num(0);
	$cms->tag('sb_entry_image'=>$selector);
}
# ==================================================
# // private functions - utilities
# ==================================================
sub _load_toolset {
	my $self = shift;
	my $list = $self->load_template(
		'dir'  => sb::Config->get->value('dir_temp'),
		'file' => TOOLSET_FILE
	);
	return split("\n",$list);
}
# ==================================================
# // public functions - callback
# ==================================================
sub callback { # コールバック
	my $self = shift;
	return ( $self->{'regi'} ) 
		? $self->_save_entry(@_)
		: $self->_open_entry(@_);
}
# ==================================================
# // private functions - main routine
# ==================================================
sub _save_entry { # 記事更新処理
	my $self = shift;
	my %var = (
		'message'  => '',
		'ping'     => [],
		'tbping'   => [],
		'zone'     => sb::Config->get->value('conf_timezone'),
		'date'     => '',
		'rewrite'  => undef,
		'category' => undef,
		'elem'     => {},
		@_
	);
	$self->_init_instance; # インスタンス変数初期化
	# 環境変数
	my $user = $self->{'user'};
	my $cgi = sb::Interface->get;
	my $lang = sb::Language->get;
	my $msg = '';
	my $entry = undef;
	# ローカル変数の初期化
	$var{'rewrite'} = ($cgi->value('id') ne '');
	$var{'olddate'} = undef;
	$var{'zone'} = $cgi->value('entry_tz_hour') . $cgi->value('entry_tz_min');
	$var{'date'} = sb::Time->convert(
		'year' => $cgi->value('entry_date_yr'),
		'mon'  => $cgi->value('entry_date_mo'),
		'day'  => $cgi->value('entry_date_dy'),
		'hour' => $cgi->value('entry_date_ho'),
		'min'  => $cgi->value('entry_date_mi'),
		'sec'  => $cgi->value('entry_date_sc'),
		'zone' => $var{'zone'},
	);
	$var{'tbping'} = [split(/\n/,$cgi->value('entry_tbping'))];
	$var{'ping'}   = [split(/\0/,$cgi->value('entry_ping'))];
	$var{'elem'} = {
		'subj' => sb::Text->entitize($cgi->value('entry_title')),
		'cat'  => ($cgi->value('entry_category') eq 'none') ? '' : int($cgi->value('entry_category')),
		'auth' => ($cgi->value('entry_author') ne '') ? $cgi->value('entry_author') : $user->id,
		'stat' => ($cgi->value('open_save') ne '') ? 1 : 0,
		'file' => ($cgi->value('entry_file') =~ /^\w+$/) ? $cgi->value('entry_file') : '',
		'date' => $var{'date'},
		'tz'   => $var{'zone'},
		'add'  => '',
		'edit' => $user->id,
		'acm'  => $cgi->value('entry_com'),
		'atb'  => $cgi->value('entry_tb'),
		'form' => $cgi->value('entry_format'),
		'body' => $cgi->value('entry_body'),
		'more' => $cgi->value('entry_more'),
		'sum'  => sb::Text->entitize($cgi->value('entry_summary')),
		'key'  => sb::Text->entitize($cgi->value('entry_keyword')),
		'tmp'  => undef,
	};
	if ($cgi->value('entry_multicat') ne '' or $user->get_option('auto_cat')) { # 関連カテゴリー
		my @related = split(/\0/,$cgi->value('entry_multicat'));
		if ($user->get_option('auto_cat') and $var{'elem'}->{'cat'} ne '') {
			my $child = $self->{'cat'}->{$var{'elem'}->{'cat'}};
			push(@related,$child->main) if ($child and $child->main ne '');
		}
		{ # getting rid of duplication
			my %cnt;
			@related = grep(!$cnt{$_}++, @related);
		}
		$var{'elem'}->{'add'} = ',' . join(',',@related) . ',' if (@related);
	}
	$var{'elem'}->{'subj'} =~ tr/\x0D\x0A//d;
	$var{'elem'}->{'key'}  =~ tr/\x0D\x0A//d;
	$var{'elem'}->{'tmp'} = join("\n",@{$var{'tbping'}});
	$var{'entry_body'} = $var{'elem'}->{'body'} . $var{'elem'}->{'more'};
	if ($cgi->value('entry_add_category') ne '') { # カテゴリーチェック
		$var{'category'}->{'name'} = sb::Text->entitize($cgi->value('entry_add_category'));
		$var{'category'}->{'sub'} = ($cgi->value('entry_add_sub') ne '') ? 1 : undef;
		$var{'category'}->{'name'} =~ tr/\x0D\x0A//d;
	}
	if ($var{'elem'}->{'cat'} ne '' and $self->{'cat'}->{$var{'elem'}->{'cat'}}) {
		$var{'elem'}->{'stat'} = 2 if ($var{'elem'}->{'stat'} and $self->{'cat'}->{$var{'elem'}->{'cat'}}->get_option('top'));
	}
	# エントリーデータのバッファリング
	if ($var{'rewrite'}) {
		$entry = sb::Data->load('Entry','id'=>$cgi->value('id'));
		$var{'elem'}->{'stat'} = $entry->stat if ($entry and ($cgi->value('upload') or $cgi->value('findtb')));
	} else {
		$entry = $self->_check_redundancy_for_entry(
			'subj' => $var{'elem'}->{'subj'},
			'body' => $var{'elem'}->{'body'},
			'more' => $var{'elem'}->{'more'},
		);
	}
	if ($entry) { # 既存記事
		$var{'rewrite'} = 1;
		if ($entry->date != $var{'elem'}->{'date'}) { # 日付が変更されている場合
			my ($prv,$nxt) = $self->_search_neighbor($entry);
			$var{'olddate'}->{'date'} = $entry->date;
			$var{'olddate'}->{'zone'} = $entry->tz;
			$var{'olddate'}->{'prev'} = $prv;
			$var{'olddate'}->{'next'} = $nxt;
		}
	} else { # 新規記事
		$var{'rewrite'} = undef;
		$entry = sb::Data->add('Entry');
	}
	die($lang->string('error_unknown')) if (!$entry); # 記事情報が存在するはず
	foreach my $elem ( keys(%{$var{'elem'}}) ) { # データのコピー
		$entry->$elem($var{'elem'}->{$elem});
	}
	$self->{'entry'} = $entry if ($var{'rewrite'}); # 既存記事なら記事情報を $self に格納
	# イメージアップロード
	if ($cgi->value('upload')) {
		sb::Data->reduce('Entry') if (!$var{'rewrite'}); # entry object is temporary, so needs to reduce index.
		my $num = $self->upload_image('max'=>1,'over'=>($cgi->value('upload_overwrite') eq 'on'));
		if ($num > 0 and !$user->get_option('imagetag'))
		{
			my $img = sb::Data->load('Image','sort'=>'date','order'=>1,'num'=>1); # 最新画像取得
			my $target = $cgi->value('insert_target');
			my $option = ('file','thumb','link','link')[$user->get_option('imagelist')];
			$target = 'body' if ($target ne 'body' and $target ne 'more');
			$option = 'link' if (!$img->is_image);
			my $text = $entry->$target() . $img->get_as_tag('type'=>'link');
			$entry->$target($text);
		}
		return $self->_open_entry(
			'message'  => ($num > 0) ? sprintf($lang->string('parts_add_comp'),$num) : $lang->string('error_failtoadd'),
			'entry'    => $entry,
			'category' => $var{'category'},
		);
	}
	# トラックバック自動検出
	if ($cgi->value('findtb')) {
		my @urls = sb::Ping->new->discover_trackback($var{'entry_body'});
		my $num = @urls;
		push(@{$var{'tbping'}},@urls) if ($num > 0);
		$entry->tmp(join("\n",@{$var{'tbping'}}));
		return $self->_open_entry(
			'message'  => $num . $lang->string('parts_findtb'),
			'entry'    => $entry,
			'category' => $var{'category'},
		);
	}
	# エラーチェック
	if ($self->check_entry_body($var{'entry_body'})) {
		return $self->_open_entry(
			'message'  => $lang->string('error_no_body'),
			'entry'    => $entry,
			'category' => $var{'category'},
		);
	}
	# 新規カテゴリー追加処理
	if ($var{'category'}) {
		my $category = $self->create_category(
			'main' => $var{'elem'}->{'cat'},
			'name' => $var{'category'}->{'name'},
			'sub'  => $var{'category'}->{'sub'},
			'num'  => 1,
		);
		if ($category) {
			$var{'category'} = undef;
			$entry->cat($category->id);
			$self->{'cat'}->{$category->id} = $category;
		}
	}
	# 記事更新処理
	if (sb::Config->get->value('basic_img_chck')) { # 利用イメージ検索
		$self->_check_image(
			'text' => $var{'entry_body'},
			'id'   => $entry->id,
		);
	}
	if ($entry)
	{
		sb::Data->update($entry); # データ更新
		$self->{'entry'} = $entry; # 保存したので既存記事として扱う
		push(@{$self->{'ents'}},$entry); # エントリーバッファ更新
		$self->_build_files($var{'olddate'}); # 構築処理
	}
	# トラックバック送信処理
	if ($entry->stat)
	{
		if ($entry->cat ne '')
		{ # カテゴリーのトラックバック url 追加処理
			my $check = $self->{'cat'}->{$entry->cat};
			my $tburl = ($check) ? $check->url : '';
			my $sent = $entry->ping;
			push(@{$var{'tbping'}},$tburl) if ($tburl ne '' and $sent !~ m!$tburl!);
		}
		my $ping_sender = sb::Ping->new;
		my $stat = $ping_sender->send_trackback(
			'url'       => $entry->permalink,
			'excerpt'   => $entry->sum,
			'title'     => $entry->subj,
			'blog_name' => $self->{'blog'}->title,
			'list'      => $var{'tbping'},
			'eid'       => $entry->id,
			'now'       => $self->{'time'},
		);
		if ($stat)
		{
			if (ref($stat->{'sent'}) eq 'ARRAY')
			{
				$entry->add_ping(@{$stat->{'sent'}});
				foreach my $success ( @{$stat->{'sent'}} )
				{
					$msg .= $success . $lang->string('parts_sentping') . "\n";
				}
			}
			if (ref($stat->{'error'}) eq 'ARRAY')
			{
				$entry->tmp(join("\n",@{$stat->{'error'}}));
				foreach my $failure ( @{$stat->{'error'}} )
				{
					my $err_msg = sb::Text->entitize($ping_sender->error->{$failure});
					$err_msg =~ tr/\x0D\x0A//d;
					$msg .= $failure . '[failed]' . $err_msg . "<br />\n";
				}
			}
			sb::Data->update($entry); # データ更新
		}
		elsif (@{$var{'tbping'}})
		{
			$msg .= '[ping failed]' . $ping_sender->error . "<br />\n";
		}
	}
	# 更新 ping 送信処理
	if ($entry->stat and @{$var{'ping'}}) {
		my $stat = sb::Ping->new->send_update(
			'list' => $var{'ping'},
			'mode' => 'ping',
			'name' => $self->{'blog'}->title,
		);
		if ($stat and ref($stat->{'sent'}) eq 'ARRAY') {
			foreach my $success ( @{$stat->{'sent'}} ) {
				$msg .= $success . $lang->string('parts_sentping') . "\n";
			}
		}
	}
	# 終了処理
	$msg .= ($var{'rewrite'}) ? $lang->string('parts_editcomp') : $lang->string('parts_new_comp');
	$msg .= ' <a href="#" onclick="window.close()">' . $lang->string('parts_bm_close') . '</a>' if ($cgi->value('bm'));
	return $self->_open_entry(
		'message'  => $msg,
		'entry'    => $entry,
		'category' => $var{'category'},
	);
}
sub _open_entry { # 記事編集画面
	my $self = shift;
	my %param = (
		'message'  => '',
		'entry'    => undef, # エントリーデータ
		'newtext'  => undef, # 新規記事作成時のデフォルトテキスト
		'category' => undef, # カテゴリーデータ
		@_
	);
	$self->_init_instance; # インスタンス変数初期化
	my $conf = sb::Config->get;
	my $cgi = sb::Interface->get;
	my $cms = sb::TemplateManager->new($self->load_template('file'=>TEMPLATE));
	# エントリーデータの読込み [memo] 既存記事 : $self->{'entry'} あり / 新規記事 : $self->{'entry'} なし
	$self->{'entry'} = sb::Data->load('Entry','id'=>$cgi->value('eid')) if ($cgi->value('eid') ne '');
	$param{'entry'}  = $self->{'entry'} if ( $self->{'entry'} );
	# ローカルパラメータ宣言
	my $entry = $param{'entry'};
	my $user  = $self->{'user'};
	my %option = ();
	# パーミッションチェック
	if ( $entry and !$self->check_permission('user'=>$entry->auth) ) {
		die(sb::Language->string('error_not_allow') . "\n");
	}
	# オプションの確認
	$option{'format'}    = ($self->{'entry'}) ? $entry->form : $user->get_option('format');
	$option{'comment'}   = ($self->{'entry'}) ? $entry->acm  : $user->get_option('comment');
	$option{'trackback'} = ($self->{'entry'}) ? $entry->atb  : $user->get_option('trackback');
	$option{'imagelist'} = $user->get_option('imagelist');
	$option{'imagemax'}  = $user->get_option('imagemax');
	$option{'sequel'} = ($user->get_option('sequel') == 0 or ($self->{'entry'} and $entry->more ne ''));
	$option{'summary'} = ($user->get_option('advanced') == 1 or ($self->{'entry'} and $entry->entitize('sum') ne '')); # [*1]
	$option{'advanced'} = ($user->get_option('advanced') == 1);
	$option{'tb_option'} = ($user->get_option('tb_option') == 0);
	$option{'cat_open'} = ($user->get_option('cat_open') == 0);
	# [note][*1] used be ($user->get_option('summary') == 0)
	# 共通パーツの初期化
	$self->common_template_parts($cms);
	# カテゴリーセレクタ
	$cms->tag('sb_entry_category'=>
		'<option value="none">' . sb::Language->get->string('parts_no_cat') . '</option>' .
		$self->category_selector(
			'cat' => [ sort { $b->order <=> $a->order } values(%{$self->{'cat'}}) ],
			'now' => ($entry) ? $entry->cat : $user->cat,
		)
	);
	if ($entry and $entry->add ne '') { # 関連カテゴリー
		my $options = '';
		foreach ( split(',',$entry->add) ) {
			next if ($_ eq '');
			$options .= '<option value="' . $_ . '">' . $self->{'cat'}->{$_}->name . '</option>' if ($self->{'cat'}->{$_});
		}
		$cms->num(0);
		$cms->tag('sb_multi_category_current'=>$options);
		$cms->tag('sb_extra_category'=>sb::Language->get->string('parts_extracat')) if ($option{'cat_open'});
	}
	if ($param{'category'}) {
		$cms->num(0);
		$cms->tag('sb_entry_add_category'=>$param{'category'}->{'name'});
		$cms->tag('sb_entry_add_sub'=>'checked="checked"') if ($param{'category'}->{'sub'});
	}
	# イメージセレクタ
	$self->image_selector(
		'cms'    => $cms,
		'num'    => $option{'imagemax'},
		'option' => $option{'imagelist'},
	);
	# ステータス表示・前後記事へのリンク
	if ( $self->{'entry'} ) {
		$cms->num(0);
		$cms->tag('sb_entry_status'=>$self->_display_entry_status($entry));
		my ($prv,$nxt) = $self->_search_neighbor($entry);
		my $path  = $self->get_script_path . '?__mode=edit&amp;eid=';
		my $parts = $conf->value('srv_temp');
		$cms->tag('sb_entry_prev'=>($prv and $cgi->value('bm') ne 'on')
			? '<a href="' . $path . $prv->id . '"><img src="' . $parts . 
			   IMAGE_PREV . ' title="' . $prv->subj . '" /></a>'
			: '<img src="' . $parts . IMAGE_BLANK . ' />'
		);
		$cms->tag('sb_entry_next'=>($nxt and $cgi->value('bm') ne 'on')
			? '<a href="' . $path . $nxt->id . '"><img src="' . $parts . 
			   IMAGE_NEXT . ' title="' . $nxt->subj . '" /></a>'
			: '<img src="' . $parts . IMAGE_BLANK . ' />'
		);
	}
	# コメント・トラックバック・デフォルトフォーマット
	foreach my $key ('format','comment','trackback') {
		next if ($option{$key} !~ /^\d+$/);
		$self->select_option(
			'cms'      => $cms,
			'tag'      => 'sb_entry_' . $key . '_',
			'selected' => $option{$key},
		);
	}
	{ # テキストフォーマット(追加分)
		my $selector = '';
		my @filters  = sb::Plugin->get_text_filter;
		foreach my $name (@filters) {
			$selector .= '<option value="' . $name . '"';
			$selector .= ' selected="selected"' if ($option{'format'} eq $name);
			$selector .= '>' . $name . '</option>';
		}
		$cms->tag('sb_entry_extra_format'=>$selector);
	}
	{ # 時刻
		my $date = (!$self->{'entry'} or $user->get_option('init_date')) ? $self->{'time'} : $entry->date;
		my $zone = ($self->{'entry'}) ? $entry->tz : $conf->value('conf_timezone');
		$self->_generate_dateform(
			'cms'     => $cms,
			'tag'     => 'sb_entry',
			'current' => $date,
			'zone'    => $zone,
		);
		if ($option{'advanced'}) {
			$self->timezone_selector(
				'cms'     => $cms,
				'tag'     => 'sb_entry_zone',
				'current' => $zone,
			);
		} else {
			my ($hour,$min) = ( $zone =~ /([\+-]\d\d)(\d\d)/ );
			my $hidden = '<input type="hidden" name="%s" value="%s" />';
			$cms->tag('hidden_entry_tz_hour'=>sprintf($hidden,'entry_tz_hour',$hour));
			$cms->tag('hidden_entry_tz_min' =>sprintf($hidden,'entry_tz_min' ,$min ));
		}
	}
	{ # 更新 PING チェックボックス
		my @ping_list = split('\\n',$conf->value('conf_edit_ping'));
		my $flag = ($user->get_option('ping') and (!$self->{'entry'} or $entry->stat == 0));
		my $num = 0;
		foreach my $ping (@ping_list) {
			if ($num == 0) {
				$cms->num(0);
				$cms->tag('sb_entry_ping_name_one'=>$ping);
			} else {
				$cms->num($num - 1);
				$cms->tag('sb_entry_ping_name'=>$ping);
			}
			$cms->tag('sb_entry_ping'=>($flag) ? 'checked="checked"' : '');
			$num++;
		}
		$cms->num(0);
		$cms->tag('sb_enttry_ping_num'=>$num);
		$cms->block('sb_entry_ping'=>($num > 0) ? 1 : 0);
		$cms->block('sb_entry_ping_moreone'=>($num > 1) ? $num - 1 : 0);
	}
	{ # 表示設定
		$cms->num(0);
		$cms->tag('sb_entry_body_rows'=>($option{'sequel'}) ? BODYROW_STD : BODYROW_EXT );
		$cms->block('sb_entry_moreform'=>($option{'sequel'}) ? 1 : 0);
		$cms->block('sb_entry_sum_form'=>($option{'summary'}) ? 1 : 0);
		$cms->block('sb_entry_advancedform'=>($option{'advanced'}) ? 1 : 0);
		$cms->block('sb_entry_tbform'=>($option{'tb_option'}) ? 1 : 0);
		$cms->block('sb_entry_file'=>($option{'advanced'} and $conf->value('conf_entry_archive') eq 'Individual') ? 1 : 0);
		$cms->tag('sb_entry_suffix'=>$conf->value('basic_suffix'));
	}
	# 著者設定(管理ユーザーのみ)
	if ($option{'advanced'} and $user->stat == 0) {
		my $current = ($self->{'entry'}) ? $entry->auth : $user->id;
		my $selector = '';
		my @array = sort { $a->id <=> $b->id } values(%{$self->{'users'}});
		foreach my $usr_chk ( @array ) {
			$selector .= '<option value="' . $usr_chk->id . '"';
			$selector .= ' selected="selected"' if ($usr_chk->id eq $current);
			$selector .= '>' . $usr_chk->real . '</option>';
		}
		$cms->num(0);
		$cms->tag('sb_entry_author'=>$selector);
		$cms->block('sb_entry_user'=>1);
	}
	# カテゴリー追加フォーム(管理ユーザー/上級ユーザー)
	$cms->block('add_category_form'=>1) if ($user->stat < 2);
	# ツールアイコン
	$self->display_toolicons(
		'cms'  => $cms,
		'opt'  => $user->get_option('edit_tool'),
		'set'  => $user->ext,
		'more' => $option{'sequel'},
	);
	# 送信済みトラックバック PING
	if ($self->{'entry'} and $entry and $entry->ping ne '') {
		my $ping = $entry->ping;
		$ping =~ s/\n/<br \/>/g;
		$cms->num(0);
		$cms->tag('sb_entry_tbsent'=>$ping);
		$cms->block('entry_sent_ping'=>1);
	}
	# 未送信トラックバック PING
	if ($entry and $entry->tmp ne '') {
		$cms->num(0);
		$cms->tag('sb_entry_tbping'=>$entry->tmp);
	}
	# for Bookmarklet
	if ($self->{'mode'} eq 'bm' or $cgi->value('bm') eq 'on') {
		$cms->num(0);
		$cms->tag('sb_bm_para'=>'on');
		if ($cgi->value('bm') ne 'on') {
			my $orig = $cgi->value('_u');
			my $url  = &_decode_uri($orig);
			$url = substr($url,0,index($url,'#')) if (index($url,'#') > -1);
			my @urls = sb::Ping->new->discover_trackback($url . ' ' . &_decode_uri($orig));
			$cms->tag('sb_entry_tbping'=>join("\n",@urls)) if (@urls);
		}
	}
	# 記事内容の出力
	if ($entry) {
		$cms->num(0);
		$cms->tag('sb_entry_title'   => $entry->subj);
		$cms->tag('sb_entry_body'    => $entry->entitize('body'));
		$cms->tag('sb_entry_more'    => $entry->entitize('more'));
		$cms->tag('sb_entry_summary' => $entry->sum) if ($entry->entitize('sum') ne '');
		$cms->tag('sb_entry_key'     => $entry->key);
		$cms->tag('sb_entry_file'    => $entry->file);
		if ($self->{'entry'}) {
			$cms->tag('sb_edit_viewlink' => $conf->value('conf_srv_cgi') . $conf->value('basic_sb') . '?eid=' . $entry->id);
			$cms->tag('sb_entry_id'      => $entry->id);
			$cms->block('sb_edit_info'=>1);
			$cms->block('sb_edit_viewpage'=>1);
			$self->_display_list('cms'=>$cms,'id'=>$entry->id);
		}
	} elsif ($param{'newtext'} ne '') {
		$cms->num(0);
		$cms->tag('sb_entry_body'=>$param{'newtext'});
	}
	# イメージアップロードフォーム
	$self->imagedir_selector(
		'cms'   => $cms,
		'tag'   => 'sb_img_dir',
		'thumb' => 'sb_edit_imagethumb',
		'over'  => 'check',
	);
	# header
	$cms->block('sb_new_mode'=>1) if (!$self->{'entry'});
	$cms->block('sb_edit_mode'=>1) if ($self->{'entry'});
	# 処理通知
	if ($param{'message'} ne '') {
		$cms->num(0);
		$cms->tag('sb_process_message'=>$param{'message'});
		$cms->block('sb_edit_message'=>1);
	}
	return sb::Interface->get->head('type'=>'text/html') . $self->set_main($cms->output);
}
# ==================================================
# // private functions - for editor screen
# ==================================================
sub _init_instance {
	my $self = shift;
	$self->{'cat'}  = { sb::Data->load_as_hash('Category') } if (!defined($self->{'cat'}));
	$self->{'ents'} = [sb::Data->load('Entry','sort'=>'date','order'=>0)] if (!defined($self->{'ents'}));
	$self->{'blog'} = sb::Data->load('Weblog','id'=>0) if (!defined($self->{'blog'}));
	return($self);
}
sub _build_files { # 構築処理
	my $self = shift;
	my $old  = shift;
	return( undef ) if (!$self->{'entry'});
	my $type = sb::Config->get->value('conf_entry_archive');
	my $builder = sb::Build->new(
		'time'      => $self->{'time'},
		'user'      => $self->{'users'},
		'cat'       => $self->{'cat'},
		'sortedcat' => [ sort { $b->order <=> $a->order } values(%{$self->{'cat'}}) ],
		'blog'      => $self->{'blog'},
	);
	$builder->set_entryinfo;
	if ($type eq 'Individual') {
		my @entries = ($self->{'entry'});
		my @ids = ($self->{'entry'}->id);
		if ($old) {
			push(@ids,$old->{'prev'}->id) if ($old->{'prev'});
			push(@ids,$old->{'next'}->id) if ($old->{'next'});
		}
		my ($prv,$nxt) = $self->_search_neighbor($self->{'entry'});
		push(@ids,$prv->id) if ($prv);
		push(@ids,$nxt->id) if ($nxt);
		{ # getting rid of duplication
			my %cnt;
			@ids = grep(!$cnt{$_}++, @ids);
		}
		foreach my $id ( @ids ) {
			next if ($id == $self->{'entry'}->id);
			my $tmp = sb::Data->load('Entry','id'=>$id);
			push(@entries,$tmp) if ($tmp);
		}
		foreach (@mScriptsForEntries) { # generate javascripts first.
			$builder->build_javascript( $_ );
		};
		foreach my $entry ( @entries ) {
			next if ($entry->stat == 0);
			$builder->build_entry( $entry );
		}
	} elsif ($type eq 'Monthly') {
		my $month = sb::Time->format(
			'time'=>$self->{'entry'}->date,
			'form'=>'%Year%%Mon%',
			'zone'=>$self->{'entry'}->tz
		);
		$builder->build_monthly_archive( $month );
		if ($old) {
			my $check = sb::Time->format(
				'time'=>$old->{'date'},
				'form'=>'%Year%%Mon%',
				'zone'=>$old->{'zone'}
			);
			$builder->build_monthly_archive( $check ) if ($check ne $month);
		}
	}
	$builder->build_category_index( $self->{'entry'}->cat ) if ($self->{'entry'}->cat ne '');
	$builder->set_latest_entries;
	$builder->build_top_page;
	$builder->build_feedfile('all');
	$builder->build_cookie_js;
}
sub _check_image { # 利用イメージ検索
	my $self = shift;
	my %param = (
		'text' => undef,
		'id'   => undef,
		@_
	);
	return( undef ) if ( !$param{'text'} or !defined($param{'id'}) );
	my @urls = ($param{'text'} =~ /<img.*?src="(.*?)"/ig);
	{ # 重複している url を削除
		my %cnt;
		@urls = grep(!$cnt{$_}++, @urls);
	}
	my @imgs = sb::Data->load('Image');
	my @update = ();
	my @ignore = ();
	foreach my $img (@imgs) {
		my $chk_image = $img->get_url;
		my $chk_thumb = $img->get_url('type'=>'thumb');
		if (grep(/^(\Q$chk_image\E|\Q$chk_thumb\E)$/,@urls)) {
			push(@update,$img);
		} elsif (index($img->eid,$param{'id'} . ':') > -1) {
			push(@ignore,$img);
		}
	}
	foreach my $img (@update) {
		my @buf = split(':',$img->eid);
		my %cnt;
		push(@buf,$param{'id'});
		@buf = grep(!$cnt{$_}++, @buf);
		$img->eid(join(':',@buf) . ':');
	}
	foreach my $img (@ignore) {
		my @buf = split(':',$img->eid);
		@buf = grep { $_ ne $param{'eid'} } @buf;
		$img->eid(join(':',@buf) . ':');
	}
	sb::Data->update(@update,@ignore);
}
sub _check_redundancy_for_entry { # 記事の重複チェック
	my $self = shift;
	my %param = (
		'subj' => undef,
		'body' => undef,
		'more' => undef,
		@_
	);
	return sb::Data->load('Entry',
		'cond'=>{
			'subj'=>$param{'subj'},
			'body'=>$param{'body'},
			'more'=>$param{'more'},
		},
		'num'=>1,
		'detail'=>'on',
	);
}
sub _search_neighbor { # 隣接記事検索
	my $self = shift;
	my $entry = shift;
	return( undef, undef ) if (!$entry);
	my ($prv,$nxt);
	my $check = -1;
	my @array = @{$self->{'ents'}};
	for (my $i=0;$i<@array;$i++) {
		next if ($entry->id != $array[$i]->id);
		$check = $i;
		last;
	}
	$prv = $array[$check - 1] if ($check > 0);
	$nxt = $array[$check + 1] if ($check > -1 and $check < $#array);
	return($prv,$nxt);
}
sub _generate_dateform { # 日付フォーム
	my $self = shift;
	my %param = (
		'cms'     => undef,
		'tag'     => undef,
		'name'    => DATE_NAME,
		'zone'    => sb::Config->get->value('conf_timezone'),
		'current' => undef,
		'format'  => {
			'date' => sb::Language->get->string('parts_formdate'),
			'time' => sb::Language->get->string('parts_formtime'),
		},
		@_
	);
	return( undef ) if (!defined($param{'cms'}) or !defined($param{'tag'}));
	my $cms = $param{'cms'};
	my $tag = $param{'name'};
	my $pre = '<input type="text" class="text" name=';
	$param{'format'}{'date'} =~ s/%Year%/$pre"$tag\_yr" value="%Year%" size="4" maxlength="4" \/>/;
	$param{'format'}{'date'} =~ s/%Mon%/$pre"$tag\_mo" value="%Mon%" size="2" maxlength="2" \/>/;
	$param{'format'}{'date'} =~ s/%Day%/$pre"$tag\_dy" value="%Day%" size="2" maxlength="2" \/>/;
	$param{'format'}{'time'} =~ s/%Hour%/$pre"$tag\_ho" value="%Hour%" size="2" maxlength="2" \/>/;
	$param{'format'}{'time'} =~ s/%Min%/$pre"$tag\_mi" value="%Min%" size="2" maxlength="2" \/>/;
	$param{'format'}{'time'} =~ s/%Sec%/$pre"$tag\_sc" value="%Sec%" size="2" maxlength="2" \/>/;
	$cms->num(0);
	$cms->tag($param{'tag'} . '_date'=>
		sb::Time->format(
			'time'=>$param{'current'},
			'zone'=>$param{'zone'},
			'form'=>$param{'format'}{'date'}
		)
	);
	$cms->tag($param{'tag'} . '_time'=>
		sb::Time->format(
			'time'=>$param{'current'},
			'zone'=>$param{'zone'},
			'form'=>$param{'format'}{'time'}
		)
	);
}
sub _decode_uri {
	$_[0] =~ s/%([0-9A-Fa-f][0-9A-Fa-f])/pack('H2',$1)/eg;
	return($_[0]);
}
# ==================================================
# // private functions - for message list
# ==================================================
sub _display_list { # 記事ごとのリスト表示
	my $self = shift;
	my %param = (
		'cms' => undef,
		'id'  => undef,
		@_
	);
	return( undef ) if (!defined($param{'cms'}) or !defined($param{'id'}));
	my $cms = $param{'cms'};
	{ # コメント
		$cms->num(0);
		my @message = sb::Data->load('Message','cond'=>{'eid'=>$param{'id'}});
		$cms->tag('sb_com_num'=>sb::Data->matched);
		$self->listmain(
			'template' => $cms,
			'block'    => 'sb_edit_com_list',
			'objects'  => \@message,
			'tags'     => {
				'sb_com_author' => \&_clip_for_comment,
				'sb_com_date'   => 'date',
				'sb_com_status' => \&_display_message_status,
				'sb_com_del'    => \&_display_checkbox,
			},
		);
	}
	{ # トラックバック
		$cms->num(0);
		my @trackback = sb::Data->load('Trackback','cond'=>{'eid'=>$param{'id'}});
		$cms->tag('sb_tb_num'=>sb::Data->matched);
		$self->listmain(
			'template' => $cms,
			'block'    => 'sb_edit_tb_list',
			'objects'  => \@trackback,
			'tags'     => {
				'sb_tb_name'   => \&_clip_for_trackback,
				'sb_tb_date'   => 'date',
				'sb_tb_status' => \&_display_message_status,
				'sb_tb_del'    => \&_display_checkbox,
			},
		);
	}
	$cms->block('sb_edit_info'=>1);
}
sub _display_checkbox { # リスト内のチェックボックス
	my $self = shift;
	my $obj  = shift;
	return DENIED_CHECK if (!$self->{'entry'});
	return $self->check_permission('user'=>$self->{'entry'}->auth)
	? '<input type="checkbox" name="sel" value="' . $obj->id . '" onclick="switchList(this)" />'
	: DENIED_CHECK;
}
sub _display_message_status { # リスト内のステータス表示
	my $self = shift;
	return $self->SUPER::_display_message_status(@_);
}
sub _clip_for_comment { # コメントリストの著者表示
	my $self = shift;
	my $obj  = shift;
	return if (!$self->{'entry'});
	return $self->clip_text(
		'text'   => ($obj->auth eq '') ? sb::Language->get->string('parts_noname') : $obj->auth,
		'length' => ITEM_LENGTH,
		'base'   => '?__mode=comment&amp;mid=' . $obj->id,
		'user'   => $self->{'entry'}->auth,
	);
}
sub _clip_for_trackback { # トラックバックリストの送信元表示
	my $self = shift;
	my $obj  = shift;
	return if (!$self->{'entry'});
	return $self->clip_text(
		'text'   => ($obj->name eq '') ? sb::Language->get->string('parts_noname') : $obj->name,
		'length' => ITEM_LENGTH,
		'base'   => '?__mode=trackback&amp;bid=' . $obj->id,
		'user'   => $self->{'entry'}->auth,
	);
}
1;
__END__
