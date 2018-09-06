# XXX Configure test needed. id:475
# Some Linux releases like to hide their <nlist.h>
$self->{CCFLAGS} = $Config{ccflags} . ' -I/usr/include/libelf'
	if -f "/usr/include/libelf/nlist.h";
1;
