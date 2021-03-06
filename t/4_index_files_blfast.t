
use strict;
use vars qw! $dbh !;

$^W = 1;

require 't/test.lib';

print "1..12\n";

use DBIx::FullTextSearch;
use Benchmark;

print "ok 1\n";


print "We will drop all the tables first\n";
for (qw! _fts_test _fts_test_data _fts_test_words _fts_test_docid !) {
	local $dbh->{'RaiseError'} = 0;
	local $dbh->{'PrintError'} = 0;
	$dbh->do("drop table $_");
	}

print "ok 2\n";

my $fts;


print "Creating DBIx::FullTextSearch index with file frontend\n";
$fts = DBIx::FullTextSearch->create($dbh, '_fts_test',
	'frontend' => 'file', 'backend' => 'blobfast') or print "$DBIx::FullTextSearch::errstr\nnot ";
print "ok 3\n";


my $DIR = 'test_data';
chdir $DIR or die "Cannot chdir to $DIR\n";

use Benchmark;

my ($t0, $t1);
$t0 = new Benchmark;

my ($totfiles, $totwords) = (0, 0);
opendir DIR, '.';
my @files = sort grep { -f $_ } readdir DIR;
closedir DIR;
$| = 1;
for my $file (@files) {
	print "$file: ";
	if (defined (my $ret = $fts->index_document($file))) {
		print "$ret\n";
		$totwords += $ret;
		$totfiles++;
		}
	else {
		print $fts->errstr, "\n";
		}
	}
$t1 = new Benchmark;
print "Indexing of $totfiles files ($totwords words) took\n    ", timestr(timediff($t1, $t0)), "\n";

print "ok 4\n";

my (@docs, $expected);
print "Calling contains('while')\n";
@docs = sort($fts->contains('while'));
print "Documents containing `while': @docs\n";
$expected = 'Index.modul Makefile.file Makefile.old.file Memo.modul MyConText.modul SQL.modul XBase.modul driver_characteristics dump';
print "expected $expected\nnot " unless "@docs" eq $expected;
print "ok 5\n";


print "Calling contains('genius')\n";
my @notfound = $fts->contains('genius');
print 'not ' if @notfound > 0;
print "ok 6\n";


print "Calling contains('whi*')\n";
@docs = sort($fts->contains('whi*'));
print "Documents containing `whi*': @docs\n";
$expected = 'Base.modul Changes.file Index.modul Makefile.file Makefile.old.file Memo.modul MyConText.modul SQL.modul XBase.modul driver_characteristics dump';
print "expected $expected\nnot " unless "@docs" eq $expected;
print "ok 7\n";

chdir '../test_data_empty' or die "Error chdirring to *_empty directory\n";
print "Remove document XBase.modul from index\n";
$t0 = new Benchmark;
if (not defined ($fts->index_document('XBase.modul'))) {
	print $fts->errstr, "\nnot ";
	}
print "ok 8\n";
$t1 = new Benchmark;
print 'Removing took ', timestr(timediff($t1, $t0)), "\n";


print "Calling contains('whi*')\n";
@docs = sort($fts->contains('whi*'));
print "Documents containing `whi*': @docs\n";
$expected = 'Base.modul Changes.file Index.modul Makefile.file Makefile.old.file Memo.modul MyConText.modul SQL.modul driver_characteristics dump';
print "expected $expected\nnot " unless "@docs" eq $expected;
print "ok 9\n";


chdir "../$DIR" or die "Error chdirring back to $DIR\n";
print "Indexing the XBase.modul back\n";
$t0 = new Benchmark;
if (not defined $fts->index_document('XBase.modul')) {
	print $fts->errstr, "\nnot ";
	}
print "ok 10\n";
$t1 = new Benchmark;
print 'Reindexing took ', timestr(timediff($t1, $t0)), "\n";


print "Calling contains('whi*')\n";
@docs = sort($fts->contains('whi*'));
print "Documents containing `whi*': @docs\n";
$expected = 'Base.modul Changes.file Index.modul Makefile.file Makefile.old.file Memo.modul MyConText.modul SQL.modul XBase.modul driver_characteristics dump';
print "expected $expected\nnot " unless "@docs" eq $expected;
print "ok 11\n";


print "Calling contains('zvirata')\n";
@docs = $fts->contains('zvirata');
print "Documents containing `zvirata': @docs\n";
$expected = 'XBase.modul';
print "expected $expected\nnot " unless "@docs" eq $expected;
print "ok 12\n";


