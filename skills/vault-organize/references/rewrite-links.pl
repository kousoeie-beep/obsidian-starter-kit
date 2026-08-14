#!/usr/bin/env perl
# パス付きリンク [[フォルダ/名前]] を [[名前]] に落とす。
# ただし同名ノートが存在する名前は、どれを指すか決められないのでパスを残す。
use strict;
use warnings;
use utf8;
binmode(STDOUT, ':encoding(UTF-8)');

my $dupfile = shift or die "usage: rewrite-links.pl <dupes.txt> <file...>\n";
open(my $dh, '<:encoding(UTF-8)', $dupfile) or die "cannot open $dupfile: $!";
my %dupes = map { chomp; ($_ => 1) } <$dh>;
close($dh);

my ($changed_files, $changed_links, $kept_links) = (0, 0, 0);

for my $file (@ARGV) {
    open(my $fh, '<:encoding(UTF-8)', $file) or next;
    local $/;
    my $text = <$fh>;
    close($fh);
    my $orig = $text;

    # [[パス/名前]] と [[パス/名前|表示]] の両方を扱う
    $text =~ s{\[\[([^\]\|#]*?/)([^\]\|#/]+)((?:\|[^\]]*)?)\]\]}{
        my ($path, $name, $alias) = ($1, $2, $3);
        if (exists $dupes{$name}) {
            $kept_links++;
            "[[$path$name$alias]]";          # 同名あり → そのまま
        } else {
            $changed_links++;
            "[[$name$alias]]";               # パスを落とす
        }
    }ge;

    if ($text ne $orig) {
        open(my $out, '>:encoding(UTF-8)', $file) or die "cannot write $file: $!";
        print $out $text;
        close($out);
        $changed_files++;
    }
}

print "  書き換えたファイル: $changed_files\n";
print "  パスを落としたリンク: $changed_links\n";
print "  同名のため残したリンク: $kept_links\n";
