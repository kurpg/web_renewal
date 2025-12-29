# sb::Data::Category - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Data::Category;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.07';
# 0.07 [2007/07/04] removed @mStruct and added elements
# 0.06 [2007/02/09] added sub
# 0.05 [2007/02/07] added formated_text
# 0.04 [2007/02/06] changed %aOptionKeys to add line/sum options
# 0.03 [2005/07/22] changed data structure to array
# 0.02 [2005/07/11] changed config variable "srv_cgi" to "conf_srv_cgi"
# 0.01 [2005/06/01] added 'dir' method
# 0.00 [2005/02/02] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Config ();
use sb::Data::Object ();
@ISA = qw( sb::Data::Object );
# ==================================================
# // declaration for constant value
# ==================================================
sub CATEGORY_FORMAT (){ '%Main% &gt; %Sub%' }
sub DEFAULT_OPTION  (){ '0:0:0:1:' };
my %aOptionKeys = (
	'top'  => 0,  # トップページ表示設定
	'list' => 1,  # リスト表示設定
	'line' => 2,  # 説明の改行設定
	'sum'  => 3,  # リストの概要表示
);
# ==================================================
# // declaration for data structure
# ==================================================
sub elements
{
	return(
		'id',    # id
		'wid',   # wid
		'name',  # 名前
		'text',  # 説明
		'url',   # トラックバック送信先
		'main',  # 親カテゴリ
		'order', # 並び順
		'temp',  # テンプレート id
		'dir',   # 保存先
		'disp',  # 表示設定
		'sub',   # 子カテゴリ
		'num',   # 記事数
		'idx',   # カテゴリインデックス
	);
}
# ==================================================
# // public functions
# ==================================================
sub dir
{
	my $self = shift;
	$self->{'dir'} = shift if @_;
	return ($self->{'dir'} ne '')
		? $self->{'dir'}
		: sb::Config->get->value('conf_dir_log');
}
sub get_option
{
	my $self = shift;
	my $key  = shift;
	my @option = split(':',$self->disp);
	return $option[$aOptionKeys{$key}];
}
sub sub
{
	my $self = shift;
	$self->{'sub'} = shift if (@_);
	$self->{'sub'} =~ s/,,/,/g;
	$self->{'sub'} = '' if ($self->{'sub'} eq ',');
	$self->{'sub'};
}
sub add_sub
{
	my $self = shift;
	my $add  = shift;
	my $sub  = ($add ne '') ? $add . ',' . $self->sub : $self->sub;
	return $self->sub($sub);
}
sub remove_sub
{
	my $self = shift;
	my $del  = shift;
	my @subs = ();
	foreach ( split(',',$self->sub) )
	{
		push(@subs,$_) if ($_ ne $del);
	}
	return $self->sub(join(',',@subs) . ',');
}
sub fullname_with_link
{
	my $self = shift;
	return '<a href="' . $self->cat_url . '">' . $self->fullname(@_) . '</a>';
}
sub cat_url
{
	my $self = shift;
	return ($self->idx)
		? sb::Config->get->value('conf_srv_base') . $self->dir
		: sb::Config->get->value('conf_srv_cgi') . sb::Config->get->value('basic_sb') . '?cid=' . $self->id;
}
sub fullname
{
	my $self = shift;
	my $cat  = shift;
	my $form = (@_) ? shift : CATEGORY_FORMAT;
	return($self->name) if ( !defined($cat) );
	if ( $self->main ne '' and defined($cat->{$self->main}) )
	{
		my $main = $cat->{$self->main}->fullname($cat,$form);
		my $name = $self->name;
		$form =~ s/%Main%/$main/;
		$form =~ s/%Sub%/$name/;
		return($form);
	}
	return($self->name);
}
sub formated_text
{
	my $self = shift;
	my $as_summary = shift;
	return if ($self->text() eq '');
	my $text = 
		  ($as_summary)               ? sb::Text->clip('text'=>$self->text(),'form'=>1)
		: ($self->get_option('line')) ? sb::Text->format('text'=>$self->text(),'form'=>1)
		: $self->text();
	return( $text );
}
sub initialize
{
	my $self  = shift;
	my %param = @_;
	$param{'wid'} |= 0;
	$param{'order'} |= $self->id;
	$param{'temp'} = -1 if ($param{'temp'} eq '');
	$param{'disp'} = DEFAULT_OPTION if ($param{'disp'} eq '');
	$param{'num'} |= 0;
	$param{'idx'} |= 0;
	$self->SUPER::initialize(%param);
}
1;
__END__
