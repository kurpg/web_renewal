#----------------------------------+
# ▼ ファイルロックサブルーチン ▼ +--------------------------------------------
#----------------------------------+
sub filelock {

	# 変数の局所化宣言
  my %lfh = (dir => "$INI{'filelock_dir'}", basename => "$INI{'filelock_file'}", timeout => "$INI{'filelock_timeout'}", trytime => "$INI{'filelock_retry'}",@_);
	my($i,@filelist);

  $lfh{path} = $lfh{dir} . $lfh{basename};

  for ($i = 0; $i < $lfh{trytime}; $i++, sleep 1) {
    return \%lfh if (rename($lfh{path}, $lfh{current} = $lfh{path} . time));
  }
  opendir(LOCKDIR, $lfh{dir});
  	@filelist = readdir(LOCKDIR);
  closedir(LOCKDIR);
  foreach (@filelist) {
    if (/^$lfh{basename}(\d+)/) {
      return \%lfh if (time - $1 > $lfh{timeout} and rename($lfh{dir} . $_, $lfh{current} = $lfh{path} . time));
      last;
    }
  }
  undef;

} # close sub filelock


#----- ロック解除 --------------------------------------------------------------
sub unlock {

  rename($_[0]->{current}, $_[0]->{path});

}

1;




#-------------------------------------------------------------------------------
#               Copyright (c) 2001-CurrentYear bayashi.net. All rights reserved.
#                                                       http://tech.bayashi.net/

