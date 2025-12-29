# sb::Data::Link - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Data::Link;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.03';
# 0.03 [2007/07/04] removed @mStruct and added elements
# 0.02 [2005/07/22] changed data structure to array
# 0.01 [2005/06/30] removed default target attribute
# 0.00 [2005/02/02] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Data::Object ();
@ISA = qw( sb::Data::Object );
# ==================================================
# // declaration for constant value
# ==================================================
sub GROUP_LABEL (){ 'group' };
# ==================================================
# // declaration for data structure
# ==================================================
sub elements
{
	return(
		'id',     # id
		'wid',    # wid
		'name',   # サイト名
		'url',    # アドレス
		'text',   # 説明
		'user',   # 作成者
		'order',  # 並び順
		'disp',   # 表示設定
		'type',   # リンクタイプ
		'target', # ターゲット
	);
}
# ==================================================
# // public functions
# ==================================================
sub is_group
{
	my $self = shift;
	return ($self->type eq GROUP_LABEL);
}
sub set_as_group
{
	my $self = shift;
	$self->type(GROUP_LABEL);
}
sub initialize
{
	my $self  = shift;
	my %param = @_;
	$param{'wid'} |= 0;
	$param{'user'} |= 0;
	$param{'disp'} |= 0;
	$param{'order'} = $self->id;
	$self->SUPER::initialize(%param);
}
1;
__END__
