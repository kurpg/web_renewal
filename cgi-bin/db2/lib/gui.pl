#----------------------------------+
# ▼ ユーザ情報取得サブルーチン ▼ +--------------------------------------------
#----------------------------------+
sub get_usr_info {

	# 変数の局所化宣言
	my(%jua);

	# ホスト名の取得
	$remote_host = $ENV{'REMOTE_HOST'};
	$remote_addr = $ENV{'REMOTE_ADDR'};
	if($remote_host eq '' || $remote_host eq $remote_addr){
		$remote_host = gethostbyaddr(pack('C4',split(/\./,$remote_addr)),2);
		if($remote_host eq ''){ $remote_host = $remote_addr; }
	}

	# ブラウザ名の取得
	%jua = &jua($ENV{'HTTP_USER_AGENT'});
	$http_user_agent = "$jua{'agent_name'}/$jua{'agent_version'}";

} # close sub get_usr_info

1;




#-------------------------------------------------------------------------------
#               Copyright (c) 2001-CurrentYear bayashi.net. All rights reserved.
#                                                       http://tech.bayashi.net/

