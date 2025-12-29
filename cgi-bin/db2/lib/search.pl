#----------------------------+
# ▼ 検索処理サブルーチン ▼ +--------------------------------------------------
#----------------------------+
sub search {

	#----- 変数の局所化宣言
	my($start,$end,$i,$pat,$qua2);

	#----- キーワードが空ならエラー出力
	if($FORM{'search'} eq ''){ &error('検索キーワードが空です'); }

	&http_header(); # HTTPヘッダ出力
	&html_header(); # HTMLヘッダ部分出力

	#----- ログファイルが存在しなければ投稿募集して戻る
	if(!-e $INI{'log_file'} || -z $INI{'log_file'}){ print "<center><b>投稿記事募集中です。<b></center>"; return; }

	#----- 記事の表示
	$start = $FORM{'pg'} * $INI{'put_kiji_page'} + 1; # 表示開始記事番号
	$end = $FORM{'pg'} * $INI{'put_kiji_page'} + $INI{'put_kiji_page'}; # 表示終了記事番号
	#----- ログファイルから読み込み
	open(LOG,"<$INI{'log_file'}") || &error('ファイルオープンエラー','記事ファイルが開けません。');
	#----- 総記事数取得
	$kiji = 0;
	$kiji++ while (<LOG>);
	seek(LOG,0,0);

	#----- ページ処理
	&page_ctrl();

	#----- 表示ループ開始
	print "<center>";

	#----- 検索処理準備
	$keyword = $FORM{'search'};
	$keyword =~ s/　/ /g;
	$keyword =~ s/^ +//;
	$keyword =~ s/  +/ /g;
	$keyword =~ s/ +$//;
	&jcode'convert(*keyword,'euc');
	@keywords = split(/ /,$keyword);
	if($FORM{'soption'} < 0 || $FORM{'soption'} > 2){ $FORM{'soption'} = 0; }
	$i = 0;
	foreach $search_log (<LOG>){
		&jcode'convert(*search_log,'euc');
		if(&match($search_log,$FORM{'soption'},@keywords) == 1){
			$i++;
			#----- 表示範囲内か判定
			if($i >= $start && $i <= $end){
				# 記事データの分解
				&jcode'convert(*search_log,$INI{'charset_in'});
				($time,$name,$remote_host,$http_user_agent,$rmkey,$title,$txt) = split(/\t/,$search_log);
				&pdatas();

				#----- 記事表示
				print <<"_HTML_";
<form action="$INI{'script'}?a=rm" method=POST onSubmit="return send_check()">
<table border=1 bordercolor="$INI{'color_table_border'}" cellspacing=0 cellpadding=0 width=80%>
<tr><td align="center">
	<table border=0 bgcolor="$INI{'color_title_back'}" cellpadding=4 cellspacing=0 width=100%>
	<tr><td style="$INI{'style_txt_title'}">■ $title </td></tr>
	<tr><td bgcolor="$INI{'color_ui_back'}">
<span style="$INI{'style_txt_namae'}">名前：</span><span style="$INI{'style_txt_name'}">$name </span>　<span style="$INI{'style_txt_nichiji'}">日時：</span><span style="$INI{'style_txt_time'}">$year/$mon/$mday $hour:$min:$sec</span>
_HTML_

				if($INI{'put_usr_info'} == 1){
					print <<"_HTML_";
　<span style="font-size: 8pt;">
[ $remote_host : $http_user_agent ]
</span>
_HTML_
				}

				print <<"_HTML_";
	</td></tr>
	</table>
	<table border=0 cellpadding=4 cellspacing=0 width=90%>
	<tr><td style="font-size: 11pt;">$txt</td></tr>
	</table>
</td></tr>
</table>
<p>
_HTML_

			}elsif($i > $end){ last; } # 範囲外なのでループ脱出
		}
	}
		close(LOG);

		print "</center>";

		&page_ctrl();

	return;

}



#----------------------------------+
# ▼ 検索マッチ判定サブルーチン ▼ +--------------------------------------------
#----------------------------------+
sub match {

	my($search_line,$option,@targets) = @_;
	my($target,$i,$a) = '';
	my $ascii = '[\x00-\x7F]';
	my $twoBytes = '[\x8E\xA1-\xFE][\xA1-\xFE]';
	my $threeBytes = '\x8F[\xA1-\xFE]{2}';

	$i = 0;
	$a = 0;

	# AND
	if($option == 0 || $#targets == 0){
		foreach $target (@targets){
			if($search_line =~ /^(?:$ascii|$twoBytes|$threeBytes)*?\Q$target\E/ && $target ne ''){
				$a++;
			}
		}
		if($a == $#targets+1){ $i = 1; }
	}

	# OR
	elsif($option == 1){
		foreach $target (@targets){
			if($search_line =~ /^(?:$ascii|$twoBytes|$threeBytes)*?\Q$target\E/ && $target ne ''){
				$i = 1;
				last;
			}
		}
	}

	# XOR
	elsif($option == 2){
		$target = shift(@targets);
		if($search_line =~ /^(?:$ascii|$twoBytes|$threeBytes)*?\Q$target\E/ && $target ne ''){
			foreach $target (@targets){
				if($search_line !~ /^(?:$ascii|$twoBytes|$threeBytes)*?\Q$target\E/ && $target ne ''){ $a++; }
			if($a == $#targets+1){ $i = 1; }
			}
		}else{ $i = 0; }
	}

	return $i;

} # close sub search

1;




#-------------------------------------------------------------------------------
#               Copyright (c) 2001-CurrentYear bayashi.net. All rights reserved.
#                                                       http://tech.bayashi.net/

