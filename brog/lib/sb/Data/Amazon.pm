# sb::Data::Amazon - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Data::Amazon;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.03';
# 0.03 [2007/07/22] added some accessors to handle blank image url
# 0.02 [2007/07/04] removed @mStruct and added elements
# 0.01 [2005/07/22] changed data structure to array
# 0.00 [2005/02/02] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Data::Object ();
@ISA = qw( sb::Data::Object );
# ==================================================
# // declaration for constant value
# ==================================================
sub ICON_UNDEFINED (){ '_parts/icon/undefined.gif' };
# ==================================================
# // declaration for data structure
# ==================================================
sub elements
{
	return(
		'id',    # id
		'wid',   # wid
		'pid',   # 作成者 id
		'order', # 並び順
		'stat',  # ステータス
		'name',  # 名前
		'cat',   # カタログ
		'cre',   # クリエーター
		'days',  # 発売日
		'make',  # メーカー
		'ism',   # イメージ(小)
		'imd',   # イメージ(中)
		'ilg',   # イメージ(大)
		'ava',   # 販売情報
		'lpr',   # 希望小売価格
		'opr',   # 販売価格
		'msg',   # コメント
		'url',   # アドレス
		'date',  # 追加日
		'tz',    # タイムゾーン
	);
}
# ==================================================
# // public functions
# ==================================================
sub noimage
{
	my $class = shift;
	my $name = shift;
	return sb::Config->get->value('srv_temp') . ICON_UNDEFINED;
}
sub formated_item
{
	my $self = shift;
	my $url   = $self->url;
	my $image = $self->imd;
	my $name  = $self->name;
	my $maker = $self->make;
	my $msg   = sb::Text->format('text'=>$self->msg,'form'=>1);
	return <<"__AMAZON_ITEM__";
<div class=\"amazon\">
<a href=\"$url\" target=\"_blank\"><img src=\"$image\" alt=\"$name\" class=\"amazon_pict\" /></a>
<div class=\"amazon_text\">
<a href=\"$url\" target=\"_blank\"><strong>$name</strong></a><br />
$maker<br />$msg</div>
</div>
__AMAZON_ITEM__
}
sub ism
{
	my $self = shift;
	return $self->_image('ism',@_);
}
sub imd
{
	my $self = shift;
	return $self->_image('imd',@_);
}
sub ilg
{
	my $self = shift;
	return $self->_image('ilg',@_);
}
sub initialize
{
	my $self  = shift;
	my %param = @_;
	$param{'wid'} |= 0;
	$param{'pid'} |= 0;
	$param{'stat'} |= 0;
	$param{'order'} = $self->id;
	$self->SUPER::initialize(%param);
}
# ==================================================
# // private functions
# ==================================================
sub _image
{
	my $self = shift;
	my $name = shift;
	$self->{$name} = shift if (@_);
	return $self->noimage($name) if ($self->{$name} eq '');
	return $self->{$name};
}
1;
__END__
