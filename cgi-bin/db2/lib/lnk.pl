#----------------------------------------+
# ▼ 画像リダイレクト処理サブルーチン ▼ +--------------------------------------
#----------------------------------------+
sub lnk {

	&http_header(); # HTTPヘッダ出力

	#----- HTMLヘッダ出力
	print <<"_HTML_";
<html lang="ja">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=$INI{'charset_html'}">
<title>$INI{'bbs_title'}：画像URLリダイレクト</title>
$INI{'html_style'}
</head><body>
[<a href="$INI{'script'}">掲示板に戻る</a>]<p>
_HTML_

		if($INI{'image_redirect'} ==1 && $COM{'url'} =~ /\.(gif|jpg|jpeg|png)$/){
			print <<"_HTML_";
▼リンク先の画像を$INI{'image_redirect_width'}×$INI{'image_redirect_height'}で表\示しています。<br>
<a href="$COM{'url'}" target="_top">
<img src="$COM{'url'}" border=1 alt="クリックして実寸表\示" width=$INI{'image_redirect_width'} height=$INI{'image_redirect_height'}><br>$COM{'url'}</a><p>
_HTML_
		}else{
			&error('不正なリダイレクトリクエストです。','画像へのリンク以外リダイレクトできません。');
		}

} # close sub lnk

1;




#-------------------------------------------------------------------------------
#               Copyright (c) 2001-CurrentYear bayashi.net. All rights reserved.
#                                                       http://tech.bayashi.net/

