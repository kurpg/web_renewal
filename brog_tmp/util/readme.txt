======================================================================
=== Serene Bach - weblog management system ===========================
======================================================================
                                     Written by T.Otani / 30 Jul 2005 
                         Copyright (C) 2005 SimpleBoxes/SerendipityNZ 
                                                  All rights reserved.

  util 内のスクリプトは通常 Serene Bach をお使いいただく上では必須では
  ありません。

[アーカイブの内容]
- feed.cgi
      rss や atom feed を動的に出力するスクリプトを sb.cgi から変更した
      際に利用します。利用時にはグローバル環境設定による設定が必要です。

- tb.cgi
      トラックバックの受信処理を行うスクリプトを sb.cgi から分けたい場
      合に利用します。利用時にはグローバル環境設定による設定が必要です。

- xml-rpc.cgi
      XML-RPC API を利用した記事投稿のエンドポイントなどを admin.cgi 
      から分けたい場合に利用します。

- sb_default.txt
      Serene Bach beta でデフォルトだった sb とほぼ同等なテンプレート
      パッケージファイルです

いずれのスクリプトも ScriptPath 上にファイルを置き、sb.cgi と同じパー
ミッションを設定します。また、先頭行の perl のパスをお使いいただいてい
るサーバ環境の設定にあわせてください。
