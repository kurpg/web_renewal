# sb::Admin::Upload - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Admin::Upload;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.06';
# 0.06 [2006/09/30] changed _update_image to check user permission
# 0.05 [2005/07/27] chnaged _update_image to pass _open_entry correctly
# 0.04 [2005/07/22] changed _update_image to pass _display_image_list after deleting images
# 0.03 [2005/07/20] changed _is_editable to fix a bug
# 0.02 [2005/07/08] changed _update_image to build a js for cookie
# 0.01 [2005/06/07] changed _display_image_list to fix a bug
# 0.00 [2005/02/02] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Config ();
use sb::Language ();
use sb::Interface ();
use sb::TemplateManager ();
use sb::Build ();
use sb::Data ();
use sb::Text ();
use sb::Admin::Entry ();
@ISA = qw( sb::Admin::Entry );
# ==================================================
# // declaration for constant value
# ==================================================
sub TEMPLATE     (){ 'upload.html' };
sub THUMB_SIZE   (){ 80 };
sub TABLE_WIDTH  (){ 495 };
sub LIST_COLUMN  (){ 6 };
sub DENIED_CHECK (){ '-' };
sub NO_DATA      (){ '-' };
sub DATE_FORMAT  (){ '%YearShort%.%Mon%.%Day% %Hour%:%Min%' };
sub DATE_LANG    (){ 'en' };
sub LIST_MARK    (){ '[L]' };
sub COMICON_MARK (){ '[C]' };
sub TB_ICON_MARK (){ '[T]' };
# ==================================================
# // declaration for class member
# ==================================================
# ==================================================
# // public functions - callback
# ==================================================
sub callback { # コールバック
	my $self = shift;
	return ($self->{'regi'}) 
		? $self->_update_image(@_) 
		: $self->_display_image_list(@_);
}
# ==================================================
# // private functions - main routine
# ==================================================
sub _update_image {
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi = sb::Interface->get;
	my $lang = sb::Language->get;
	if ($cgi->value('__regi') eq 'upload') { # アップロード
		my $num = $self->upload_image('over'=>($cgi->value('upload_overwrite') eq 'on'));
		return $self->_display_image_list(
			'message'=> ($num > 0) ? sprintf($lang->string('parts_add_comp'),$num) : $lang->string('error_failtoadd')
		);
	} elsif ($cgi->value('namechange') ne '') { # 名称変更
		my @ids = split("\0",$cgi->value('iid'));
		my @imgs = sb::Data->load('Image','cond'=>{'id'=>\@ids});
		foreach my $img (@imgs)
		{
			next if (!$self->check_permission('user'=>$img->auth));
			my $name = $cgi->value('img_name' . $img->id);
			$img->name(sb::Text->entitize($name));
		}
		sb::Data->update(@imgs) if (@imgs);
		return $self->_display_image_list('message'=>$lang->string('parts_editcomp'));
	} else { # ステータス変更
		my $flag = undef;
		my @sels = split("\0",$cgi->value('sel'));
		my @imgs = sb::Data->load('Image','cond'=>{'id'=>\@sels});
		ACTION_SWITCH: {
			$_ = $cgi->value('regi_action');
			/^entry$/ && do { # 記事作成
				my $option = ('file','thumb','link','link')[$self->{'user'}->get_option('imagelist')];
				my $newtext = '';
				foreach my $img (@imgs) {
					$newtext .= $img->get_as_tag('type'=>$img->is_image ? $option : 'link') . "\n";
				}
				$self->{'mode'} = 'new';
				return $self->_open_entry('newtext'=>$newtext);
			};
			/^del$/ && do { # 削除
				foreach my $img (@imgs) {
					$img->erase;
				}
				last ACTION_SWITCH;
			};
			/^lst(\d)$/ && do { # イメージ挿入支援
				my $new = $1;
				foreach my $img (@imgs) {
					$img->stat($new);
				}
				last ACTION_SWITCH;
			};
			/^com(\d)$/ && do { # コメントアイコン
				$flag = 1;
				my $new = $1;
				foreach my $img (@imgs) {
					$img->icon_c($new);
				}
				last ACTION_SWITCH;
			};
			/^tb(\d)$/ && do { # トラックバックアイコン
				my $new = $1;
				foreach my $img (@imgs) {
					$img->icon_t($new);
				}
				last ACTION_SWITCH;
			};
			/^\[(.+)\]$/ && do { # 保存先変更
				my $new = $1;
				foreach my $img (@imgs) {
					$img->rename_file('dir'=>$new);
				}
				last ACTION_SWITCH;
			};
		};
		sb::Build->build_cookie_js('force_to_create') if ($flag);
		sb::Data->update(@imgs) if (@imgs);
		return ($cgi->value('regi_action') eq 'del')
			? $self->_display_image_list('message'=>($#imgs + 1) . $lang->string('parts_deleted'))
			: $self->_display_image_list('message'=>$lang->string('parts_editcomp'));
	}
}
sub _display_image_list {
	my $self = shift;
	my %param = (
		'message' => '',
		'setup'   => $self->setup_list,
		@_
	);
	my $cgi = sb::Interface->get;
	my $cms = sb::TemplateManager->new($self->load_template('file'=>TEMPLATE));
	my $disptype = ( $cgi->value('__type') eq 'form' ) ? 'form' : 'main';
	my $iid = ( $cgi->value('image_id') eq '' ) ? undef : $cgi->value('image_id');
	if ($disptype eq 'main') {
		my $dispsort = ( $cgi->value('dispsort') ne '' ) ? $cgi->value('dispsort') : 'date';
		my $disp_num = $param{'setup'}->{'dispnum'} / 2;
		my $page = int($cgi->value('page'));
		$page = int($cgi->value('now_page')) + 1 if ( $cgi->value('next') ne '' );
		$page = int($cgi->value('now_page')) - 1 if ( $cgi->value('prev') ne '' );
		my @imgs = sb::Data->load('Image',
			'sort'  => $dispsort,
			'order' => 1,
			'id'    => $iid,
			'num'   => $disp_num,
			'bgn'   => $page * $disp_num,
			'cond'  => $self->_generate_condition,
		);
		$cms->num(0);
		$cms->tag('sb_list_page'=>$self->display_pagelink( # ページリンク
				'mode'    => 'upload',
				'column'  => LIST_COLUMN,
				'all'     => sb::Data->matched,
				'printed' => $#imgs + 1,
				'num'     => $disp_num,
				'params'  => ['dispsort','dispdir','dispdate','dispnum'],
			)
		);
		$self->imagedir_selector( # イメージセレクタ[選択/処理]
			'cms'    => $cms,
			'tag'    => 'sb_img_dirsel',
			'select' => '',
			'format' => '[%s]',
		);
		$self->imagedir_selector( # イメージセレクタ[検索条件]
			'cms'    => $cms,
			'tag'    => 'sb_img_dispdir',
			'select' => $cgi->value('dispdir'),
		);
		$self->dispnum_selector( # 表示数セレクタ
			'cms'  => $cms,
			'now'  => $param{'setup'}->{'dispnum'},
			'half' => 'yes',
		);
		$self->monthly_selector( # 月別セレクタ
			'cms'  => $cms,
			'tag'  => 'sb_message_dispdate',
			'data' => 'Image',
		);
		$self->select_option( # 並び順
			'cms'      => $cms,
			'tag'      => 'sb_dispsort_',
			'selected' => $dispsort,
		);
		$self->listmain(
			'template' => $cms,
			'block'    => 'sb_upload_list',
			'objects'  => \@imgs,
			'tags'     => {
				'sb_img_id'        => 'id',
				'sb_img_image'     => \&_display_image,
				'sb_img_nametext'  => 'name',
				'sb_img_disable'   => \&_is_editable,
				'sb_img_thumb'     => \&_thumb_mark,
				'sb_img_dirdisp'   => 'dir',
				'sb_img_imagsize'  => \&_display_image_size,
				'sb_img_statclass' => \&_display_status,
				'sb_img_sel'       => \&_display_checkbox,
				'sb_img_height'    => sub { THUMB_SIZE },
			},
		);
		if ($iid ne '' and $imgs[0]) {
			my $date = sb::Time->format(
				'time' => $imgs[0]->date,
				'form' => DATE_FORMAT,
				'zone' => $imgs[0]->tz,
				'lang' => DATE_LANG,
			);
			my $author = $self->{'users'}->{$imgs[0]->auth};
			my $status = '';
			$status .= LIST_MARK if ($imgs[0]->stat eq '0');
			$status .= COMICON_MARK if ($imgs[0]->icon_c eq '1');
			$status .= TB_ICON_MARK if ($imgs[0]->icon_t eq '1');
			my $entry = ($imgs[0]->eid ne '') ? '' : NO_DATA;
			if ($imgs[0]->eid ne '') {
				my @eids = split(':',$imgs[0]->eid);
				foreach my $eid (@eids) {
					my $buf = sb::Data->load('Entry','id'=>$eid);
					$entry .= $self->clip_text(
						'text' => $buf->subj,
						'length' => length($buf->subj),
						'base'   => '?__mode=edit&amp;eid=' . $buf->id,
						'user'   => $buf->auth,
					) . '<br />';
				}
			}
			my $image = $imgs[0]->get_as_tag('max_w'=>TABLE_WIDTH,'max_h'=>TABLE_WIDTH,'type'=>'file');
			$cms->num(0);
			$cms->tag('sb_img_one_id'     => $imgs[0]->id);
			$cms->tag('sb_img_one_name'   => $imgs[0]->name);
			$cms->tag('sb_img_one_dir'    => $imgs[0]->dir);
			$cms->tag('sb_img_one_size'   => $self->_display_image_size($imgs[0]));
			$cms->tag('sb_img_one_author' => $author ? $author->real : NO_DATA);
			$cms->tag('sb_img_one_date'   => $date);
			$cms->tag('sb_img_one_status' => $status);
			$cms->tag('sb_img_one_entry'  => $entry);
			$cms->tag('sb_img_one_image'  => $image);
			$cms->tag('sb_img_one_type'   => $imgs[0]->get_content_type);
		}
	}
	if ($iid eq '') {
		my $max = ($disptype eq 'form') ? sb::Config->get->value('basic_max_img') : 1;
		for (my $i=0;$i<$max;$i++) { # アップロードフォーム
			$cms->num($i);
			$cms->tag('sb_upload_num'=>$i);
		}
		$self->imagedir_selector( # イメージセレクタ[フォーム]
			'cms'   => $cms,
			'tag'   => 'sb_img_dir',
			'thumb' => 'sb_upload_thumb',
			'over'  => 'check',
		);
		$cms->block('sb_upload_formname'=>1) if ($disptype eq 'main');
		$cms->block('sb_upload_eachform'=>$max);
	}
	$cms->num(0);
	$cms->tag('sb_submenu_upload_main'=>' class="current"') if ($disptype eq 'main');
	$cms->tag('sb_submenu_upload_form'=>' class="current"') if ($disptype eq 'form');
	$cms->block('sb_upload_select'=>($disptype eq 'main' and $iid eq '') ? 1 : 0);
	$cms->block('sb_upload_one'=>($iid eq '') ? 0 : 1);
	$cms->block('sb_upload_main'=>($disptype eq 'main') ? 1 : 0);
	$cms->block('sb_upload_form'=>($iid eq '') ? 1 : 0);
	if ($param{'message'} ne '') { # 処理通知
		$cms->num(0);
		$cms->tag('sb_process_message'=>$param{'message'});
		$cms->block('sb_upload_message'=>1);
	}
	$self->common_template_parts($cms);
	return sb::Interface->get->head('type'=>'text/html') . $self->set_main($cms->output);
}
# ==================================================
# // private functions - for image list
# ==================================================
sub _generate_condition {
	my $self = shift;
	my %cond = ();
	my $cgi  = sb::Interface->get;
	if ($cgi->value('dispdir') ne '') {
		$cond{'dir'} = $cgi->value('dispdir');
	}
	if ($cgi->value('dispdate') ne '') {
		$cond{'date'} = $self->create_date_condition($cgi->value('dispdate'));
		$cond{'__range'} = { 'date' => 'tz' };
	}
	return \%cond;
}
sub _display_image {
	my $self = shift;
	my $obj  = shift;
	my $img = $obj->get_as_tag(
		'max_w' => THUMB_SIZE,
		'max_h' => THUMB_SIZE,
		'type'  => ($obj->thumb eq '') ? 'file' : 'thumb',
	);
	return $self->clip_text(
		'text' => $img,
		'base' => '?__mode=upload&amp;image_id=' . $obj->id,
		'user' => $obj->auth,
		'length' => length($img),
	);
}
sub _is_editable {
	my $self = shift;
	my $obj  = shift;
	return ($self->check_permission('user'=>$obj->auth)) ? '' : 'disabled="disabled"';
}
sub _thumb_mark {
	my $self = shift;
	my $obj  = shift;
	return ($obj->thumb ne '') ? sb::Language->get->string('parts_thumblst') : '';
}
sub _display_checkbox {
	my $self = shift;
	my $obj  = shift;
	return ( $self->check_permission('user'=>$obj->auth) and sb::Interface->get->value('image_id') eq '' )
	? '<input type="checkbox" name="sel" value="' . $obj->id . '" onclick="switchList(this)" />'
	: DENIED_CHECK;
}
sub _display_image_size {
	my $self = shift;
	my $obj  = shift;
	my ($w,$h) = $obj->get_size;
	my $size = $obj->get_filesize;
	return( $w . ' x ' . $h . ' / ' . $size . 'KB' );
}
sub _display_status {
	my $self = shift;
	my $obj  = shift;
	my $text = '';
	$text .= 'lst' . $obj->stat;
	$text .= '_com' . $obj->icon_c;
	$text .= '_tb' . $obj->icon_t;
	$text .= '_[' . $obj->dir . ']';
	return($text);
}
1;
__END__
