#--------------------------------+
# ▼ クッキー取得サブルーチン ▼ +----------------------------------------------
#--------------------------------+
sub get_cookie {

	# 変数の局所化宣言
	my($cookie_name) = @_;
	my($http_cookie,@pairs,$pair,$name,$value,%cookie_data);

	$http_cookie = $ENV{'HTTP_COOKIE'};

	@pairs = split(/;/, $http_cookie);
	foreach $pair (@pairs) {
		($name, $value) = split(/=/, $pair);
		$name =~ s/ //g;
		$cookie_data{$name} = $value;
	}

	@pairs = split(/\,/,$cookie_data{$cookie_name});
	foreach $pair (@pairs) {
		($name, $value) = split(/\:/, $pair);
		$COOKIE{$name} = $value;
	}

} # close sub cookie_get

#===============================================================================



#--------------------------------+
# ▼ クッキー送出サブルーチン ▼ +----------------------------------------------
#--------------------------------+
sub put_cookie {

	# 変数の局所化宣言
	my($cookie_name,$cookie_on_days,$cookie_data,$cookie_path) = @_;
	my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst,$month,$youbi,$date_gmt);

	$ENV{'TZ'} = "GMT";
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time + $cookie_on_days * 24 * 60 * 60);
	$month = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec')[$mon];
	$youbi = ('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday')[$wday];
	$date_gmt = sprintf("%s\, %02d\-%s\-%04d %02d:%02d:%02d GMT",$youbi,$mday,$month,$year + 1900,$hour,$min,$sec);

	print "Set-Cookie: $cookie_name=$cookie_data; expires=$date_gmt; path=$cookie_path\n";

} # close sub put_cookie

1;




#-------------------------------------------------------------------------------
#               Copyright (c) 2001-CurrentYear bayashi.net. All rights reserved.
#                                                       http://tech.bayashi.net/

