# sb::Data::Entry - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Data::Entry;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.04';
# 0.04 [2007/07/04] removed @mStruct and added elements
# 0.03 [2005/07/25] changed pingurl to use 'basic_tb'
# 0.02 [2005/07/11] changed config variable "srv_cgi" to "conf_srv_cgi"
# 0.01 [2005/07/08] added add_ping as public method
# 0.00 [2005/02/02] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Config ();
use sb::Time ();
use sb::Text ();
use sb::Data ();
use sb::Data::Object ();
@ISA = qw( sb::Data::Object );
# ==================================================
# // declaration for constant value
# ==================================================
sub SUMMARY_LENGTH (){ 200 }
# ==================================================
# // declaration for data structure
# ==================================================
sub elements
{
	return(
		'id',   # id
		'wid',  # wid
		'subj', # タイトル / entitized text
		'cat',  # メインカテゴリー
		'date', # 日付
		'auth', # 著者
		'stat', # ステータス
		'com',  # コメント数
		'tb',   # トラックバック数
		'file', # 保存名
		'tz',   # タイムゾーン
		'add',  # 関連カテゴリー
		'edit', # 編者
		'acm',  # コメント受付設定
		'atb',  # トラックバック受付設定
		'form', # フォーマット
		'ping', # 送信済みトラックバック
		'body', # 本文
		'more', # 続き
		'sum',  # 概要 / entitized text
		'key',  # キーワード / entitized text
		'ext',  # 予約フィールド
		'tmp',  # 未送信トラックバック
	);
}
# ==================================================
# // public functions
# ==================================================
sub add_ping
{
	my $self = shift;
	my @new  = @_;
	my @ping = split("\n",$self->ping);
	push(@ping,@new);
	{ # removing duplication
		my %cnt;
		@ping = grep(!$cnt{$_}++, @ping);
	}
	$self->ping(join("\n",@ping));
}
sub sum
{
	my $self = shift;
	$self->{'sum'} = shift if @_;
	return($self->{'sum'}) if ($self->{'sum'} ne '');
	return sb::Text->clip('text'=>$self->body,'form'=>$self->form,'length'=>SUMMARY_LENGTH);
}
sub formated_body
{
	my $self = shift;
	return sb::Text->format('text'=>$self->body,'form'=>$self->form);
}
sub formated_more
{
	my $self = shift;
	return sb::Text->format('text'=>$self->more,'form'=>$self->form);
}
sub file_path
{
	my $self = shift;
	my $cat  = shift;
	my $conf = sb::Config->get;
	my $filename = undef;
	return( $filename ) if ($conf->value('conf_entry_archive') ne 'Individual');
	my $log_dir = $conf->value('conf_dir_log');
	my $logfile = $conf->value('basic_preid') . $self->id;
	$cat = {sb::Data->load_as_hash('Category')} if ( !defined($cat) );
	if ( defined($cat->{$self->cat}) )
	{
		$log_dir = $cat->{$self->cat}->dir if ($self->cat ne '' and $cat->{$self->cat}->dir ne '');
	}
	$logfile = $self->file if ($self->file ne '');
	$filename = $conf->value('conf_dir_base') . $log_dir . $logfile . $conf->value('basic_suffix');
	return( $filename );
}
sub permalink
{
	my $self = shift;
	my %param = ( # 入力パラメータ
		'type' => sb::Config->get->value('conf_entry_archive'), # 保存形式
		'mode' => '',                                           # 出力形式
		'cat'  => undef,                                        # カテゴリーオブジェクト
		@_
	);
	my $permalink = ''; # 出力パラメータ
	my $conf = sb::Config->get; # 環境設定オブジェクト
	$param{'type'} = '' if ($param{'type'} eq 'Monthly' and $param{'mode'} ne '');
	TYPE_SWITCH: {
		$_ = $param{'type'};
		/^Individual$/ && do {
			$permalink = $self->_filename($param{'cat'},$conf);
			$permalink .= '#comments'  if ($param{'mode'} eq 'com');
			$permalink .= '#trackback' if ($param{'mode'} eq 'tb');
			$permalink .= '#sequel'    if ($param{'mode'} eq 'more');
			last TYPE_SWITCH;
		}; # end of Individual
		/^Monthly$/ && do {
			my $filename = sb::Time->format(
				'time' => $self->date,
				'form' => '%Year%%Mon%' . $conf->value('basic_suffix'),
				'zone' => $conf->value('conf_timezone')
			);
			$permalink = $conf->value('conf_srv_base') 
			           . $conf->value('conf_dir_log') 
			           . $filename . '#' . $conf->value('basic_preid') . $self->id;
			last TYPE_SWITCH;
		}; # end of Monthly
		/^Mobile$/ && do {
			my $mobile = (index($0,$conf->value('basic_sb')) > -1) 
			           ? $conf->value('basic_sb') 
			           : $conf->value('basic_mob');
			$permalink = $conf->value('conf_srv_cgi') . $mobile . '?eid=' . $self->id;
			$permalink .= '&amp;com=0'  if ($param{'mode'} eq 'com');
			$permalink .= '&amp;tb=0'   if ($param{'mode'} eq 'tb');
			$permalink .= '&amp;more=0' if ($param{'mode'} eq 'more');
			$permalink .= '&amp;form=0' if ($param{'mode'} eq 'form');
			last TYPE_SWITCH;
		}; # end of Mobile
		$permalink = $conf->value('conf_srv_cgi') . $conf->value('basic_sb') . '?eid=' . $self->id;
		$permalink .= '#comments'  if ($param{'mode'} eq 'com');
		$permalink .= '#trackback' if ($param{'mode'} eq 'tb');
		$permalink .= '#sequel'    if ($param{'mode'} eq 'more');
	} # end of TYPE_SWITCH
	return($permalink);
}
sub pingurl
{
	my $self = shift;
	return sb::Config->get->value('conf_srv_cgi') . sb::Config->get->value('basic_tb') . '/' . $self->id;
}
sub authname
{
	my $self = shift;
	my $user = shift;
	$user = {sb::Data->load_as_hash('User')} if ( !defined($user) );
	my $pid = ( defined($user->{$self->auth}) ) ? $self->auth : 0;
	return $user->{$pid}->real;
}
sub authlink
{
	my $self = shift;
	my $user = shift;
	$user = {sb::Data->load_as_hash('User')} if ( !defined($user) );
	my $pid = ( defined($user->{$self->auth}) ) ? $self->auth : 0;
	my $cgi = sb::Config->get->value('conf_srv_cgi') . sb::Config->get->value('basic_sb');
	return( '<a href="' . $cgi . '?pid=' . $pid . '">' . $self->authname($user) . '</a>' );
}
sub initialize
{
	my $self  = shift;
	my %param = @_;
	$param{'wid'} |= 0;
	$param{'auth'} |= 0;
	$param{'edit'} = $param{'auth'} if ($param{'edit'} eq '');
	$param{'com'} |= 0;
	$param{'tb'} |= 0;
	$self->SUPER::initialize(%param);
}
# ==================================================
# // private functions
# ==================================================
sub _filename
{
	my ($self,$cat,$conf) = @_;
	my $filename = '';
	my $log_dir = $conf->value('conf_dir_log');
	my $logfile = $conf->value('basic_preid') . $self->id;
	$cat = {sb::Data->load_as_hash('Category')} if ( !defined($cat) );
	if ( defined($cat->{$self->cat}) )
	{
		$log_dir = $cat->{$self->cat}->dir if ($self->cat ne '' and $cat->{$self->cat}->dir ne '');
	}
	$logfile = $self->file if ($self->file ne '');
	$filename = $conf->value('conf_srv_base') . $log_dir . $logfile . $conf->value('basic_suffix');
	return( $filename );
}
1;
__END__
