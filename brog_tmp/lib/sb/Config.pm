# sb::Config - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Config;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.16';
# 0.16 [2007/04/11] changed _loadGlobalConfig and _init to set feed path / rsd path consistently
# 0.15 [2006/09/30] changed 'conf_edit_ping' to change url http://ping.rss.drecom.jp/ from http://ping.myblog.jp/
# 0.14 [2006/09/10] added 'conf_spamstat' and changed store to conver line feed properly
# 0.13 [2006/08/01] changed conf_edit_ping to apply new site address
# 0.12 [2006/02/01] changed _loadGlobalConfig
# 0.11 [2005/08/12] added 'basic_sessiontag' to %mEnv
# 0.10 [2005/08/11] changed default value of some variables
# 0.09 [2005/07/26] changed _readWeblogConfig to set 'srv_temp' initially
# 0.08 [2005/07/25] removed 'setup_amazon' from %mEnv / added 'basic_aws_locale' to %mEnv
# 0.07 [2005/07/22] added 'basic_build_ajax' to %mEnv
# 0.06 [2005/07/20] changed _loadGlobalConfig to ignore if there is no init.cgi
# 0.05 [2005/07/19] added 'basic_use_ajax' to %mEnv
# 0.04 [2005/07/17] added get_keys to get savable keys
# 0.03 [2005/07/16] changed _loadGlobalConfig to handle DataSuffix correctly
# 0.02 [2005/07/13] changed _readWeblogConfig, old config file is not loaded any more
# 0.01 [2005/07/11] changed config variable "srv_cgi" to "conf_srv_cgi"

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Language ();
# ==================================================
# // declaration for constant value
# ==================================================
sub RESOURCE_DIR (){ 'lib/resource/' };
# ==================================================
# // declaration for class member
# ==================================================
my %mEnv = (); # static variables for configuration
# ==================================================
# // declaration for private variables
# ==================================================
my $pObject = undef; # object instance for sb::Config
# ==================================================
# // constructor
# ==================================================
sub get {
	my $class = shift;
	return($pObject) if ( defined($pObject) );
	$pObject = bless({},$class);
	&_init(@_);
	return($pObject);
}
sub new {
	&get; # 'new' is alias for 'get'
}
# ==================================================
# // destructor
# ==================================================
sub bye {
	my $class = shift;
	$pObject = undef;
}
sub DESTROY {
	my $self = shift;
	return();
}
# ==================================================
# // public functions
# ==================================================
sub value { # [accessor] read/write each value
	my $self = shift;
	my $key  = shift;
	return( undef ) if ( !defined($key) );
	$mEnv{$key} = shift if (@_);
	$mEnv{$key};
}
sub store
{ # store weblog configuration to the file
	my $self = shift;
	my $conf = $mEnv{'dir_data'} . $mEnv{'file_conf'};
	open(CONFOUT,">$conf") or die(sb::Language->string('error_file_open') . $conf);
	binmode(CONFOUT);
	foreach my $key ( keys(%mEnv) )
	{
		my $value = $mEnv{$key};
		if ($value =~ /\x0D|\x0A/)
		{
			$value =~ s/\x0D\x0A/\n/g;
			$value =~ tr/\x0D\x0A/\n\n/;
		}
		print CONFOUT &_encode($key,$value) if (index($key,'conf_') == 0);
	}
	close(CONFOUT);
	return();
}
sub get_keys {
	my $self = shift;
	return grep /^conf_/, keys(%mEnv);
}
sub writable_dir { # get writable directories on base directory
	my $self = shift;
	my $base = shift;
	my @out = ($base);
	foreach my $dir ($mEnv{'conf_dir_base'}, $mEnv{'conf_dir_base'} . $base) {
		opendir(CHECKDIR, $dir);
		my @filelist = readdir(CHECKDIR);
		closedir(CHECKDIR);
		foreach my $file (@filelist) {
			my $check = $dir . $file;
			next if ($file =~ /^\./);
			next if ($file =~ /^_/);
			next if (!-d $check);
			next if (!-r $check);
			next if (!-w $check);
			$file .= '/';
			if ($dir eq $mEnv{'conf_dir_base'}) {
				next if (index('util/',$file) == 0);
				next if (index('lib/',$file) == 0);
				next if (index('ext/',$file) == 0);
				next if (index('doc/',$file) == 0);
				next if (index($mEnv{'conf_dir_log'},$file) == 0);
				next if (index($mEnv{'conf_dir_img'},$file) == 0);
				next if (index($mEnv{'dir_style'},$file) == 0);
				next if (index($mEnv{'dir_plugin'},$check) == 0);
				next if (index($mEnv{'dir_lock'},$check) == 0);
				next if (index($mEnv{'dir_data'},$check) == 0);
				push(@out,$file);
				push(@out,&_recursive_search($file));
			} else {
				push(@out,$base . $file);
				push(@out,&_recursive_search($base . $file));
			}
		}
	}
	return(@out);
}
# ==================================================
# // private functions
# ==================================================
sub _init
{
	my %param = @_;
	%mEnv = (
		# Global configuration
		'basic_max_data'     => 15360000,        # アップロード許容サイズ [単位:byte] 15MB
		'basic_base_enc'     => 1026,            # base64 エンコード処理バッファサイズ [54 の倍数を推奨]
		'basic_preid'        => 'eid',           # 記事 id 属性用
		'basic_suffix'       => '.html',         # html 生成時の拡張子
		'basic_marking'      => 1,               # アーカイブにつくエントリー用のマーキングフラグ
		'basic_gen_atom'     => 10,              # Atom Feed に保存するエントリー数
		'basic_gen_rss'      => 10,              # RSS に保存するエントリー数
		'basic_sb'           => 'sb.cgi',        # Serene Bach 本体スクリプト名
		'basic_tb'           => '',              # トラックバック受信スクリプト名
		'basic_feed'         => '',              # フィードスクリプト名
		'basic_rsd'          => '',              # RSD(Really Simple Discoverability)スクリプト名
		'basic_xmlrpc'       => 'admin.cgi',     # XMP-RPC API スクリプト名
		'basic_admn'         => 'admin.cgi',     # 管理用スクリプト名
		'basic_cnt'          => 'cnt.cgi',       # ログ収集スクリプト名
		'basic_mob'          => 'mb.cgi',        # 携帯閲覧用スクリプト名
		'basic_install'      => 'install.cgi',   # セットアップ用スクリプト名
		'basic_buildnum'     => 50,              # 一度に再構築する件数
		'basic_mailsize'     => 102400,          # 許容メールサイズ 100KB
		'basic_cooktag'      => 'sbviewer',      # クッキー用識別子
		'basic_admntag'      => 'sbadmin',       # 管理用クッキー識別子
		'basic_logtag'       => 'sblog',         # アクセスログ用クッキー識別子
		'basic_sessiontag'   => 'sb_session',    # セッション用クッキー識別子
		'basic_cookiekey'    => 'on',            # クッキー用の保存値 [for sblog]
		'basic_admn_expire'  => 1,               # ログイン有効期間 [単位:日]
		'basic_max_img'      => 10,              # アップロードできる最大数
		'basic_img_chck'     => 0,               # 記事内のイメージ検索
		'basic_http_proxy'   => '',              # 外部接続時のプロキシ設定
		'basic_com_format'   => 2,               # コメントフォーマット
		'basic_ref_check'    => 1,               # 管理画面リファラチェック
		'basic_temp_conv'    => 1,               # リソースの文字コード変換
		'basic_xmlpublish'   => 0,               # XML-RPC強制公開フラグ
		'basic_file_attr'    => 0666,            # 保存ファイル属性
		'basic_dir_attr'     => 0777,            # 作成ディレクトリ属性
		'basic_min_update'   => 30,              # 自動更新時間間隔設定 [単位:分]
		'basic_mobswitch'    => 'ASTEL|UP\.Browser|KDDI|PDXGW|DoCoMo|J\-PHONE|L\-mode|DDIPOCKET', # 携帯用コンテンツ切替フラグ
		'basic_cookie'       => ['email','url','name','icon','checkid'], # クッキー保存パラメータ
		'basic_use_ajax'     => 1,               # 再構築に Ajax を利用する
		'basic_build_ajax'   => 10,              # 再構築に Ajax を利用時の一度に再構築する件数
		'basic_aws_locale'   => 'jp',            # AWS ロケール
		# Weblog configuration
		'conf_entry_disp'     => 10,
		'conf_com_disp'       => 10,
		'conf_tb_disp'        => 10,
		'conf_newent_disp'    => 5,
		'conf_aws_disp'       => 5,
		'conf_page_disp'      => 1,
		'conf_search_disp'    => 1,
		'conf_entry_sort'     => 1,
		'conf_archive_sort'   => 1,
		'conf_com_sort'       => 1,
		'conf_tb_sort'        => 1,
		'conf_timezone'       => '+0900',
		'conf_thumbsize'      => 120,
		'conf_thumbcheck'     => 0,
		'conf_imagename'      => 0,
		'conf_srv_cgi'        => '',
		'conf_srv_base'       => '',
		'conf_dir_base'       => './',
		'conf_dir_log'        => 'log/',
		'conf_dir_img'        => 'img/',
		'conf_lang'           => 'ja',
		'conf_entry_archive'  => 'Individual',
		'conf_ip_ban'         => '',
		'conf_edit_ping'      => "http://ping.rss.drecom.jp/\nhttp://ping.bloggers.jp/rpc/\nhttp://www.blogpeople.net/servlet/weblogUpdates\nhttp://serenebach.net/rep.cgi\n",
		'conf_archive_temp'   => -1,
		'conf_profile_temp'   => -1,
		'conf_mobile_temp'    => -1,
		'conf_css_change'     => 0,
		'conf_spamlevel'      => 0,
		'conf_spamid'         => 'sbSpamBlock',
		'conf_spamword'       => "name=poker\nname=slot\nname=diet\nname=penis\nname=pills\nname=merchant account\nname=tramadol\nname=ambien\nname=cialis\nname=Briana\nname=Buy\nname=buy\nname=fioricet\nname=levitra\nname=black jack\nname=texas\nname=viagra\nname=casino",
		'conf_entry_date'     => '%Year%.%Mon%.%Day% %WeekLong%',
		'conf_entry_time'     => '%Hour%:%Min%',
		'conf_msg_time'       => '%Year%/%Mon%/%Day% %Hour12%:%Min% %HourAP%',
		'conf_dateinlist'     => ' (%Mon%/%Day%)',
		'conf_archivelist'    => '%MonLong% %Year%',
		'conf_time_lang'      => 'en',
		'conf_dbtype'         => 'Text',
		'conf_checklog'       => 30,
		'conf_spamstat'       => 0,
		'conf_spamtb'         => 0,
		# Settings for array
		'setup_lang'          => ['ja',],
		'setup_entry_archive' => ['Individual','Monthly','None',],
		'setup_debug_ping'    => 'serenebach.net/',
		'setup_tz_hour'       => [
			'+13','+12','+11','+10','+09','+08','+07','+06','+05','+04','+03','+02','+01',
			'+00','-01','-02','-03','-04','-05','-06','-07','-08','-09','-10','-11','-12',
		],
		'setup_tz_min'        => ['00','30','45',],
		# Settings for servers
		'srv_doc'  => './doc/',
		'srv_temp' => '',
		# Settings for directories
		'dir_style'  => 'template/',
		'dir_temp'   => './' . RESOURCE_DIR,
		'dir_plugin' => './plugin/',
		'dir_lock'   => './lock/',
		'dir_data'   => './data/',
		'dir_access' => 'log/',
		# Settings for files
		'file_index'  => 'index.html', # in base
		'file_css'    => 'style.css',  # in base
		'file_rss'    => 'index.rdf',  # in log
		'file_atom'   => 'atom.xml',   # in log
		'file_conf'   => 'configure.cgi',
		'file_cook'   => 'cookie.js',
		'file_logjs'  => 'cnt.js',
		'file_lock'   => 'lock',
		'file_lckcnt' => 'cnt',
		'file_access' => 'log.cgi',
		'file_suf'    => '.cgi',
		# Settings for sb::Driver::Text
		'dbtxt_data' => './data/',
		'dbtxt_suf'  => '.cgi',
		'dbtxt_save' => 'save',
		'dbtxt_ids'  => 'id',
	);
	&_loadGlobalConfig($param{'config'}) if ($param{'config'});
	return();
}
sub _loadGlobalConfig
{ # load global configuration
	my $file = shift;
	if (-r $file) {
		open(GLOBALCONF,"<$file");
		while (my $line = <GLOBALCONF>) {
			next if ($line =~ /^#/);
			$line =~ tr/\x0D\x0A//d;
			my ($key,$val) = split(/\s/,$line,2);
			CHECKCONF: {
				$_ = $key;
				/^DataDir/ && do { # データディレクトリ [DIR.]
					$mEnv{'dir_data'} = &_check_dir($val);
					$mEnv{'dbtxt_data'} = $mEnv{'dir_data'};
					last CHECKCONF;
				};
				/^DataSuffix/ && do { # 保存データの拡張子 [文字]
					if ($val ne '') {
						$mEnv{'file_suf'} = $val;
						$mEnv{'file_suf'} = '.' . $mEnv{'file_suf'} if ($mEnv{'file_suf'} !~ /^\./);
						$mEnv{'dbtxt_suf'} = $mEnv{'file_suf'};
					}
					last CHECKCONF;
				};
				/^LockDir/ && do { # ロック用ディレクトリ名 [DIR.]
					$mEnv{'dir_lock'} = &_check_dir($val);
					last CHECKCONF;
				};
				/^TempDir/ && do { # 管理画面テンプレートの保管場所 [DIR.]
					$mEnv{'dir_temp'} = &_check_dir($val);
					last CHECKCONF;
				};
				/^PluginDir/ && do { # プラグインディレクトリ [DIR.]
					$mEnv{'dir_plugin'} = &_check_dir($val);
					last CHECKCONF;
				};
				/^StyleDir/ && do { # テンプレート用のパーツディレクトリ [DIR.]
					$mEnv{'dir_style'} = &_check_dir($val);
					last CHECKCONF;
				};
				/^HelpSrv/ && do { # ヘルプドキュメントの設定場所 [URI.]
					$mEnv{'srv_doc'} = &_check_dir($val);
					last CHECKCONF;
				};
				/^TempSrv/ && do { # 管理画面パーツの設定場所 [URI.]
					$mEnv{'srv_temp'} = &_check_dir($val);
					last CHECKCONF;
				};
				/^TopIndex/ && do { # トップページ用のファイル名 [文字]
					$mEnv{'file_index'} = $val;
					last CHECKCONF;
				};
				/^TempConv/ && do { # テンプレート文字コード変換設定 [選択] 1:変換する(デフォルト) 0:変換しない
					$mEnv{'basic_temp_conv'} = int($val);
					last CHECKCONF;
				};
				/^HttpProxy/ && do { # プロキシ設定 [URI.]
					$mEnv{'basic_http_proxy'} = $val;
					last CHECKCONF;
				};
				/^AdminCookieDay/ && do { # 管理画面用のクッキー保存形式 [数値]
					$mEnv{'basic_admn_expire'} = int($val);
					last CHECKCONF;
				};
				/^RefCheck/ && do { # 管理画面のリファラチェック [選択] 1:チェックする 0:チェックしない
					$mEnv{'basic_ref_check'} = int($val);
					last CHECKCONF;
				};
				/^WeblogId/ && do { # Serene Bach を複数設置した際に利用する識別子 [文字]
					if ($val =~ /\w*/) {
						$mEnv{'basic_cooktag'}    .= $val;
						$mEnv{'basic_admntag'}    .= $val;
						$mEnv{'basic_logtag'}     .= $val;
						$mEnv{'basic_sessiontag'} .= $val;
					}
					last CHECKCONF;
				};
				/^MainScript/ && do { # メインスクリプト名 [文字]
					$mEnv{'basic_sb'} = $val;
					last CHECKCONF;
				};
				/^FeedScript/ && do { # フィードスクリプト名 [文字]
					$mEnv{'basic_feed'} = $val;
					last CHECKCONF;
				};
				/^TrackbackReceiver/ && do { # トラックバック受信スクリプト名 [文字]
					$mEnv{'basic_tb'} = $val;
					last CHECKCONF;
				};
				/^XmlrpcEntryPoint/ && do { # XMP-RPC APIエントリーポイント [文字]
					$mEnv{'basic_xmlrpc'} = $val;
					last CHECKCONF;
				};
				/^XmlrpcForcedPublish/ && do { # XML-RPC APIを利用時の強制公開 [選択] 0:通常 1:強制公開
					$mEnv{'basic_xmlpublish'} = int($val);
					last CHECKCONF;
				};
				/^StaticFileSuffix/ && do { # 静的ファイルの拡張子 [文字]
					if ($val ne '') {
						$mEnv{'basic_suffix'} = $val;
						$mEnv{'basic_suffix'} = '.' . $mEnv{'basic_suffix'} if ($mEnv{'basic_suffix'} !~ /^\./);
					}
					last CHECKCONF;
				};
				/^OldStyleRebuilding/ && do { # 再構築に Ajax を利用するかどうか [選択] 1:Ajaxを利用しない
					$mEnv{'basic_use_ajax'} = 0 if ($val eq '1');
					last CHECKCONF;
				};
				/^AmazonWebServiceLocale/ && do { # アマゾンウェブサービスロケール [文字]
					$mEnv{'basic_aws_locale'} = $val if ($val =~ /\w\w/);
					last CHECKCONF;
				};
				/^MobileRegex/ && do { # 携帯電話判別正規表現 [文字]
					$mEnv{'basic_mobswitch'} = $val;
					last CHECKCONF;
				};
				# === 以下、設定初期値の書き換え ===
				# 環境設定の保存後は、init.cgi の設定は利用されない
				/^ScriptPath/ && do { # スクリプト用サーバアドレス [URI.]
					$mEnv{'conf_srv_cgi'} = &_check_dir($val);
					last CHECKCONF;
				};
				/^BaseDir/ && do { # ベースディレクトリ [DIR.]
					$mEnv{'conf_dir_base'} = &_check_dir($val);
					last CHECKCONF;
				};
				/^BaseSrv/ && do { # ベースサーバアドレス [URI.]
					$mEnv{'conf_srv_base'} = &_check_dir($val);
					last CHECKCONF;
				};
				/^LogDir/ && do { # ログディレクトリ [DIR.]
					$mEnv{'conf_dir_log'} = &_check_dir($val);
					last CHECKCONF;
				};
				/^ImgDir/ && do { # 画像ディレクトリ [DIR.]
					$mEnv{'conf_dir_img'} = &_check_dir($val);
					last CHECKCONF;
				};
				/^SpamCheckLevel/ && do { # コメントスパム対策レベル [数値]
					$mEnv{'conf_spamlevel'} = int($val);
					last CHECKCONF;
				};
				/^SpamCheckId/ && do { # コメントスパム用ID [文字]
					$mEnv{'conf_spamid'} = $val;
					last CHECKCONF;
				};
				/^InitLanguage/ && do { # 利用言語
					$mEnv{'conf_lang'} = $val if ($val =~ /\w\w/);
					last CHECKCONF;
				};
			}
		}
		close(GLOBALCONF);
	}
	&_readWeblogConfig() if (-e $mEnv{'dir_data'} . $mEnv{'file_conf'});
	$mEnv{'basic_tb'} = $mEnv{'basic_sb'} if ($mEnv{'basic_tb'} eq '');
	$mEnv{'basic_feed'} = $mEnv{'basic_sb'} . '?feed=' if ($mEnv{'basic_feed'} eq '');
	$mEnv{'basic_rsd'} = $mEnv{'basic_sb'} . '?rsd=on' if ($mEnv{'basic_rsd'} eq '');
	$mEnv{'conf_srv_cgi'} = './' if ($mEnv{'conf_srv_cgi'} eq '/' or $mEnv{'conf_srv_cgi'} eq '');
	$mEnv{'conf_srv_base'} = $mEnv{'conf_srv_cgi'} if ($mEnv{'conf_srv_base'} eq '/' or $mEnv{'conf_srv_base'} eq '');
	$mEnv{'srv_temp'} = $mEnv{'conf_srv_cgi'} . RESOURCE_DIR if ($mEnv{'srv_temp'} eq '/' or $mEnv{'srv_temp'} eq '');
	return();
}
sub _readWeblogConfig { # load weblog configuration
	my $conf = $mEnv{'dir_data'} . $mEnv{'file_conf'};
	open(CONF,"<$conf") or die("failed opening configure file.\n");
	while (my $line = <CONF>) {
		$line =~ tr/\x0D\x0A//d;
		my ($key,$val) = split("\t",$line,2);
		next if ($key !~ /^conf_/);
		next if ($key eq '');
		$val = &_decode($val);
		$val = &_check_dir($val) if ($key =~ /_srv_/ or $key =~ /_dir_/);
		$mEnv{$key} = $val;
	}
	close(CONF);
	return();
}
sub _decode {
	return ( map { s/\\(.)/$1 eq 't' and "\t" or $1 eq 'n' and "\n" or "$1"/eg; $_; } ($_[0]) )[0];
}
sub _encode {
	my @fields = map { s/\\/\\\\/g; s/\t/\\t/g; s/\n/\\n/g; $_; } @_;
	return join("\t",@fields) . "\n";
}
sub _check_dir {
	$_[0] .= '/' if ($_[0] !~ /\/$/);
	return($_[0]);
}
sub _recursive_search {
	my $dir = shift;
	my @out = ();
	opendir(CHECKDIR, $mEnv{'conf_dir_base'} . $dir);
	my @filelist = readdir(CHECKDIR);
	closedir(CHECKDIR);
	foreach my $file (@filelist) {
		my $check = $mEnv{'conf_dir_base'} . $dir . $file;
		next if ($file =~ /^\./);
		next if ($file =~ /^_/);
		next if (!-d $check);
		next if (!-r $check);
		next if (!-w $check);
		$file .= '/';
		push(@out,$dir . $file);
		push(@out,&_recursive_search($dir . $file));
	}
	return(@out);
}
1; # end of package
__END__
