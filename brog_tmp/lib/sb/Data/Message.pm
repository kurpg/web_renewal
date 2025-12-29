# sb::Data::Message - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Data::Message;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.02';
# 0.02 [2007/07/04] removed @mStruct and added elements
# 0.01 [2005/07/22] changed data structure to array
# 0.00 [2005/02/02] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Config ();
use sb::Text ();
use sb::Data::Object ();
@ISA = qw( sb::Data::Object );
# ==================================================
# // declaration for constant value
# ==================================================
sub LINK_TARGET (){ ' target="_blank"' }
# ==================================================
# // declaration for data structure
# ==================================================
sub elements
{
	return(
		'id',   # id
		'wid',  # wid
		'eid',  # 記事 id
		'stat', # ステータス
		'date', # 受信日
		'auth', # 名前
		'host', # 送信者ホストアドレス
		'tz',   # タイムゾーン
		'mail', # メールアドレス
		'url',  # サイトアドレス
		'agnt', # 送信者ユーザーエージェント
		'body', # コメント内容
		'icon', # アイコン
		'ext',  # 追加情報
		'admn', # 管理者コメント
		'out',  # 参照回数
	);
}
# // public functions
# ==================================================
sub formated_body
{
	my $self = shift;
	return sb::Text->format('text'=>$self->body,'form'=>sb::Config->get->value('basic_com_format'));
}
sub auth_with_url
{
	my $self = shift;
	my $target = LINK_TARGET;
	return ($self->url)
		? '<a href="' . $self->url . '"' . $target . '>' . $self->auth . '</a>'
		: $self->auth;
}
sub get_size
{
	my $self = shift;
	return( length($self->formated_body) + length($self->auth_with_url) );
}
sub icon_image
{
	my $self = shift;
	my $text = '';
	return($text) if ($self->icon eq '');
	my $icon = sb::Data->load('Image','id'=>$self->icon);
	if ($icon)
	{
		my $conf = sb::Config->get;
		my $src = $conf->value('conf_srv_base') . $conf->value('conf_dir_img') . $icon->file;
		my $alt = $icon->name;
		my ($w,$h) = $icon->get_size;
		return '<img src="' . $src . '" width="' . $w . '" height="' . $h . 
		       '" alt="' . $alt . '" title="' . $alt . '" class="comment_icon" />';
	}
	return($text);
}
sub initialize
{
	my $self  = shift;
	my %param = @_;
	$param{'wid'} |= 0;
	$self->SUPER::initialize(%param);
}
1;
__END__
