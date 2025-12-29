#                                                                     +--------+
#  ■時系列型掲示板 doBOARD 初期設定スクリプト                        | dbi.pl |
#---------------------------------------------------------------------+--------+
$version = '20040423'; # 変更しない


#----------------+
# ▼ 初期設定 ▼ +--------------------------------------------------------------
#----------------+

#----- 管理者パスワード(英数字のみ有効)(定期的に変更しましょう)
$INI{'admin_pswd'} = 'locke668';

#----- スクリプトの位置(このスクリプトのURL)
$INI{'script'} = 'http://ku-rpg.chu.jp/cgi-bin/db2/db.cgi';

#----- サイトトップページのURL(もしくは相対パス)
$INI{'top_page_url'} = '../../../index.html';


#     デフォルト構成ならば上記３つを設定すれば動くはずです。


#----- ライブラリの読み込み
require './lib/cookie.pl';
require './lib/error.pl';
require './lib/filelock.pl';
require './lib/gdatas.pl';
require './lib/gui.pl';
require './lib/html_header.pl';
require './lib/http_header.pl';
require './lib/jcode.pl';
require './lib/jua.pl';
require './lib/lnk.pl';
require './lib/page_ctrl.pl';
require './lib/pdatas.pl';
require './lib/put_log.pl';
require './lib/rm.pl';
require './lib/search.pl';
require './lib/sendmail.pl';
require './lib/trip.pl';
require './lib/write.pl';

#----- ログファイルの位置(このスクリプトからの相対パスもしくは絶対パス)
$INI{'log_file'} = './dat/db_log.cgi';

#----- 掲示板タイトル(ブラウザへのタイトル出力)
$INI{'bbs_title'} = '京都大学ＲＰＧ研究会　ゲストブック';

#----- 掲示板ヘッダー(表示タイトル部分)
$INI{'bbs_header'} = <<"_HTML_";
<br>
<center>
<h1>京都大学ＲＰＧ研究会　ゲストブック</h1>
</center>
_HTML_

#----- HTMLスタイルシートの設定
# 基本的な要素の見た目を設定をしています。
# 背景画像を使用する場合は /* background-image: url("./bg.gif"); */ の/* */を削除して
# "./bg.gif" を背景画像へのパス(このスクリプトからのパス)に書き換えます
$INI{'html_style'} = <<"_HTML_";
<STYLE type="text/css">
<!--
body { 
	color: #333333; background-color: #ffffff;
	font-size: 10pt;
	line-height: 110%;
	TEXT-DECORATION: none;
	}
input,textarea {
	font-size: 10pt;
	font-weight: normal;
	color: #333333;
	background-color: #ffffff;
	}
a:link	{
	color: #0099ff;
	TEXT-DECORATION: underline;
	}
