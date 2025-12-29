# sb::Content - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Content;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.22';
# 0.22 [2007/04/14] changed _area_category to enable category_area for any page in category
# 0.21 [2007/04/11] changed _check_page to set page correctly
# 0.20 [2007/03/05] changed _trackback_auto_discovery
# 0.19 [2007/02/17] changed _check_page to fix a bug
# 0.18 [2007/02/13] changed _check_page
# 0.17 [2007/02/09] added {mode_name} and {mode_id}
# 0.16 [2007/02/07] added sb::Content::Category
# 0.15 [2006/10/11] added {amazon_htmlcomment}
# 0.14 [2006/10/05] changed _check_page to output a page correctly in searching
# 0.13 [2006/02/01] changed _list_comment, _list_trackback to filter objects correctly
# 0.12 [2005/10/18] changed output to receive TemplateManager object directly
# 0.11 [2005/10/15] chnaged _page to handle category page for mobile correctly
# 0.10 [2005/10/06] changed _category_tree to handle description of category.
# 0.09 [2005/08/24] changed _area_comment and _area_trackback to load data faster
# 0.08 [2005/08/03] changed _extract_entry to sort entries correctly
# 0.07 [2005/08/02] changed output, _extract_entry and _page to add 'num' option
# 0.06 [2005/08/02] changed _list_link to display correctly with empty group
# 0.05 [2005/07/27] changed _category_tree to add an option, 'no_num'
# 0.04 [2005/07/11] changed config variable "srv_cgi" to "conf_srv_cgi"
# 0.03 [2005/07/09] changed _calendar to display horizontal and vertical calendar correctly
# 0.02 [2005/07/08] changed _sequel in Entry and _entry_info
# 0.01 [2005/06/29] changed _list_link to display link group.
# 0.00 [2005/02/06] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Language ();
use sb::Config ();
use sb::Plugin ();
use sb::TemplateManager ();
use sb::Data ();
use sb::Time ();
use sb::Text ();
use sb::App ();
# ==================================================
# // declaration for constant value
# ==================================================
sub CATEGORY_TITLE (){ '%Main%::%Sub%' };
sub PREV_ARROW     (){ '&lt;&lt;' };
sub NEXT_ARROW     (){ '&gt;&gt;' };
# ==================================================
# // declaration for class member
# ==================================================
my %mCallbacks = (
	'main'      => {},
	'entry'     => {},
	'comment'   => {},
	'trackback' => {},
	'profile'   => {},
);
# ==================================================
# // public functions
# ==================================================
sub output
{
	my $class = shift;
	my $cms   = shift;
	my %var = ( # 各種変数
		'mode'      => undef,             # [CHAR]モード => 'ent','cat','arc','srch','page','user','mob' or 'css'
		'css'       => '',                # [URI.]スタイルシートのパス
		'page'      => 0,                 # [NUM.]ページ数
		'id'        => undef,             # [NUM.]id (eid, cid or pid)
		'cond'      => undef,             # [CHAR]抽出条件
		'time'      => 0,                 # [NUM.]時刻
		'conf'      => sb::Config->get,   # [OBJ.]環境設定
		'lang'      => sb::Language->get, # [OBJ.]言語設定
		'blog'      => undef,             # [OBJ.]ウェブログデータ
		'user'      => undef,             # [HASH]ユーザーデータ
		'cat'       => undef,             # [HASH]カテゴリーデータ(詳細)
		'sortedcat' => undef,             # [ARRY]カテゴリーデータ(並替済)
		'entryinfo' => undef,             # [HASH]エントリー情報
		'entry'     => undef,             # [ARRY]エントリーデータ(詳細)
		'entry_num' => undef,             # [NUM.]抽出したエントリー数
		'num'       => undef,             # [NUM.]ページ当たりの記事数
		'callback'  => undef,             # [SEL.]コールバック初期化フラグ
		'extend' => {
			'main'      => undef,
			'entry'     => undef,
			'message'   => undef,
			'trackback' => undef,
			'profile'   => undef,
		},
		@_
	);
	return( undef ) if (!$cms); # ベースが未指定の場合
	return( &_css_output($cms,%var) ) if ($var{'mode'} eq 'css'); # スタイルシート出力
	# ==== 初期化ルーチン ====
	$var{'num'}  = $var{'conf'}->value('conf_entry_disp') if (!$var{'num'});
	$var{'page'} = &_check_page(%var); # ページ
	$var{'blog'} = sb::Data->load('Weblog','id'=>0) if (!$var{'blog'}); # ウェブログデータ
	$var{'user'} = {sb::Data->load_as_hash('User')} if (!$var{'user'}); # ユーザーデータ
	if (!$var{'cat'})
	{ # カテゴリーデータ
		$var{'cat'} = {sb::Data->load_as_hash('Category')};
		$var{'sortedcat'} = [ sort { $b->order <=> $a->order } values(%{$var{'cat'}}) ];
	}
	if (!$var{'entry'})
	{ # エントリーデータ
		$var{'entry'} = [&_extract_entry(%var)];
		$var{'entry_num'} = sb::Data->matched;
	}
	$var{'entryinfo'} = &_entry_info(%var) if (!$var{'entryinfo'}); # エントリー情報
	&_register_callback(%{$var{'extend'}}) if (!$var{'callback'}); # コールバック
	# ==== メインループ ====
	eval{ &{$mCallbacks{'main'}{'_main'}}($cms,%var) }; # ブロック非依存系パーツ
	foreach my $block (keys %{$mCallbacks{'main'}} )
	{ # ブロック依存系パーツ
		next if ($block eq '_main');
		if ($cms->existed($block))
		{
			my $num = 0;
			eval{ $num = &{$mCallbacks{'main'}{$block}}($cms,%var) };
			$cms->block($block=>$num);
		}
	}
	return $cms->output;
}
# ==================================================
# // private functions - utilities
# ==================================================
sub _register_callback
{ # コールバックの登録処理
	my %extension = @_;
	# 標準コールバック登録
	$mCallbacks{'main'} = {
		'_main'            => \&_common_parts,
		'title'            => \&_title,
		'archives'         => \&_list_archives,
		'category'         => \&_list_category,
		'link'             => \&_list_link,
		'recent_comment'   => \&_list_comment,
		'recent_trackback' => \&_list_trackback,
		'latest_entry'     => \&_list_latest,
		'selected_entry'   => \&_list_selected,
		'profile'          => \&_list_profile,
		'calendar'         => \&_calendar,
		'amazon'           => \&_amazon,
		'page'             => \&_page,
		'option'           => \&_option,
	};
	$mCallbacks{'entry'}     = &sb::Content::Entry::_init();
	$mCallbacks{'comment'}   = &sb::Content::Message::_init();
	$mCallbacks{'trackback'} = &sb::Content::Trackback::_init();
	$mCallbacks{'profile'}   = &sb::Content::Profile::_init();
	$mCallbacks{'category'}  = &sb::Content::Category::_init();
	# 追加コールバック登録
	foreach my $area ( keys( %extension ) )
	{
		next if ( !defined($extension{$area}) );
		foreach my $callback ( keys( %{$extension{$area}} ) )
		{
			$mCallbacks{$area}{$callback} = $extension{$area}->{$callback};
		}
	}
	sb::Plugin->load_content_module(\%mCallbacks); # プラグイン呼出し
	# エリアブロック用コールバック登録 (上書き不可)
	$mCallbacks{'main'}{'entry'}          = \&_area_entry;
	$mCallbacks{'main'}{'comment_area'}   = \&_area_comment;
	$mCallbacks{'main'}{'trackback_area'} = \&_area_trackback;
	$mCallbacks{'main'}{'profile_area'}   = \&_area_profile;
	$mCallbacks{'main'}{'category_area'}  = \&_area_category;
	return;
}
sub _extract_entry
{ # エントリー抜き出し処理
	my %var = @_;
	if ($var{'mode'} eq 'ent')
	{
		return sb::Data->load('Entry','id'=>$var{'id'});
	}
	else
	{
		my $bgn = ($var{'page'} == -1) ? 0  : $var{'page'} * $var{'num'};
		my $num = ($var{'page'} == -1) ? -1 : $var{'num'};
		my %cond = ($var{'mode'} eq 'page') ? ('stat' => 1) : ('stat' => [1,2]);
		my $sortor = $var{'conf'}->value('conf_entry_sort');
		if ($var{'mode'} eq 'arc')
		{
			$cond{'date'} = sb::App->create_date_condition($var{'cond'});
			$cond{'__range'} = { 'date' => 'tz' };
			$sortor = $var{'conf'}->value('conf_archive_sort');
		}
		elsif ($var{'mode'} eq 'cat')
		{
			$cond{'cat'} = $var{'id'};
			$cond{'__combo'} = { 'cat' => 'add' , 'add' => ',' . $var{'id'} . ',' };
			$sortor = $var{'conf'}->value('conf_archive_sort');
		}
		elsif ($var{'mode'} eq 'srch')
		{
			my $word = $var{'cond'};
			$cond{'subj'} = '/' . $word . '/';
			$cond{'body'} = '/' . $word . '/';
			$cond{'more'} = '/' . $word . '/';
			$sortor = $var{'conf'}->value('conf_archive_sort');
		}
		return sb::Data->load('Entry',
			'bgn'    => $bgn,
			'num'    => $num,
			'sort'   => 'date',
			'order'  => $sortor,
			'cond'   => \%cond,
			'detail' => 'on'
		);
	}
}
sub _monthly_link
{ # 月別リンクアドレス生成
	my ($base,$conf) = @_;
	my $url = $conf->value('conf_srv_cgi') . $conf->value('basic_sb') . '?month=' . $base;
	if ($conf->value('conf_entry_archive') eq 'Monthly')
	{
		my $file = $conf->value('conf_dir_log') . $base . $conf->value('basic_suffix');
		$url = $conf->value('conf_srv_base') . $file if (-e $conf->value('conf_dir_base') . $file);
	}
	return($url);
}
sub _check_page
{ # ページ数の決定
	my %var = @_;
	my $page = $var{'page'};
	my $check = $var{'conf'}->value('conf_page_disp');
	$check = 0 if (  $var{'mode'} eq 'arc' 
	             and $var{'cond'} =~ /^\d{6}$/ 
	             and $var{'conf'}->value('conf_entry_archive') eq 'Monthly');
	$check = $var{'conf'}->value('conf_search_disp') if ($var{'mode'} eq 'srch');
	$check = 1 if ($var{'mode'} eq 'mob');
	$page = -1 if ($var{'mode'} ne 'page' and !$check);
	return($page);
}
sub _entry_info
{ # 各種エントリー情報の取得
	my %var = @_;
	my %info = (
		'latest'   => [],
		'monthly'  => {},
		'daily'    => {},
		'neighbor' => {'prev'=>undef,'next'=>undef,},
		'category' => {},
	);
	my $check_month = ($var{'mode'} eq 'arc') 
		? substr($var{'cond'},0,6) 
		: sb::Time->format(
			'time'=>$var{'time'},
			'form'=>'%Year%%Mon%',
			'zone'=>$var{'conf'}->value('conf_timezone')
		);
	my $check = -1;
	my @array = sb::Data->load('Entry','cond'=>{'stat'=>[1,2]},'sort'=>'date','order'=>1);
	for (my $i=0;$i<@array;$i++)
	{
		my $entry = $array[$i];
		if ($var{'fast_mode'} ne 'skip_archive_count')
		{
			my $date = sb::Time->format(
				'time'=>$entry->date,
				'form'=>'%Year%%Mon%%Day%',
				'zone'=>$entry->tz,
			);
			my $month = substr($date,0,6);
			if ( !defined($info{'monthly'}{$month}) )
			{ # 月別アーカイブのカウント
				$info{'monthly'}{$month} = {
					'count' => 1,
					'name'  => sb::Time->format(
						'time'=>$entry->date,
						'form'=>$var{'conf'}->value('conf_archivelist'),
						'lang'=>$var{'conf'}->value('conf_time_lang'),
						'zone'=>$entry->tz,
					),
				};
			}
			else
			{
				$info{'monthly'}{$month}{'count'}++;
			}
			$info{'category'}{$entry->cat}++ if ($entry->cat ne ''); # カテゴリーのカウント
			if ($entry->add ne '')
			{ # 関連カテゴリーのカウント
				foreach ( split(',',$entry->add) )
				{
					next if ($_ eq '');
					$info{'category'}{$_}++;
				}
			}
			$info{'daily'}{$date}++ if ($month eq $check_month); # 日別アーカイブのカウント
			push(@{$info{'latest'}},$entry) if ($i < $var{'conf'}->value('conf_newent_disp')); # 最新エントリー格納
		}
		if ( ($var{'mode'} eq 'ent' and $var{'id'} == $entry->id)
		  or ($var{'mode'} eq 'mob' and $var{'id'} ne '' and $var{'id'} == $entry->id) )
		{
			$check = $i; # 前後のエントリーを格納
		}
	}
	$info{'neighbor'}{'next'} = $array[$check - 1] if ($check > 0);
	$info{'neighbor'}{'prev'} = $array[$check + 1] if ($check > -1 and $check < $#array);
	return(\%info);
}
sub _pad0
{ # zero-padding
	return( ($_[0] < 10) ? '0' . $_[0] : $_[0] );
}
sub _category_tree
{ # category tree
	my %param = (
		'cat'    => [],
		'branch' => undef,
		'num'    => {},
		'no_num' => undef,
		@_
	);
	my $list = '';
	foreach my $cat ( @{$param{'cat'}} )
	{
		next if ($cat->get_option('list') == 1);
		next if (!defined($param{'branch'}) and $cat->main ne '');
		next if ( defined($param{'branch'}) and $cat->main ne $param{'branch'});
		my $text = $cat->get_option('sum') ? $cat->formated_text('as_summary') : '';
		$text = ($text ne '') ? ' title="' . sb::Text->entitize($text) . '"' : '';
		$list .= '<li><a href="' . $cat->cat_url . '"' . $text . '>' . $cat->name . '</a>';
		$list .= ' (' . int($param{'num'}->{$cat->id}) . ')' if (!$param{'no_num'});
		if ($cat->sub ne '')
		{
			$list .= "\n" . '<ul>';
			$list .= &_category_tree(
				'cat'    => $param{'cat'},
				'branch' => $cat->id,
				'num'    => $param{'num'},
				'no_num' => $param{'no_num'},
			);
			$list .= '</ul>';
		}
		$list .= '</li>' . "\n";
	}
	return($list);
}
# ==================================================
# // private functions - non block related
# ==================================================
sub _css_output
{ # for css
	my $cms = shift;
	my %var = @_;
	$cms->num(0);
	$cms->tag('site_parts'=>$var{'conf'}->value('conf_srv_base') . $var{'conf'}->value('dir_style'));
	$cms->tag('site_encoding'=>sb::Language->get->charset);
	return $cms->output;
}
sub _common_parts
{ # block independent parts
	my $cms = shift;
	my %var = @_;
	my $title = $var{'blog'}->title;
	my $srvbase = $var{'conf'}->value('conf_srv_base');
	my $selected = '';
	$title .= ' | ' . $var{'entry'}->[0]->subj if ($var{'mode'} eq 'ent');
	$selected = $var{'cat'}->{$var{'id'}}->fullname($var{'cat'},CATEGORY_TITLE) if ($var{'mode'} eq 'cat');
	$selected = join('/',( $var{'cond'} =~ /(\d\d\d\d)(\d\d)(\d\d)?/ )) if ($var{'mode'} eq 'arc');
	$selected =~ s/\/$// if ($var{'mode'} eq 'arc' and $selected =~ /\/$/);
	$title .= ' | ' . $selected if ($selected);
	$selected = 'Search: ' . $var{'cond'} if ($var{'mode'} eq 'srch');
	$cms->num(0);
	$cms->tag('site_css'=>$var{'css'});
	$cms->tag('site_title'=>$title);
	$cms->tag('selected_archive'=>$selected);
	$cms->tag('site_cgi'=>$var{'conf'}->value('conf_srv_cgi') . $var{'conf'}->value('basic_sb'));
	$cms->tag('site_mobile'=>$var{'conf'}->value('conf_srv_cgi') . $var{'conf'}->value('basic_mob'));
	$cms->tag('site_rss'=>$srvbase . $var{'conf'}->value('conf_dir_log') . $var{'conf'}->value('file_rss'));
	$cms->tag('site_atom'=>$srvbase . $var{'conf'}->value('conf_dir_log') . $var{'conf'}->value('file_atom'));
	$cms->tag('site_rsd'=>$var{'conf'}->value('conf_srv_cgi') . $var{'conf'}->value('basic_rsd'));
	$cms->tag('site_top'=>$srvbase);
	$cms->tag('site_encoding'=>$var{'lang'}->charset);
	$cms->tag('site_lang'=>$var{'lang'}->code);
	$cms->tag('site_parts'=>$var{'conf'}->value('conf_srv_base') . $var{'conf'}->value('dir_style'));
	$cms->tag('script_version'=>$sb::VERSION);
	$cms->tag('script_name'=>$sb::PRODUCT);
	$cms->tag('script_webpage'=>$sb::WEBPAGE);
	my $name = 
		  ($var{'mode'} eq 'ent')                             ? 'entry'
		: ($var{'mode'} eq 'arc' and $var{'cond'} =~ /\d{8}/) ? 'daily'
		: ($var{'mode'} eq 'arc' and $var{'cond'} =~ /\d{6}/) ? 'monthly'
		: ($var{'mode'} eq 'srch')                            ? 'search'
		: ($var{'mode'} eq 'cat')                             ? 'category'
		: ($var{'mode'} eq 'user')                            ? 'profile'
		: 'page';
	$cms->tag('mode_name'=>$name);
	my $id = 
	  ($var{'mode'} eq 'page')                          ? $var{'page'}
	: ($var{'mode'} eq 'arc' or $var{'mode'} eq 'srch') ? $var{'cond'}
	: $var{'id'};
	$cms->tag('mode_id'=>$id);
	return(1);
}
# ==================================================
# // private functions - list
# ==================================================
sub _list_archives
{ # アーカイブリスト
	my $cms = shift;
	my %var = @_;
	my @linklist = ('<ul>');
	my @array = sort { $b <=> $a } keys(%{$var{'entryinfo'}{'monthly'}});
	foreach my $list ( @array )
	{
		my $count = $var{'entryinfo'}{'monthly'}{$list}{'count'};
		my $name  = $var{'entryinfo'}{'monthly'}{$list}{'name'};
		my $url   = &_monthly_link($list,$var{'conf'});
		push(@linklist,qq|<li><a href="$url">$name</a> ($count)</li>|);
	}
	push(@linklist,'</ul>');
	$cms->num(0);
	$cms->tag('archives_list'=>join("\n",@linklist));
	return (@linklist > 2) ? 1 : 0;
}
sub _list_category
{ # カテゴリーリスト
	my $cms = shift;
	my %var = @_;
	my ($all_list,$sub_list);
	my $cat = undef;
	$all_list = &_category_tree(
		'cat' => $var{'sortedcat'},
		'num' => $var{'entryinfo'}{'category'},
	);
	$cat = $var{'cat'}->{$var{'id'}} if ($var{'mode'} eq 'cat');
	if ($var{'mode'} eq 'ent' and $var{'entry'}->[0])
	{
		my $cat_id = $var{'entry'}->[0]->cat;
		$cat = $var{'cat'}->{$cat_id} if ($cat_id ne '');
	}
	if ($cat)
	{
		$sub_list = &_category_tree(
			'cat'    => $var{'sortedcat'},
			'branch' => $cat->id,
			'num'    => $var{'entryinfo'}{'category'},
		);
	}
	$cms->num(0);
	$cms->tag('category_list'    => ($all_list) ? '<ul>' . $all_list . '</ul>' : '');
	$cms->tag('subcategory_list' => ($sub_list) ? '<ul>' . $sub_list . '</ul>' : '');
	return ($all_list or $sub_list) ? 1 : 0;
}
sub _list_comment
{ # コメントリスト
	my $cms = shift;
	my %var = @_;
	my $num = 0;
	my @linklist = ('<ul>');
	my @array = sb::Data->load('Message',
		'sort' => 'date',
		'cond' => {'stat'=>1},
		'order'=> 1,
	);
	foreach my $list ( @array )
	{
		my $entry = sb::Data->load('Entry','id'=>$list->eid);
		next if (!$entry or $entry->stat == 0 or $entry->acm == 0);
		my $url  = $entry->permalink(
			'cat'=>$var{'cat'},
			'mode'=>'com',
			'type'=>$var{'conf'}->value('conf_entry_archive')
		);
		my $subj = $entry->subj;
		my $date = sb::Time->format(
			'time'=>$list->date,
			'form'=>$var{'conf'}->value('conf_dateinlist'),
			'zone'=>$var{'conf'}->value('conf_timezone')
		);
		my $arrow = $var{'lang'}->string('parts_arrow');
		my $author = $list->auth;
		push(@linklist,qq|<li>$subj<br />$arrow <a href="$url">$author$date</a></li>|);
		$num++;
		last if ($num == $var{'conf'}->value('conf_com_disp'));
	}
	push(@linklist,'</ul>');
	$cms->num(0);
	$cms->tag('recent_comment_list'=>join("\n",@linklist));
	return (@linklist > 2) ? 1 : 0;
}
sub _list_trackback
{ # トラックバックリスト
	my $cms = shift;
	my %var = @_;
	my $num = 0;
	my @linklist = ('<ul>');
	my @array = sb::Data->load('Trackback',
		'sort' => 'date',
		'cond' => {'stat'=>1},
		'order'=> 1,
	);
	foreach my $list ( @array )
	{
		my $entry = sb::Data->load('Entry','id'=>$list->eid);
		next if (!$entry or $entry->stat == 0 or $entry->atb == 0);
		my $url = $entry->permalink(
			'cat'=>$var{'cat'},
			'mode'=>'tb',
			'type'=>$var{'conf'}->value('conf_entry_archive')
		);
		my $subj = $entry->subj;
		my $date = sb::Time->format(
			'time'=>$list->date,
			'form'=>$var{'conf'}->value('conf_dateinlist'),
			'zone'=>$var{'conf'}->value('conf_timezone')
		);
		my $arrow = $var{'lang'}->string('parts_arrow');
		my $name = $list->name;
		push(@linklist,qq|<li>$subj<br />$arrow <a href="$url">$name$date</a></li>|);
		$num++;
		last if ($num == $var{'conf'}->value('conf_tb_disp'));
	}
	push(@linklist,'</ul>');
	$cms->num(0);
	$cms->tag('recent_trackback_list'=>join("\n",@linklist));
	return (@linklist > 2) ? 1 : 0;
}
sub _list_latest
{ # 最新エントリーリスト
	my $cms = shift;
	my %var = @_;
	my @linklist = ('<ul>');
	foreach my $list ( @{$var{'entryinfo'}{'latest'}} )
	{
		my $subj = $list->subj;
		my $url = $list->permalink(
			'cat'=>$var{'cat'},
			'type'=>($var{'mode'} eq 'mob') ? 'Mobile' : $var{'conf'}->value('conf_entry_archive')
		);
		my $date = sb::Time->format(
			'time'=>$list->date,
			'form'=>$var{'conf'}->value('conf_dateinlist'),
			'zone'=>$var{'conf'}->value('conf_timezone')
		);
		push(@linklist,qq|<li><a href="$url">$subj</a>$date</li>|);
	}
	push(@linklist,'</ul>');
	$cms->num(0);
	$cms->tag('latest_entry_list'=>join("\n",@linklist));
	return (@linklist > 2) ? 1 : 0;
}
sub _list_selected
{ # 選択エントリーリスト
	my $cms = shift;
	my %var = @_;
	my @linklist = ('<ul>');
	my @entries = @{$var{'entry'}};
	if ($var{'mode'} eq 'ent')
	{
		my $neighbor = $var{'entryinfo'}->{'neighbor'};
		unshift(@entries,$neighbor->{'next'}) if ($neighbor->{'next'});
		push(@entries,$neighbor->{'prev'}) if ($neighbor->{'prev'});
	}
	foreach my $list ( @entries )
	{
		my $subj = $list->subj;
		my $url = $list->permalink(
			'cat'=>$var{'cat'},
			'type'=>($var{'mode'} eq 'mob') ? 'Mobile' : $var{'conf'}->value('conf_entry_archive')
		);
		my $date = sb::Time->format(
			'time'=>$list->date,
			'form'=>$var{'conf'}->value('conf_dateinlist'),
			'zone'=>$var{'conf'}->value('conf_timezone')
		);
		push(@linklist,qq|<li><a href="$url">$subj</a>$date</li>|);
	}
	push(@linklist,'</ul>');
	$cms->num(0);
	$cms->tag('selected_entry_list'=>join("\n",@linklist));
	return (@linklist > 2) ? 1 : 0;
}
sub _list_link
{ # リンクリスト
	my $cms = shift;
	my %var = @_;
	my @linklist = ('<ul>');
	my @array = sb::Data->load('Link','sort'=>'order','cond'=>{'disp'=>0},'order'=>1);
	my %group = ();
	foreach my $list ( @array )
	{
		$group{$list->id} = [] if ($list->is_group);
	}
	foreach my $list ( @array )
	{
		if ($list->type =~ /^\d+$/ and $list->url ne '' and ref($group{$list->type}) eq 'ARRAY')
		{
			push(@{$group{$list->type}},$list);
		}
	}
	foreach my $list (@array)
	{
		next if ($list->type =~ /^\d+$/);
		my $title  = ($list->text ne '')   ? ' title="'  . $list->text  . '"'  : '';
		my $target = ($list->target ne '') ? ' target="' . $list->target . '"' : '';
		my $url    = $list->url;
		my $name   = $list->name;
		if ($list->is_group and @{$group{$list->id}})
		{
			push(@linklist,qq|<li><span$title>$name</span><ul>|);
			foreach my $lnk (@{$group{$list->id}})
			{
				my $chd_title  = ($lnk->text ne '')   ? ' title="'  . $lnk->text  . '"'  : '';
				my $chd_target = ($lnk->target ne '') ? ' target="' . $lnk->target . '"' : '';
				my $chd_url    = $lnk->url;
				my $chd_name   = $lnk->name;
				push(@linklist,qq|<li><a href="$chd_url"$chd_title$chd_target>$chd_name</a></li>|);
			}
			push(@linklist,qq|</ul></li>|);
		}
		elsif ($url ne '')
		{
			push(@linklist,qq|<li><a href="$url"$title$target>$name</a></li>|);
		}
	}
	push(@linklist,'</ul>');
	$cms->num(0);
	$cms->tag('link_list'=>join("\n",@linklist));
	return (@linklist > 2) ? 1 : 0;
}
sub _list_profile
{ # プロフィールリスト
	my $cms = shift;
	my %var = @_;
	my $baseurl = $var{'conf'}->value('conf_srv_cgi') . $var{'conf'}->value('basic_sb') . '?pid=';
	my @userlist = ('<ul>');
	my @array = sort { $b->order <=> $a->order } values( %{$var{'user'}} );
	foreach my $user ( @array )
	{
		next if ($user->disp == 1);
		my $name = ($user->real ne '') ? $user->real : $user->name;
		my $url = join('',$baseurl,$user->id);
		push(@userlist,qq|<li><a href="$url">$name</a></li>|);
	}
	push(@userlist,'</ul>');
	$cms->num(0);
	$cms->tag('user_list'=>join("\n",@userlist));
	return (@userlist > 2) ? 1 : 0;
}
# ==================================================
# // private functions - navigation
# ==================================================
sub _title
{ # タイトルブロック
	my $cms = shift;
	my %var = @_;
	my $toplink = $var{'conf'}->value('conf_srv_base');
	$cms->num(0);
	$cms->tag('blog_name_only'=>$var{'blog'}->title);
	$cms->tag('blog_name'=>'<a href="' . $toplink . '">' . $var{'blog'}->title . '</a>');
	$cms->tag('blog_description'=>sb::Text->format('text'=>$var{'blog'}->text,'form'=>1));
	return(1);
}
sub _calendar
{ # カレンダー
	my $cms = shift;
	my %var = @_;
	my %cal = ('no1'=>'','no2'=>'','hor'=>'','ver'=>'','tab'=>'');
	my $zone = $var{'conf'}->value('conf_timezone');
	my $date = ($var{'mode'} eq 'arc') 
		? substr($var{'cond'},0,6) 
		: sb::Time->format(
			'time'=>$var{'time'},
			'form'=>'%Year%%Mon%',
			'zone'=>$zone,
		);
	my $year  = substr($date,0,4);
	my $mon   = substr($date,4,2);
	my $week  = sb::Time->get_weekday('year'=>$year,'mon'=>$mon);
	my $end   = sb::Time->get_lastday('year'=>$year,'mon'=>$mon);
	my $today = sb::Time->format(
		'time'=>$var{'time'},
		'form'=>'%Year%%Mon%%Day%',
		'zone'=>$zone,
	);
	my $cgi   = $var{'conf'}->value('conf_srv_cgi') . $var{'conf'}->value('basic_sb') . '?day=';
	my $label = sb::Time->format(
		'time'=>($var{'mode'} eq 'arc')
			? sb::Time->convert('year'=>$year,'mon'=>$mon,'zone'=>$zone)
			: $var{'time'},
		'form'=>$var{'conf'}->value('conf_archivelist'),
		'lang'=>$var{'conf'}->value('conf_time_lang'),
		'zone'=>$zone,
	);
	my $prev  = ($mon != 1)  ? $year . &_pad0($mon - 1) : ($year - 1) . '12';
	my $next  = ($mon != 12) ? $year . &_pad0($mon + 1) : ($year + 1) . '01';
	$prev = '<a href="' . &_monthly_link($prev,$var{'conf'}) . '">' . PREV_ARROW . '</a>';
	$next = '<a href="' . &_monthly_link($next,$var{'conf'}) . '">' . NEXT_ARROW . '</a>';
	{ # カレンダー最初の処理
		$cal{'no1'}  = '<table border="0" cellspacing="0" cellpadding="0" class="calendar">' . "\n";
		$cal{'no2'}  = '<table border="0" cellspacing="0" cellpadding="0" class="calendar">' . "\n";
		$cal{'no2'} .= '<tr>' . "\n" . '<td colspan="7" class="calendar_month">' . $prev . ' ';
		$cal{'no2'} .= $label . ' ' . $next . '</td>' . "\n" . '</tr>' . "\n";
		$cal{'no2'} .= '<tr><td class="weekday">Sun</td>';
		$cal{'no2'} .= '<td class="weekday">Mon</td>';
		$cal{'no2'} .= '<td class="weekday">Tue</td>';
		$cal{'no2'} .= '<td class="weekday">Wed</td>';
		$cal{'no2'} .= '<td class="weekday">Thu</td>';
		$cal{'no2'} .= '<td class="weekday">Fri</td>';
		$cal{'no2'} .= '<td class="weekday">Sat</td></tr>' . "\n";
		$cal{'ver'}  = '<br />' . "\n" . $mon . '<br />' . "\n" . '--<br />' . "\n";
		$cal{'hor'}  = $prev . ' <span class="calendar_month">';
		$cal{'hor'} .= $label . '</span> | ';
	}
	for (my $d=1;$d<=$end;$d++)
	{ # カレンダー本体
		my $w = ($d - 1 + $week) % 7;
		my $check = $date . &_pad0($d);
		$cal{'tab'} .= '<tr>' if ($d == 1 or ($w == 0 and $d > 1));
		$cal{'tab'} .= ('<td class="cell">&nbsp;</td>' x $w) if ($d == 1 and $w > 0);
		$cal{'tab'} .= '<td class="cell">';
		if ($var{'entryinfo'}{'daily'}{$check})
		{
			$cal{'tab'} .= '<a href="' . $cgi . $check . '">';
			$cal{'hor'} .= '<a href="' . $cgi . $check . '">';
			$cal{'ver'} .= '<a href="' . $cgi . $check . '">';
		}
		{ # 日付表示
			$cal{'tab'} .= ($check eq $today) ? '<span class="today">' . $d . '</span>' : $d;
			$cal{'hor'} .= ($check eq $today) ? '<span class="today">' . $d . '</span>' : $d;
			$cal{'ver'} .= ($check eq $today) ? '<span class="today">' . $d . '</span>' : $d;
		}
		if ($var{'entryinfo'}{'daily'}{$check})
		{
			$cal{'tab'} .= '</a>';
			$cal{'hor'} .= '</a>';
			$cal{'ver'} .= '</a>';
		}
		$cal{'tab'} .= '</td>';
		$cal{'hor'} .= ' ';
		$cal{'ver'} .= '<br />' . "\n";
		$cal{'tab'} .= ('<td class="cell">&nbsp;</td>' x (6 - $w)) if ($d == $end);
		$cal{'tab'} .= '</tr>' . "\n" if ($d == $end or $w == 6);
	}
	{ # カレンダー最後の処理
		$cal{'no1'} .= $cal{'tab'} . '<tr><td colspan="7"><div style="text-align: center;" class="calendar_month">';
		$cal{'no1'} .= $prev . ' ' . $label . ' ' . $next . '</div></td></tr>' . "\n" . '</table>' . "\n";
		$cal{'no2'} .= $cal{'tab'} . '</table>';
		$cal{'ver'} .= '--<br />' . "\n" . $next . '<br />' . "\n";
		$cal{'ver'} .= $prev . '<br />' . "\n" . '--<br />' . "\n";
		$cal{'hor'} .= $next . "\n";
	}
	$cms->num(0);
	$cms->tag('calendar'=>$cal{'no1'});
	$cms->tag('calendar2'=>$cal{'no2'});
	$cms->tag('calendar_vertical'=>$cal{'ver'});
	$cms->tag('calendar_horizontal'=>$cal{'hor'});
	return(1);
}
sub _amazon
{ # オススメ
	my $cms = shift;
	my %var = @_;
	my @array = sb::Data->load('Amazon',
		'sort'  => 'order',
		'cond'  => {'stat'=>1},
		'order' => 1,
		'num'   => $var{'conf'}->value('conf_aws_disp'),
	);
	my $num = 0;
	foreach my $item ( @array )
	{
		$cms->num($num);
		$cms->tag('amazon_ProductName'=>$item->name);
		$cms->tag('amazon_Catalog'=>$item->cat);
		$cms->tag('amazon_Creator'=>sb::Text->format('text'=>$item->cre,'form'=>1));
		$cms->tag('amazon_ReleaseDate'=>$item->days);
		$cms->tag('amazon_Manufacturer'=>$item->make);
		$cms->tag('amazon_ImageUrlSmall'=>$item->ism);
		$cms->tag('amazon_ImageUrlMedium'=>$item->imd);
		$cms->tag('amazon_ImageUrlLarge'=>$item->ilg);
		$cms->tag('amazon_Availability'=>$item->ava);
		$cms->tag('amazon_ListPrice'=>$item->lpr);
		$cms->tag('amazon_OurPrice'=>$item->opr);
		$cms->tag('amazon_comment'=>sb::Text->format('text'=>$item->msg,'form'=>1));
		$cms->tag('amazon_htmlcomment'=>sb::Text->detitize($item->msg));
		$cms->tag('amazon_url'=>$item->url);
		$cms->tag('amazon_item'=>$item->formated_item);
		$num++;
	}
	return($num);
}
sub _page
{ # ページ
	my $cms = shift;
	my %var = @_;
	return(0) if ($var{'page'} == -1 or $var{'mode'} eq 'ent' or $var{'mode'} eq 'user');
	my $disp = ( $var{'num'} > 0 ) ? $var{'num'} : 1;
	my $page_num = int($var{'entry_num'} / $disp);
	my $cgi = ($var{'mode'} ne 'mob')
		? $var{'conf'}->value('conf_srv_cgi') . $var{'conf'}->value('basic_sb') . '?page='
		: $var{'conf'}->value('conf_srv_cgi') . $var{'conf'}->value('basic_mob') . '?page=';
	my $query = '';
	my $prev_url = '';
	my $next_url = '';
	$cms->num(0);
	$page_num++ if ($var{'entry_num'} % $disp != 0 and $var{'entry_num'} > 0);
	$cms->tag('page_num'=>$page_num);
	$cms->tag('page_now'=>$var{'page'} + 1);
	$query = 'cid=' . $var{'id'} if ($var{'mode'} eq 'cat' or $var{'mode'} eq 'mob' and $var{'id'} ne '');
	$query = 'month=' . $var{'cond'} if ($var{'mode'} eq 'arc' and $var{'cond'} =~ /^\d{6}$/);
	$query = 'day=' . $var{'cond'} if ($var{'mode'} eq 'arc' and $var{'cond'} =~ /^\d{8}$/);
	if ($var{'mode'} eq 'srch')
	{
		my $text = $var{'cond'};
		$text =~ s/(\W)/'%' . unpack('H2', $1)/eg;
		$query = 'search=' . $text;
	}
	$prev_url = $cgi . ($var{'page'} - 1) if ($var{'page'} > 0);
	$next_url = $cgi . ($var{'page'} + 1) if ($var{'page'} < ($page_num - 1));
	$prev_url .= '&amp;' . $query if ($query and $prev_url);
	$next_url .= '&amp;' . $query if ($query and $next_url);
	$cms->tag('prev_page_url'=>$prev_url);
	$cms->tag('prev_page_link'=>'<a href="' . $prev_url . '">' . PREV_ARROW . '</a>') if ($prev_url);
	$cms->tag('next_page_url'=>$next_url);
	$cms->tag('next_page_link'=>'<a href="' . $next_url . '">'. NEXT_ARROW . '</a>') if ($next_url);
	return(1);
}
sub _option
{ # オプションブロック
	my $cms = shift;
	my %var = @_;
	$cms->deleteBlock('option') if ( $var{'mode'} ne 'ent' );
	return ( $var{'mode'} eq 'ent' ) ? 1 : 0;
}
# ==================================================
# // private functions - main block
# ==================================================
sub _parse_area
{
	my ($cms,$area,$var,$data) = @_;
	my $num = 0;
	foreach my $obj ( @{$data} )
	{
		$cms->num($num);
		foreach my $label (keys %{ $mCallbacks{$area} } )
		{
			next if ($label eq '_main');
			eval{ &{$mCallbacks{$area}{$label}}($cms,$obj,%$var) };
		}
		$num++;
	}
	$cms->num(0);
	eval{ &{$mCallbacks{$area}{'_main'}}($cms,%{$var}) };
	return($num);
}
sub _area_entry
{ # entry block
	my $cms = shift;
	my %var = @_;
	return(0) if ( $var{'mode'} eq 'user' );
	return &_parse_area($cms,'entry',\%var,$var{'entry'});
}
sub _area_comment
{ # comment_area block
	my $cms = shift;
	my %var = @_;
	return(0) if ( $var{'mode'} ne 'ent' );
	return(0) if ( $var{'entry'}[0]->acm == 0 );
	my @list = sb::Data->load('Message',
		'sort'   => 'date',
		'cond'   => {'stat'=>1,'eid'=>$var{'id'}},
		'order'  => $var{'conf'}->value('conf_com_sort'),
	);
	my @comments = ();
	for (my $i=0;$i<@list;$i++)
	{
		my $com = sb::Data->load('Message','id'=>$list[$i]->id);
		push(@comments,$com) if ($com);
	}
	my $num = &_parse_area($cms,'comment',\%var,\@comments);
	$cms->block('comment'=>$num);
	return(1);
}
sub _area_trackback
{ # trackback_area block
	my $cms = shift;
	my %var = @_;
	return(0) if ( $var{'mode'} ne 'ent' );
	return(0) if ( $var{'entry'}[0]->atb == 0 );
	my @list = sb::Data->load('Trackback',
		'sort'   => 'date',
		'cond'   => {'stat'=>1,'eid'=>$var{'id'}},
		'order'  => $var{'conf'}->value('conf_tb_sort'),
	);
	my @trackbacks = ();
	for (my $i=0;$i<@list;$i++)
	{
		my $tb = sb::Data->load('Trackback','id'=>$list[$i]->id);
		push(@trackbacks,$tb) if ($tb);
	}
	my $num = &_parse_area($cms,'trackback',\%var,\@trackbacks);
	$cms->block('trackback'=>$num);
	return(1);
}
sub _area_profile
{ # profile_area block
	my $cms = shift;
	my %var = @_;
	return(0) if ( $var{'mode'} ne 'user' );
	my $user = sb::Data->load('User','id'=>$var{'id'});
	&_parse_area($cms,'profile',\%var,[$user]);
	return(1);
}
sub _area_category
{ # category_area block
	my $cms = shift;
	my %var = @_;
	return(0) if ( $var{'mode'} ne 'cat' );
	# return(0) if ( $var{'page'} > 0 ); # just for top page only (ignored)
	&_parse_area($cms,'category',\%var,[$var{'cat'}->{$var{'id'}}]);
	return(1);
}
# ==================================================
# // private functions - entry block
# ==================================================
package sb::Content::Entry;

sub PREV_ARROW (){ '&lt;&lt;' };
sub NEXT_ARROW (){ '&gt;&gt;' };

sub _init
{ # デフォルトコールバック関数
	return {
		'_main'     => \&_main,
		'date_time' => \&_date_time,
		'authors'   => \&_authors,
		'attach'    => \&_attachment,
		'category'  => \&_category,
		'body_text' => \&_body_text,
		'discovery' => \&_trackback_auto_discovery,
		'sequel'    => \&_sequel,
		'others'    => \&_others,
	};
}
sub _main
{ # 共通要素
	my $cms  = shift;
	my %var  = @_;
	undef;
}
sub _date_time
{ # 日付と時刻
	my $cms   = shift;
	my $entry = shift;
	my %var   = @_;
	my $date = sb::Time->format(
		'time'=>$entry->date,
		'form'=>$var{'conf'}->value('conf_entry_date'),
		'zone'=>$entry->tz,
		'lang'=>$var{'conf'}->value('conf_time_lang')
	);
	$cms->tag('entry_date'=>$date);
	my $time = sb::Time->format(
		'time'=>$entry->date,
		'form'=>$var{'conf'}->value('conf_entry_time'),
		'zone'=>$entry->tz,
		'lang'=>$var{'conf'}->value('conf_time_lang')
	);
	my $permalink =  &_permalink($entry,$var{'cat'},'',$var{'mode'});
	$cms->tag('entry_time'=>'<a href="' . $permalink . '">' . $time . '</a>');
	$cms->tag('entry_disp_time'=>$time);
}
sub _authors
{ # 著者
	my $cms   = shift;
	my $entry = shift;
	my %var   = @_;
	$cms->tag('user_name'=>$entry->authlink($var{'user'}));
	$cms->tag('user_disp_name'=>$entry->authname($var{'user'}));
	$cms->tag('user_id'=>$entry->auth);
}
sub _attachment
{ # コメント数・トラックバック数
	my $cms   = shift;
	my $entry = shift;
	my %var   = @_;
	if ($entry->acm > 0)
	{ # コメント数
		my $permalink = &_permalink($entry,$var{'cat'},'com',$var{'mode'});
		my $string = $var{'lang'}->string('parts_com_num');
		$cms->tag('comment_num'=>'<a href="' . $permalink . '">' . $string . '(' . $entry->com . ')</a>');
		$cms->tag('comment_count'=>$entry->com);
	}
	else
	{
		$cms->tag('comment_num'=>'-');
		$cms->tag('comment_count'=>'');
	}
	if ($entry->atb > 0)
	{ # トラックバック数
		my $permalink = &_permalink($entry,$var{'cat'},'tb',$var{'mode'});
		my $string = $var{'lang'}->string('parts_tb_num');
		$cms->tag('trackback_num'=>'<a href="' . $permalink . '">' . $string . '(' . $entry->tb . ')</a>');
		$cms->tag('trackback_count'=>$entry->tb);
	}
	else
	{
		$cms->tag('trackback_num'=>'-');
		$cms->tag('trackback_count'=>'');
	}
}
sub _category
{ # カテゴリー
	my $cms   = shift;
	my $entry = shift;
	my %var   = @_;
	if ( $entry->cat ne '' and defined($var{'cat'}->{$entry->cat}) )
	{ # カテゴリー
		$cms->tag('category_name'=>$var{'cat'}->{$entry->cat}->fullname_with_link($var{'cat'}));
		$cms->tag('category_id'=>$entry->cat);
		$cms->tag('category_disp_name'=>$var{'cat'}->{$entry->cat}->fullname($var{'cat'}));
	}
	else
	{
		$cms->tag('category_name'=>'-');
		$cms->tag('category_id'=>'');
		$cms->tag('category_disp_name'=>'-');
	}
	if ( $entry->add ne '' )
	{ # 関連カテゴリー
		my (@text,@with_link);
		foreach ( split(',',$entry->add) )
		{
			next if ($_ eq '');
			next if ( !defined($var{'cat'}->{$_}) );
			push(@with_link,$var{'cat'}->{$_}->fullname_with_link($var{'cat'}));
			push(@text,$var{'cat'}->{$_}->fullname($var{'cat'}));
		}
		$cms->tag('related_category'=>join(', ',@with_link));
		$cms->tag('related_category_disp'=>join(', ',@text));
	}
	else
	{
		$cms->tag('related_category'=>'-');
		$cms->tag('related_category_disp'=>'-');
	}
}
sub _body_text
{ # 本文・続き・概要
	my $cms   = shift;
	my $entry = shift;
	my %var   = @_;
	if ($entry->body ne '')
	{ # 本文
		my $body = $entry->formated_body;
		$body .= '<a id="sequel"></a>' if ($entry->more ne '' and $var{'mode'} eq 'ent');
		$cms->tag('entry_description'=>$body);
	}
	if ($entry->more ne '')
	{ # 続き
		my $permalink = &_permalink($entry,$var{'cat'},'more',$var{'mode'});
		my $more = ($var{'mode'} eq 'ent') 
		         ? $entry->formated_more 
		         : '<a href="' . $permalink . '">' . $var{'lang'}->string('parts_sequel') . '</a>';
		$cms->tag('entry_sequel'=>$more);
	}
	$cms->tag('entry_excerpt'=>$entry->sum);
}
sub _trackback_auto_discovery
{ # トラックバック自動検出用 rdf 埋め込み
	my $cms   = shift;
	my $entry = shift;
	my %var   = @_;
	return if ($entry->atb == 0); # trackback is not acceptable, so we ignore this.
	my $permalink = &_permalink($entry,$var{'cat'},'',$var{'mode'});
	my $subject   = $entry->subj;
	my $author    = ( defined($var{'user'}->{$entry->auth}) ) ? $var{'user'}->{$entry->auth}->real : '';
	my $summary   = $entry->sum;
	my $pingurl   = $entry->pingurl;
	my $creatdate = sb::Time->format(
		'time'=>$entry->date,
		'form'=>'%Year%-%Mon%-%Day%T%Hour%:%Min%:%Sec%',
		'zone'=>$var{'conf'}->value('conf_timezone'),
	);
	$summary =~ s/\-\-/\&#45;\&#45;/g if ($summary =~ /\-\-/);
	my $auto_discovery = <<"_TRACKBACK_AUTO_DISCOVERY_";
<!--
<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"
         xmlns:dc=\"http://purl.org/dc/elements/1.1/\"
         xmlns:trackback=\"http://madskills.com/public/xml/rss/module/trackback/\">
<rdf:Description
   rdf:about=\"$permalink\"
   dc:identifier=\"$permalink\"
   dc:title=\"$subject\"
   dc:description=\"$summary\"
   dc:creator=\"$author\"
   dc:date=\"$creatdate\"
   trackback:ping=\"$pingurl\" />
</rdf:RDF>
-->
_TRACKBACK_AUTO_DISCOVERY_
	$cms->tag('trackback_auto_discovery'=>$auto_discovery);
}
sub _sequel
{ # sequel ブロック
	my $cms   = shift;
	my $entry = shift;
	my %var   = @_;
	return if (!$cms->existed('sequel'));
	if ($var{'mode'} eq 'ent' or $var{'mode'} eq 'mob')
	{
		foreach my $label ('next','prev')
		{
			my $entry = $var{'entryinfo'}{'neighbor'}{$label};
			if ($entry)
			{
				my $url  = &_permalink($entry,$var{'cat'},'',$var{'mode'});
				my $subj = $entry->subj;
				my $text = ($label eq 'next') 
				         ? $subj . ' ' . NEXT_ARROW
				         : PREV_ARROW . ' ' . $subj;
				$cms->tag($label . '_permalink'=>$url);
				$cms->tag($label . '_title'=>$subj);
				$cms->tag($label . '_entry'=>'<a href="' . $url . '">' . $text . '</a>');
			}
		}
		$cms->block('sequel'=>1);
	}
	else
	{
		$cms->deleteBlock('sequel');
	}
}
sub _others
{ # その他のパーツ
	my $cms   = shift;
	my $entry = shift;
	my %var   = @_;
	$cms->tag('entry_id'=>$entry->id);
	$cms->tag('permalink'=>&_permalink($entry,$var{'cat'},'',$var{'mode'}));
	$cms->tag('entry_permalink'=>&_permalink($entry,$var{'cat'},'',$var{'mode'}));
	$cms->tag('entry_title'=>$entry->subj);
	$cms->tag('entry_keyword'=>$entry->key);
	$cms->tag('site_parts'=>$var{'conf'}->value('conf_srv_base') . $var{'conf'}->value('dir_style'));
	if ($var{'conf'}->value('basic_marking') and $var{'mode'} ne 'ent')
	{
		$cms->tag('sb_entry_marking'=>'<a id="' . $var{'conf'}->value('basic_preid') . $entry->id . '"></a>');
	}
}
sub _permalink
{ # パーマリンク生成
	my ($entry,$cat,$mode,$check) = @_;
	my $type = ($check eq 'mob') ? 'Mobile' : sb::Config->get->value('conf_entry_archive');
	$entry->permalink('cat'=>$cat,'type'=>$type,'mode'=>$mode);
}
# ==================================================
# // private functions - comment block
# ==================================================
package sb::Content::Message;

sub _init
{ # デフォルトコールバック関数
	return {
		'_main'   => \&_main,
		'content' => \&_content,
	};
}
sub _main
{ # 共通要素
	my $cms  = shift;
	my %var  = @_;
	my $js = $var{'conf'}->value('conf_srv_base') . $var{'conf'}->value('conf_dir_log') . $var{'conf'}->value('file_cook');
	$cms->tag('sb_comment_js'=>'<script type="text/javascript" src="' . $js . '"></script>');
	$cms->tag('cookie_name'=>'');
	$cms->tag('cookie_email'=>'');
	$cms->tag('cookie_url'=>'');
	my @icons = sb::Data->load('Image','cond'=>{'icon_c'=>1});
	if (@icons)
	{
		my $icon_form = '<div id="icon_form"><select name="icon" id="icon" onchange="previewCommentIcon(this.value);">';
		$icon_form .= '<option value="">' . $var{'lang'}->string('parts_no_icon') . '</option>' . "\n";
		foreach my $icon (@icons)
		{
			$icon_form .= '<option value="' . $icon->id . '"';
			$icon_form .= ' selected="selected"' if ($icon->id eq $var{'cookie'}->{'icon'});
			$icon_form .= '>' . $icon->name . '</option>' . "\n";
		}
		$icon_form .= '</select><span>[icon]</span></div>' . "\n";
		$cms->tag('comment_iconform'=>$icon_form);
	}
}
sub _content
{ # ブロック内の要素
	my $cms  = shift;
	my $com  = shift;
	my %var  = @_;
	my $date = sb::Time->format(
		'time'=>$com->date,
		'form'=>$var{'conf'}->value('conf_msg_time'),
		'zone'=>$com->tz,
		'lang'=>$var{'conf'}->value('conf_time_lang'),
	);
	$cms->tag('comment_description'=>$com->formated_body);
	$cms->tag('comment_name'=>$com->auth_with_url);
	$cms->tag('comment_time'=>$date);
	$cms->tag('comment_icon'=>$com->icon_image);
	$cms->tag('site_parts'=>$var{'conf'}->value('conf_srv_base') . $var{'conf'}->value('dir_style'));
}
# ==================================================
# // private functions - trackback block
# ==================================================
package sb::Content::Trackback;

sub _init
{ # デフォルトコールバック関数
	return {
		'_main'   => \&_main,
		'content' => \&_content,
	};
}
sub _main
{ # 共通要素
	my $cms  = shift;
	my %var  = @_;
	$cms->tag('trackback_url'=>$var{'entry'}[0]->pingurl);
}
sub _content
{ # ブロック内の要素
	my $cms  = shift;
	my $tb   = shift;
	my %var  = @_;
	my $date = sb::Time->format(
		'time'=>$tb->date,
		'form'=>$var{'conf'}->value('conf_msg_time'),
		'zone'=>$tb->tz,
		'lang'=>$var{'conf'}->value('conf_time_lang'),
	);
	$cms->tag('trackback_title'=>$tb->subj_with_url);
	$cms->tag('trackback_excerpt'=>$tb->formated_body);
	$cms->tag('trackback_blog_name'=>$tb->name);
	$cms->tag('trackback_time'=>$date);
	$cms->tag('site_parts'=>$var{'conf'}->value('conf_srv_base') . $var{'conf'}->value('dir_style'));
}
# ==================================================
# // private functions - profile block
# ==================================================
package sb::Content::Profile;

sub _init
{ # デフォルトコールバック関数
	return {
		'_main'   => \&_main,
		'content' => \&_content,
	};
}
sub _main
{ # 共通要素
	my $cms  = shift;
	my %var  = @_;
	undef;
}
sub _content
{ # ブロック内の要素
	my $cms  = shift;
	my $user = shift;
	my %var  = @_;
	my $prof = ($user->form ne 'on') 
	         ? sb::Text->format('text'=>$user->prof,'form'=>1) 
	         : $user->prof;
	$cms->tag('profile_description'=>$prof);
	$cms->tag('profile_name'=>$user->real);
	$cms->tag('site_parts'=>$var{'conf'}->value('conf_srv_base') . $var{'conf'}->value('dir_style'));
}
# ==================================================
# // private functions - category area block
# ==================================================
package sb::Content::Category;

sub _init
{ # default callbacks
	return {
		'_main'   => \&_main,
		'content' => \&_content,
	};
}
sub _main
{ # common
	my $cms  = shift;
	my %var  = @_;
	undef;
}
sub _content
{ # contents in block
	my $cms  = shift;
	my $cat  = shift;
	my %var  = @_;
	$cms->tag('category_description'=>$cat->formated_text());
	$cms->tag('category_pagename'=>$cat->name());
	$cms->tag('category_fullname'=>$cat->fullname($var{'cat'}));
	$cms->tag('site_parts'=>$var{'conf'}->value('conf_srv_base') . $var{'conf'}->value('dir_style'));
}
1; # end of package
__END__
