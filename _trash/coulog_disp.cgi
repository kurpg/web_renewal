#!/usr/local/bin/ruby -Ks

=begin
= coulog_disp.cgi v1.00
  このスクリプトはcoulog.cgiのカウンタ表示部分のみを
切り出したものです。
* Written By Raito
* Modified By valkyrja
* mailto: raito@mbh.nifty.com
= 更新履歴
* 2001/04/25 v1.00 (By valkyrja)
  coulog.cgiから表示部分のみを切り出した。
  イメージカウンタだったものをテキストに変更

=end

################ 前処理(変数の宣言など) ################
# アクセスカウンタの表示桁数
keta = 6

# アクセスカウントを収納するファイル名
countfilename = './c.dat'

# テキストカウンタの文字飾り用タグ（開始タグ）
tag_begin = "<b>"

# テキストカウンタの文字飾り用タグ（終了タグ）
tag_end = "</b>"

################ カウント数表示 ################
# カウンタファイル読み込み
presentcount = 0
begin
  presentcount = File::open(countfilename,"r").gets.to_i
rescue
  presentcount = 0
end

# テキストカウンタ出力
# print "Content-type: text/html\n\n"
print tag_begin, presentcount, tag_end, "\n"
################ カウント数表示終了 ################
