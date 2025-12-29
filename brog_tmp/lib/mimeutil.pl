package mimeutil;

# Copyright (C) 1993-94,1997 Noboru Ikuta <noboru@ikuta.ichihara.chiba.jp>
# ============================== Modified by Takuya Otani@SimpleBoxes 2004
#
# mimer.pl: MIME decoder library Ver.2.02 (1997/12/30)
# mimew.pl: MIME encoder library Ver.2.02 (1997/12/30)

# オリジナルの配布条件 ================================================
# 配布条件 : 著作権は放棄しませんが、配布・改変は自由とします。改変して
#            配布する場合は、オリジナルと異なることを明記し、オリジナル
#            のバージョンナンバーに改変版バージョンナンバーを付加した形
#            例えば Ver.2.02-XXXXX のようなバージョンナンバーを付けて下
#            さい。なお、Copyright表示は変更しないでください。
# =====================================================================
{
	my $aVersion_ = 0.01;
	# ベースバージョン
	# $mime_version = '2.02';
	# ver 0.00 [2004/09/10] 作成
	# ver 0.01 [2004/09/12] mimeencode のバグ修正
}
# <!-- パラメータ - from mimer.pl -->
%code = (
"A", "000000",  "B", "000001",  "C", "000010",  "D", "000011",
"E", "000100",  "F", "000101",  "G", "000110",  "H", "000111",
"I", "001000",  "J", "001001",  "K", "001010",  "L", "001011",
"M", "001100",  "N", "001101",  "O", "001110",  "P", "001111",
"Q", "010000",  "R", "010001",  "S", "010010",  "T", "010011",
"U", "010100",  "V", "010101",  "W", "010110",  "X", "010111",
"Y", "011000",  "Z", "011001",  "a", "011010",  "b", "011011",
"c", "011100",  "d", "011101",  "e", "011110",  "f", "011111",
"g", "100000",  "h", "100001",  "i", "100010",  "j", "100011",
"k", "100100",  "l", "100101",  "m", "100110",  "n", "100111",
"o", "101000",  "p", "101001",  "q", "101010",  "r", "101011",
"s", "101100",  "t", "101101",  "u", "101110",  "v", "101111",
"w", "110000",  "x", "110001",  "y", "110010",  "z", "110011",
"0", "110100",  "1", "110101",  "2", "110110",  "3", "110111",
"4", "111000",  "5", "111001",  "6", "111010",  "7", "111011",
"8", "111100",  "9", "111101",  "+", "111110",  "/", "111111",
);
$match_ascii = '\x1b\([BHJ]([\t\x20-\x7e]*)';
$match_jis = '\x1b\$[@B](([\x21-\x7e]{2})*)';
$match_mime = '=\?[Ii][Ss][Oo]-2022-[Jj][Pp]\?[Bb]\?([A-Za-z0-9\+\/]+)=*\?=';
$match_sjis = '([\x81-\x9f\xe0-\xfc][\x40-\x7e\x80-\xfc])+';
$match_euc  = '([\xa1-\xfe]{2})+';
$bdebuf = "";

# <!-- パラメータ - from mimew.pl -->
$often_use_kanji = 'EUC'; # or 'SJIS'
$jis_in  = "\x1b\$B"; # ESC-$-B ( or ESC-$-@ )
$jis_out = "\x1b\(B"; # ESC-(-B ( or ESC-(-J )
%mime = (
"000000", "A",  "000001", "B",  "000010", "C",  "000011", "D",
"000100", "E",  "000101", "F",  "000110", "G",  "000111", "H",
"001000", "I",  "001001", "J",  "001010", "K",  "001011", "L",
"001100", "M",  "001101", "N",  "001110", "O",  "001111", "P",
"010000", "Q",  "010001", "R",  "010010", "S",  "010011", "T",
"010100", "U",  "010101", "V",  "010110", "W",  "010111", "X",
"011000", "Y",  "011001", "Z",  "011010", "a",  "011011", "b",
"011100", "c",  "011101", "d",  "011110", "e",  "011111", "f",
"100000", "g",  "100001", "h",  "100010", "i",  "100011", "j",
"100100", "k",  "100101", "l",  "100110", "m",  "100111", "n",
"101000", "o",  "101001", "p",  "101010", "q",  "101011", "r",
"101100", "s",  "101101", "t",  "101110", "u",  "101111", "v",
"110000", "w",  "110001", "x",  "110010", "y",  "110011", "z",
"110100", "0",  "110101", "1",  "110110", "2",  "110111", "3",
"111000", "4",  "111001", "5",  "111010", "6",  "111011", "7",
"111100", "8",  "111101", "9",  "111110", "+",  "111111", "/",
);
%mimelen = (
 8,30, 10,34, 12,34, 14,38, 16,42,
18,42, 20,46, 22,50, 24,50, 26,54,
28,58, 30,58, 32,62, 34,66, 36,66,
38,70, 40,74, 42,74,
);
$limit=74;    # ＊注意＊ $limitを75より大きい数字に設定してはいけない。
$foldcol=72;  # ＊注意＊ $foldcolは76以下の4の倍数に設定すること。
$qfoldcol=75; # ＊注意＊ $foldcolは76以下に設定すること。
@zero = ( "", "00000", "0000", "000", "00", "0" );
@pad  = ( "", "===",   "==",   "=" );
$mime_head = '=?ISO-2022-JP?B?';
$mime_tail = '?=';
$benbuf = "";
$bensize = int($foldcol/4)*3;

