#!./perl

BEGIN {
    chdir 't' if -d 't';
    require './test.pl';
    set_up_inc('../lib');
}

use strict;
use warnings;

plan tests => 21;

sub list_context {
    my ($func) = @_;
    my $gimme = wantarray;
    ok defined($gimme) && !$gimme, "$func supplies scalar context";
    \*DATA
}

for my $func (qw(
    close
    eof
    fileno
    getc
    lstat
    stat
    tell
)) {
    eval "no warnings qw(io); () = $func(list_context('$func'))";
    die $@ if $@;

    local $::TODO = "XXX stat/lstat check is still broken" if $func =~ /\Al?stat\z/;
    my $code = "$func(0,1,2)";
    is eval("() = $code; 1"), undef, "$code errors";
    like $@, qr/^Too many arguments for \Q$func\E at/, "$code message is 'Too many arguments'";
}

__DATA__
