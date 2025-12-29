#                                                                     +--------+
#  ユーザエージェント解析ライブラリ                                   | jua.pl |
#---------------------------------------------------------------------+--------+

#-------------------------------------------------------------------------------
# ユーザエージェント値を解析して、ブラウザ名やバージョン等を返します。
# 著名ブラウザをはじめ、携帯端末やロボット、リンクチェッカ、プリフェッチャ類まで
# 判別可能です。このライブラリの文字コードと判別する際のユーザエージェント値は
# 統一した方が良いです
#-------------------------------------------------------------------------------

#;----- 使用方法 ---------------------------------------------------------------
# require "設置パス/jua.pl";
# %jua = &jua($ENV{'HTTP_USER_AGENT'});
#        ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#;----- %juaに以下の内容が返ってきます
#; $jua{'agent_name'} = 'ブラウザ名';
#; $jua{'agent_version'} = 'ブラウザのバージョン';
#; $jua{'platform'} = 'プラットフォーム(OS･機種･ロボットならHTTP_ROBOT)';
#; $jua{'language'} = '使用言語';
#; $jua{'hua'} = '受け渡されたままのエージェント値';
#; 特定できない場合は---が返ってきます。
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# $version = 'v1.4.4';
# v1.0.0Beta とりあえず公開。
# v1.0.0 一応動作確認バージョン。オリジナルのユーザエージェント値も返すようにした
# v1.1.0 Opera6対応。IEやMozilla互換ブラウザが判定できないアルゴリズムを修整(^_^;)
# v1.2.0 判定スピードと判定精度アップ
# v1.2.1 NT関係がうまく判定できていなかったバグの修正
# v1.3.1 タブブラウザの一部デフォルト設定名への対応と精度＆スピードUP
# v1.3.2 プリフェッチャ＆リンクチェッカ類の名称を「先読み更新チェッカ」に変更
# v1.4.2 全体的に処理速度と精度の見直し実施
# v1.4.3 Sleipnirを判別
# v1.4.4 CacheFlowプロクシに対応
# v1.4.5 Mac OS X 対応
# v1.4.6 Teleport Pro対応
#-------------------------------------------------------------------------------