# <!-- サブルーチン - from mimer.pl -->
sub mimedecode {
	local($_, $kout) = @_;
	1 while s/($match_mime)[ \t]*\n?[ \t]+($match_mime)/$1$3/o;
	s/$match_mime/&kconv(&base64decode($1))/geo;
	s/(\x1b[\$\(][BHJ@])+/$1/g;
	1 while s/(\x1b\$[B@][\x21-\x7e]+)\x1b\$[B@]/$1/;
	1 while s/(\x1b\([BHJ][\t\x20-\x7e]+)\x1b\([BHJ]/$1/;
	s/^([\t\x20-\x7e]*)\x1b\([BHJ]/$1/;
	$_;
}
sub bodydecode {
	local($_, $coding) = @_;
	if (!defined($coding) || $coding eq "" || $coding eq "b64") {
		s/[^A-Za-z0-9\+\/\=]//g;
		$_ = $bdebuf . $_;
		local($cut) = int((length)/4)*4;
		$bdebuf = substr($_, $cut+$[);
		$_ = substr($_, $[, $cut);
		&base64decode($_);
	} elsif ($coding eq "qp") {
		&qpdecode($_);
	}
}
sub bdeflush {
	local($coding) = @_;
	local($ret) = "";
	if ((!defined($coding) || $coding eq "" || $coding eq "b64") && $bdebuf ne "") {
		$ret = &base64decode($bdebuf);
		$bdebuf = "";
	}
	$ret;
}
sub base64decode {
	local($bin) = @_;
	$bin = join('', @code{split(//, $bin)});
	$bin = pack("B".(length($bin)>>3<<3), $bin);
}
sub qpdecode {
	local($qptxt) = @_;
	$qptxt =~ s/=\r\n//g;
	$qptxt =~ s/=\n//g;
	$qptxt =~ s/=\r//g;
	if ($qptxt =~ /=[^0-9A-Za-z]/) {
		print STDERR "[MIME::qpdecode] Illegal '=' character exists.\n";
	}
	$qptxt =~ s/=([0-9A-Fa-f]{2})/pack("C",hex($1))/ge;
	$qptxt;
}
sub kconv {
	local($_) = @_;
	if ($kout eq "EUC") {
		s/$match_jis/&j2e($1)/geo;
		s/$match_ascii/$1/go;
	} elsif ($kout eq "SJIS") {
		s/$match_jis/&j2s($1)/geo;
		s/$match_ascii/$1/go;
	}
	$_;
}
sub j2e {
	local($_) = @_;
	tr/\x21-\x7e/\xa1-\xfe/;  # for original perl (or jperl -Llatin)
	$_;
}
sub j2s {
	local($string);
	local(@ch) = split(//, $_[0]);
	while (($j1,$j2) = unpack("CC", shift(@ch).shift(@ch))) {
		if ($j1 % 2) {
			$j1 = ($j1>>1) + ($j1 >= 0x5f ? 0xb1 : 0x71);
			$j2 += ($j2 > 0x5f ? 0x20 : 0x1f);
		} else {
			$j1 = ($j1>>1) + ($j1 > 0x5f ? 0xb0 : 0x70);
			$j2 += 0x7e;
		}
		$string .= pack("CC", $j1, $j2);
	}
	$string;
}

# <!-- サブルーチン - from mimew.pl -->
sub mimeencode {
	local($_) = @_;
	s/$match_jis/$jis_in$1/go;
	s/$match_ascii/$jis_out$1/go;
	$kanji = &checkkanji;
	s/$match_sjis/&s2j($&)/geo if ($kanji eq 'SJIS');
	s/$match_euc/&e2j($&)/geo if ($kanji eq 'EUC');
	s/(\x1b[\$\(][BHJ@])+/$1/g;
	1 while s/(\x1b\$[B@][\x21-\x7e]+)\x1b\$[B@]/$1/;
	1 while s/$match_jis/&mimeencode_inline($&,$`,$')/eo; #'
	s/$match_ascii/$1/go;
	$_;
}
sub bodyencode {
	local($_,$coding) = @_;
	if (!defined($coding) || $coding eq "" || $coding eq "b64") {
		$_ = $benbuf . $_;
		local($cut) = int((length)/$bensize)*$bensize;
		$benbuf = substr($_, $cut+$[);
		$_ = substr($_, $[, $cut);
		$_ = &base64encode($_);
		s/.{$foldcol}/$&\n/g;
    } elsif ($coding eq "qp") {
		$_ = $benbuf . $_;
		s/\r\n/\n/g;
		s/\r/\n/g;
		@line = split(/\n/,$_,-1);
		$benbuf = pop(@line);
		local($result) = "";
		foreach (@line) {
			$_ = &qpencode($_);
			$result .= $_ . "\n";
		}
		$_ = $result;
	}
	$_;
}
sub benflush {
	local($coding) = @_;
	local($ret) = "";
	if ((!defined($coding) || $coding eq "" || $coding eq "b64") && $benbuf ne "") {
		$ret = &base64encode($benbuf) . "\n";
		$benbuf = "";
	} elsif ($coding eq "qp" && $benbuf ne "") {
		$ret = &qpencode($benbuf) . "\n";
		$benbuf = "";
	}
	$ret;
}
sub mimeencode_inline {
	local($_, $befor, $after) = @_;
	local($back, $forw, $blen, $len, $flen, $str);
	$befor = substr($befor, rindex($befor, "\n")+1);
	$after = substr($after, 0, index($after, "\n")-$[);
	$back = " " unless ($befor eq "" || $befor =~ /[ \t\(]$/);
	$forw = " " unless ($after =~ /^\x1b\([BHJ]$/ || $after =~ /^\x1b\([BHJ][ \t\)]/);
	$blen = length($befor);
	$flen = length($forw)+length($&)-3 if ($after =~ /^$match_ascii/o);
	$len = length($_);
	return "" if ($len <= 3);
	if ($len > 39 || $blen + $mimelen{$len+3} > $limit) {
		if ($limit-$blen < 30) {
			$len = 0;
		} else {
			$len = int(($limit-$blen-26)/4)*2+3;
		}
		if ($len >= 5) {
			$str = substr($_, 0, $len).$jis_out;
			$str = &base64encode($str);
			$str = $mime_head.$str.$mime_tail;
			$back.$str."\n ".$jis_in.substr($_, $len);
		} else {
			"\n ".$_;
		}
	} else {
		$_ .= $jis_out;
		$_ = &base64encode($_);
		$_ = $back.$mime_head.$_.$mime_tail;
		if ($blen + (length) + $flen > $limit) {
			$_."\n ";
		} else {
			$_.$forw;
		}
	}
}
sub base64encode {
	local($_) = @_;
	$_ = unpack("B".((length)<<3), $_);
	$_ .= $zero[(length)%6];
	s/.{6}/$mime{$&}/go;
	$_.$pad[(length)%4];
}
sub qpencode {
	local($_) = @_;
	s/=/=3D/g;
	s/\t$/=09/;
	s/ $/=20/;
	s/([^!-~ \t])/&qphex($1)/ge;
	local($folded, $line) = "";
	while (length($_) > $qfoldcol) {
		$line = substr($_, 0, $qfoldcol-1);
		if ($line =~ /=$/) {
			$line = substr($_, 0, $qfoldcol-2);
			$_ = substr($_, $qfoldcol-2);
		} elsif ($line =~ /=[0-9A-Fa-f]$/) {
			$line = substr($_, 0, $qfoldcol-3);
			$_ = substr($_, $qfoldcol-3);
		} else {
			$_ = substr($_, $qfoldcol-1);
		}
		$folded .= $line . "=\n";
	}
	$folded . $_;
}
sub qphex {
	local($_) = @_;
	$_ = '=' . unpack("H2", $_);
	tr/a-f/A-F/;
	$_;
}
sub checkkanji {
	local($sjis,$euc);
	$sjis += length($&) while (/$match_sjis/go);
	$euc  += length($&) while (/$match_euc/go);
	return 'NONE' if ($sjis == 0 && $euc == 0);
	return 'SJIS' if ($sjis > $euc);
	return 'EUC'  if ($sjis < $euc);
	$often_use_kanji;
}
sub e2j {
	local($_) = @_;
	tr/\xa1-\xfe/\x21-\x7e/;
	$jis_in.$_.$jis_out;
}
sub s2j {
	local($string);
	local(@ch) = split(//, $_[0]);
	while (($j1,$j2)=unpack("CC",shift(@ch).shift(@ch))) {
		if ($j2 > 0x9e) {
			$j1 = (($j1>0x9f ? $j1-0xb1 : $j1-0x71)<<1)+2;
			$j2 -= 0x7e;
		} else {
			$j1 = (($j1>0x9f ? $j1-0xb1 : $j1-0x71)<<1)+1;
			$j2 -= ($j2>0x7e ? 0x20 : 0x1f);
		}
		$string .= pack("CC", $j1, $j2);
	}
	$jis_in.$string.$jis_out;
}
1;
