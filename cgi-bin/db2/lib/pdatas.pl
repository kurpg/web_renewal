#----------------------------------+
# ▼ 出力データ成形サブルーチン ▼ +--------------------------------------------
#----------------------------------+
sub pdatas {

	if($name eq ''){ $name = $INI{'noname'}; } # 名前空欄をダミーに
	if($title eq ''){ $title = $INI{'notitle'}; } # タイトル空欄をダミーに

	#----- ホスト名のマスク
	if($INI{'put_usr_info'} == 1){
		if($remote_host =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/){
			$remote_host = "$1\.$2\.$3\.\*";
		}elsif($remote_host =~ /(.*)\.(.*)\.(.*)\.(.*)$/){
			$remote_host = "\*\.$2\.$3\.$4";
		}elsif($remote_host =~ /(.*)\.(.*)\.(.*)$/){
			$remote_host = "\*\.$2\.$3";
		}
	}
	#----- 時刻処理
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
	$year += 1900;
	$mon++;
	if($mon < 10){ $mon = "0$mon"; }
	if($mday < 10){ $mday = "0$mday"; }
	if($hour < 10){ $hour = "0$hour"; }
	if($min < 10){ $min = "0$min"; }
	if($sec < 10){ $sec = "0$sec"; }

	#----- 記事テキスト成形処理
	# 文字色タグ処理
	$txt =~ s/^&lt;font(\s)color=(&quot;|\')?([a-zA-Z]+|\#?[0-9a-fA-F]{6})(&quot;|\')?&gt;\r/<font color="$3">/i;
	# URL自動リンク処理
	$txt =~ s/(s?https?:\/\/([-_\.!~\*'\(a-zA-Z0-9;\/\?:\@&=\+\$,%#]+))/&url_lnk($1)/eg;
	# ダイレクトリンクかリダイレクトか判定
	sub url_lnk {
		my($url) = @_;
		my($lnk);
		if($url !~ /\.(gif|jpg|jpeg|png)$/ || $INI{'image_redirect'} != 1){
			$lnk = "<a href=\"$url\" target=\"_blank\">$url<\/a>";
		}else{
			$lnk = "<a href=\"$INI{'script'}?a=lnk&url=$url\" target=\"_blank\">$url<\/a>";
		}
		return $lnk;
	}

	# 文字色タグ閉じ処理
	if($txt =~ /^<font color=/){
		$txt .= "</font>";
	}
	# 検索エンジン自動リンク
	my $pat = '0-9a-zA-Z\!\#\$\%\'\(\)\=\~\|\-\^\\\-\^\|\@\`\{\;\+\:\*\}\/\?\_\,\.|\x8E\xA1-\xFE\xA1-\xFE|\x8F\xA1-\xFE\xA1-\xFE|\s'; # 検索キーワードマッチ用
	$txt_euc = $txt;
	&jcode'convert(*txt_euc,'euc');
	# google 引用
	while($txt_euc =~ /\[google\:([$pat]+)\]/ && $INI{'google_url'} ne ''){
		$qua = $qua2 = $1;
		&jcode'convert(*qua,'sjis');
		$qua =~ s/(\W)/'%'.unpack("H2", $1)/ego;
		$qua =~ tr/ /+/;
		$txt_euc =~ s/\[google\:([$pat]+)\]/\[Google\:<a href=\"$INI{'google_url'}$qua\" target=\"_blank\">$qua2<\/a>\]/;
	}
	# Yahoo! 引用
	while($txt_euc =~ /\[yahoo\:([$pat]+)\]/ && $INI{'yahoo_url'} ne ''){
		$qua = $qua2 = $1;
		&jcode'convert(*qua,'sjis');
		$qua =~ s/(\W)/'%'.unpack("H2", $1)/ego;
		$qua =~ tr/ /+/;
		$txt_euc =~ s/\[yahoo\:([$pat]+)\]/\[Yahoo\:<a href=\"$INI{'yahoo_url'}$qua\" target=\"_blank\">$qua2<\/a>\]/;
	}
	&jcode'convert(*txt_euc,$INI{'charset_in'});
	$txt = $txt_euc;
	undef($txt_euc);
	# 改行を<br>タグに
	$txt =~ s/\r/<br>/g;

	return;

}

1;




#-------------------------------------------------------------------------------
#               Copyright (c) 2001-CurrentYear bayashi.net. All rights reserved.
#                                                       http://tech.bayashi.net/

