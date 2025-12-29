#----------------------------------------+
# ▼ クエリーデータの取得サブルーチン ▼ +--------------------------------------
#----------------------------------------+
sub get_query_string {

	# 変数の局所化宣言
	my($buffer,@pairs,$pair,$name);

	$buffer = $ENV{'QUERY_STRING'};
	@pairs = split(/&/,$buffer);
	foreach $pair (@pairs){
		($name,$value) = split(/=/,$pair);
			$name =~ s/([^a-zA-Z0-9])//g; # アルファベットと数字以外は無効
		if($name ne 'url'){
			$value =~ s/([^a-zA-Z0-9])//g; # アルファベットと数字以外は無効
		}
		$COM{$name} = $value;
	} # close foreach $pair (@pairs)

} # close sub get_query_string

#===============================================================================



#----------------------------------------+
# ▼ 標準入力のデータ取得サブルーチン ▼ +--------------------------------------
#----------------------------------------+
sub get_content_length {

	# 変数の局所化宣言
	my($buffer,@pairs,$pair,$name,);

	read(STDIN,$buffer,$ENV{'CONTENT_LENGTH'});
	@pairs = split(/&/,$buffer);
	foreach $pair (@pairs){
		($name,$value) = split(/=/,$pair);
		$value =~ tr/+/ /; # +に変換された空白を元に戻す
		$value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("H2",$1)/eg; # アンエスケープ
		&jcode'convert(*value,$INI{'charset_in'}); # 文字コード変換
		$value =~ s/\x0D\x0A/\r/g; # 改行コードの統一
		$value =~ s/\t//g; # タブの削除(データの区切り文字なので削除する)
		$value =~ s/&/&amp;/g;
		$value =~ s/</&lt;/g;
		$value =~ s/>/&gt;/g;
		$value =~ s/"/&quot;/g;
		$value =~ s/&amp;([a-zA-Z0-9]+);/&$1;/g; # 外字対応

		$FORM{$name} = $value;
	}

} # close sub get_content_length

1;




#-------------------------------------------------------------------------------
#               Copyright (c) 2001-CurrentYear bayashi.net. All rights reserved.
#                                                       http://tech.bayashi.net/

