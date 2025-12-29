#----------------------------------+
# ▼ HTTPヘッダ出力サブルーチン ▼ +--------------------------------------------
#----------------------------------+
sub http_header {

	if($ENV{'HTTP_ACCEPT_ENCODING'}=~/gzip/ && $INI{'gzip'} ne ''){
		$|=1;
		print "Content-type: text/html;charset=$INI{'charset_html'}\n";
		if($ENV{'HTTP_ACCEPT_ENCODING'}=~/x-gzip/){
			print "Content-encoding: x-gzip\n\n";
		}else{
			print "Content-encoding: gzip\n\n";
		}
		open(STDOUT,"| $INI{'gzip'} -1 -c");
	}else{
		print "Content-type: text/html;charset=$INI{'charset_html'}\n\n";
	}
	$http_header = 1; # HTTPヘッダ出力フラグ

} #close sub http_header

1;




#-------------------------------------------------------------------------------
#               Copyright (c) 2001-CurrentYear bayashi.net. All rights reserved.
#                                                       http://tech.bayashi.net/

