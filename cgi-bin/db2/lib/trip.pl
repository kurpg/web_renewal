#--------------------------------+
# ▼ トリップ処理サブルーチン ▼ +----------------------------------------------
#--------------------------------+
sub trip {

	my ($name) = @_;
	my ($trip,$key,$salt);

	$a = "◆"; $b = "◇";
	$name =~ s/\Q$a/$b/g;

	if($name =~ /#(.+)/){
		$key = $1;
		$salt = substr($key."do", 1, 2);
		$salt =~ s/[^\.-z]/\./go;
		$salt =~ tr/:;<=>?@[\\]^_`/ABCDEFGabcdef/;
		$trip = substr(crypt($key,$salt),-8);
	} 

	$name =~ /([^#]*)/;
	$name = $1;
	$name ="$name◆$trip" if($trip);

	return $name;


} # close trip sub

1;




#-------------------------------------------------------------------------------
#               Copyright (c) 2001-CurrentYear bayashi.net. All rights reserved.
#                                                       http://tech.bayashi.net/

# このルーチンは2chのどっかから拾ってきたものです。
# なので著作者は実質私ではないです。便宜上私かのように表記しておりますが。
