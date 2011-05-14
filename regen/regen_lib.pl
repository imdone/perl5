#!/usr/bin/perl -w
use strict;
use vars qw($Needs_Write $Verbose @Changed $TAP);
use File::Compare;
use Symbol;
use Text::Wrap;

# Common functions needed by the regen scripts

$Needs_Write = $^O eq 'cygwin' || $^O eq 'os2' || $^O eq 'MSWin32';

$Verbose = 0;
@ARGV = grep { not($_ eq '-q' and $Verbose = -1) }
  grep { not($_ eq '--tap' and $TAP = 1) }
  grep { not($_ eq '-v' and $Verbose = 1) } @ARGV;

END {
  print STDOUT "Changed: @Changed\n" if @Changed;
}

sub safer_unlink {
  my @names = @_;
  my $cnt = 0;

  my $name;
  foreach $name (@names) {
    next unless -e $name;
    chmod 0777, $name if $Needs_Write;
    ( CORE::unlink($name) and ++$cnt
      or warn "Couldn't unlink $name: $!\n" );
  }
  return $cnt;
}

# Open a new file.
sub open_new {
    my ($final_name, $mode) = @_;
    my $name = $final_name . '-new';
    my $fh = gensym;
    if (!defined $mode or $mode eq '>') {
	if (-f $name) {
	    unlink $name or die "$name exists but can't unlink: $!";
	}
	open $fh, ">$name" or die "Can't create $name: $!";
    } elsif ($mode eq '>>') {
	open $fh, ">>$name" or die "Can't append to $name: $!";
    } else {
	die "Unhandled open mode '$mode#";
    }
    *{$fh}->{name} = $name;
    *{$fh}->{final_name} = $final_name;
    *{$fh}->{lang} = ($final_name =~ /\.(?:c|h|tab|act)$/ ? 'C' : 'Perl');
    binmode $fh;
    $fh;
}

sub close_and_rename {
    my $fh = shift;
    my $name = *{$fh}->{name};
    close $fh or die "Error closing $name: $!";
    my $final_name = *{$fh}->{final_name};

    if ($TAP) {
	my $not = compare($name, $final_name) ? 'not ' : '';
	print STDOUT $not . "ok - $0 $final_name\n";
	safer_unlink($name);
	return;
    }
    if (compare($name, $final_name) == 0) {
	warn "no changes between '$name' & '$final_name'\n" if $Verbose > 0;
	safer_unlink($name);
	return;
    }
    warn "changed '$name' to '$final_name'\n" if $Verbose > 0;
    push @Changed, $final_name unless $Verbose < 0;

    # Some dosish systems can't rename over an existing file:
    safer_unlink $final_name;
    chmod 0600, $name if $Needs_Write;
    rename $name, $final_name or die "renaming $name to $final_name: $!";
}

sub read_only_top {
    my %args = @_;
    die "Missing language argument" unless defined $args{lang};
    die "Unknown language argument '$args{lang}'"
	unless $args{lang} eq 'Perl' or $args{lang} eq 'C';
    my $style = $args{style} ? " $args{style} " : '   ';

    my $raw = "-*- buffer-read-only: t -*-\n";

    if ($args{file}) {
	$raw .= "\n   $args{file}\n";
    }
    if ($args{copyright}) {
	local $" = ', ';
	local $Text::Wrap::columns = 75;
	$raw .= wrap('   ', '   ', <<"EOM") . "\n";

Copyright (C) @{$args{copyright}} by\0Larry\0Wall\0and\0others

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the README file.
EOM
    }

    $raw .= "!!!!!!!   DO NOT EDIT THIS FILE   !!!!!!!\n";

    if ($args{by}) {
	$raw .= "This file is built by $args{by}";
	if ($args{from}) {
	    my @from = ref $args{from} eq 'ARRAY' ? @{$args{from}} : $args{from};
	    my $last = pop @from;
	    if (@from) {
		$raw .= ' from ' . join (', ', @from) . " and $last";
	    } else {
		$raw .= " from $last";
	    }
	}
	$raw .= ".\n";
    }
    $raw .= "Any changes made here will be lost!\n";
    $raw .= $args{final} if $args{final};

    local $Text::Wrap::columns = 78;
    my $cooked = $args{lang} eq 'Perl'
	? wrap('# ', '# ', $raw) . "\n" : wrap('/* ', $style, $raw) . " */\n\n";
    $cooked =~ tr/\0/ /; # Don't break Larry's name etc
    $cooked =~ s/ +$//mg; # Remove all trailing spaces
    return $cooked;
}

sub read_only_bottom {
    my ($sources, $lang) = @_;

    my $comment;
    if ($sources) {
	$comment = "Generated from:\n";
	foreach my $file (sort @$sources) {
	    my $digest = digest($file);
	    $comment .= "$digest $file\n";
	}
    }
    $comment .= "ex: set ro:";

    if (defined $lang && $lang eq 'Perl') {
	$comment =~ s/^/# /mg;
    } else {
	$comment =~ s/^/ * /mg;
	$comment =~ s! \* !/* !;
	$comment .= " */";
    }
    return "$comment\n";
}

sub read_only_bottom_close_and_rename {
    my ($fh, $sources) = @_;
    my $name = *{$fh}->{name};
    my $lang = *{$fh}->{lang};
    die "No final name specified at open time for $name"
	unless *{$fh}->{final_name};

    print $fh "\n", read_only_bottom($sources, $lang);

    close_and_rename($fh);
}

sub tab {
    my ($l, $t) = @_;
    $t .= "\t" x ($l - (length($t) + 1) / 8);
    $t;
}

sub digest {
    my $file = shift;
    # Need to defer loading this, as the main regen scripts work back to 5.004,
    # and likely we don't even have this module on every 5.8 install yet:
    require Digest::SHA;

    local ($/, *FH);
    open FH, "$file" or die "Can't open $file: $!";
    my $raw = <FH>;
    close FH or die "Can't close $file: $!";
    return Digest::SHA::sha256_hex($raw);
};

1;
