#!/usr/local/bin/ruby -Ks

=begin
= coulog.cgi v1.03
  このスクリプトはアクセスカウンタとアクセス解析の
両方をまとめたものです。
* Written By Raito
* mailto: raito@mbh.nifty.com
* Modified By valkyrja
* mailto: valkyrja@mx.biwa.ne.jp
= 更新履歴
* 2001/03/01 v1.00
  とりあえず、完成
* 2001/04/10 v1.01
  可読性を高めるとともに、ログデータの肥大化を緩和
* 2001/04/14 v1.02
  ファイルサイズを求めるときにファイルが存在するかどうかを
  チェックするようにした。
* 2001/04/25 v1.02 rev.2　(By valkyrja)
  カウンタ表示部をcoulog_disp.cgiへ切り出し。
* 2002/05/21 v1.03 (By valkyrja)
  過去ログをGZIP圧縮
=end

################ 前処理(変数の宣言など) ################
# 日付関連の処理のためのモジュール
require 'date'

# ログファイル名
# ファイル名があまりにも判りやすいと逆に問題になるかも知れません．
datafile = './dlaotga.dat'

# 過去ログ
oldlog = './log/oldlog'

# oldlog が格納されるディレクトリのモード
# サーバー環境に合わせて変更してください
oldMode = 0705

# アクセスカウントを収納するファイル名
countfilename = './c.dat'

# ログファイルの最大サイズ(標準20KB)
maxDataSize = 1024 * 20

# ログファイルのサイズが大きくなったときに
# 待避させるための関数
def movelog(datafile, oldlog, oldMode)
  # 過去ログ用のディレクトリを作成
  dir = File::dirname(oldlog)
  if (!FileTest.exist?(dir))
    Dir::mkdir(dir, oldMode)
  end
  i = 1
  while
    # ファイル名の決定
    tmpfile = oldlog + i.to_s + ".dat"
    # ファイル名が重複していないかチェック
    if (!FileTest.exist?(tmpfile + ".gz"))
      File::rename(datafile, tmpfile)
      system "gzip " + tmpfile
      break
    else
      # 重複していれば次のループへ
      i += 1
    end
  end
end
################ 前処理終了 ################

################ アクセスカウンタ ################
presentcount = 0
begin
  presentcount = File::open(countfilename,"r").gets.to_i
rescue
  presentcount = 0
end
# カウント数を1上げる
newcount = presentcount + 1

# カウント数の書き込み
begin
  File::open(countfilename,"w"){ |file|
    file.print newcount,"\n"
  }
rescue
  print "Content-type: text/plain\n\n"
  print "Error!\n"
end

################ アクセスカウンタ終了 ################

################ アクセス解析 ################
# 日付・日時を取得
today = Date::today
t     = Time::now
warray = %w(日 月 火 水 木 金 土)
date_now = %Q!"#{today.to_s}(#{warray[t.wday]}) #{t.strftime("%H:%M:%S")}"!

# 環境変数 の取り込み
host = ENV['REMOTE_HOST']
addr = ENV['REMOTE_ADDR']
from = ENV['HTTP_REFERER']
tool = ENV['HTTP_USER_AGENT']

# 記録対象のリスト
out = [newcount, host, addr, from, tool]
menu = %!"日付","カウント","ホスト","アドレス","リンク元","ブラウザ/OS情報"\n!

# データの取得
txt = ""
# ファイルが存在するかチェック
if FileTest.exist?(datafile)
  # データサイズの確認
  size = File::size(datafile)
  if size  > maxDataSize
    movelog(datafile, oldlog, oldMode) 
  else
    # 存在している場合には、データを取得
    File::open(datafile,"r"){ |file|
      file.gets               # 一行目を切り取る
      txt = file.read.chomp
    }
  end
end

# データの書き込み
File::open(datafile,"w"){ |file|
  file.print menu
  file.print date_now
  out.each{|i|
    file.print ',"', i, '"'
  }
  file.print "\n"
  file.print txt, "\n" if(!txt.empty?)
}
################ アクセス解析終了 ################
