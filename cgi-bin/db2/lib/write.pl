#--------------------------------+
# ▼ 書き込み処理サブルーチン ▼ +----------------------------------------------
#--------------------------------+
sub write {

	#----- 変数の局所化宣言
	my($name,$time,@deny_hosts,$i,@logs,$log,$log_num);

	#----- リクエストメソッドが正常か
	if($ENV{'REQUEST_METHOD'} ne 'POST'){ &error('不正なメソッドのデータが送信されました。','書き込みを受け付けられません。'); }

	#----- 管理者モード？
	if($INI{'admin_only'} == 1 && $INI{'admin_pswd'} ne $FORM{'rmkey'}){ &error('現在、管理者以外投稿できません。'); }

	#----- 入力値の空欄チェック
	if($FORM{'txt'} eq '' || $FORM{'txt'} =~ /^(?:\s|\xA1\xA1)*$/){ &error('本文が空欄です。'); }
	if($FORM{'txt'} =~ /^&lt;font(\s)color=(&quot;|\')?([a-zA-Z]+|\#?[0-9a-fA-F]{6})(&quot;|\')?&gt;[\r\s]*$/){ &error('メッセージがありません。'); }
	if($FORM{'rmkey'} eq '' || $FORM{'rmkey'} =~ /^(?:\s|\xA1\xA1)*$/){ &error('削除キーが空欄です。'); }

	#----- 記事最後の改行を無くす
	$FORM{'txt'} =~ s/\r+$//g;

	# 入力値の長さチェック
	if(length($FORM{'name'}) > $INI{'max_name_length'}){ &error('名前が長すぎです。'); }
	if(length($FORM{'title'}) > $INI{'max_title_length'}){ &error('タイトルが長すぎです。'); }
	if(length($FORM{'rmkey'}) > $INI{'max_rmkey_length'}){ &error('削除キーが長すぎです。'); }
	if(length($FORM{'txt'}) > $INI{'max_txt_length'}){ &error('本文が長すぎです。'); }

	#----- ホスト名による規制
	@deny_hosts = split(/\,/,$INI{'deny_host'});
	foreach $deny_host (@deny_hosts){
		if($deny_host ne '' && $remote_host =~ /$deny_host/ && $remote_addr =~ /$deny_host/){ &error('書き込み制限中です。'); }
	}

	#----- フレーズによる規制
	@deny_phrases =split(/\,/,$INI{'deny_phrase'});
	foreach $deny_phrase (@deny_phrases){
		if($deny_phrase ne '' && (index($FORM{'txt'},$deny_phrase) >=0 || index($FORM{'title'},$deny_phrase) >=0 || index($FORM{'name'},$deny_phrase) >=0)){ &error('書き込み制限文字が入っていました。'); }
	}

	#----- ユーザ情報を取得しない設定なら値をクリア
	if($INI{'get_usr_info'} == 0){
		$remote_host = '';
		$http_user_agent = '';
	}

	#----- 名前のトリップ変換
	$name = $FORM{'name'};
	$FORM{'name'} = &trip($FORM{'name'});

	#----- 2重書き込み判定
	if($INI{'2write_check_log'} > 0 && -e $INI{'log_file'}){
		open(RD,"<$INI{'log_file'}") || &error('ファイルオープンエラー','ログファイルが開けません。','2重書き込み判定に失敗しました。');
		for($i = 1; $i < $INI{'2write_check_log'}; $i++){
			$log = <RD>;
			chomp($log);
			@logs = split(/\t/,$log);
			if($INI{'2write_check_lv'} == 0 && ($logs[2] eq $remote_host && $logs[1] eq $FORM{'name'} && $logs[5] eq $FORM{'title'} && $logs[6] eq $FORM{'txt'})){ &error('２重書き込みです。'); }
			elsif($INI{'2write_check_lv'} > 0 && ($logs[1] eq $FORM{'name'} && $logs[5] eq $FORM{'title'} && $logs[6] eq $FORM{'txt'})){ &error('２重書き込みです。'); }
			elsif($INI{'2write_check_lv'} > 1 && ($logs[5] eq $FORM{'title'} && $logs[6] eq $FORM{'txt'})){ &error('２重書き込みです。'); }
			elsif($INI{'2write_check_lv'} > 2 && $logs[6] eq $FORM{'txt'}){ &error('２重書き込みです。'); }
		undef($log);
		undef(@logs);
		}
	close(RD);
	}

	#----- ファイルロック
	$lfh = &filelock() || &error('書き込みプロセスが衝突しました。','リロード願います。');

	#----- 投稿時刻取得
	$time = time;

	#----- 一時ログファイルを作成
	open(WT,">>$INI{'log_file'}$time") || &error('ファイルオープンエラー','一時ログファイルが開けません。');

	#----- 一時ログファイルに投稿データを書き込み
	$log = "$time\t$FORM{'name'}\t$remote_host\t$http_user_agent\t$FORM{'rmkey'}\t$FORM{'title'}\t$FORM{'txt'}\n";
	print WT $log;
	$log_size = length($log);

	#----- 元ログファイルが既にあれば開く
	if(-e $INI{'log_file'}){
		open(RD,"<$INI{'log_file'}") || &error('ファイルオープンエラー','元ログファイルが開けません(読み込み)。');
		#----- 一時ログファイルに元ログデータを追加書き込み
		$log_num = 0;
		while (<RD>){
			$log_num++;
			$log_size += length($_);
			#----- 記事保持数内、記事保持サイズ内であれば追加
			if($log_num < $INI{'max_log_num'} && $log_size < $INI{'max_log_size'}){
				print WT "$_";
			}else{
				last;
			}
		}
		#----- ファイルハンドル<RD>閉じる
		close(RD);
	} # close if(-e $INI{'log_file'})

	#----- ファイルハンドル<WT>閉じる
	close(WT);

	#----- 一時ファイルのパーミション変更(設定？)
	chmod 0606,"$INI{'log_file'}$time" || &error('パーミション変更失敗','一時ファイルのパーミション変更ができません。');

	#----- 元データファイルがあれば削除
	if(-e $INI{'log_file'}){
		unlink($INI{'log_file'}) || &error('ファイル削除エラー','データファイルが削除できません。');
	} # if(-e $INI{'log_file'})

	#----- 一時ファイルを元データファイル名に変更
	rename("$INI{'log_file'}$time","$INI{'log_file'}") || &error('ファイル名の変更に失敗しました。','一時ファイルのファイル名変更に失敗しました。');

	#----- ファイルロック解除
	&unlock($lfh);

	#----- クッキーに情報を保存
	if($FORM{'rmkey'} ne ''){ $COOKIE{'rmkey'} = $FORM{'rmkey'}; }
	&put_cookie("$INI{'cookie_name'}$INI{'cookie_path'}",$INI{'cookie_days'},"name:$name\,rmkey:$COOKIE{'rmkey'}",$INI{'cookie_path'});

	#----- 確認メール送信
	if($INI{'mail_check'} == 1){
		$FORM{'name'} =~ s/&lt;/</g;
		$FORM{'name'} =~ s/&gt;/>/g;
		$FORM{'name'} =~ s/&quot;/"/g;
		$FORM{'name'} =~ s/&amp;/&/g;
		$FORM{'title'} =~ s/&lt;/</g;
		$FORM{'title'} =~ s/&gt;/>/g;
		$FORM{'title'} =~ s/&quot;/"/g;
		$FORM{'title'} =~ s/&amp;/&/g;
		$FORM{'txt'} =~ s/&lt;/</g;
		$FORM{'txt'} =~ s/&gt;/>/g;
		$FORM{'txt'} =~ s/&quot;/"/g;
		$FORM{'txt'} =~ s/&amp;/&/g;
		$FORM{'txt'} =~ s/\r/\n/g;
		$msg = <<"_TXT_";
$INI{'bbs_title'}に投稿がありました。

■タイトル
$FORM{'title'}

■投稿者
$FORM{'name'}

■ユーザ情報
$remote_host
$http_user_agent

■本文
$FORM{'txt'}
_TXT_

		&sendmail($msg);

	} #close if($INI{'mail_check'} == 1)

	&http_header(); # HTTPヘッダ出力

	#----- HTMLヘッダ出力
	print <<"_HTML_";
<html lang="ja">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=$INI{'charset_html'}">
<meta http-equiv=refresh content=$INI{'after_write'};url=$INI{'script'}>
<title>$INI{'bbs_title'}：書き込み終了</title>
$INI{'html_style'}
</head><body>
書き込みました。<p>[<a href="$INI{'script'}">掲示板に戻る</a>]
_HTML_

} # close sub write

1;




#-------------------------------------------------------------------------------
#               Copyright (c) 2001-CurrentYear bayashi.net. All rights reserved.
#                                                       http://tech.bayashi.net/