#----- メインルーチン ----------------------------------------------------------
sub jua {

	my($HUA) = @_;
	my(@ua,%jua,@ns);

	$jua{'hua'} = $HUA;
	@ua = split(/\//,$HUA); # @uaに/でデータを区分ける

#----- Opera6以降
	if($HUA =~ /\)\sOpera\s([\d+\.?]+)/){
		$jua{'agent_name'} = 'Opera';
		$jua{'agent_version'} = $1;
		$jua{'platform'} = &platform($HUA);
		if($HUA =~ /Opera.*\[([a-zA-Z0-9\_\-\/\s]*)\]/){ $jua{'language'} = $1; }
		%jua = &null(%jua);
		return %jua;
	}


#----- Opera(6より前)/OmniWeb/HotJava/Lynx 
	if($HUA =~ /^(OmniWeb|HotJava|Lynx|w3m|Opera)\/([a-zA-Z0-9\.\-\_\;]*)[\s|\/]?/){
		$jua{'agent_name'} = $1;
		$jua{'agent_version'} = $2;
		$jua{'platform'} = &platform($HUA);
		if($HUA =~ /\[([a-zA-Z0-9\_\-\/\s]*)\]/){ $jua{'language'} = $1; }
		%jua = &null(%jua);
		return %jua;
	}


#----- Sleipnir
	if($HUA =~ /^Sleipnir/){
		$jua{'agent_name'} = 'Sleipnir';
		%jua = &null(%jua);
		return %jua;
	}


#----- Cuam
	if($HUA =~ /^Cuam\sVer(([\d+\.?]+)\w\w)$/){
		$jua{'agent_name'} = 'Cuam';
		$jua{'agent_version'} = $1;
		%jua = &null(%jua);
		return %jua;
	}


#----- iCab
	if($HUA =~ /iCab\s?J?\/?([\d+\.?]+)/){
		$jua{'agent_name'} = 'iCab';
		$jua{'agent_version'} = $1;
		$jua{'platform'} = &platform($HUA);
		%jua = &null(%jua);
		return %jua;
	}


#----- BugBrowser
	if($HUA =~ /^BugBrowser$/){
		$jua{'agent_name'} = 'BugBrowser';
		%jua = &null(%jua);
		return %jua;
	}


#----- Donut
	if($HUA =~ /Donut/){
		$HUA =~ /Donut(\sP|Rapt|L)?\s?V?e?r?\/?([\d+\.?]+)?/;
		$jua{'agent_name'} = "Donut";
		$jua{'agent_version'} = "$1 $2";
		%jua = &null(%jua);
		return %jua;
	}


#----- Lunascape
	if($HUA =~ /Lunascape\s(([\d+\.?]+)\w)/){
		$jua{'agent_name'} = 'Lunascape';
		$jua{'agent_version'} = $1;
		$jua{'platform'} = &platform($HUA);
		%jua = &null(%jua);
		return %jua;
	}


#----- Lite
	if($HUA =~ /^Lite\s([\d+\.\d+]+\w*)/){
		$jua{'agent_name'} = "Lite";
		$jua{'agent_version'} = $1;
		$jua{'platform'} = &platform($HUA);
		%jua = &null(%jua);
		return %jua;
	}


#----- Internet Ninja
	if($HUA =~ /^(Internet\sNinja)\s([\d+\.\d+]+\w*)/){
		$jua{'agent_name'} = $1;
		$jua{'agent_version'} = $2;
		$jua{'platform'} = '---';
		%jua = &null(%jua);
		return %jua;
	}


#----- SHARP製品
	if($HUA =~ /^(sharp(\s)(.*)(\s)browser\/)/){
		$jua{'agent_name'} = $ua[0];
		if($ua[1] =~ /^(\d)\.(\d)/){ $jua{'agent_version'} = "$1\.$2"; }
		if($HUA =~ /AVE-Front/){ $jua{'platform'} = "AVE-Front" }elsif($HUA =~ /\(([a-zA-Z0-9\-\_\/\.\s]+)\)/){ $jua{'platform'} = $1; }else{ $jua{'platform'} = $ua[0]; }
		if($ua[1] =~ /\[([a-zA-Z0-9_-\s]+)\]/){ $jua{'language'} = "$1"; }
		%jua = &null(%jua);
		return %jua;
	}


#----- WebTV
	if($HUA =~ /WebTV\/([\d+\.?]+)/){
		$jua{'agent_name'} = 'WebTV';
		$jua{'agent_version'} = $1;
		$jua{'platform'} = &platform($HUA);
		%jua = &null(%jua);
		return %jua;
	}


#----- L-mode
	if($HUA =~ /^L-mode\/\//){
		$jua{'agent_name'} = $ua[0];
		$jua{'agent_version'} = $ua[2];
		%jua = &null(%jua);
		return %jua;
	}


#----- DreamCast
	if($HUA =~ /\(DreamPassport\/([\d+\.?]+)/){
		$jua{'agent_name'} = "DreamPassport";
		$jua{'agent_version'} = "$1";
		$jua{'platform'} = "DreamCast";
		%jua = &null(%jua);
		return %jua;
	}


#----- AVE-Front
	if($HUA =~ /AVE-Front\/([\d+\.?]+)/){
		$jua{'agent_name'} = "AVE-Front";
		$jua{'agent_version'} = "$1";
		if($HUA =~ /Product\=([a-zA-Z0-9\.\-\/\_\s]+)\;/){ $jua{'platform'} = $1; }else{ $jua{'platform'} = &platform($HUA); }
		if($HUA =~ /Language\=([a-zA-Z0-9\.\-\/\_\s]+)\;/){ $jua{'language'} = $1; }
		%jua = &null(%jua);
		return %jua;
	}


#----- NetFront
	if($HUA =~ /lla\/\d*\.\d*\sNF\/([\d+\.?]+)\s\(/){
		$jua{'agent_name'} = "NetFront";
		$jua{'agent_version'} = "$1";
		if($HUA =~ /Product\=([a-zA-Z0-9\.\-\/\_\s]+)\;/){ $jua{'platform'} = $1; }else{ $jua{'platform'} = &platform($HUA); }
		if($HUA =~ /Language=([a-zA-Z0-9\.\-\/\_\s]+)\;/){ $jua{'language'} = $1; }
		%jua = &null(%jua);
		return %jua;
	}


#----- i-mode & FOMA
	if($HUA =~ /^(DoCoMo)\/([\d+\.?]+)(\/|\xA1\xA1|\x81\x40)([a-zA-Z0-9]+)/ && $HUA !~ /\(Google/){
		$jua{'agent_name'} = "$1";
		$jua{'agent_version'} = "$2";
		$jua{'platform'} = $4;
		%jua = &null(%jua);
		return %jua;
	}


#----- 携帯 i-mode 以外
if($HUA =~ /(J-PHONE|UP.Browser|PDXGW|ASTEL)\// && $HUA !~ /\(Google/){
	$jua{'agent_name'} = $1;
	if($ua[1] =~ /^([\d+\.?]+)/){ $jua{'agent_version'} = "$1"; }
	if($ua[0] =~ /J-PHONE|ASTEL/){
		$jua{'platform'} = $ua[2]; }
	elsif($ua[0] =~ /^UP.Browser/){
		if($ua[1] =~ /([a-zA-Z0-9\.\/\_]+)\sUP\./){ $jua{'platform'} = $1; }
	}elsif($ua[0] =~ /^KDDI\-([a-zA-Z0-9\.\-\/\_]+)/){
		$jua{'platform'} = $1;
	}else{
		if($ua[1] =~ /(\([a-zA-Z0-9\=\;]+\))/){ $jua{'platform'} = $1; }
	}
	%jua = &null(%jua);
	return %jua;
}




#----- ロボット
	if($HUA =~ /(Googlebot|Lycos\_Spider|Slurp.so\/Goo|Slurp|moget|InfoNaviRobot|InfoSeek\sSidewinder|FAST-WebCrawler|ArchitextSpider|Scooter|suke|iYappo|Mercator|Robot\/www\.pj\-search\.com|SlySearch|gazz|Openfind\sdata\sgatherer)[\-\/\s]?(([\d+\.?]+)\w*)?[\/\s]?/){
		$jua{'agent_name'} = $1;
		if($1 ne 'Slurp'){ $jua{'agent_version'} = $2; }
		if($1 eq 'InfoNaviRobot' && $HUA =~ /\((F\d+)\)/){ $jua{'agent_version'} = $1; }
		$jua{'platform'} = '検索ロボット';
		%jua = &null(%jua);
		return %jua;
	}


#----- プリフェッチャ＆リンクチェッカなど
	if($HUA =~ /(WWWcp|WWWC|Pockey|Wget|WebFetch|FaEdit|PerMan\sSurfer|WebAuto|MSIECrawler|Asahina-Antenna|PageDown|WebAuto|http_get|Teleport\sPro)[\/\s]?([\d+\.?]+\w+)?/){
		$jua{'agent_name'} = $1;
		if($1 eq 'Pockey'){ $jua{'agent_name'} = "Pockey(GetHTMLW)"; }
		$jua{'agent_version'} = $2;
		$jua{'platform'} = &platform($HUA);
		if($jua{'platform'} eq '---'){ $jua{'platform'} = 'DL先読み更新チェッカ'; }
		%jua = &null(%jua);
		return %jua;
	}


#----- Google CHTML ゲートウェイ？！
	if($HUA =~ /(Google\s[a-zA-Z0-9]+\sProxy)\/([\d+\.?]+)/){
		$jua{'agent_name'} = $1;
		$jua{'agent_version'} = $2;
		$jua{'platform'} = 'ゲートウェイ';
		%jua = &null(%jua);
		return %jua;
	}


#----- CacheFlowプロクシ
	if($HUA eq 'Mozilla/3.01 (compatible;)' || $HUA =~ /CacheFlow\/([\d+\.?]+)/){
		$jua{'agent_name'} = 'CacheFlowプロクシ';
		$jua{'agent_version'} = $1;
		%jua = &null(%jua);
		return %jua;
	}


#----- Mozilla compatible
	if($HUA =~ /^Mozilla\/\d*\.\d*\s\(compatible\;\s(OmniWeb|MSIE)[\s|\/]([\d*\.]*)\d*\;/){
		$jua{'agent_name'} = $1;if($jua{'agent_name'} =~ /iCab/){ $jua{'agent_name'} = 'iCab'; }
		$jua{'agent_version'} = $2;
		$jua{'platform'} = &platform($HUA);
		%jua = &null(%jua);
		return %jua;
	}


#----- Netscape 6
	if($HUA =~ /\sGecko\/([0-9a-zA-Z]*)/ && $HUA !~ /Galeon\//){
		$jua{'agent_name'} = "Netscape";
		if($HUA =~ /Netscape(\d*)\/(([\d*\.]*)\d)/){ $jua{'agent_version'} = $2; }else{ $jua{'agent_version'} = 6; }
		$jua{'platform'} = &platform($HUA);
		$HUA =~ /\s\((.*)\)\s/;
		@ns = split(/\;/,$1);
		$ns[3] =~ /\s([a-zA-Z0-9\-]+)/;
		$jua{'language'} = $1;
		%jua = &null(%jua);
		return %jua;
	}


#----- NN NC
	if($HUA =~ /Mozilla\/([\d+\.?]+)([a-zA-Z0-9]+)?\s\[?([\w-_]*)?\]?\s?\((.*)\)/ && $HUA !~ /compatible\;/){
		$jua{'agent_name'} = "Netscape";
		$jua{'agent_version'} = $1;
		$jua{'platform'} = &platform($HUA);
		$jua{'language'} = $3;
		%jua = &null(%jua);
		return %jua;
	}


#----- Linux版 NN NC
	if($HUA =~ /Mozilla\// && $HUA =~ /X11\;/){
		$jua{'agent_name'} = "Netscape";
		if($HUA =~ /Mozilla\/([\d+\.?]+)/){ $jua{'agent_version'} = $1; }
		$jua{'platform'} = &platform($HUA);
		if($HUA =~ /\[([a-zA-Z0-9\.\-\/\_]+)\]/){ $jua{'language'} = $1; }
		%jua = &null(%jua);
		return %jua;
	}


#----- Mozilla compatible;
	if($HUA =~ /^Mozilla\/([\d+\.?]+)/ && $HUA =~ /compatible\;/){
		$jua{'agent_name'} = "Mozilla compatible";
		$jua{'agent_version'} = $1;
		$jua{'platform'} = &platform($HUA);
		if($HUA =~ /\[([a-zA-Z0-9\.\-\/\_]+)\]/){ $jua{'language'} = $1; }
		%jua = &null(%jua);
		return %jua;
	}


#----- Proxomitron
	if($HUA =~ /^Space\s?Bison\/([\d+\.?]+)(.*)/){
		$jua{'agent_name'} = "Proxomitron";
		$jua{'agent_version'} = $1;
		if($HUA =~ /\[([a-zA-Z0-9\.\-\/\_]+)\]/){ $jua{'language'} = $1; }
		%jua = &null(%jua);
		return %jua;
	}


#----- その他エージェント名のみ抽出
#      (バージョンはほとんど当てにならないので判別しない方針(・ε・) )
$jua{'agent_name'} = $ua[0];
if($HUA =~ /\[([a-zA-Z0-9_-\s]+)\]/){ $jua{'language'} = $1; }
%jua = &null(%jua);

return %jua;





# platform sub -----------------------------------------------------------------
	sub platform {
		my($hua,$platform,$a) = @_;
		if($hua =~ /Win(dows)? ?98/i){ $platform = 'Windows98'; }
			elsif($hua =~ /Win(dows)? ?9x/i){ $platform = 'WindowsME'; }
			elsif($hua =~ /Win(dows)? ?95/i){ $platform = 'Windows95'; }
			elsif($hua =~ /Win(dows)? ?CE/i){ $platform = 'WindowsCE'; }
			elsif($hua =~ /Win(dows)? ?3/i){ $platform = 'Windows3.1'; }
			elsif($hua =~ /(w|W)ind?o?w?s? ?NT ?([\d+\.\d+\w+]+)?/i){
				$a = $2;
				if($a =~ /4\.(\d*)/){ $platform = "WindowsNT"; }
					elsif($a =~ /5\.1/){ $platform = "WindowsXP"; }
					elsif($a =~ /5\.?0?/){ $platform = "Windows2000"; }
					elsif($a =~ /6\.(\d*)/){ $platform = "WindowsNT$a"; }
					else{ $platform = "WindowsNT"; }
			}
			elsif($hua =~ /Windows\s?([\w\d]+)/i){ $platform = "Windows$1"; }
			elsif($hua =~ /Win32/i || $hua =~ /Win(dows)?/i){ $platform = 'Windows'; }

			elsif($hua =~ /Mac_68000/i){ $platform = 'Mac68K'; }
			elsif($hua =~ /Mac_PowerPC/i){ $platform = 'MacPowerPC'; }
			elsif($hua =~ /Mac\sOS\sX/i){ $platform = 'Mac OS X'; }
			elsif($hua =~ /Mac/i){ $platform = 'MacOS'; }

			elsif($hua =~ /SunOS/i){ $platform = 'SunOS'; }
			elsif($hua =~ /Linux/i){ $platform = 'Linux'; }
			elsif($hua =~ /FreeBSD/i){ $platform = 'FreeBSD'; }
			elsif($hua =~ /NetBSD/i){ $platform = 'NetBSD'; }
			elsif($hua =~ /(AIX|IRIX|HP-UX|OSF1|X11|BSD)/i){ $platform = "UNIX($1)"; }
			else{ $platform = '---';
		}
		return $platform;
	}


# null sub -----------------------------------------------------------------
sub null {
	my(%jua) = @_;
	if($jua{'agent_name'} eq ''){ $jua{'agent_name'} = '---'; }
	if($jua{'agent_version'} eq ''){ $jua{'agent_version'} = '---'; }
	if($jua{'platform'} eq ''){ $jua{'platform'} = '---'; }
	if($jua{'language'} eq ''){ $jua{'language'} = '---'; }
	if($jua{'hua'} eq ''){ $jua{'hua'} = '---'; }
	return %jua;
}

#-------------------------------------------------------------------------------


} # close jua

1;



#-------------------------------------------------------------------------------
#               Copyright (c) 2001-CurrentYear bayashi.net. All rights reserved.
#                                                       http://tech.bayashi.net/

