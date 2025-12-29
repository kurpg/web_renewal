# sb::Language - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Language;

use strict;
use Carp;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.01';
# 0.01 [2007/03/14] changed string
# 0.00 [2005/01/17] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
# ==================================================
# // declaration for class member
# ==================================================
my $mCharset = undef; # キャラクターセット
my $mCode    = undef; # 文字コード
my %mString  = ();    # 文字列設定
my $mInit    = 0;     # 初期化フラグ
my $mLang    = undef; # オブジェクト
# ==================================================
# // constructor
# ==================================================
sub new {
	my $class = shift;
	my $lang = shift if (@_);
	my $obj = undef;
	return($mLang) if ($mInit);
	eval {
		if ($lang) {
			eval("require sb::Language::$lang");
			$obj = "sb::Language::$lang"->get();
		} else {
			$obj = &get($class);
		}
	};
	croak("Fail to initialize" . $@) if (!$obj);
	return($obj);
}
sub get {
	my $class = shift;
	if ( !$mInit or !defined($mLang) ) {
		$mLang = {};
		bless($mLang,$class);
		&_base_init($class); # 初期化
	}
	return($mLang);
}
# ==================================================
# // destructor
# ==================================================
sub bye {
	my $class = shift;
	$mLang = undef;
}
sub DESTROY {
	my $self = shift;
	$mCharset = undef;
	$mCode    = undef;
	%mString  = ();
	$mInit    = undef;
	return();
}
# ==================================================
# // public functions
# ==================================================
sub code { # [アクセサ] 言語コード
	my $self = shift;
	return( $mLang->{'lang'} );
}
sub init { # [アクセサ] 初期化済みかどうか
	my $self = shift;
	return( $mInit );
}
sub charset { # [アクセサ] キャラクターセット
	my $self  = shift;
	$mCharset = shift if (@_);
	return( $mCharset );
}
sub charcode { # [アクセサ] 文字コード
	my $self = shift;
	$mCode   = shift if (@_);
	return( $mCode );
}
sub strings { # [アクセサ] 文字列設定全体
	my $self = shift;
	my $strings = shift;
	%mString = %$strings if ( defined($strings) );
	return( \%mString );
}
sub string { # [アクセサ] 各種文字列
	my $self = shift;
	my $key  = shift;
	return if ( !defined($key) );
	$mString{$key} = shift if (@_);
	return $mString{$key} if ( defined($mString{$key}) );
	return $key;
}
sub convert { # 文字コード変換処理
	my $self = shift;
	my $text = shift; # 入力文字列
	my $code = shift if (@_); # 出力コード
	return($text);
}
sub mailtext { # メール用文字コード変換処理
	my $self = shift;
	my $text = shift; # 入力文字列
	return($text);
}
sub checkcode { # 文字コード検査
	my $self = shift;
	my $text = shift; # 検査文字列
	my $code = shift if (@_); # 設定コード
	return( $mCode );
}
sub holiday { # 祝日変換表
	my $self = shift;
	my $year = shift; # 対象年
	my %list = (
		'0101' => 'New Year Holiday',
		'1225' => 'Christmas Holiday',
		'1226' => 'Boxing Day',
	);
	return(\%list);
}
sub code_for_charset {
	my $self = shift;
	my $charset = lc( shift() );
	my %aCharset = (
		'ascii'       => 'ascii',
		'iso-8859-1'  => 'ascii',
		'binary'      => 'binary',
		'euc-jp'      => 'euc',
		'shift_jis'   => 'sjis',
		'iso-2022-jp' => 'jis',
		'ucs2'        => 'ucs2',
		'utf-8'       => 'utf8',
		'utf-16'      => 'utf16',
	);
	return ($aCharset{$charset}) ? $aCharset{$charset} : $charset;
}
# ==================================================
# // private functions
# ==================================================
sub _base_init {
	return() if ($mInit);
	$mLang->{'lang'} = ($_[0] =~ /^(.+)::([^:]+)$/)[1];
	if (!$mLang->{'lang'}) {
		$mLang->{'lang'} = 'en';
		$mCharset = 'ASCII';
		$mCode    = 'ascii';
	}
	my %msg = ( # default strings
		# string arrays for week
		'week_en'     => ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'],
		'week_enlong' => ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'],
		'week_fr'     => ['dim','lun','mar','mer','jeu','ven','sam'],
		'week_frlong' => ['dimanche','lundi','mardi','mercredi','jeudi','vendredi','samedi'],
		'week_ja'     => ['&#x65E5;','&#x6708;','&#x706B;','&#x6C34;','&#x6728;','&#x91D1;','&#x571F;'],
		'week_jalong' => ['&#x65E5;&#x66DC;&#x65E5;','&#x6708;&#x66DC;&#x65E5;','&#x706B;&#x66DC;&#x65E5;','&#x6C34;&#x66DC;&#x65E5;','&#x6728;&#x66DC;&#x65E5;','&#x91D1;&#x66DC;&#x65E5;','&#x571F;&#x66DC;&#x65E5;'],
		# string arrays for month
		'month_en'     => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'],
		'month_enlong' => ['January','February','March','April','May','June','July','August','September','October','November','December'],
		'month_fr'     => ['jan','f&eacute;v','mar','avr','mai','juin','juil','ao&ucirc;','sep','oct','nov','d&eacute;c'],
		'month_frlong' => ['janvier','f&eacute;vrier','mars','avril','mai','juin','juillet','ao&ucirc;t','septembre','octobre','novembre','d&eacute;cembre'],
	);
	&strings('sb::Language',\%msg);
	$mInit = 1;
}
1; # end of package
__END__
# --------------------------------------------------------------------
# 【言語設定用モジュール】
# sb で利用される各種文字列の基本設定を行うモジュールです。文字コード
# 変換処理も sb::Language で行います。
# 
# [起動]
# use sb::Language;
# my $lang = sb::Language->new($langCode); # $langCode : 言語コード
# 
# sb::Language モジュールは常に単一のインスタンスを返します。
# --------------------------------------------------------------------
# [参考文献]
# ・Perlによる多言語対応 in あにゃきちの部屋 - 備忘録
#   http://homepage3.nifty.com/analog_only/notes/perl_i18n.html
# --------------------------------------------------------------------
