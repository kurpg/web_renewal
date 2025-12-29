# sb::Language::ja - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Language::ja;

use strict;
use Carp;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.08';
# 0.08 [2010/05/09] added some words for aws
# 0.07 [2009/05/27] added some words for aws
# 0.06 [2007/07/22] changed words for Amazon Web Services
# 0.05 [2007/03/05] changed holiday to handle new law
# 0.04 [2007/02/09] added error_saved_as_closed and changed setup_msg_stat
# 0.03 [2006/11/09] added error_dup_catidx
# 0.02 [2006/02/04] changed some strings
# 0.01 [2005/09/28] changed convert to add converting tilda functionally
# 0.00 [2005/01/17] created

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Config ();
use sb::Language ();
@ISA = qw( sb::Language );
# ==================================================
# // declaration for private variables
# ==================================================
my $aConvTilda = 1; # チルダ変換フラグ
my $pIncomingCode = undef; # 内部コード
# ==================================================
# // constructor
# ==================================================
sub get
{
	my $class = shift;
	my $self = $class->SUPER::get();
	$self->_init(); # initialize
	return($self);
}
sub new
{
	&get; # 'new' is alias for 'get'
}
# ==================================================
# // public functions (overriding)
# ==================================================
sub convert
{
	my $self = shift;
	my $text = shift;
	my $code = (@_) ? shift : $self->charcode;
	&Jcode::convert(\$text,$code,$pIncomingCode) if ($self->init);
	$text =~ s/\xE2\x80\xBE/\x7E/g if ($code eq 'utf8' and $code ne $pIncomingCode and $aConvTilda);
	return($text);
}
sub mailtext
{
	my $self = shift;
	my $text = shift;
	&Jcode::convert(\$text,'jis',$pIncomingCode) if ($self->init);
	return($text);
}
sub checkcode
{
	my $self = shift;
	my $text = shift;
	my $code = shift if (@_);
	if ($code)
	{
		$pIncomingCode = $code;
	}
	elsif ($text)
	{
		$pIncomingCode = &Jcode::getcode($text) if ($self->init);
	}
	return( $pIncomingCode );
}
sub holiday
{
	my $self = shift;
	my $year = shift; # 入力パラメータ
	my %list = ( # 出力用リスト / 引数として与えられた年の祝日リストのリファレンスを返す
		'0101' => '元日',
		'0211' => '建国記念の日',
		'0429' => 'みどりの日',
		'0503' => '憲法記念日',
		'0505' => 'こどもの日',
		'1103' => '文化の日',
		'1123' => '勤労感謝の日',
		'1223' => '天皇誕生日',
	);
	if ($year >= 2007)
	{
		$list{'0429'} = '昭和の日';
		$list{'0504'} = 'みどりの日';
	}
	if ($year < 2000)
	{
		$list{'0115'} = '成人の日';
		$list{'1010'} = '体育の日';
	}
	else
	{
		for (my $day=8;$day<=14;$day++)
		{
			$day = &_pad0($day);
			$list{'01' . $day} = '成人の日' if (&_weekday($year,'01',$day) == 1);
			$list{'10' . $day} = '体育の日' if (&_weekday($year,'10',$day) == 1);
		}
	}
	if ($year < 2003)
	{
		$list{'0720'} = '海の日' if ($year > 1995);
		$list{'0915'} = '敬老の日';
	}
	else
	{
		for (my $day=15;$day<=21;$day++)
		{
			$day = &_pad0($day);
			$list{'07' . $day} = '海の日'   if (&_weekday($year,'07',$day) == 1);
			$list{'09' . $day} = '敬老の日' if (&_weekday($year,'09',$day) == 1);
		}
	}
	{ # 春分/秋分の日 // 1980年から2099年まで有効
		my $spring = int(20.8431 + 0.242194*($year-1980)-int(($year-1980)/4));
		my $autumn = int(23.2488 + 0.242194*($year-1980)-int(($year-1980)/4));
		$list{'03' . $spring} = '春分の日';
		$list{'09' . $autumn} = '秋分の日';
		$list{'09' . ($autumn-1)} = '国民の休日' if (&_weekday($year,'09',$autumn - 1) == 2);
		$list{'0504'} = '国民の休日' if (&_weekday($year,'05','04') > 1 and $year < 2007);
	}
	foreach my $date (keys(%list))
	{ # 振替休日計算
		my $mon = substr($date,0,2);
		my $day = substr($date,2,2);
		$list{$mon . &_pad0($day + 1)} = '(振替休日)' if ( &_weekday($year,$mon,$day) == 0 );
	}
	return(\%list);
}
# ==================================================
# // private functions
# ==================================================
sub _init
{
	my $self = shift;
	return() if ( $self->charset );
	eval("require 'Jcode.pm'"); # 外部ライブラリ呼び出し
	croak($@) if ($@);
	my $check = ord("漢"); # 「漢」と書いて「おとこ」と読む
	if ($check == 0xb4 or $check ==  -76)
	{
		$self->charset('EUC-JP');
		$self->charcode('euc');
	}
	elsif ($check == 0x8a or $check == -118)
	{
		$self->charset('Shift_JIS');
		$self->charcode('sjis');
	}
	elsif ($check == 0xe6 or $check ==  -26)
	{
		$self->charset('UTF-8');
		$self->charcode('utf8');
	}
	elsif ($check == 0x1b)
	{
		$self->charset('iso-2022-jp');
		$self->charcode('jis');
	}
	else
	{ # 不明なコード
		croak("Unknown char code.");
	}
	# 言語セレクタ
	$self->string('language_ja'=>'日本語');
	$self->string('language_en'=>'英語');
	$self->string('language_fr'=>'フランス語');
	# 保存形式
	$self->string('entryarchive_Individual'=>'個別記事をhtml保存');
	$self->string('entryarchive_Monthly'   =>'月別アーカイブをhtml保存');
	$self->string('entryarchive_None'      =>'トップページのみhtml生成');
	# 設定関連
	$self->string('setup_aws_stat'      =>'非公開:公開');
	$self->string('setup_msg_stat'      =>'待ち:公開:非公開');
	$self->string('setup_link_stat'     =>'公開:非公開');
	$self->string('setup_edit_stat'     =>'非公開:公開');
	$self->string('setup_edit_format'   =>'そのまま:自動改行');
	$self->string('setup_edit_date'     =>'そのまま:編集時に更新');
	$self->string('setup_edit_comment'  =>'受け付けない:受け付ける:承認が必要');
	$self->string('setup_edit_trackback'=>'受け付けない:受け付ける:承認が必要');
	# オススメ
	$self->string('aws_genre_All' => '[全て]');
	$self->string('aws_genre_Blended' => '[ブレンド検索]');
	$self->string('aws_genre_Apparel' => '服&amp;ファッション小物');
	$self->string('aws_genre_Automotive' => 'カー&amp;バイク用品');
	$self->string('aws_genre_Baby' => 'ベビー&amp;マタニティ');
	$self->string('aws_genre_Beauty' => '美容');
	$self->string('aws_genre_Books' => '和書');
	$self->string('aws_genre_Classical' => 'クラシック音楽');
	$self->string('aws_genre_DigitalMusic' => 'デジタルミュージック');
	$self->string('aws_genre_DVD' => 'DVD');
	$self->string('aws_genre_Electronics' => '家電&amp;カメラ');
	$self->string('aws_genre_ForeignBooks' => '洋書');
	$self->string('aws_genre_GourmetFood' => 'グルメ&amp;フード');
	$self->string('aws_genre_Grocery' => '食品');
	$self->string('aws_genre_HealthPersonalCare' => 'ヘルス&amp;ビューティー');
	$self->string('aws_genre_Hobbies' => 'ホビー');
	$self->string('aws_genre_HomeGarden' => 'ガーデニング');
	$self->string('aws_genre_HomeImprovement' => 'DIY・工具');
	$self->string('aws_genre_Industrial' => '工業用品');
	$self->string('aws_genre_Jewelry' => 'ジュエリー');
	$self->string('aws_genre_KindleStore' => 'キンドル');
	$self->string('aws_genre_Kitchen' => 'ホーム&amp;キッチン');
	$self->string('aws_genre_Lighting' => '照明');
	$self->string('aws_genre_Magazines' => '雑誌');
	$self->string('aws_genre_Merchants' => '商業用品');
	$self->string('aws_genre_Miscellaneous' => 'その他');
	$self->string('aws_genre_MP3Downloads' => 'MP3ダウンロード');
	$self->string('aws_genre_Music' => '音楽');
	$self->string('aws_genre_MusicalInstruments' => '楽器');
	$self->string('aws_genre_MusicTracks' => 'ミュージックトラック');
	$self->string('aws_genre_OfficeProducts' => 'オフィス用品');
	$self->string('aws_genre_OutdoorLiving' => 'アウトドア');
	$self->string('aws_genre_Outlet' => 'アウトレット');
	$self->string('aws_genre_PCHardware' => 'PC');
	$self->string('aws_genre_PetSupplies' => 'ペット用品');
	$self->string('aws_genre_Photo' => '写真');
	$self->string('aws_genre_Shoes' => 'シューズ');
	$self->string('aws_genre_Software' => 'ソフトウェア');
	$self->string('aws_genre_SoftwareVideoGames' => 'ソフトウェア(ゲーム)');
	$self->string('aws_genre_SportingGoods' => 'スポーツ');
	$self->string('aws_genre_Tools' => '工具');
	$self->string('aws_genre_Toys' => 'おもちゃ');
	$self->string('aws_genre_UnboxVideo' => 'ビデオ(箱なし)');
	$self->string('aws_genre_VHS' => 'ビデオ(VHS)');
	$self->string('aws_genre_Video' => 'ビデオ');
	$self->string('aws_genre_VideoGames' => 'ゲーム');
	$self->string('aws_genre_Watches' => '時計');
	$self->string('aws_genre_Wireless' => '無線用品');
	$self->string('aws_genre_WirelessAccessories' => '無線アクセサリー');
	$self->string('aws_genre_ASIN' =>'ASIN');
	# 管理モードラベル
	$self->string('mode_new'      =>'新規記事');
	$self->string('mode_edit'     =>'記事編集');
	$self->string('mode_list'     =>'記事リスト');
	$self->string('mode_upload'   =>'アップロード');
	$self->string('mode_amazon'   =>'オススメ');
	$self->string('mode_category' =>'記事カテゴリー');
	$self->string('mode_link'     =>'リンク');
	$self->string('mode_profile'  =>'プロフィール');
	$self->string('mode_view'     =>'ウェブページ確認');
	$self->string('mode_rebuild'  =>'ページ構築');
	$self->string('mode_comment'  =>'コメント');
	$self->string('mode_trackback'=>'トラックバック');
	$self->string('mode_refuse'   =>'拒否設定');
	$self->string('mode_user'     =>'ユーザー');
	$self->string('mode_template' =>'テンプレート');
	$self->string('mode_config'   =>'環境設定');
	$self->string('mode_editor'   =>'編集設定');
	$self->string('mode_help'     =>'ヘルプ');
	$self->string('mode_access'   =>'アクセス解析');
	$self->string('mode_status'   =>'ステータス');
	$self->string('mode_logout'   =>'ログアウト');
	$self->string('mode_login'    =>'ログイン');
	$self->string('mode_welcome'  =>'ようこそ');
	$self->string('mode_bm'       =>'クイック投稿');
	$self->string('mode_edittemp' =>'テンプレート編集');
	$self->string('mode_edituser' =>'ユーザー情報編集');
	# メッセージパーツ
	$self->string('parts_noname'  =>'[名称未設定]');
	$self->string('parts_notitle' =>'[名称未設定]');
	$self->string('parts_arrow'   =>'⇒');
	$self->string('parts_sequel'  =>'続きを読む＞＞');
	$self->string('parts_more_rss'=>'[続きがあります]');
	$self->string('parts_com_num' =>'comments ');
	$self->string('parts_tb_num'  =>'trackbacks ');
	$self->string('parts_mailchar'=>'iso-2022-jp'); # メール送信用コード
	$self->string('parts_no_cat'  =>'未指定');
	$self->string('parts_thumb'   =>' (サムネイル)');
	$self->string('parts_withlink'=>' (リンク)');
	$self->string('parts_thumblst'=>' [*]');
	$self->string('parts_advuser' =>' [*]');
	$self->string('parts_tmpinfo' =>' [*]');
	$self->string('parts_formdate'=>'%Year%年%Mon%月%Day%日');
	$self->string('parts_formtime'=>'%Hour%:%Min%:%Sec%');
	$self->string('parts_error'   =>'処理通知：');
	$self->string('parts_logout'  =>'ログアウトしました。');
	$self->string('parts_sentping'=>'にPINGを送信しました。<br />');
	$self->string('parts_findtb'  =>'件のトラックバックURLを見つけました。<br />');
	$self->string('parts_deleted' =>'件削除しました。<br />');
	$self->string('parts_confcomp'=>'設定を反映しました。<br />');
	$self->string('parts_needmake'=>'これまでの記事に対して反映させるには再構築が必要です。');
	$self->string('parts_rec_make'=>'変更を完全に反映させるには再構築が必要です。');
	$self->string('parts_link_bld'=>'⇒<a href="%s?__mode=rebuild">再構築</a><br />');
	$self->string('parts_buildcmp'=>'再構築しました。「ウェブページ確認」よりご確認下さい。');
	$self->string('parts_passchng'=>'パスワードを変更しました。ログインしなおしてください。<br />');
	$self->string('parts_userchng'=>'ユーザー名を変更しました。ログインしなおしてください。<br />');
	$self->string('parts_editcomp'=>'編集しました。<br />');
	$self->string('parts_new_comp'=>'新規作成しました。<br />');
	$self->string('parts_add_comp'=>'%d 件追加しました。<br />');
	$self->string('parts_sw_on'   =>'公開する');
	$self->string('parts_sw_off'  =>'非公開にする');
	$self->string('parts_showfile'=>'[詳細...]');
	$self->string('parts_bm_close'=>'[閉じる]');
	$self->string('parts_tempedit'=>'編集');
	$self->string('parts_temp_use'=>'利用中');
	$self->string('parts_temp_can'=>'-');
	$self->string('parts_temp_sel'=>'利用テンプレートを変更しました。<br />');
	$self->string('parts_temp_css'=>'CSSテンプレートの内容を反映しました。<br />');
	$self->string('parts_temp_add'=>'テンプレートを追加保存しました。<br />');
	$self->string('parts_tempcomp'=>'HTMLテンプレートを更新しました。<br />');
	$self->string('parts_no_icon' =>'アイコンなし');
	$self->string('parts_build_op'=>'[#%d] アーカイブの再構築 (最新:%d-%d)');
	$self->string('parts_subj_tb' =>'[Serene Bach]トラックバック通知');
	$self->string('parts_subj_com'=>'[Serene Bach]コメント通知');
	$self->string('parts_body_tb' =>'トラックバックを受信しました。');
	$self->string('parts_body_com'=>'コメントの投稿がありました。');
	$self->string('parts_extracat'=>'<script type="text/javascript">showCategorySelector(\'関連…\',\'隠す\');</script>');
	$self->string('parts_not_inst'=>'<strong style="color:red">%sはインストールされていません。</strong>');
	$self->string('parts_install' =>'<strong style="color:green">%sはインストールされています。</strong>');
	$self->string('parts_no_file' =>'<strong style="color:red">「%s」がありません。</strong>');
	$self->string('parts_unread'  =>'<strong style="color:red">「%s」が読み込みできません。パーミッションを確認してください。</strong>');
	$self->string('parts_unwrite' =>'<strong style="color:red">「%s」が書き込みできません。パーミッションを確認してください。</strong>');
	$self->string('parts_finefile'=>'<strong style="color:green">「%s」は正しく置かれています。</strong>');
	# エラーメッセージ
	$self->string('error_not_allow'      =>'この処理を行う権限がありません。');
	$self->string('error_wrong_text'     =>'この文字はご利用になれません。');
	$self->string('error_wrong_pass'     =>'パスワードが間違っています。');
	$self->string('error_file_open'      =>'ファイルが開けません。 : ');
	$self->string('error_unsuppoted'     =>'サポートされていません。 : ');
	$self->string('error_unknown'        =>'予期しないエラーが発生しました。');
	$self->string('error_file_lock'      =>'ファイルロックされています。');
	$self->string('error_initialize'     =>'初期認証が出来ませんでした。もう一度インストールしなおしてください。');
	$self->string('error_expired'        =>'ログインの有効期間が過ぎています。');
	$self->string('error_difference'     =>'確認項目と一致しません。');
	$self->string('error_dup_dir'        =>'同名のディレクトリが既に存在しています。');
	$self->string('error_failtomake'     =>'作成できませんでした。パーミッションなどをご確認下さい。');
	$self->string('error_failtodel'      =>'削除できませんでした。パーミッションなどをご確認下さい。');
	$self->string('error_no_user'        =>'該当するユーザーがいません。');
	$self->string('error_no_entry'       =>'該当する記事がありません。');
	$self->string('error_no_cat'         =>'該当するカテゴリーがありません。');
	$self->string('error_dup_cat'        =>'同名のカテゴリーが既に存在します。<br />');
	$self->string('error_no_name'        =>'名称が指定されていません。');
	$self->string('error_exist_user'     =>'既に同名のユーザーが存在します。');
	$self->string('error_no_body'        =>'記事内容がありません。');
	$self->string('error_banned'         =>'投稿を受け付けることができません。');
	$self->string('error_doubled'        =>'既に投稿されています。');
	$self->string('error_no_comment'     =>'コメント内容がありません。');
	$self->string('error_wait_msg'       =>'コメント投稿ありがとうございます。投稿されたコメントは管理者の承認後、表示されます。');
	$self->string('error_res_msg'        =>'コメント投稿処理通知');
	$self->string('error_exist_cat'      =>'このカテゴリーは既に存在しています。');
	$self->string('error_failtoadd'      =>'追加できませんでした。');
	$self->string('error_inst_skipped'   =>'999 Skipped');
	$self->string('error_inst_load_temp' =>'テンプレートの読込みに失敗しました。');
	$self->string('error_inst_init'      =>'インストールの初期化に失敗しました。');
	$self->string('error_installing'     =>'インストール時に予期しないエラーが発生しました。');
	$self->string('error_alredy_inst'    =>'すでにセットアップ済みです。');
	$self->string('error_dup_catidx'     =>'同じ保存先のカテゴリーが存在します。[%s]<br />');
	$self->string('error_saved_as_closed'=>'コメント投稿ありがとうございます。投稿されたコメントは非公開で保存されました。');
	# 日付用パーツ
	$self->string('week_ja'     =>['日','月','火','水','木','金','土']);
	$self->string('week_jalong' =>['日曜日','月曜日','火曜日','水曜日','木曜日','金曜日','土曜日']);
	$self->string('month_ja'    =>['一月','二月','三月','四月','五月','六月','七月','八月','九月','十月','十一月','十二月']);
	$self->string('month_jalong'=>['睦月','如月','弥生','卯月','皐月','水無月','文月','葉月','長月','神無月','霜月','師走']);
	return();
}
sub _pad0
{
	my $num = shift;
	return('0' . $num) if ($num < 10);
	return($num);
}
sub _weekday
{ # 曜日取得（programed by OHZAKI Hiroki）
	my ($year,$mon,$mday) = @_; # 入力パラメータ /年,月,日/
	if ($mon == 1 or $mon == 2)
	{
		$year--;
		$mon += 12;
	}
	return(int($year + int($year / 4) - int($year / 100) + int($year / 400) + int((13 * $mon + 8) / 5) + $mday) % 7);
}
1;
