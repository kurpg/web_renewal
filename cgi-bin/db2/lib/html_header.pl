#----------------------------------+
# ▼ HTMLヘッダ出力サブルーチン ▼ +--------------------------------------------
#----------------------------------+
sub html_header {

	#----- HTMLヘッダ出力
	print <<"_HTML_";
<html lang="ja">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=$INI{'charset_html'}">
<meta name="description" content="$INI{'bbs_title'}">
<title>$INI{'bbs_title'}</title>
$INI{'html_style'}
</head>
<body>
<SCRIPT language="JavaScript">
<!--
// 投稿ボタンの連続押し防止JavaScript
sent = false
function send_check(){
     if(sent){
         return false
      }else{
         sent = true
         return true
      }
}
// -->
</SCRIPT>
[<a href="$INI{'script'}?a=p" target="_top">更新</a>]　[<a href="$INI{'top_page_url'}" target="_top">トップページに戻る</a>]<br>
$INI{'bbs_header'}
<hr>
_HTML_

	if($INI{'admin_only'} == 1){
		print "<b>★ 現在管理者のみ投稿可能\です。 ★</b>";
	}

	print <<"_HTML_";
$INI{'bbs_guide'}
<hr><p>

<center>
<table border=1 bordercolor="$INI{'color_table_form_border'}" cellspacing=0 cellpadding=12>
<tr><td align="center">
	<form action="$INI{'script'}?a=w" method=POST onSubmit="return send_check()">
	<table>
	<tr><th>名前</th><td><input type="text" name="name" size=$INI{'size_input_name'} maxlength=$INI{'size_input_name_max'} value="$COOKIE{'name'}"></td></tr>
	<tr><th>タイトル</th><td><input type="text" name="title" size=$INI{'size_input_title'} maxlength=$INI{'size_input_title_max'}></td></tr>
	<tr><th>本文</th><td><textarea name="txt" rows=$INI{'size_input_txt_height'} cols=$INI{'size_input_txt_width'} wrap="OFF"></textarea></td></tr>
	<tr><th>削除キー</th><td><input type="text" name="rmkey" size=$INI{'size_input_rmkey'} maxlength=$INI{'size_input_rmkey_max'} value="$COOKIE{'rmkey'}"></td></tr>
	<tr><td align="right" colspan=2><span style="$INI{'style_usrinfo_get'}">
_HTML_

	if($INI{'get_usr_info'} == 1){
		print "★現在投稿者のホスト名/ブラウザ名取得中です　　";
	}else{
		print "";
	}

print <<"_HTML_";
</span>
<input type="submit" name="submit" value="　投稿　">　<input type="reset" name="reset" value="Reset"></td></form>
	</tr>
	</table>
_HTML_

if($INI{'log_search'} == 1){
	print <<"_HTML_";
</td></tr>
<th align="center" colspan=2>
<form action="$INI{'script'}?a=s" method=POST onSubmit="return send_check()">
記事の検索 <input type="text" name="search" size=20 value="$FORM{'search'}">
<select name="soption" size=1>
<option value=0>AND<option value=1>OR<option value=2>XOR
</select>
<input type="submit" name="submit" value=" 実行 "></th></form>
_HTML_
}else{
	print "</td>";
}

print "</tr></table></center><p><hr>";


_HTML_

}

1;




#-------------------------------------------------------------------------------
#               Copyright (c) 2001-CurrentYear bayashi.net. All rights reserved.
#                                                       http://tech.bayashi.net/

