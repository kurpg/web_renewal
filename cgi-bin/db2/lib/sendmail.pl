#------------------------------+
# ▼ メール送信サブルーチン ▼ +------------------------------------------------
#------------------------------+
sub sendmail {

	($mail_msg) = @_; # コード変換するのでmy宣言しない

	if($INI{'mail_title'} !~ /^[0-9a-zA-Z\_\-\+\*\\\!\"\#\$\%\&\'\(\)\[\]\=\~\{\}\:\;]+$/ || $INI{'sendmail_path'} eq ''){ return 0; }

	# 成形処理
	$mail_title = $INI{'mail_title'};
	&jcode'convert(*mail_title,"jis"); # メールタイトルをJISに変換
	$mail_msg =~ s/\r/\n/g;
	&jcode'convert(*mail_msg,"jis"); # 本文をJISに変換
	&jcode'h2z_jis(*mail_msg); # 本文の半角カナ→全角(JIS)変換

	# SENDMAILオープン
	open(SD,"| $INI{'sendmail_path'} -t") || return 0;

	# メール送信
	print SD "X-SERVER_NAME: $ENV{'SERVER_NAME'}\n";
	print SD "X-SCRIPT_NAME: $ENV{'SCRIPT_NAME'}\n";
	print SD "X-MAILER: doBOARD by bayashi.net(www.bayashi.net)\n";
	print SD "Errors-To: $INI{'admin_mail'}\n";
	print SD "To: $INI{'admin_mail'}\n";
	print SD "From: $INI{'admin_mail'}\n";
	print SD "Subject: $mail_title\n";
	print SD "Content-Transfer-Encoding: 7bit\n";
	print SD "Content-Type: text/plain; charset=\"ISO-2022-JP\"\n\n";
	print SD "$mail_msg";

	close(SD);

	return 1;

} # close sub sendmail

1;




#-------------------------------------------------------------------------------
#               Copyright (c) 2001-CurrentYear bayashi.net. All rights reserved.
#                                                       http://tech.bayashi.net/

