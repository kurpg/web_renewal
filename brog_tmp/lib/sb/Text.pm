# sb::Text - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Text;

use strict;

# ==================================================
# // Module version
# ==================================================
use vars qw( $VERSION @ISA %ESCAPE );
$VERSION = '0.05';
# 0.05 [2009/05/27] added uri_encode_utf8 / uri_decode_utf8 / debase64 / enbase64
# 0.04 [2006/02/04] changed clip and _clip_text_utf8 to clip string correctly
# 0.03 [2005/10/04] changed format to set target attribute correctly
# 0.02 [2005/07/07] added remove_tag as public method / renamed _remove_tag to _remove_tag_fast
# 0.01 [2005/06/06] changed entitize and detitize
# 0.00 [2005/02/17] generated

# --------------------------------------
# // initializer
BEGIN
{
	for (0..255)
	{
		$ESCAPE{chr($_)} = sprintf("%%%02X", $_);
	}
}
# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Language ();
use sb::Plugin ();
# ==================================================
# // declaration for constant value
# ==================================================
sub LINK_ATTRIBUTE  (){ ' target="_blank"' };
sub LINE_BREAK      (){ '<br />' };
sub DEFAULT_CODE    (){ 'euc' };
sub CLIPPING_TAIL   (){ '...' };
sub CLIPPING_LENGTH (){ 200 };
# ==================================================
# // public functions
# ==================================================
sub format { # format text
	my $class = shift;
	my %param = (
		'text'      => '',             # Text
		'form'      => 0,              # Format => 0 : nothing, 1 : auto breaks, 2 : auto breaks and auto link
		'attribute' => LINK_ATTRIBUTE, # The attribute of "a" element for the format "2"
		@_,
	);
	return($param{'text'}) if ($param{'text'} eq '' or $param{'form'} eq '0');
	if ($param{'form'} !~ /^\d$/) {
		my $func = sb::Plugin->load_text_filter($param{'form'});
		my $text = eval{ &$func($param{'text'}); };
		$param{'text'} = ($@) ? $param{'text'} : $text;
	} elsif ($param{'form'} > 0) {
		my $br = LINE_BREAK;
		$param{'text'} =~ s/\n/$br\n/g;
		if ($param{'form'} == 2) {
			my $target = $param{'attribute'};
			$param{'text'} =~ s/s?https?:\/\/[-_.!~*\'()a-zA-Z0-9;\/?:\@&=+\$,%#]+/<a href="$&"$target>$&<\/a>/g;
		}
	}
	return($param{'text'});
}
sub clip { # clip text
	my $class = shift;
	my %param = (
		'text'    => '',              # Text
		'form'    => undef,           # Format
		'length'  => CLIPPING_LENGTH, # Clipping length
		'fromend' => undef,           # Direction
		@_,
	);
	my $tail = CLIPPING_TAIL;
	my $len  = $param{'length'};
	if (defined($param{'form'})) {
		$param{'text'} = $class->format('text'=>$param{'text'},'form'=>$param{'form'});
		$param{'text'} = &_remove_tag_fast($param{'text'});
	}
	$param{'text'} =~ tr/\x0D\x0A//d;
	if ( length($param{'text'}) > $len ) {
		$len -= length($tail);
		return ($param{'fromend'})
			? $tail . &_clip_text($param{'text'},-$len,$len)
			: &_clip_text($param{'text'},0,$len) . $tail;
	}
	return( $param{'text'} );
}
sub entitize { # 文字実体参照への変換処理
	my $class = shift;
	my $text = shift;
	$text =~ s/&/&amp;/g;
	$text =~ s/\"/&quot;/g;
	$text =~ s/</&lt;/g;
	$text =~ s/>/&gt;/g;
	$text =~ s/\{/&#123;/g;
	$text =~ s/\}/&#125;/g;
	return($text);
}
sub detitize { # 文字実体参照からの変換処理
	my $class = shift;
	my $text = shift;
	$text =~ s/&#123;/\{/g;
	$text =~ s/&#125;/\}/g;
	$text =~ s/&gt;/>/g;
	$text =~ s/&lt;/</g;
	$text =~ s/&quot;/\"/g;
	$text =~ s/&amp;/&/g;
	return($text);
}
sub remove_tag { # html タグ除去処理 (不完全)
	# from Perl memo http://www.din.or.jp/%7Eohzaki/perl.htm
	# Copyright (C) 1999-2004 OHZAKI Hiroki
	my $class = shift;
	my %param = (
		'text'  => undef,
		'code'  => DEFAULT_CODE,
		'allow' => undef,
		@_
	);
	return('') if ($param{'text'} eq '');
	my $text = $param{'text'};
	my $tags = $param{'allow'};
	my $output = '';
	my $tmp;
	# templates for regular expression
	my $tag_regex_    = q{[^"'<>]*(?:"[^"]*"[^"'<>]*|'[^']*'[^"'<>]*)*(?:>|(?=<)|$(?!\n))}; #'}
	my $comment_regex = '<!(?:--[^-]*-(?:[^-]+-)*?-(?:[^>-]*(?:-[^>-]+)*?)??)*(?:>|$(?!\n)|--.*$)';
	my $tag_regex     = qq{$comment_regex|<$tag_regex_};
	my $text_regex    = q{[^<]*};
	# converting charcode
	if ($param{'code'} ne DEFAULT_CODE) {
		sb::Language->get->checkcode('',$param{'code'});
		$text = sb::Language->get->convert($text,DEFAULT_CODE);
	}
	# removing tags
	while ($text =~ /($text_regex)($tag_regex)?/gso) {
		last if ($1 eq '' and $2 eq '');
		$output .= $1;
		$tmp = $2;
		if ($tags ne '' and $tmp =~ /^<\/?($tags)(?![0-9A-Za-z])/i) {
			$output .= $tmp;
		}
	}
	# restoring charcode
	if ($param{'code'} ne DEFAULT_CODE) {
		sb::Language->get->checkcode('',DEFAULT_CODE);
		$output = sb::Language->get->convert($output,$param{'code'});
	}
	return($output);
}
sub uri_encode_utf8
{ # ported from URI::Escape
	my $class = shift;
	my $text = shift;
	$text =~ s/([^A-Za-z0-9\-_.!~*\'()])/$ESCAPE{$1} || sprintf("%%%02X",ord($1))/ge;
	return $text;
}
sub uri_decode_utf8
{ # ported from URI::Escape
	my $class = shift;
	my $text = shift;
	$text =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
	return $text;
}
sub enbase64
{
	require 'mimeutil.pl';
	return &mimeutil::bodyencode($_[0],'b64') . &mimeutil::benflush('b64');
}
sub debase64
{
	require 'mimeutil.pl';
	return &mimeutil::bodydecode($_[0],'b64') . &mimeutil::bdeflush('b64');
}
# ==================================================
# // private functions
# ==================================================
sub _remove_tag_fast { # タグ除去簡易処理(高速化のため)
	my $text = shift;
	$text =~ s/<[^>]*>//g; 
	return($text);
}
sub _clip_text {
	my ($text,$st,$len) = @_; # input parameters same as substr
	my $code = sb::Language->get->charcode;
	if ($code eq 'utf8') {
		return &_clip_text_utf8($text,$st,$len);
	} elsif ($code eq 'euc' or $code eq 'sjis' or $code eq 'jis') {
		if ($code ne 'euc') {
			sb::Language->get->checkcode('',$code);
			$text = sb::Language->get->convert($text,'euc');
		}
		$text = &_clip_text_euc($text,$st,$len);
		if ($code ne 'euc') {
			sb::Language->get->checkcode('','euc');
			$text = sb::Language->get->convert($text,$code);
		}
		return($text);
	}
	return substr($text,$st,$len);
}
sub _clip_text_euc {
	# reference : Perl memo http://www.din.or.jp/%7Eohzaki/perl.htm
	my ($text,$st,$len) = @_; # input parameters same as substr
	my $out;                  # output parameter
	if ($st > 0) { # checking the start position
		$out = substr($text,0,$st);
		if    ($out =~ /\x8F$/)                { $st+=2; }
		elsif ($out =~ tr/\x8E\xA1-\xFE// % 2) { $st++; }
	} elsif ($st < 0) {
		$out = substr($text,0,length($text) + $st);
		if    ($out =~ /\x8F$/)                { $st--; }
		elsif ($out =~ tr/\x8E\xA1-\xFE// % 2) { $st++; }
	}
	$out = substr($text,$st,$len);
	if ($st >= 0) { # adjusting length
		if    ($out =~ /\x8F$/)                { $out = substr($text,$st,$len-1); }
		elsif ($out =~ tr/\x8E\xA1-\xFE// % 2) { $out = substr($text,$st,$len+1); }
	}
	return($out);
}
sub _clip_text_utf8 {
	# reference : http://www.akatsukinishisu.net/itazuragaki/id/round_utf-8
	my ($text,$st,$len) = @_; # input parameters same as substr
	my $out;                  # output parameter
	if ($st > 0) { # checking the start position
		$out = substr($text,0,$st);
		ST: {
			$_ = $out;
			/[\x00-\x7F]$/                         , last ST;
			/[\xC0-\xFD]$/               and $st-- , last ST;
			/[\xE0-\xFD][\x80-\xBF]$/    and $st-=2, last ST;
			/[\xF0-\xFD][\x80-\xBF]{2}$/ and $st-=3, last ST;
		}
		$st = 0 if ($st < 0);
	}
	{ # adjusting length
		$out = substr($text,$st,$len);
		if ($st < 0 and $out !~ /^([\x00-\x7F]|[\xC0-\xFD])/) {
			$out =~ s/^[\x80-\xBF]{1,4}//;
		} elsif ($out !~ /[\x00-\x7F]$/) {
			$out =~ s/[\xC0-\xFD]$//;
			$out =~ s/[\xE0-\xFD][\x80-\xBF]$//;
			$out =~ s/[\xF0-\xFD][\x80-\xBF]{2}$//;
		}
	}
	return($out);
}
1;
__END__
