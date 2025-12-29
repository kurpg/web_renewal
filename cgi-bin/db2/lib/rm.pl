#--------------------------------+
# ▼ ログ削除処理サブルーチン ▼ +----------------------------------------------
#--------------------------------+
sub rm {

	#----- 変数の局所化宣言
	my($admin,$time,$log,@delete,$i,$del);

	#----- リクエストメソッドが正常か
	if($ENV{'REQUEST_METHOD'} ne 'POST'){ &error('不正なメソッドのデータが送信されました。','書き込みを受け付けられません。'); }

	#----- 管理パスワード判定
	if($INI{'admin_pswd'} eq $FORM{'admin_pswd'}){ $admin = 1; }

	#----- 削除記事リスト作成
	foreach (keys %FORM){
		if($_ =~ /^(\d+)$/ && $FORM{$_} eq 'on'){
			push(@delete,$1);
		}
	}

	#----- ファイルロック
	$lfh = &filelock() || &error('処理プロセスが衝突しました。','リロード願います。');

	#----- 投稿時刻取得
	$time = time;

	#----- 元ログを開く
	if(-e $INI{'log_file'}){
		open(RD,"<$INI{'log_file'}") || &error('ファイルオープンエラー','元ログファイルが開けません。');
	}else{
		&error('ログファイルが見つかりません','記事の削除はできません。');
	}

	#----- 一時ファイルを作成
	open(WT,">>$INI{'log_file'}$time") || &error('ファイルオープンエラー','一時ログファイルが開けません。');

	#----- 一時ログファイルに元ログデータを追加書き込み
	$i = 0;
	foreach $log (<RD>){
		my ($t,$name,$remote_host,$http_user_agent,$rmkey,$title,$txt) = split(/\t/,$log);
		#----- 記事ID(時刻)が削除リストにあり、管理パスか削除キーが一致すれば削除
		$del = 1;
		foreach (@delete){
			if($_ ne '' && $_ eq $t && ($INI{'admin_pswd'} eq $FORM{'admin_pswd'} || $FORM{'admin_pswd'} eq $rmkey)){ $del = 0; }
		}
		if($del){ print WT "$log"; }else{ $i++; }
	}

	#----- ファイルハンドル<RD><WT>閉じる
	close(RD);
	close(WT);

	#----- 一時ファイルのパーミション変更(設定？)
	chmod 0606,"$INI{'log_file'}$time" || &error('パーミション変更失敗','一時ファイルのパーミション変更ができません。');

	#----- 元データファイルがあれば削除
	unlink($INI{'log_file'}) || &error('ファイル削除エラー','データファイルが削除できません。');

	#----- 一時ファイルを元データファイル名に変更
	rename("$INI{'log_file'}$time","$INI{'log_file'}") || &error('ファイル名の変更に失敗しました。','一時ファイルのファイル名変更に失敗しました。');

	#----- ファイルロック解除
	&unlock($lfh);

	#----- HTTPヘッダ出力
	&http_header();

	#----- 削除失敗ならエラー出力
	if($i == 0){ &error('記事削除エラー','管理パスか削除キーが一致しません。','または削除対象記事が存在しません。'); }

	#----- 削除結果出力
	print <<"_HTML_";
<html lang="ja">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=$INI{'charset_html'}">
<title>$INI{'bbs_title'}：削除処理終了</title>
$INI{'html_style'}
</head><body>
$i件の記事を削除しました。<p>[<a href="$INI{'script'}">掲示板に戻る</a>]
_HTML_

	return;

}

1;




#-------------------------------------------------------------------------------
#               Copyright (c) 2001-CurrentYear bayashi.net. All rights reserved.
#                                                       http://tech.bayashi.net/