a:hover	{TEXT-DECORATION: none;}
a:active{color: #ff6666;}
a:visited{color: #cc66ff;}
-->
</STYLE>
_HTML_

#----- スタイルや色の設定
$INI{'style_txt_title'} = 'font-size: 14pt; font-weight: bold; color: #000000;'; # タイトル文字のスタイル
$INI{'style_txt_namae'} = 'font-size: 10pt;'; # 「名前：」のスタイル
$INI{'style_txt_name'} = 'font-size: 10pt; font-weight: bold; color: #000000;'; # 名前文字のスタイル
$INI{'style_txt_nichiji'} = 'font-size: 10pt;'; # 「日時：」のスタイル
$INI{'style_txt_time'} = 'font-size: 10pt; color: #000000;'; # 時刻文字のスタイル
$INI{'style_txt_usrinfo'} = 'font-size: 8pt;'; # ユーザ情報のスタイル
$INI{'style_txt_txt'} = 'font-size: 11pt;'; # 本文文字のスタイル
$INI{'style_txt_rm'} = 'font-size: 8pt; color: #666666;'; # 削除文字のスタイル
$INI{'style_txt_rmform'} = 'text-align: right; font-size: 9pt; color: #333333'; # 削除フォーム文字のスタイル
$INI{'color_table_form_border'} = "#ffffff"; # 投稿フォームの枠の色
$INI{'color_table_border'} = "#666666"; # 記事の枠の色
$INI{'color_title_back'} = "#ddddff"; # 記事のタイトルの背景色
$INI{'color_ui_back'} = "#eeeeee"; # ユーザ情報表示部分の背景色
$INI{'size_input_name'} = 30; # 名前入力欄のサイズ
$INI{'size_input_name_max'} = 40; # 名前入力の最大サイズ
$INI{'size_input_title'} = 55; # タイトル入力欄のサイズ
$INI{'size_input_title_max'} = 65; # タイトル入力の最大サイズ
$INI{'size_input_txt_width'} = 65; # 本文入力欄の横サイズ
$INI{'size_input_txt_height'} = 6; # 本文入力欄の縦サイズ
$INI{'size_input_rmkey'} = 10; # 削除キー入力欄のサイズ
$INI{'size_input_rmkey_max'} = 12; # 削除キー入力の最大サイズ
$INI{'style_usrinfo_get'} = 'font-size: 9pt;'; # ユーザー情報取得状況テキストのスタイル

#----- 掲示板ヘッダー(ガイドライン部分)
$INI{'bbs_guide'} = <<"_HTML_";
<center>
ゲストブックです。当サイトへのご意見、ご感想など気軽に書き込んで下さい。なお、スパム対策のためこの掲示板にリンクを書き込むことはできません。
</center>
_HTML_

#----- 掲示板管理人メールアドレス
$INI{'admin_mail'} = 'webmaster@ku-rpg.org';
#----- 投稿があったらメール送信(1:する 0:しない)
$INI{'mail_check'} = 0;
$INI{'sendmail_path'} = '/usr/sbin/sendmail'; # sendmailパス(正確に設定！なければ無記入！)
$INI{'mail_title'} = "guestbook_Mail"; # メールタイトル(英数字以外(空白も!)化けるので注意!)

#----- 保持する記事数(この件数を超えると古いものから削除)
$INI{'max_log_num'} = 500; #(件)
#----- 保持する記事サイズ(このサイズを超えると古いものから削除)
$INI{'max_log_size'} = 512 * 1000; #(バイト)

#----- 1ページに表示する記事件数(保持件数÷10 くらいを目安)
$INI{'put_kiji_page'} = 10; #(件)

#----- 名前欄の入力文字数制限
$INI{'max_name_length'} = 40; #(バイト)
#----- 削除パスワードの入力文字数制限
$INI{'max_rmkey_length'} = 12; #(バイト)
#----- タイトル欄の入力文字数制限
$INI{'max_title_length'} = 70; #(バイト)
#----- 本文欄の入力文字数制限
$INI{'max_txt_length'} = 1800; #(バイト)

#----- 名前欄の空欄ダミー
$INI{'noname'} = '無記入';
#----- タイトル欄の空欄ダミー
$INI{'notitle'} = '無題';

#----- ユーザ情報(ホスト名：ブラウザ)を取得(1:する 0:しない)
$INI{'get_usr_info'} = 0;
#----- ユーザ情報(ホスト名：ブラウザ)を表示(1:する 0:しない)
$INI{'put_usr_info'} = 0;

#----- 管理者のみ投稿可能に(1:する 0:しない)
$INI{'admin_only'} = 0;

#----- ログの検索を可能に(1:する 0:しない)
$INI{'log_search'} = 1;

#----- 投稿禁止ホスト名 or IPアドレス(,カンマ区切りで複数設定可能)
$INI{'deny_host'} = '';

#---- 投稿禁止フレーズ(,カンマ区切りで複数設定可能)
$INI{'deny_phrase'} ='a href=,http://';

#----- 2重書き込み禁止(0:無効 判定するログの数)
$INI{'2write_check_log'} = 3;
$INI{'2write_check_lv'} = 2; #弱い 0 - 3 強い

#----- HTML文字コード(HTMLのメタタグで定義する文字コード)
$INI{'charset_html'} = 'Shift_JIS';
#----- ログ文字コード(jcode.plで変換する文字コード)
$INI{'charset_in'} = 'sjis';

#----- 書き込み処理後の待ち時間
$INI{'after_write'} = 0; # (秒)

# 画像はリダイレクト(1:する 0:しない)
$INI{'image_redirect'} = 1;
# リダイレクト時に表示する画像横幅
$INI{'image_redirect_width'} = 200;
# リダイレクト時に表示する画像縦幅
$INI{'image_redirect_height'} = 150;

#----- 検索エンジン自動リンク用設定(それぞれ空にすれば非対応=サーバ負荷軽減できます。)
$INI{'google_url'} = ""; # google
$INI{'yahoo_url'} = ""; # Yahoo!

#----- ファイルロック用ディレクトリの位置(このスクリプトからの相対パス)
$INI{'filelock_dir'} = './dat/';
#----- ファイルロック用ファイル名
$INI{'filelock_file'} = 'db.lck';
#----- ファイルロックタイムアウト値
$INI{'filelock_timeout'} = 45; #(秒)
#----- ファイルロックリトライ回数
$INI{'filelock_retry'} = 5; #(回)

#----- クッキーの名称
$INI{'cookie_name'} = 'db'; # 実際はこの値にクッキーPathを加えたものを使用します。
#----- クッキーの有効日数
$INI{'cookie_days'} = 30; #(日)
#----- クッキーのPath(ほぼ下2行で自動設定されます)
$INI{'cookie_path'} = $ENV{SCRIPT_NAME};
$INI{'cookie_path'} =~ s/[^\/]*$//;
# クッキー取得
&get_cookie("$INI{'cookie_name'}$INI{'cookie_path'}");

#----- gzipのパス(わからなければ空白でOK)
$INI{'gzip'} = ''; # 例えば /bin/gzip






1;






#-------------------------------------------------------------------------------
#               Copyright (c) 2001-CurrentYear bayashi.net. All rights reserved.
#                                                       http://tech.bayashi.net/
