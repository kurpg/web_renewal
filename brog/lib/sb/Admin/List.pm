# sb::Admin::List - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Admin::List;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.05';
# 0.05 [2006/11/01] changed _change_entry_status to change status of comment/trackback via the list
# 0.04 [2006/11/01] added _display_entry_statnum to output entry status class correctly
# 0.03 [2005/07/26] changed change_order to allow setting the order to the top
# 0.02 [2005/06/02] fixed a buf for displaying label of list related setting title attribute.
# 0.01 [2005/06/01] set title attribute for a list / load detail data for updating attachment.
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
use sb::Time ();
use sb::Build ();
use sb::App::Admin ();
@ISA = qw( sb::App::Admin );
# ==================================================
# // declaration for constant value
# ==================================================
sub TEMPLATE        (){ 'list.html' };
sub PAGELINK        (){ 'pagelink.html' };
sub COOKIE_CONF     (){ 'conf' };
sub MAX_LISTNUM     (){ 100 };
sub MIN_LISTNUM     (){ 10 };
sub DEFAULT_NUM     (){ 20 };
sub ITEM_LENGTH     (){ 20 };
sub CATEGORY_LENGTH (){ 25 };
sub NO_CATEGORY     (){ '&nbsp;' };
sub DENIED_CHECK    (){ '-' };
sub LIST_COLUMN     (){ 7 };
sub DATE_FORMAT     (){ '%YearShort%.%Mon%.%Day% %Hour%:%Min%' };
sub DATE_LANG       (){ 'en' };
# ==================================================
# // declaration for class member
# ==================================================
my %mListSettings = (
	'dispnum'  => DEFAULT_NUM, # 表示数
	'displist' => 'simple',    # 表示タイプ(simple or detail)
);
my @mListNumArray = (20,50,100);
# ==================================================
# // public functions - for sub class
# ==================================================
sub setup_list { # リスト表示設定
	my $self = shift;
	my %setting = %mListSettings;
	my $cgi  = sb::Interface->get;
	my $conf = sb::Config->get;
	my $cookie = $cgi->cookie('name'=>$conf->value('basic_admntag') . COOKIE_CONF);
	foreach my $key ( keys(%setting) ) {
		$setting{$key} = $cookie->{$key} if ( $cookie->{$key} ne '' );
		$setting{$key} = $cgi->value($key) if ( $cgi->value($key) ne '' );
	}
	$setting{'dispnum'} = MAX_LISTNUM if ($setting{'dispnum'} > MAX_LISTNUM);
	$setting{'dispnum'} = MIN_LISTNUM if ($setting{'dispnum'} < MIN_LISTNUM);
	$cgi->set_cookie(
		'time'   => $self->{'time'},
		'name'   => $conf->value('basic_admntag') . COOKIE_CONF,
		'expire' => $conf->value('basic_admn_expire'),
		'path'   => $self->get_script_path,
		'data'   => \%setting,
	);
	return \%setting;
}
sub listmain { # リスト表示
	my $self = shift;
	my %param = (
		'template'    => undef,
		'block'       => 'sb_list',
		'objects'     => [],
		'tags'        => {},
		'date_format' => DATE_FORMAT,
		@_
	);
	return( undef ) unless ( defined($param{'template'}) );
	my $conf = sb::Config->get;
	my $cms = $param{'template'};
	my $num = 0;
	foreach my $obj ( @{$param{'objects'}} ) {
		$cms->num($num);
		foreach my $tag ( keys( %{$param{'tags'}} ) ) {
			my $elem = $param{'tags'}->{$tag};
			if ($elem eq 'date' or $elem eq 'gen' or $elem eq 'mod') {
				my $date = sb::Time->format(
					'time' => $obj->$elem(),
					'form' => $param{'date_format'},
					'zone' => ($elem eq 'date' and $obj->{'tz'} ne '') 
					        ? $obj->tz
					        : $conf->value('conf_timezone'),
					'lang' => DATE_LANG,
				);
				$cms->tag($tag=>$date);
			} elsif ( ref($elem) eq 'CODE' ) {
				eval{ $cms->tag($tag=>&$elem($self,$obj)); };
			} else {
				$cms->tag( $tag => $obj->$elem() );
			}
		}
		$cms->tag('sb_list_class'=>($num % 2) ? 'odd' : 'even');
		$num++;
	}
	$cms->block($param{'block'}=>$num);
	return( $num );
}
sub list_status { # リスト用ステータス
	my $self = shift;
	my %param = (
		'stat'   => 0,
		'string' => 'open:close',
		@_
	);
	$param{'stat'} = 1 if ($param{'stat'} == 2);
	my @status = split(':',$param{'string'});
	return $status[$param{'stat'}];
}
sub clip_text { # リスト用クリッピングテキスト
	my $self = shift;
	my %param = (
		'text'   => undef,
		'length' => ITEM_LENGTH,
		'base'   => undef,
		'user'   => undef,
		'target' => undef,
		@_
	);
	my $attr = ($param{'target'}) ? ' target="' . $param{'target'} . '"' : '';
	my $text = sb::Text->clip('text'=>$param{'text'},'length'=>$param{'length'});
	my $url  = (index('\?',$param{'base'}) == 0) 
	         ? $self->get_script_path . $param{'base'} 
	         : $param{'base'};
	$attr .= ' title="' . $param{'text'} . '"' if ($text ne $param{'text'});
	return ( !defined($param{'user'}) or $self->check_permission('user'=>$param{'user'}) )
		? '<a href="' . $url . '"' . $attr . '>' . $text . '</a>' 
		: $text;
}
sub display_pagelink { # リスト用ページリンク
	my $self = shift;
	my %param = (
		'mode'    => undef,
		'column'  => 1,
		'all'     => 0,
		'printed' => 0,
		'num'     => DEFAULT_NUM,
		'start'   => 0,
		'end'     => undef,
		'params'  => [],
		@_
	);
	return( '' ) unless ( defined($param{'mode'}) );
	my $cms = sb::TemplateManager->new($self->load_template('file'=>PAGELINK));
	my $cgi  = sb::Interface->get;
	my $end  = defined($param{'end'}) ? $param{'end'} : int( $param{'all'} / $param{'num'} );
	my $page = ($cgi->value('page') eq '') ? $param{'start'} : int($cgi->value('page'));
	$page = int($cgi->value('now_page')) + 1 if ( $cgi->value('next') ne '' );
	$page = int($cgi->value('now_page')) - 1 if ( $cgi->value('prev') ne '' );
	$end--  if ( !defined($param{'end'}) and $param{'all'} % $param{'num'} == 0 and $param{'all'} > 0 );
	$self->common_template_parts($cms);
	$cms->num(0);
	$cms->tag('sb_list_all'=>$param{'all'});
	$cms->tag('sb_list_printed'=>$param{'printed'});
	$cms->tag('sb_pagenow'=>$page);
	$cms->tag('sb_pageprev'=>'disabled="disabled"') if ($page == $param{'start'});
	$cms->tag('sb_pagenext'=>'disabled="disabled"') if ($page == $end);
	my $selector = '';
	for (my $i=$param{'start'};$i<=$end;$i++) {
		$selector .= '<option value="' . $i . '"';
		$selector .= ' selected="selected"' if ($i == $page);
		$selector .= '>' . ($i + 1) . '</option>' if ($param{'start'} == 0);
		$selector .= '>' . $i . '</option>' if ($param{'start'} == 1);
	}
	$cms->tag('sb_pageselect'=>$selector);
	$cms->tag('sb_currentmode'=>$param{'mode'});
	$cms->tag('sb_table_column'=>$param{'column'});
	my $params = '';
	foreach my $key ( @{$param{'params'}} ) {
		$params .= '<input type="hidden" name="' . $key . '" value="';
		$params .= sb::Text->entitize($cgi->value($key)) . '" />' . "\n";
	}
	$cms->tag('sb_list_params'=>$params);
	return( $cms->output );
}
sub dispnum_selector { # ページセレクタ
	my $self = shift;
	my %param = (
		'cms'  => undef,
		'now'  => DEFAULT_NUM,
		'list' => \@mListNumArray,
		'half' => undef,
		@_
	);
	return( undef ) unless ( defined($param{'cms'}) );
	my $cms = $param{'cms'};
	my $selector = '';
	for (my $i=0;$i<@{$param{'list'}};$i++) {
		my $num = ($param{'half'}) ? $param{'list'}->[$i] / 2 : $param{'list'}->[$i];
		$selector .= '<option value="' . $param{'list'}->[$i] . '"';
		$selector .= ' selected="selected"' if ($param{'list'}->[$i] == $param{'now'});
		$selector .= '>' . $num . '</option>';
	}
	$cms->num(0);
	$cms->tag('sb_dispnum_option'=>$selector);
}
sub select_option { # セレクタオプション
	my $self = shift;
	my %param = (
		'cms'      => undef,
		'tag'      => undef,
		'selected' => undef,
		@_
	);
	return( undef ) if ( !$param{'cms'} or !$param{'tag'} or $param{'selected'} eq '' );
	my $cms = $param{'cms'};
	$cms->num(0);
	$cms->tag($param{'tag'} . $param{'selected'}=>'selected="selected"');
}
sub monthly_selector { # 月別セレクタ
	my $self = shift;
	my %param = (
		'cms'  => undef,
		'tag'  => undef,
		'data' => undef,
		@_,
	);
	return( undef ) if ( !$param{'cms'} or !$param{'tag'} or !$param{'data'} );
	my $cms = $param{'cms'};
	my %check = ();
	my @array = sb::Data->load($param{'data'},'sort'=>'date','order'=>1);
	for (my $i=0;$i<@array;$i++) {
		my $month = sb::Time->format(
			'time'=>$array[$i]->date,
			'form'=>'%Year%%Mon%',
			'zone'=>$array[$i]->tz
		);
		if ( !defined($check{$month}) ) {
			$check{$month} = sb::Time->format(
				'time'=>$array[$i]->date,
				'form'=>sb::Config->get->value('conf_archivelist'),
				'zone'=>$array[$i]->tz
			);
		}
	}
	my $selector = '';
	my @monthly = sort { $b <=> $a } keys(%check);
	foreach my $month ( @monthly ) {
		$selector .= '<option value="' . $month . '"';
		$selector .= ' selected="selected"' if ($month eq sb::Interface->get->value('dispdate'));
		$selector .= '>' . $check{$month} . '</option>';
	}
	$cms->num(0);
	$cms->tag($param{'tag'}=>$selector);
}
sub imagedir_selector { # イメージディレクトリセレクタ
	my $self = shift;
	my $conf = sb::Config->get;
	my %param = (
		'cms'    => undef,
		'tag'    => undef,
		'thumb'  => undef,
		'select' => $conf->value('conf_dir_img'),
		'format' => '%s',
		'over'   => undef,
		@_,
	);
	return( undef ) if ( !$param{'cms'} or !$param{'tag'} );
	my $cms = $param{'cms'};
	my @dirs = sort { $a cmp $b } $conf->writable_dir($conf->value('conf_dir_img'));
	my $selector = '';
	foreach my $dir (@dirs) { # ディレクトリ設定
		$selector .= '<option value="' . sprintf($param{'format'},$dir) . '"';
		$selector .= ' selected="selected"' if ($param{'select'} eq $dir);
		$selector .= '>' . $dir . '</option>';
	}
	$cms->num(0);
	$cms->tag($param{'tag'}=>$selector);
	if ($param{'thumb'}) {
		$cms->block($param{'thumb'}=>1) if ( eval('require Image::Magick') );
		$cms->tag('sb_thumbchecked'=>'checked="checked"') if ($conf->value('conf_thumbcheck'));
	}
	$cms->block('sb_upload_overwrite'=>1) if ($param{'over'} and $conf->value('conf_imagename'));
}
sub template_selector { # テンプレートセレクタ
	my $self = shift;
	my %param = (
		'cms' => undef,
		'tag' => undef,
		'now' => undef,
		@_
	);
	return( undef ) if ( !$param{'cms'} or !$param{'tag'} );
	my $cms = $param{'cms'};
	my @temps = sb::Data->load('Template');
	my $selector = '';
	foreach my $temp ( @temps ) {
		$selector .= '<option value="' . $temp->id . '"';
		$selector .= ' selected="selected"' if ($temp->id eq $param{'now'});
		$selector .= '>' . $temp->name . '</option>';
	}
	$cms->num(0);
	$cms->tag($param{'tag'}=>$selector);
}
sub category_selector {
	# [note] need to set $self->{'cat'} as category hash ref. to call this method.
	my $self = shift;
	my %param = (
		'cat'    => [],
		'now'    => undef,
		'branch' => undef,   
		'main'   => undef,
		'except' => undef,
		'val'    => '%d',
		@_
	);
	my $selector = '';
	foreach my $cat ( @{$param{'cat'}} ) {
		next if ($param{'except'} ne '' and $cat->id eq $param{'except'});
		next if ($param{'main'} eq '' and $cat->main ne '');
		next if (defined($param{'branch'}) and $cat->main ne $param{'branch'});
		$selector .= '<option value="' . sprintf($param{'val'},$cat->id) . '"';
		$selector .= ($cat->id eq $param{'now'}) ? ' selected="selected">' : '>';
		$selector .= $cat->fullname($self->{'cat'}) . '</option>' . "\n";
		if ($cat->sub ne '') {
			$selector .= $self->category_selector(
				'cat'    => $param{'cat'},
				'branch' => $cat->id,
				'now'    => $param{'now'},
				'main'   => $cat->name,
				'except' => $param{'except'},
				'val'    => $param{'val'},
			);
		}
	}
	return($selector);
}
sub update_entry_attachment {
	my $self = shift;
	my @eids = @_;
	{ # delete duplicated id.
		my %cnt;
		@eids = grep(!$cnt{$_}++, @eids);
	}
	my @entries = sb::Data->load('Entry','cond'=>{'id'=>\@eids},'detail'=>'on');
	foreach my $entry ( @entries ) {
		my @com = sb::Data->load('Message','cond'=>{'eid'=>$entry->id,'stat'=>1});
		my @tb  = sb::Data->load('Trackback','cond'=>{'eid'=>$entry->id,'stat'=>1});
		$entry->com($#com + 1);
		$entry->tb($#tb + 1);
	}
	if (@entries) {
		sb::Data->update(@entries);
		$self->{'cat'} = { sb::Data->load_as_hash('Category') } unless (defined($self->{'cat'}));
		my $builder = sb::Build->new(
			'time'      => $self->{'time'},
			'user'      => $self->{'users'},
			'cat'       => $self->{'cat'},
			'sortedcat' => [ sort { $b->order <=> $a->order } values(%{$self->{'cat'}}) ],
			'blog'      => sb::Data->load('Weblog','id'=>0),
		);
		foreach my $entry (@entries) {
			$self->build_entries('entry'=>$entry,'builder'=>$builder);
		}
	}
}
sub change_order { # 並び替え処理
	my $self = shift;
	my %param = (
		'data'      => [],
		'target'    => undef,
		'direction' => undef,
		@_
	);
	return( undef ) unless ( defined($param{'target'}) );
	my @objs = @{$param{'data'}};
	my $check = undef;
	for (my $i=0;$i<@objs;$i++) {
		$objs[$i]->order($#objs - $i);
		if ($objs[$i]->id == $param{'target'}->id) {
			$check = $i;
			$objs[$i]->order($#objs + 1) if ($param{'direction'} == 0 and $i > 0);
		}
	}
	if ($param{'direction'} == -1 and $check < $#objs) {
		$objs[$check]->order($#objs - $check - 1);
		$objs[$check + 1]->order($#objs - $check);
	}
	if ($param{'direction'} ==  1 and $check > 0) {
		$objs[$check]->order($#objs - $check + 1);
		$objs[$check - 1]->order($#objs - $check);
	}
	return @objs;
}
sub build_entries { # 構築処理
	my $self = shift;
	my %param = (
		'entry'   => undef,
		'builder' => undef,
		@_
	);
	return( undef ) if (!$param{'entry'} or !$param{'builder'});
	my $entry   = $param{'entry'};
	my $builder = $param{'builder'};
	if (sb::Config->get->value('conf_entry_archive') eq 'Individual') {
		$builder->build_entry( $entry ) if ($entry->stat != 0);
	} elsif (sb::Config->get->value('conf_entry_archive') eq 'Monthly') {
		my $month = sb::Time->format(
			'time'=>$entry->date,
			'form'=>'%Year%%Mon%',
			'zone'=>$entry->tz
		);
		$builder->build_monthly_archive( $month );
	}
	return(1);
}
sub build_list { # リスト更新処理
	my $self = shift;
	my $type = shift;
	$self->{'cat'} = { sb::Data->load_as_hash('Category') } unless (defined($self->{'cat'}));
	my $builder = sb::Build->new(
		'time'      => $self->{'time'},
		'user'      => $self->{'users'},
		'cat'       => $self->{'cat'},
		'sortedcat' => [ sort { $b->order <=> $a->order } values(%{$self->{'cat'}}) ],
		'blog'      => sb::Data->load('Weblog','id'=>0),
	);
	if (sb::Config->get->value('conf_entry_archive') eq 'Individual' and $type ne '') {
		$builder->build_javascript($type);
	}
	$builder->build_top_page;
	return;
}
# ==================================================
# // public functions - callback
# ==================================================
sub callback { # コールバック
	my $self = shift;
	return ($self->{'regi'}) 
		? $self->_change_entry_status(@_) 
		: $self->_display_entry_list(@_);
}
# ==================================================
# // private functions - main routine
# ==================================================
sub _change_entry_status { # 記事情報の一括変更
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi  = sb::Interface->get;
	my $lang = sb::Language->get;
	my $msg  = '';
	my @sels = split("\0",$cgi->value('sel'));
	my @ents = sb::Data->load('Entry','cond'=>{'id'=>\@sels},'detail'=>'on');
	$self->{'cat'} = { sb::Data->load_as_hash('Category') } unless (defined($self->{'cat'})); # カテゴリーデータ
	ACTION_SWITCH: {
		$_ = $cgi->value('regi_action');
		/^del$|^del_htm$/ && do { # 削除
			my @files = ();
			my @coms  = ();
			my @tbs   = ();
			foreach my $ent (@ents) {
				push(@files,$ent->file_path($self->{'cat'}));
				push(@coms,sb::Data->load('Message','cond'=>{'eid'=>$ent->id}));
				push(@tbs,sb::Data->load('Trackback','cond'=>{'eid'=>$ent->id}));
				$ent->erase;
			}
			if ($_ eq 'del_htm' and @files) {
				foreach my $file (@files) {
					unlink($file) if (-e $file);
				}
			}
			if (@coms) {
				foreach my $com (@coms) {
					$com->erase;
				}
				sb::Data->update(@coms);
			}
			if (@tbs) {
				foreach my $tb (@tbs) {
					$tb->erase;
				}
				sb::Data->update(@tbs);
			}
			$msg = ($#ents + 1) . $lang->string('parts_deleted');
			last ACTION_SWITCH;
		};
		/^(acm|atb|stat)(\d)$/ && do { # ステータス変更
			my $targ = $1;
			my $new = $2;
			foreach my $ent (@ents) {
				if ($targ eq 'stat')
				{
					my $cat = ($ent->cat ne '') ? $self->{'cat'}->{$ent->cat} : undef;
					$new = 2 if ($new == 1 and $cat and $cat->get_option('top'));
				}
				$ent->$targ($new);
			}
			$msg = $lang->string('parts_editcomp');
			last ACTION_SWITCH;
		};
		/^none$|^\d+$/ && do { # カテゴリー変更
			my $new = ($_ eq 'none') ? undef : $self->{'cat'}->{$_};
			foreach my $ent (@ents) {
				$ent->cat(($new) ? $new->id : undef);
				if ($ent->stat > 0) {
					$ent->stat(($new and $new->get_option('top')) ? 2 : 1);
				}
			}
			$msg = $lang->string('parts_editcomp');
			last ACTION_SWITCH;
		};
	};
	sb::Data->update(@ents) if (@ents);
	$msg .= $lang->string('parts_rec_make');
	$msg .= sprintf($lang->string('parts_link_bld'),$self->get_script_path);
	return $self->_display_entry_list('message'=>$msg);
}
sub _display_entry_list { # 記事リスト表示
	my $self = shift;
	my %param = (
		'message' => '',
		'setup'   => $self->setup_list,
		@_
	);
	$self->{'cat'} = { sb::Data->load_as_hash('Category') } unless (defined($self->{'cat'})); # カテゴリーデータ
	my @cats = sort { $b->order <=> $a->order } values(%{$self->{'cat'}});
	my $cgi = sb::Interface->get;
	my $cms = sb::TemplateManager->new($self->load_template('file'=>TEMPLATE));
	my $dispsort = ( $cgi->value('dispsort') ne '' ) ? $cgi->value('dispsort') : 'date';
	my $page = int($cgi->value('page'));
	$page = int($cgi->value('now_page')) + 1 if ( $cgi->value('next') ne '' );
	$page = int($cgi->value('now_page')) - 1 if ( $cgi->value('prev') ne '' );
	my @entry = sb::Data->load('Entry', # 記事データ読込み
		'sort'  => $dispsort,
		'order' => 1,
		'num'   => $param{'setup'}->{'dispnum'},
		'bgn'   => $page * $param{'setup'}->{'dispnum'},
		'cond'  => $self->_generate_condition,
	);
	$cms->num(0);
	$cms->tag('sb_list_page'=>$self->display_pagelink( # ページリンク
			'mode'    => 'list',
			'column'  => LIST_COLUMN,
			'all'     => sb::Data->matched,
			'printed' => $#entry + 1,
			'num'     => $param{'setup'}->{'dispnum'},
			'params'  => ['dispsort','disptype','dispword','dispdate','dispnum','dispcat'],
		)
	);
	$cms->tag('sb_entry_changecat'=> # カテゴリーセレクタ[ 変更用 ]
		'<option value="none">' . sb::Language->get->string('parts_no_cat') . '</option>' .
		$self->category_selector('cat'=>\@cats)
	);
	$cms->tag('sb_entry_dispcat'=> # カテゴリーセレクタ[ 検索用 ]
		$self->category_selector('cat'=>\@cats,'now'=>$cgi->value('dispcat'))
	);
	$cms->tag('sb_entry_selectcat'=> # カテゴリーセレクタ[ 選択用 ]
		$self->category_selector('cat'=>\@cats,'val'=>'cat%d_')
	);
	$self->dispnum_selector( # 表示数セレクタ
		'cms' => $cms,
		'now' => $param{'setup'}->{'dispnum'},
	);
	$self->monthly_selector( # 月別セレクタ
		'cms'  => $cms,
		'tag'  => 'sb_entry_dispdate',
		'data' => 'Entry',
	);
	foreach my $key ('dispsort','disptype') { # 表示オプションなど
		$self->select_option(
			'cms'      => $cms,
			'tag'      => 'sb_' . $key . '_',
			'selected' => ($key eq 'dispsort') ? $dispsort : $cgi->value($key),
		);
	}
	$cms->block('sb_entry_delcheck'=>1) if (sb::Config->get->value('conf_entry_archive') eq 'Individual');
	$self->listmain(
		'template' => $cms,
		'block'    => 'sb_entry_list',
		'objects'  => \@entry,
		'tags'     => {
			'sb_entry_id'        => 'id',
			'sb_entry_title'     => \&_clip_for_entry,
			'sb_entry_author'    => \&_display_author,
			'sb_entry_category'  => \&_display_category,
			'sb_entry_date'      => 'date',
			'sb_entry_status'    => \&_display_entry_status,
			'sb_entry_catclass'  => 'cat',
			'sb_entry_statclass' => \&_display_entry_statnum,
			'sb_entry_sel'       => \&_display_checkbox,
		},
	);
	$cms->num(0);
	$cms->tag('sb_dispword'=>sb::Text->entitize($cgi->value('dispword'))) if ($cgi->value('disptype') ne '');
	$self->common_template_parts($cms);
	if ($param{'message'} ne '') { # display message
		$cms->num(0);
		$cms->tag('sb_process_message'=>$param{'message'});
		$cms->block('sb_process_message'=>1);
	}
	return sb::Interface->get->head('type'=>'text/html') . $self->set_main($cms->output);
}
# ==================================================
# // private functions - for entry list
# ==================================================
sub _generate_condition { # 検索条件生成
	my $self = shift;
	my %cond = ();
	my $cgi  = sb::Interface->get;
	if ($cgi->value('dispword') ne '') {
		my $word = $cgi->value('dispword');
		SWITCH_CHECK_COND: {
			$_ = $cgi->value('disptype');
			/^subj/ && do {
				$cond{'subj'} = '/' . $word . '/';
				last SWITCH_CHECK_COND;
			};
			/^auth/ && do {
				$cond{'auth'} = [];
				my @users = sb::Data->load('User','cond'=>{'real'=>'/' . $word . '/','name'=>'/' . $word . '/'});
				foreach my $user (@users) {
					push(@{$cond{'auth'}},$user->id);
				}
				last SWITCH_CHECK_COND;
			};
			/^cat/ && do {
				$cond{'cat'} = [];
				my @cats = sb::Data->load('Category','cond'=>{'name'=>'/' . $word . '/'});
				foreach my $cat (@cats) {
					push(@{$cond{'cat'}},$cat->id);
				}
				last SWITCH_CHECK_COND;
			};
		}
	}
	if ($cgi->value('dispcat') ne '') {
		$cond{'cat'} = $cgi->value('dispcat');
		$cond{'__combo'} = { 'cat' => 'add' , 'add' => ',' . $cgi->value('dispcat') . ',' };
	}
	if ($cgi->value('dispdate') ne '') {
		$cond{'date'} = $self->create_date_condition($cgi->value('dispdate'));
		$cond{'__range'} = { 'date' => 'tz' };
	}
	return \%cond;
}
sub _display_entry_status { # 記事ステータス
	my $self = shift;
	my $obj  = shift;
	return $self->list_status(
		'stat'   => $obj->stat,
		'string' => sb::Language->get->string('setup_edit_stat'),
	);
}
sub _display_message_status { # コメント・トラックバックステータス
	my $self = shift;
	my $obj  = shift;
	return $self->list_status(
		'stat'   => $obj->stat,
		'string' => sb::Language->get->string('setup_msg_stat'),
	);
}
sub _display_entry_statnum
{
	my $self = shift;
	my $obj  = shift;
	return ($obj->stat == 0) ? 0 : 1;
}
sub _clip_for_entry { # 記事タイトル表示
	my $self = shift;
	my $obj  = shift;
	my $subj = ($obj->subj eq '') ? sb::Language->get->string('parts_notitle') : $obj->subj;
	return $self->clip_text(
		'text' => $subj,
		'base' => '?__mode=edit&amp;eid=' . $obj->id,
		'user' => $obj->auth,
	);
}
sub _display_author { # 記事著者表示
	my $self = shift;
	my $obj  = shift;
	my $pid  = ( defined($self->{'users'}->{$obj->auth}) ) ? $obj->auth : 0;
	return( $self->{'users'}->{$pid}->real );
}
sub _display_category { # 記事カテゴリ表示
	my $self = shift;
	my $obj  = shift;
	my $cat  = $self->{'cat'}->{$obj->cat};
	return sb::Text->clip(
		'text'    => ($cat) ? $cat->fullname($self->{'cat'}) : NO_CATEGORY,
		'length'  => CATEGORY_LENGTH,
		'fromend' => 1,
	);
}
sub _display_checkbox { # 記事リストチェックボックス
	my $self = shift;
	my $obj  = shift;
	return $self->check_permission('user'=>$obj->auth) 
		? '<input type="checkbox" name="sel" value="' . $obj->id . '" onclick="switchList(this)" />'
		: DENIED_CHECK;
}
1;
__END__
