# BSD platforms have extra fields in struct tm that need to be initialized.
#  XXX A Configure test is needed. id:318
$self->{CCFLAGS} = $Config{ccflags} . ' -DSTRUCT_TM_HASZONE' ;
