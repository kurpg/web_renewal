# sb::Data::User - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Data::User;

use strict;

use if ($ENV{'SERVER_NAME'} == '127.0.0.1'), subs => qw(crypt);
use if ($ENV{'SERVER_NAME'} == '127.0.0.1'), "Crypt::PasswdMD5";

if ($ENV{'SERVER_NAME'} == '127.0.0.1') {
	sub crypt {
		unix_md5_crypt(@_)
	}
}

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.06';
# 0.06 [2007/07/04] removed @mStruct and added elements
# 0.05 [2007/05/04] added imagetag option to edit
# 0.04 [2006/09/30] changed DEFAULT_OPTION
# 0.03 [2005/07/25] added cat_open option to edit
# 0.02 [2005/07/22] changed data structure to array
# 0.01 [2005/02/03] added auto_cat option to edit
# 0.00 [2005/02/02] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Data::Object ();
@ISA = qw( sb::Data::Object );
# ==================================================
# // declaration for constant value
# ==================================================
my %aOptionKeys = (
	'status'    => 0,  # ステータス設定(未使用)
	'format'    => 1,  # フォーマット設定
	'init_date' => 2,  # 日付の更新設定
	'comment'   => 3,  # コメント受付設定
	'trackback' => 4,  # トラックバック受付設定
	'ping'      => 5,  # 更新PING送信設定
	'sequel'    => 6,  # 「続き」表示設定
	'summary'   => 7,  # 「概要」表示設定(未使用)
	'imagelist' => 8,  # イメージオプション
	'imagemax'  => 9,  # イメージリスト制限
	'advanced'  => 10, # 上級者向け設定
	'tb_option' => 11, # トラックバックオプション
	'edit_tool' => 12, # ツールアイコン
	'auto_cat'  => 13, # 関連カテゴリーオプション
	'cat_open'  => 14, # カテゴリー欄オプション
	'imagetag'  => 15, # 画像タグ挿入オプション
);
sub DEFAULT_OPTION  (){ '1:1:0:1:1:1:0:0:0:10:0:0:0000000001111111111111111111:0:0:0:' };
sub DEFALT_TOOLICON (){ "strong:strong\nem:em\np:p\nblockquote:quote\nul:ul\nli:li\np[class=&quot;note&quot;]:cust1\n:cust2\n:cust3\nhr[/]:hr\nol:ol\ndl:dl\ndt:dt\ndd:dd\ndel:del\nins:ins\nh3:h3\nh4:h4\ntable:table\ntr:tr\nth:th\ntd:td\ndiv[style=&quot;text-align&#58;left&quot;]:left\ndiv[style=&quot;text-align&#58;center&quot;]:center\ndiv[style=&quot;text-align&#58;right&quot;]:right" };
# ==================================================
# // declaration for data structure
# ==================================================
sub elements
{
	return(
		'id',     # id
		'wid',    # wid
		'name',   # アカウント名
		'pass',   # パスワード
		'real',   # 名前
		'disp',   # 表示設定
		'mail',   # メールアドレス
		'notice', # メール通知設定
		'stat',   # アカウントレベル
		'order',  # 並び順
		'prof',   # プロフィール内容
		'aws',    # アマゾン id
		'edit',   # 編集設定
		'ext',    # ツールアイコン設定
		'info',   # 予約フィールド
		'img',    # 予約フィールド
		'friend', # 予約フィールド
		'cat',    # デフォルトカテゴリー設定
		'form',   # プロフィールフォーマット
		'ad_css', # 管理画面スタイルシート設定
	);
}
# ==================================================
# // public functions
# ==================================================
sub real
{
	my $self = shift;
	$self->{'real'} = shift if @_;
	return ($self->{'real'} ne '') ? $self->{'real'} : $self->{'name'};
}
sub pass
{
	my $self = shift;
	if ( @_ )
	{
		my $pass = shift;
		my $salt = '';
		my @tmps = ('a'..'z','A'..'Z','0'..'9','.','/');
		1 while ( length($salt .= $tmps[rand(@tmps)]) < 8 );
		$salt = '$1$' . $salt . '$' if (index(crypt('a','$1$a$'),'$1$a$') == 0);
		$self->{'pass'} = crypt($pass,$salt);
	}
	return( $self->{'pass'} );
}
sub set_option
{
	my $self = shift;
	my ($key,$value) = @_;
	my @option = split(':',$self->edit);
	$option[$aOptionKeys{$key}] = $value;
	$self->edit(join(':',@option) . ':');
}
sub get_option
{
	my $self = shift;
	my $key  = shift;
	my @option = split(':',$self->edit);
	return $option[$aOptionKeys{$key}];
}
sub get_option_keys
{
	my $self = shift;
	return keys(%aOptionKeys);
}
sub check_pass
{
	my $self = shift;
	my $input = shift;
	return( crypt($input,$self->{'pass'}) eq $self->{'pass'} );
}
sub initialize
{
	my $self  = shift;
	my %param = @_;
	$param{'wid'} |= 0;
	$param{'edit'} |= DEFAULT_OPTION;
	$param{'ext'} |= DEFALT_TOOLICON;
	$param{'stat'} = 2 if ($param{'stat'} eq '');
	$param{'order'} = $self->id;
	$self->SUPER::initialize(%param);
}
1;
__END__
