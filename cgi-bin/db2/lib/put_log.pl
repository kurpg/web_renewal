#--------------------------------+
# ▼ ログ表示処理サブルーチン ▼ +----------------------------------------------
#--------------------------------+
sub put_log {

	#----- 変数の局所化宣言
	my($start,$end,$i,$pat,$qua2);

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
	$i = 0;
	while (<LOG>){
		$i++;
		#----- 表示範囲内か判定
		if($i >= $start && $i <= $end){
			# 記事データの分解
			($time,$name,$remote_host,$http_user_agent,$rmkey,$title,$txt) = split(/\t/,$_);

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
　<span style="$INI{'style_txt_usrinfo'}">
[ $remote_host : $http_user_agent ]
</span>
_HTML_
			}

			print <<"_HTML_";
	</td></tr>
	</table>
	<table border=0 cellpadding=4 cellspacing=0 width=90%>
	<tr><td style="$INI{'style_txt_txt'}">$txt</td></tr>
	</table>
	<table border=0 cellpadding=4 cellspacing=0 width=100%>
	<tr><td align="right" style="$INI{'style_txt_rm'}">No.$i <input type="checkbox" name="$time" style="border: none"> 削除</td></tr>
	</table>
</td></tr>
</table>
<p>
_HTML_

		}elsif($i > $end){ last; } # 範囲外なのでループ脱出
	}
	close(LOG);

	print <<"_HTML_";
</center>
<p style="$INI{'style_txt_rmform'}">
削除キー <input type="text" name="admin_pswd" size=$INI{'size_input_rmkey'} maxlength=$INI{'size_input_rmkey_max'}><br>
<input type="submit" name="submit" value="選択記事の削除">
</p></form>
_HTML_

	&page_ctrl();

	return;

}

1;





#-------------------------------------------------------------------------------
#               Copyright (c) 2001-CurrentYear bayashi.net. All rights reserved.
#                                                       http://tech.bayashi.net/

