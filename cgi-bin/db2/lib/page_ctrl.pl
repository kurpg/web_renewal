#------------------------------+
# ▼ ページ処理サブルーチン ▼ +------------------------------------------------
#------------------------------+
sub page_ctrl {

	my($before_page,$next_page,$last_page,$pg,$put_pg,$str,$str2);

	#----- ページ処理
	$before_page = $FORM{'pg'} - 1;
	$next_page = $FORM{'pg'} + 1;

	print "<table cellpadding=3><tr>";

	if($FORM{'pg'} > 0){
		print <<"_HTML_";
<td valign="top">
<form action="$dsa?a=p" method="POST" onSubmit="return send_check()">
<input type="hidden" name="pg" value="$before_page">
<input type="submit" name="page_ctrl" value="＜＜前のページ">
</form>
</td>
_HTML_
	}

	$last_page = int(($kiji - 1) / $INI{'put_kiji_page'}) + 1;

	if($pg < $last_page && $kiji > $INI{'put_kiji_page'}){
		print <<"_HTML_";
<td valign="top">
<form action="$dsa?a=p" method="POST" onSubmit="return send_check()">
<input type="hidden" name="pg" value="$next_page">
<input type="submit" name="page_ctrl" value="次のページ＞＞">
</form>
</td>
_HTML_
	}

	print <<"_HTML_";
<td valign="top" width=32>　</td>
<td valign="top"><small>[Page No.]</small></td>
_HTML_

	for($pg = 0; $pg < $last_page; $pg++){
		$put_pg = $pg + 1;
		if($pg == $FORM{'pg'}){
			print "<td valign=\"top\">$put_pg</td>";
		}else{
			print <<"_HTML_";
<td valign="top">
<form action="$dsa?a=p" method="POST" onSubmit="return send_check()">
<input type="hidden" name="pg" value="$pg">
<input type="submit" name="page_ctrl" value="$put_pg">
</form>
</td>
_HTML_
		}
	}

	if($COM{'a'} eq 's'){
		$str = "からの検索結果です。";
		$str2 = " [<a href=\"$INI{'script'}\">検索モードを抜ける</a>]";
	}

	print <<"_HTML_";
<td valign="top" width=32>　</td>
<td valign="top">【全 $kiji 記事$str】$str2</td>
</tr></table>
_HTML_

}

1;





#-------------------------------------------------------------------------------
#               Copyright (c) 2001-CurrentYear bayashi.net. All rights reserved.
#                                                       http://tech.bayashi.net/

