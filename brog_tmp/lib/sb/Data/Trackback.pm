# sb::Data::Trackback - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Data::Trackback;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.04';
# 0.04 [2007/07/04] removed @mStruct and added elements
# 0.03 [2007/03/10] fixed bugs in subj and name
# 0.02 [2007/03/08] added subj, name to entitize these value
# 0.01 [2005/07/22] changed data structure to array
# 0.00 [2005/02/02] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Text ();
use sb::Data::Object ();
@ISA = qw( sb::Data::Object );
# ==================================================
# // declaration for constant value
# ==================================================
sub LINK_TARGET (){ ' target="_blank"' }
sub SUMMARY_LENGTH (){ 300 }
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
		'subj', # トラックバック元タイトル
		'name', # トラックバック元サイト名
		'url',  # トラックバック元アドレス
		'tz',   # タイムゾーン
		'body', # トラックバック概要
		'host', # 送信元ホスト
		'admn', # 管理者コメント
		'icon', # アイコン
		'out',  # 参照回数
	);
}
# ==================================================
# // public functions
# ==================================================
sub name
{
	my $self = shift;
	$self->{'name'} = shift if (@_);
	return sb::Text->entitize($self->{'name'}) if ($self->{'name'} =~ /[<>\"]/);
	$self->{'name'};
}
sub subj
{
	my $self = shift;
	$self->{'subj'} = shift if (@_);
	return sb::Text->entitize($self->{'subj'}) if ($self->{'subj'} =~ /[<>\"]/);
	$self->{'subj'};
}
sub subj_with_url
{
	my $self = shift;
	my $target = LINK_TARGET;
	return '<a href="' . $self->url . '"' . $target . '>' . $self->subj . '</a>';
}
sub formated_body
{
	my $self = shift;
	return sb::Text->clip('text'=>$self->body,'form'=>0,'length'=>SUMMARY_LENGTH);
}
sub get_size
{
	my $self = shift;
	return( length($self->formated_body) + length($self->subj_with_url) );
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
