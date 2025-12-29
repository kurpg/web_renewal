#----------------------------------------+
# ▼ エラーメッセージ出力サブルーチン ▼ +--------------------------------------
#----------------------------------------+
sub error {

	# 変数の局所化宣言
	my(@error_msgs) = @_;

	if($http_header != 1){
		# HTTPヘッダ出力
		&http_header();
	}
	# HTMLヘッダ出力
	print <<"_HTML_";
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=$INI{'charset_html'}">
<meta name="description" content="$INI{'bbs_title'}">
<title>$INI{'bbs_title'}</title>
$INI{'html_style'}
</head>
<body>
[<a href="$INI{'script'}" target="_top">掲示板に戻る</a>]<p>
エラーが発生しました。<p>
<b><big>◆$error_msgs[0]</big></b><p>
_HTML_
	foreach (1..$#error_msgs){ print "$error_msgs[$_]<br>"; }
	print "<p><hr>《送信内容》<p>";

	foreach (keys %COM){ print "<b>■$_</b><br>$COM{$_}<br>"; }
	print "<br>";
	foreach (keys %FORM){ print "<b>■$_</b><br>$FORM{$_}<br>"; }

	&unlock($lfh);

	exit(0);

} # close sub error

1;




#-------------------------------------------------------------------------------
#               Copyright (c) 2001-CurrentYear bayashi.net. All rights reserved.
#                                                       http://tech.bayashi.net/

