# sb::Data::Image - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Data::Image;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.08';
# 0.08 [2009/07/27] added flv/mp4/m4a/m4p into supported MIME types
# 0.07 [2007/07/04] removed @mStruct and added elements
# 0.06 [2006/11/01] changed _file_extension to handle content type correctly
# 0.05 [2006/02/01] changed _file_contenttype
# 0.04 [2005/08/02] added some functions to calculate image size
# 0.03 [2005/07/26] changed _file_extension/_file_contenttype to add some file types.
# 0.02 [2005/07/22] changed data structure to array
# 0.01 [2005/07/16] changed upload to create thumbnail correctly
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
sub IMAGE_PREFIX     (){ 'img' };
sub THUMB_PREFIX     (){ 'thm' };
sub DEFAULT_FILENAME (){ 'file' };
sub PARTS_DIR        (){ '_parts/icon/' };
sub ICON_UNDEFINED   (){ 'undefined.gif' };
sub ICON_SUFFIX      (){ '.gif' };
sub ICON_WIDTH       (){ 32 };
sub ICON_HEIGHT      (){ 32 };
sub THUMB_CLASS      (){ 'thumb' };
sub IMAGE_CLASS      (){ 'pict' };
# ==================================================
# // declaration for private variables
# ==================================================
my %pSizeFunction = (
	'.jpg' => \&_get_size_jpg,
	'.png' => \&_get_size_png,
	'.gif' => \&_get_size_gif,
	'.bmp' => \&_get_size_bmp,
	'.tif' => \&_get_size_tif,
);
# ==================================================
# // declaration for data structure
# ==================================================
sub elements
{
	return(
		'id',     # id
		'wid',    # wid
		'auth',   # creator(author)
		'date',   # date of creation
		'name',   # name
		'file',   # file name
		'thumb',  # thumbnail image name if it has a thumbnail image
		'stat',   # flag for image selector
		'icon_c', # flag for comment icon
		'icon_t', # flag for trackback icon
		'dir',    # uploaded directory
		'eid',    # artilcles which are included this file
		'tz',     # timezone
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
		: sb::Config->get->value('conf_dir_img');
}
sub rename_file
{
	my $self = shift;
	my %param = (
		'dir'   => $self->dir,
		'file'  => $self->file,
		'thumb' => $self->thumb,
		@_
	);
	if (  $param{'dir'} eq $self->dir and $param{'file'} eq $self->file and $param{'thumb'} eq $self->thumb )
	{
		return( undef );
	}
	else
	{
		my $old_dir = sb::Config->get->value('conf_dir_base') . $self->dir;
		foreach my $type ('file','thumb')
		{
			next if ($self->$type() eq '');
			my $old = $old_dir . $self->$type();
			my $new = sb::Config->get->value('conf_dir_base') . $param{'dir'} . $param{$type};
			if ( (-e $old and rename($old,$new)) or (!-e $old and -e $new) )
			{
				$self->$type($param{$type});
				$self->dir($param{'dir'});
			}
		}
		return( 1 );
	}
}
sub delete_file
{
	my $self = shift;
	unlink($self->get_path);
	unlink($self->get_path('type'=>'thumb')) if ($self->thumb ne '');
}
sub erase
{
	my $self = shift;
	$self->delete_file;
	$self->SUPER::erase;
}
sub upload
{
	my $self = shift;
	my %param = (
		'entity' => undef,
		'label'  => undef,
		'dir'    => sb::Config->get->value('conf_dir_img'),
		'thumb'  => undef,
		'header' => [],
		'name'   => undef,
		'fixed'  => undef,
		'over'   => undef,
		@_
	);
	my $label = $param{'label'};
	my @header = @{$param{'header'}};
	return( undef ) if ($param{'entity'} eq '' or $label eq '' or !@header);
	foreach (@header)
	{
		next if ($_ !~ /$label/);
		$param{'type'}     = $2 if ($_ =~ /(.*)Content-type:(.*)/i);
		$param{'filename'} = $2 if ($_ =~ /(.*)filename=(.*)/i);
		$param{'macbin'}   = ($_ =~ /application\/x-macbinary/i) ? 1 : undef;
		last;
	}
	if ($param{'macbin'})
	{ # handle mac binary
		my $len = substr($param{'entity'},83,4);
		$len = unpack("%N",$len);
		$param{'entity'} = substr($param{'entity'},128,$len);
	}
	$param{'type'} =~ tr/\x0D\x0A//d;
	$param{'type'} =~ s/\s//g;
	$param{'filename'} =~ tr/\"\x0D\x0A//d;
	$param{'filename'} =~ s/.*[:\/\\](.*)/$1/; # extract file name only
	my $tail = &_file_extension($param{'type'}) || &_check_tail($param{'filename'});
	my $name = ($param{'filename'} =~ /[^a-zA-Z0-9_\-\.]/)
	         ? IMAGE_PREFIX . $self->id . '_' . DEFAULT_FILENAME . $tail
	         : IMAGE_PREFIX . $self->id . '_' . $param{'filename'};
	$name = $param{'filename'} if ($param{'fixed'} and $param{'filename'} !~ /[^a-zA-Z0-9_\-\.]/);
	if ( $tail )
	{
		$self->name(($param{'name'} ne '') ? sb::Text->entitize($param{'name'}) : sb::Text->entitize($param{'filename'}));
		$self->file($name);
		$self->dir($param{'dir'});
		my $file = $self->get_path;
		eval {
			die('file exit') if (!$param{'over'} and -e $file); # a file already exist
			open(BINOUT,">$file") or die('failed file open');
			binmode(BINOUT);
			print BINOUT $param{'entity'};
			close(BINOUT);
			chmod(sb::Config->get->value('basic_file_attr'),$file);
		};
		return( undef ) if ($@);
	}
	else
	{
		return( undef );
	}
	if ( $param{'thumb'} and &_resizable($self->file) )
	{
		my $thumb = ($param{'filename'} =~ /[^a-zA-Z0-9_\-\.]/)
		          ? THUMB_PREFIX . $self->id . '_' . DEFAULT_FILENAME . $tail
		          : THUMB_PREFIX . $self->id . '_' . $param{'filename'};
		my $base = sb::Config->get->value('conf_dir_base');
		my $size = sb::Config->get->value('conf_thumbsize');
		if ( &_create_smallimage($thumb,$name,$base . $self->dir,$size) )
		{
			$self->thumb($thumb);
		}
	}
	return( 1 );
}
sub get_as_tag
{
	my $self = shift;
	my %param = (
		'max_w' => 0,      # maximum width
		'max_h' => 0,      # maximum height
		'type'  => 'file', # file : image only / thumb : thumbnail only / link : with link to image
		@_,
	);
	my ($w,$h) = $self->get_size(%param,'type'=>'file');
	if (&_resizable($self->file))
	{
		if ($param{'type'} ne 'file' and $self->thumb ne '')
		{ # if it has a thumbnail image
			my ($tw,$th) = $self->get_size(%param,'type'=>'thumb');
			my $thumb = '<img src="' . $self->get_url('type'=>'thumb') . '" class="' . THUMB_CLASS . '" ';
			$thumb .= 'alt="' . $self->name . '" title="' . $self->name . '" ';
			$thumb .= 'width="' . $tw . '" height="' . $th . '" />';
			return ($param{'type'} eq 'thumb') ? $thumb : '<a href="' . $self->get_url . '">' . $thumb . '</a>';
		}
		else
		{ # no thumbnail image
			my $text = '<img src="' . $self->get_url . '" class="' . IMAGE_CLASS . '" ';
			$text .= 'alt="' . $self->name . '" title="' . $self->name . '" ';
			$text .= 'width="' . $w . '" height="' . $h . '" />';
			return $text;
		}
	}
	else
	{
		my $dir = sb::Config->get->value('dir_temp') . PARTS_DIR;
		my $srv = sb::Config->get->value('srv_temp') . PARTS_DIR;
		my $tail = &_check_tail($self->file);
		$tail =~ s/^\.//g;
		if ($tail ne '')
		{
			my $icon = $tail . ICON_SUFFIX;
			$icon = ICON_UNDEFINED if (!-e $dir . $icon);
			my $text = '<img src="' . $srv . $icon . '" class="' . IMAGE_CLASS . '" ';
			$text .= 'alt="' . $self->name . '" title="' . $self->name . '" ';
			$text .= 'width="' . ICON_WIDTH . '" height="' . ICON_HEIGHT . '" />';
			return ($param{'type'} ne 'link') ? $text : '<a href="' . $self->get_url . '">' . $text . '</a>';
		}
		return( undef );
	}
}
sub get_as_mime
{
	my $self = shift;
	my %param = (
		'type'  => 'file', # file or thumb
		@_,
	);
	my $out = '';
	return($out) if ($param{'type'} eq 'thumb' and $self->thumb eq '');
	my $file = $self->get_path('type'=>$param{'type'});
	my $len = sb::Config->get->value('basic_base_enc');
	if (-r $file)
	{
		require 'mimeutil.pl';
		open(IMAGEIN, $file);
		binmode(IMAGEIN);
		while( read(IMAGEIN, $_, $len) )
		{
			$out .= &mimeutil::bodyencode($_,'b64');
		}
		$out .= &mimeutil::benflush('b64');
	}
	return($out);
}
sub is_image
{
	my $self = shift;
	return &_resizable($self->file);
}
sub get_content_type
{
	my $self = shift;
	return &_file_contenttype($self->file);
}
sub get_size
{
	my $self = shift;
	my %param = (
		'max_w' => 0,      # maximum width
		'max_h' => 0,      # maximum height
		'type'  => 'file', # file or thumb
		@_,
	);
	my ($w,$h) = (0,0);
	my $path = $self->get_path('type'=>$param{'type'});
	if (&_resizable($self->file))
	{
		my $tail = &_check_tail($path);
		($w,$h) = &{$pSizeFunction{$tail}}($path) if ($tail);
		if ($param{'max_w'} and $param{'max_h'})
		{
			($w,$h) = &_resize($w,$h,$param{'max_w'},$param{'max_h'});
		}
	}
	elsif ($self->get_content_type eq 'application/x-shockwave-flash')
	{
		($w,$h) = &_get_size_swf($path); # try to get image size for flash
	}
	return ($w == 0 and $h == 0) ? ('--','--') : ($w,$h);
}
sub get_filesize
{
	my $self = shift;
	my $path = $self->get_path('type'=>'file');
	my $size = (-s $path) / 1024; # output as KB
	return sprintf("%.2f",$size);
}
sub get_path
{
	my $self = shift;
	my %param = (
		'type'  => 'file', # file or thumb
		@_,
	);
	my $dir  = sb::Config->get->value('conf_dir_base') . $self->dir;
	my $file = ($param{'type'} eq 'thumb' and $self->thumb ne '') ? $self->thumb : $self->file;
	return( $dir . $file );
}
sub get_url
{
	my $self = shift;
	my %param = (
		'type'  => 'file', # file or thumb
		@_,
	);
	my $dir  = sb::Config->get->value('conf_srv_base') . $self->dir;
	my $file = ($param{'type'} eq 'thumb' and $self->thumb ne '') ? $self->thumb : $self->file;
	return( $dir . $file );
}
sub initialize
{
	my $self  = shift;
	my %param = @_;
	$param{'wid'} |= 0;
	$param{'auth'} |= 0;
	$param{'stat'} |= 0;
	$param{'icon_c'} |= 0;
	$param{'icon_t'} |= 0;
	$self->SUPER::initialize(%param);
}
# ==================================================
# // private functions
# ==================================================
sub _resizable
{
	my $name = shift;
	my $type = &_file_contenttype($name);
	return ($type =~ /^image/);
}
sub _check_tail
{
	my $file = shift;
	return &_file_extension(&_file_contenttype($file));
}
sub _file_extension
{
	# file extensions, the following files can be handled on Serene bach
	my $content_type = shift;
	return('.html') if ($content_type eq 'text/html');
	return('.css')  if ($content_type eq 'text/css');
	return('.txt')  if ($content_type eq 'text/plain');
	return('.xml')  if ($content_type eq 'application/xml');
	return('.jpg')  if ($content_type eq 'image/jpeg' or $content_type eq 'image/pjpeg');
	return('.png')  if ($content_type eq 'image/png' or $content_type eq 'image/x-png');
	return('.gif')  if ($content_type eq 'image/gif');
	return('.bmp')  if ($content_type eq 'image/bmp');
	return('.tif')  if ($content_type eq 'image/tiff');
	return('.mov')  if ($content_type eq 'video/quicktime');
	return('.mpg')  if ($content_type eq 'video/mpeg' or $content_type eq 'video/x-mpeg');
	return('.mp4')  if ($content_type eq 'video/mp4');
	return('.avi')  if ($content_type eq 'video/x-msvideo');
	return('.flv')  if ($content_type eq 'video/x-flv');
	return('.rm')   if ($content_type eq 'audio/x-pn-realaudio');
	return('.mp3')  if ($content_type eq 'audio/mpeg' or $content_type eq 'audio/x-mpeg');
	return('.midi') if ($content_type eq 'audio/midi' or $content_type eq 'audio/x-midi');
	return('.wav')  if ($content_type eq 'audio/wav' or $content_type eq 'audio/x-wav');
	return('.m4a')  if ($content_type eq 'audio/x-m4a');
	return('.m4p')  if ($content_type eq 'audio/x-m4p');
	return('.swf')  if ($content_type eq 'application/x-shockwave-flash');
	return('.gz')   if ($content_type eq 'application/gzip' or $content_type eq 'application/x-gzip');
	return('.zip')  if ($content_type eq 'application/zip' or $content_type eq 'application/x-zip-compressed');
	return('.lzh')  if ($content_type eq 'application/lha' or $content_type eq 'application/x-lha');
	return('.sit')  if ($content_type eq 'application/x-stuffit');
	return('.z')    if ($content_type eq 'application/x-compress');
	return('.doc')  if ($content_type eq 'application/msword');
	return('.ppt')  if ($content_type eq 'application/mspowerpoint');
	return('.xls')  if ($content_type eq 'application/x-excel');
	return('.pdf')  if ($content_type eq 'application/pdf');
	return('.ps')   if ($content_type eq 'application/postscript');
	return( undef );
}
sub _file_contenttype
{
	# file MIME types, if it's unknown, this function returns as "application/octet-stream"
	my $name = shift;
	return('text/html')                     if ($name =~ /\.html?$/i);
	return('text/css')                      if ($name =~ /\.css$/i);
	return('text/plain')                    if ($name =~ /\.txt$/i);
	return('image/gif')                     if ($name =~ /\.gif$/i);
	return('image/jpeg')                    if ($name =~ /\.jpe?g$/i);
	return('image/png')                     if ($name =~ /\.png$/i);
	return('image/bmp')                     if ($name =~ /\.bmp$/i);
	return('image/tiff')                    if ($name =~ /\.tiff?$/i);
	return('audio/mpeg')                    if ($name =~ /\.mp3$/i);
	return('audio/midi')                    if ($name =~ /\.midi?$/i);
	return('audio/wav')                     if ($name =~ /\.wav$/i);
	return('audio/x-pn-realaudio')          if ($name =~ /\.rm$/i);
	return('audio/x-m4a')                   if ($name =~ /\.m4a$/i);
	return('audio/x-m4p')                   if ($name =~ /\.m4p$/i);
	return('video/mpeg')                    if ($name =~ /\.mpe?g$/i);
	return('video/mp4')                     if ($name =~ /\.mp4$/i);
	return('video/x-msvideo')               if ($name =~ /\.avi$/i);
	return('video/quicktime')               if ($name =~ /\.mov$/i);
	return('video/x-flv')                   if ($name =~ /\.flv$/i);
	return('application/xml')               if ($name =~ /\.xml$/i);
	return('application/x-shockwave-flash') if ($name =~ /\.swf$/i);
	return('application/x-stuffit')         if ($name =~ /\.sit$/i);
	return('application/x-compress')        if ($name =~ /\.z$/i);
	return('application/gzip')              if ($name =~ /\.gz$/i);
	return('application/zip')               if ($name =~ /\.zip$/i);
	return('application/lha')               if ($name =~ /\.lzh$|\.lha$/i);
	return('application/msword')            if ($name =~ /\.doc$/);
	return('application/mspowerpoint')      if ($name =~ /\.ppt$/);
	return('application/x-excel')           if ($name =~ /\.xls$/);
	return('application/pdf')               if ($name =~ /\.pdf$/);
	return('application/postscript')        if ($name =~ /\.e?ps$/);
	return('application/octet-stream');
}
sub _resize
{
	# calculate size to remain the same aspect
	my ($w,$h,$max_w,$max_h) = @_;
	if ($w > $max_w or $h > $max_h)
	{
		my $tmp = (($max_w / $w) < ($max_h / $h)) ? $max_w / $w : $max_h / $h;
		$w = int($w * $tmp) or 1;
		$h = int($h * $tmp) or 1;
	}
	return($w,$h);
}
sub _create_smallimage
{
	# create a thumbnail image via Image::Magick
	my ($thumb,$file,$dir,$size) = @_;
	return( undef ) if ($file eq '' or $thumb eq '' or $dir eq '');
	eval {
		require Image::Magick;
		my $old = Image::Magick->new;
		$old->Read($dir . $file);
		my ($w,$h) = $old->Get('width','height');
		($w,$h) = &_resize($w,$h,$size,$size);
		my $new = $old->Clone();
		$new->Scale('width'=>$w,'height'=>$h);
		$new->Write("$dir$thumb");
		chmod(sb::Config->get->value('basic_file_attr'),$dir . $thumb) if (-e $dir . $thumb);
	};
	return ($@) ? undef : 1;
}
sub _get_size_jpg
{
	# reference from KENT WEB <http://www.kent-web.com//>
	my $jpeg = shift;
	my ($t, $m, $c, $l, $w, $h);
	open(JPEG, "$jpeg") or return (0,0);
	binmode JPEG;
	read(JPEG, $t, 2);
	while (1)
	{
		read(JPEG, $t, 4);
		($m, $c, $l) = unpack("a a n", $t);
		if ($m ne "\xFF")
		{
			$w = $h = 0;
			last;
		}
		elsif ((ord($c) >= 0xC0) && (ord($c) <= 0xC3))
		{
			read(JPEG, $t, 5);
			($h, $w) = unpack("xnn", $t);
			last;
		}
		else
		{
			read(JPEG, $t, ($l - 2));
		}
	}
	close(JPEG);
	return($w, $h);
}
sub _get_size_gif
{
	# reference from KENT WEB <http://www.kent-web.com//>
	my $gif = shift;
	my ($data);
	open(GIF,"$gif") or return (0,0);
	binmode(GIF);
	read(GIF,$data,10);
	close(GIF);
	$data = substr($data,-4) if ($data =~ /^GIF/);
	my $w = unpack("v",substr($data,0,2));
	my $h = unpack("v",substr($data,2,2));
	return($w, $h);
}
sub _get_size_bmp
{
	# taken from Image::Size <http://search.cpan.org/~rjray/Image-Size-2.992/Size.pm>
	# copyright (C) 2000 Randy J. Ray
	my $bmp = shift;
	my $buffer = undef;
	open(BMP,"$bmp") or return(0, 0);
	binmode(BMP);
	read(BMP, $buffer, 26);
	my ($w, $h) = unpack("x18VV", $buffer);
	close(BMP);
	return($w, $h);
}
sub _get_size_tif
{
	# taken from Image::Size <http://search.cpan.org/~rjray/Image-Size-2.992/Size.pm>
	# copyright (C) 2000 Randy J. Ray
	my $tif = shift;
	my $endian = 'n'; # default to big-endian
	my $header = undef;
	my $offset = undef;
	my $ifd = undef;
	# === preparation ===
	open(TIF,"$tif") or return(0, 0);
	binmode(TIF);
	read(TIF, $header, 4);
	$endian = 'v' if ($header =~ /II\x2a\x00/o); # little-endian
	my @packspec = (
		undef,       # nothing (shouldn't happen)
		'C',         # BYTE (8-bit unsigned integer)
		undef,       # ASCII
		$endian,     # SHORT (16-bit unsigned integer)
		uc($endian), # LONG (32-bit unsigned integer)
		undef,       # RATIONAL
		'c',         # SBYTE (8-bit signed integer)
		undef,       # UNDEFINED
		$endian,     # SSHORT (16-bit unsigned integer)
		uc($endian), # SLONG (32-bit unsigned integer)
	);
	read(TIF, $offset, 4);
	$offset = unpack(uc($endian), $offset);
	seek(TIF, $offset, 0); # set offset
	read(TIF, $ifd, 2); # get number of directory entries
	my $num_dirent = unpack($endian, $ifd); # Make it useful
	$offset += 2;
	$num_dirent = $offset + ($num_dirent * 12); # calc. maximum offset of IFD
	seek(TIF, $offset, 0); # set offset again
	# === search width and height information
	$ifd = '';
	my $tag = 0;
	my $type = 0;
	my $w = undef;
	my $h = undef;
	while ( !defined($w) or !defined($h) )
	{
		read(TIF, $ifd, 12);
		last if ($ifd eq '' or $offset > $num_dirent);
		$offset += 12;
		$tag = unpack($endian, $ifd);
		$type = unpack($endian, substr($ifd, 2, 2));
		next if ($type > @packspec + 0 or !defined($packspec[$type]));
		if ($tag == 0x0100)
		{ # width
			$w = unpack($packspec[$type], substr($ifd, 8, 4));
		}
		elsif ($tag == 0x0101)
		{ # height
			$h = unpack($packspec[$type], substr($ifd, 8, 4));
		}
	}
	close(TIF);
	return($w, $h);
}
sub _get_size_png
{
	# taken from WWWis <http://www.bloodyeck.com/wwwis/>
	my $png = shift;
	my ($head, $a, $b, $c, $d, $e, $f, $g, $h);
	open(PNG,"$png") or return (0,0);
	binmode(PNG);
	if ( read(PNG, $head, 8) == 8 
	  && $head eq "\x89\x50\x4e\x47\x0d\x0a\x1a\x0a" 
	  && read(PNG, $head, 4) == 4 
	  && read(PNG, $head, 4) == 4 
	  && $head eq "IHDR" 
	  && read(PNG, $head, 8) == 8)
	{
		($a,$b,$c,$d,$e,$f,$g,$h) = unpack("C"x8, $head);
	}
	else
	{
		return(0,0);
	}
	close(PNG);
	return($a<<24|$b<<16|$c<<8|$d, $e<<24|$f<<16|$g<<8|$h);
}
sub _get_size_swf
{
	# taken from Image::Size <http://search.cpan.org/~rjray/Image-Size-2.992/Size.pm>
	# copyright (C) 2000 Randy J. Ray
	# Adapted from code sent by Dmitry Dorofeev <dima@yasp.com>
	my $swf = shift;
	my $bin2int = sub { unpack("N", pack("B32", substr("0" x 32 . shift, -32))) };
	my $buffer = undef;
	open(SWF,"$swf") or return(0,0);
	binmode(SWF);
	read(SWF, $buffer, 33);
	my ($w, $h) = (0, 0);
	if ($buffer =~ /^FWS/)
	{
		my $bs = unpack('B133', substr($buffer, 8, 17));
		my $bits = &$bin2int(substr($bs, 0, 5));
		$w = int( &$bin2int(substr($bs, 5 + $bits, $bits)) / 20 );
		$h = int( &$bin2int(substr($bs, 5 + $bits * 3, $bits)) / 20 );
	}
	close(SWF);
	return($w, $h);
}
1;
__END__
