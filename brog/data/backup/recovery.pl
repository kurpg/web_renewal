#!usr/bin/perl

use vars qw( %gData %gEnv );
%gEnv = (
	'entdet' => {
		'ent' => ['id','wid','subj','cat','date','auth','stat','com','tb','edit','acm','atb','form','ping','body','more','sum','add','key','file','ext',],
		'com' => ['id','wid','eid','stat','date','auth','host','mail','url','agnt','body','icon','ext',],
		'tb'  => ['id','wid','eid','stat','date','subj','name','url','body','host',],
	},
	'ent'    => ['id','wid','subj','cat','date','auth','stat','com','tb',],
);
my $dir = './entry/';
my @ids = ();
opendir(DIR, $dir);
my @filelist = readdir(DIR);
foreach my $file (@filelist) {
	if ($file =~ /(\d+)\.cgi/) {
		push(@ids,$1);
	}
}
closedir(DIR);
my $max = 0;
foreach my $id (@ids) {
	print 'reading[',$id,']...';
	&sbfile_read_entry($id);
	foreach my $elem ( @{$gEnv{'ent'}} ) {
		$gData{'ent'}[$id]{$elem} = $gData{'entry'}{$id}{'ent'}{$elem};
	}
	$max = $id if ($id > $max);
	print 'ok',"\n";
}
$gData{'num'}{'ent'} = $max + 1;
print 'writing...';
&sbfile_update_datafile('ent');
print 'finished',"\n";
exit(0);

sub sbfile_read_entry {
	my $id = shift;
	my $file = './entry/' . $id . '.cgi';
	my %num = ();
	open(ENTRYIN,"<$file");
	while (my $line = <ENTRYIN>) {
		$line =~ tr/\x0D\x0A//d;
		my ($label,$tmp) = split("\t",$line,2);
		if ($label eq 'com' or $label eq 'tb') {
			$gData{'entry'}{$id}{$label} = [] if ($num{$label} == 0);
			$gData{'entry'}{$id}{$label}[$num{$label}] = {};
		}
		my $val = '';
		foreach my $key ( @{$gEnv{'entdet'}{$label}} ) {
			($val,$tmp) = split('<>',$tmp,2);
			if ($label eq 'com' or $label eq 'tb') {
				$gData{'entry'}{$id}{$label}[$num{$label}]{$key} = $val;
			} else {
				$gData{'entry'}{$id}{$label}{$key} = $val;
			}
		}
		$num{$label}++ if ($label eq 'com' or $label eq 'tb');
	}
	close(ENTRYIN);
	return();
}
sub sbfile_update_datafile {
	my $type = shift;
	my $file = './entry.cgi';
	open(DATAOUT,">$file");
	binmode(DATAOUT);
	print DATAOUT $gData{'num'}{$type},"\n";
	for (my $i=0;$i<$gData{'num'}{$type};$i++) {
		next if ($gData{$type}[$i]{'id'} eq '');
		foreach my $elem ( @{$gEnv{$type}} ) {
			print DATAOUT $gData{$type}[$i]{$elem} . '<>';
		}
		print DATAOUT "\n";
	}
	close(DATAOUT);
	return();
}
