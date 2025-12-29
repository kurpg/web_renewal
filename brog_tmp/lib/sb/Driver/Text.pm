# sb::Driver::Text - Module for Serene Bach
# == Author(s) : Takuya Otani <takuya.otani@gmail.com> ==
# == Copyright (C) 2005 SimpleBoxes/SerendipityNZ Ltd. ==

package sb::Driver::Text;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.09';
# 0.09 [2006/11/09] changed _sort_object/_encode to make them faster
# 0.08 [2006/11/07] changed _load_detail and _load_list to make them faster
# 0.07 [2006/02/03] added decrement_id, changed _sort_object to sort data correctly
# 0.06 [2005/11/07] changed _save_list to update correctly
# 0.05 [2005/10/20] changed _generate_condition to check faster
# 0.04 [2005/10/19] changed _load_detail to load data correctly
# 0.03 [2005/10/19] use ref instead of &_class, removed _class
# 0.02 [2005/08/23] changed _load_detail to separate loading an object
# 0.01 [2005/03/01] changed how to lock a file
# 0.00 [2005/02/02] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Config ();
use sb::Language ();
use sb::Lock ();
use sb::Driver ();
@ISA = qw( sb::Driver );
# ==================================================
# // declaration for constant value
# ==================================================
sub TEMPORARY_FILE (){ '_tmp' }
my %ContentOfList = (
	'entry'     => 'id,wid,subj,cat,date,auth,stat,com,tb,file,tz,add,',
	'message'   => 'id,wid,eid,stat,date,auth,host,tz,',
	'trackback' => 'id,wid,eid,stat,date,subj,name,url,tz,',
	'template'  => 'id,wid,use,name,gen,mod,info,',
	'user'      => 'id,wid,name,pass,real,disp,mail,notice,stat,order,',
);
# ==================================================
# // constructor
# ==================================================
sub new {
	my $class = shift;
	my $self  = {
		'dir' => sb::Config->get->value('dbtxt_data'),
		'suf' => sb::Config->get->value('dbtxt_suf'),
		'max' => &_load_id(sb::Config->get),
		'num' => 0,
	};
	return bless($self,$class);
}
# ==================================================
# // public functions
# ==================================================
sub load
{
	my $self  = shift;
	my $class = shift; # class name of sb::Data::Object
	return() if ($class eq '');
	my %param = ( # arguments
		'cond'   => {},     # condition
		'id'     => undef,  # id indicated (return an object with details)
		'logic'  => 'and',  # logic operator for condition
		'bgn'    => 0,      # offset for range
		'num'    => -1,     # number of range
		'sort'   => 'id',   # sorting option
		'order'  => 0,      # order [descent/ascent]
		'detail' => undef,  # if set true, loading objects with details
		'table'  => ['id'], # elements table of object (this is not an argument)
		@_
	);
	my $func = &_generate_condition($param{'logic'},%{$param{'cond'}});
	my @array = $self->_load_detail($class,$func,%param);
	$self->{'num'} = $#array + 1;
	if ( $self->{'num'} > 1 )
	{ # more than one object
		@array = &_sort_object($param{'sort'},$param{'order'},@array);
		@array = splice(@array,$param{'bgn'},$param{'num'}) if ( $param{'num'} > 0 and @array > $param{'num'} );
	}
	return( @array );
}
sub save
{
	my $self = shift;
	my @objs = @_; # objects to save
	return(0) if ( $#objs == -1 );
	my $lock = sb::Config->get->value('dir_lock') . sb::Config->get->value('dbtxt_save');
	my $class = ref($objs[0]);
	@objs = sort { $a->id <=> $b->id } @objs;
	my $lfh = sb::Lock->locked_open($lock) or die(sb::Language->get->string('error_file_lock'));
	$self->_save_detail($class,@objs);
	$self->_save_list($class,@objs);
	&_save_id(%{$self->{'max'}});
	close($lfh);
	return(1);
}
sub new_id
{
	my $self = shift;
	my $class = shift; # class name of sb::Data::Object
	return() if ($class eq '');
	my $name = &_name($class);
	return $self->{'max'}->{$name}++;
}
sub decrement_id
{
	my $self = shift;
	my $class = shift;
	return() if ($class eq '');
	my $name = &_name($class);
	$self->{'max'}->{$name}--;
	$self->{'max'}->{$name} = 0 if ($self->{'max'}->{$name} < 0);
	$self->{'max'}->{$name};
}
sub matched_number
{
	my $self = shift;
	return( $self->{'num'} );
}
# ==================================================
# // private functions
# ==================================================
sub _save_detail
{
	my $self  = shift;
	my $class = shift;
	my @objs  = @_;
	my $name  = &_name($class);
	return() if ( !defined($ContentOfList{$name}) );
	my $dir = $self->{'dir'} . $name . '/';
	foreach my $obj ( @objs )
	{
		next if (ref($obj) ne $class);
		my $file = $dir . $obj->id . $self->{'suf'};
		if ($obj->erased)
		{
			unlink($file);
		}
		else
		{
			open(DATAOUT,">$file") or die(sb::Language->get->string('error_file_open') . $file);
			binmode(DATAOUT);
			print DATAOUT &_encode($obj,'');
			close(DATAOUT);
			chmod(sb::Config->get->value('basic_file_attr'),$file);
		}
	}
	return();
}
sub _save_list
{
	my $self  = shift;
	my $class = shift;
	my @objs  = @_;
	my $name  = &_name($class);
	my $file  = $self->{'dir'} . $name . $self->{'suf'};
	my $temp  = $self->{'dir'} . $name . TEMPORARY_FILE;
	open(LISTOUT,">$temp") or die(sb::Language->get->string('error_file_open') . $temp);
	open(LISTIN,"<$file")  or die(sb::Language->get->string('error_file_open') . $file);
	binmode(LISTOUT);
	while (my $line = <LISTIN>)
	{
		my @data = &_decode($line);
		if (@objs and $data[0] == $objs[0]->id)
		{
			print LISTOUT &_encode($objs[0],$name) if (!$objs[0]->erased and ref($objs[0]) eq $class);
			shift(@objs);
		}
		else
		{
			print LISTOUT $line;
		}
	}
	close(LISTIN);
	foreach my $obj ( @objs )
	{
		next if ($obj->erased or ref($obj) ne $class);
		print LISTOUT &_encode($obj,$name);
	}
	close(LISTOUT);
	rename($temp,$file);
	chmod(sb::Config->get->value('basic_file_attr'),$file);
}
sub _load_detail
{
	my $self  = shift;
	my $class = shift;
	my $func  = shift;
	my %param = @_;
	my @array = ();
	my $name  = &_name($class);
	return( $self->_load_list($class,$func,%param) ) if ( &_switch_loadtype($name,%param) );
	my $dir = $self->{'dir'} . $name . '/';
	if ( defined($param{'id'}) )
	{
		my $file = $dir . $param{'id'} . $self->{'suf'};
		return() if (!-r $file);
		open(DATAIN,"<$file");
		my @data = &_decode(<DATAIN>);
		my $obj = $class->alloc();
		map { $obj->{$_} = shift(@data) } @{$param{'table'}};
		close(DATAIN);
		push(@array,$obj);
	}
	else
	{
		opendir(DATADIR, $dir);
		my @file_list = readdir(DATADIR);
		closedir(DATADIR);
		foreach my $file_name (@file_list)
		{
			next if ($file_name !~ /^(\d+)\./);
			my $file = $dir . $file_name;
			open(DATAIN,"<$file");
			my @data = &_decode(<DATAIN>);
			my $obj = $class->alloc();
			map { $obj->{$_} = shift(@data) } @{$param{'table'}};
			close(DATAIN);
			next if ( &{$func}($obj) );
			push(@array,$obj);
		}
	}
	return(@array);
}
sub _load_list
{
	my $self  = shift;
	my $class = shift;
	my $func  = shift;
	my %param = @_;
	my @array = ();
	my $name  = &_name($class);
	my $file  = $self->{'dir'} . $name . $self->{'suf'};
	return(@array) if (!-e $file);
	my @buffer = ();
	if ( defined($ContentOfList{$name}) )
	{
		$param{'table'} = [split(',',$ContentOfList{$name})];
	}
	open(DATAIN,"<$file");
	while (my $line = <DATAIN>)
	{
		my @data = &_decode($line);
		next if (defined($param{'id'}) and $param{'id'} != $data[0]);
		my $obj = $class->alloc();
		map { $obj->{$_} = shift(@data) } @{$param{'table'}};
		next if ( &{$func}($obj) );
		push(@array,$obj);
		last if ( defined($param{'id'}) );
	}
	close(DATAIN);
	return(@array);
}
sub _switch_loadtype
{
	my $name  = shift;
	my %param = @_;
	return(1) if ( !defined($ContentOfList{$name}) );
	return(0) if ( defined($param{'id'}) );
	return(0) if ( defined($param{'detail'}) and $param{'detail'} eq 'on' );
	foreach my $key ( keys(%{$param{'cond'}}) )
	{
		return(0) if ( index($ContentOfList{$name},$key . ',') == -1 );
	}
	return(1);
}
sub _generate_condition
{
	my $logic = shift;
	my %cond  = @_;
	return( sub { return(0) } ) if ( !keys(%cond) );
	my %reg = ();
	foreach my $key ( keys(%cond) )
	{
		next if ( $key eq '__range' or $key eq '__combo' );
		if ( $cond{$key} =~ /^\/(.*)\/$/ )
		{
			$reg{$key} = $1;
			$cond{$key} = undef;
		}
	}
	my $re = ( keys(%reg) ) ? 1 : 0;
	my $func  = sub {
		my $flag = 0;
		foreach my $key ( keys(%reg) )
		{
			my $word = $reg{$key};
			$flag = ( index(lc($_[0]->{$key}),lc($word)) > -1 ); # ( $_[0]->{$key} =~ /\Q$word\E/i )
			last if ($flag);
		}
		return( !$flag ) if ( ($flag and $logic eq 'or' and $re) or (!$flag and $logic eq 'and' and $re) );
		foreach my $key ( keys(%cond) )
		{
			next if ( $key eq '__range' or $key eq '__combo' );
			next if ( !defined($cond{$key}) or !defined($_[0]->{$key}) );
			if ( ref($cond{$key}) eq 'ARRAY' )
			{
				my $check = $_[0]->{$key};
				$check += sb::Time->diff_timezone($_[0]->{'tz'}, 0) if ( $cond{'__range'}->{$key} eq 'tz' );
				$flag = ( defined( $cond{'__range'}->{$key} ) ) 
				      ? ( $check >= $cond{$key}[0] and $check < $cond{$key}[1] )
				      : ( grep( /^\Q$check\E$/, @{$cond{$key}} ) );
			}
			else
			{
				$flag = ( $_[0]->{$key} eq $cond{$key} );
			}
			if ( defined( $cond{'__combo'}->{$key} ) and !$flag )
			{
				my %combo = %{$cond{'__combo'}};
				$flag = ( index($_[0]->{$combo{$key}},$combo{$combo{$key}}) > -1 );
			}
			last if ( ($flag and $logic eq 'or') or (!$flag and $logic eq 'and') );
		}
		return( !$flag );
	};
	return( $func );
}
sub _name
{
	return lc( (split('::',$_[0]))[-1] );
}
sub _decode
{
	my $line = shift;
	$line =~ tr/\x0D\x0A//d;
	return map { s/\\(.)/$1 eq 't' and "\t" or $1 eq 'n' and "\n" or "$1"/eg; $_; } split("\t",$line);
}
sub _encode
{
	my ($obj,$name) = @_;
	my @data = ();
	my @elements = ( $name and defined($ContentOfList{$name}) ) 
	             ? split(',',$ContentOfList{$name}) 
	             : $obj->elements;
	foreach my $elem ( @elements )
	{
		push(@data,&_linefeed($obj->{$elem}));
	}
	return join("\t",map { s/\\/\\\\/g; s/\t/\\t/g; s/\n/\\n/g; $_; } @data) . "\t\n";
}
sub _linefeed
{ # unify linefeed code
	$_[0] =~ s/\x0D\x0A/\n/g;
	$_[0] =~ tr/\x0D\x0A/\n\n/;
	while ($_[0] =~ /\n$/) { chomp($_[0]); }
	return($_[0]);
}
sub _load_id
{
	my $conf = shift;
	my $file = $conf->value('dbtxt_data') . $conf->value('dbtxt_ids') . $conf->value('dbtxt_suf');
	my %max  = ();
	open(MAXIN,"<$file") or die(sb::Language->get->string('error_file_open') . $file);
	while (my $line = <MAXIN>)
	{
		$line =~ tr/\x0D\x0A//d;
		my ($key,$val) = split("\t",$line,2);
		next if ($key eq '');
		$max{$key} = int($val);
	}
	close(MAXIN);
	return(\%max);
}
sub _save_id
{
	my %max  = @_;
	my $conf = sb::Config->get;
	my $file = $conf->value('dbtxt_data') . $conf->value('dbtxt_ids') . $conf->value('dbtxt_suf');
	open(MAXOUT,">$file") or die(sb::Language->get->string('error_file_open') . $file);
	binmode(MAXOUT);
	foreach my $key ( keys(%max) )
	{
		print MAXOUT $key,"\t",$max{$key},"\n";
	}
	close(MAXOUT);
	return();
}
sub _sort_object
{
	my $elem  = shift;
	my $order = shift;
	my @array = @_;
	my (@data,@ids);
	foreach (@array)
	{
		push(@data, $_->{$elem});
		push(@ids,  $_->{'id'});
	}
	return @array[ sort {
		$data[$b] <=> $data[$a] or $data[$a] cmp $data[$b] or $ids[$b] <=> $ids[$a]
	} 0 .. $#ids ] if ($order);
	return @array[ sort {
		$data[$a] <=> $data[$b] or $data[$b] cmp $data[$a] or $ids[$a] <=> $ids[$b]
	} 0 .. $#ids ];
}
1; # end of package
__END__
