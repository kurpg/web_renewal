# sb::Data::Weblog - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Data::Weblog;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.03';
# 0.03 [2007/07/04] removed @mStruct and added elements
# 0.02 [2005/07/22] changed data structure to array
# 0.01 [2005/07/08] changed DEFAULT_PLUGIN
# 0.00 [2005/02/02] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Data::Object ();
@ISA = qw( sb::Data::Object );
# ==================================================
# // declaration for constant value
# ==================================================
sub DEFAULT_TITLE  (){ 'My first weblog' };
sub DEFAULT_PLUGIN (){ '[AccessLog.pm][Convert.pm]' };
# ==================================================
# // declaration for data structure
# ==================================================
sub elements
{
	return(
		'id',     # id
		'title',  # title
		'text',   # description
		'pacc',   # POP3 アカウント
		'psrv',   # POP3 サーバ
		'psubj',  # POP3 受信サブジェクト
		'pfrom',  # POP3 受信送信元
		'pcat',   # POP3 設定カテゴリー
		'pthum',  # POP3 サムネイル作成フラグ
		'pform',  # POP3 適用フォーマット
		'pping',  # POP3 更新 ping 送信設定
		'pcron',  # POP3 定期受信設定
		'ptime',  # POP3 受信間隔
		'ppass',  # POP3 パスワード
		'papop',  # POP3 APOP認証設定
		'ppath',  # POP3 access path
		'smtp',   # smtp サーバアドレス or sendmail パス
		'stype',  # メール通知タイプ(smtp or sendmail)
		'ext',    # 追加情報
		'plugin', # plugins
	);
}
# ==================================================
# // public functions
# ==================================================
sub initialize
{
	my $self  = shift;
	my %param = @_;
	$param{'title'}  = DEFAULT_TITLE  if ($param{'title'} eq '');
	$param{'plugin'} = DEFAULT_PLUGIN if ($param{'plugin'} eq '');
	$self->SUPER::initialize(%param);
}
1;
__END__
