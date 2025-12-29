#!/usr/bin/perl
#                                                                     +--------+
#  ■時系列型掲示板 doBOARD                                           | db.cgi |
#---------------------------------------------------------------------+--------+


#----- 初期設定
require './dbi.pl';

#----------------------+
# ▼ メインルーチン ▼ +--------------------------------------------------------
#----------------------+

#----- コマンド受信の判定
if($ENV{'QUERY_STRING'} ne ''){

	&get_query_string(); # クエリー取得
	&get_usr_info(); # ユーザ情報(ホスト＆ブラウザ)取得

	#----- コマンドの判定
	if($COM{'a'} =~ /^(p|w|rm|lnk|s)$/){
		&get_content_length(); # 標準入力取得
		#----- 各処理へ分岐
		if($COM{'a'} eq 'p'){
			&put_log(); # 表示処理へ
		}elsif($COM{'a'} eq 'w'){
			&write(); # 書き込み処理へ
		}elsif($COM{'a'} eq 'rm'){
			&rm(); # 削除処理へ
		}elsif($COM{'a'} eq 'lnk'){
			&lnk(); # リダイレクト処理へ
		}elsif($COM{'a'} eq 's'){
			if($INI{'log_search'} == 1){
				&search(); # 検索処理へ
			}else{
				&error('実行できないリクエストです。','検索機能は無効です。');
			}
		}
	}else{
		&error('送信内容が不正です。');
	} # close if($COM{'a'} =~ /^(p|w|rm)$/)

}else{

	#----- ログ表示処理へ
	&put_log();

} # close if($ENV{'QUERY_STRING'} ne '')

#----- 著作権表示。必ず出力してください。
print <<"_HTML_";
<center><p><hr><a href="http://tech.bayashi.net/" target="_top" style="font-size: 9pt;">掲示板doBOARD v$version</a></center>
</body></html>
_HTML_

exit(0);



#-------------------------------------------------------------------------------
#               Copyright (c) 2001-CurrentYear bayashi.net. All rights reserved.
#                                                       http://tech.bayashi.net/
