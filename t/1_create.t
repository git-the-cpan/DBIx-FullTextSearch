
use strict;
use vars qw! $dbh !;

$^W = 1;

require 't/test.lib';

print "1..51\n";

use DBIx::FullTextSearch;

print "ok 1\n";

print "For each test we will drop all _fts_test% tables.\n";

sub drop_all_tables {
	for my $tableref (@{$dbh->selectall_arrayref('show tables')}) {
		next unless $tableref->[0] =~ /^_fts_test/;
		print "Dropping $tableref->[0]\n";
		$dbh->do("drop table $tableref->[0]");
		}
	}

sub test_one_type {
	my ($testnum, $description, $parameters_arrayref,
				$result_tables_hashref, $sql_command) = @_;
	drop_all_tables();
	if (defined $sql_command) {
		if (ref $sql_command eq 'ARRAY') {
			for my $c (@$sql_command) {
				$dbh->do($c) or print $dbh->errstr, "\nnot ";
				print "ok $testnum\n";
				$testnum++;
				}
			}
		else {
			$dbh->do($sql_command) or print $dbh->errstr, "\nnot ";
			print "ok $testnum\n";
			$testnum++;
			}
		}

	print "Creating DBIx::FullTextSearch with $description\n";

	my $fts = DBIx::FullTextSearch->create($dbh, '_fts_test', @$parameters_arrayref)
		or do {
			print "$DBIx::FullTextSearch::errstr\nnot ok $testnum\n";
			for (keys %$result_tables_hashref) {
				$testnum++;
				print "ok $testnum #skip\n";
				}
			return;
			};
	print "ok $testnum\n";

	for my $table (sort keys %$result_tables_hashref) {
		print "Testing if table $table was created ok\n";
		$testnum++;
		my $info = $dbh->selectall_arrayref("show columns from $table");
		if ($info and @$info) {
			local $^W = 0;
			my $textinfo = join "\n", (map { join ' ', @{$_}[0 .. 4] } @$info), '';
			$textinfo =~ s/PRI\s*?\n/PRI 0\n/g;
			my $expected = $result_tables_hashref->{$table};
			$expected =~ s/\|$//mg;
			if ($textinfo ne $expected) {
				print "Got:\n${textinfo}Expected:\n${expected}not ";
				}
			}
		else { print 'not '; }
		print "ok $testnum\n";
		}

	print "Test if all created tables were tested.\n";
	my $ok = 1;
	for my $tableref (@{$dbh->selectall_arrayref('show tables')}) {
		next unless $tableref->[0] =~ /^_fts_test/;
		if (not defined $result_tables_hashref->{$tableref->[0]}) {
			print "Strange, a table $tableref->[0] was created that we know nothing about\n";
			$ok = 0;
			}
		}
	print 'not ' unless $ok;
	$testnum++;
	print "ok $testnum\n";
	$fts->drop;
	}

test_one_type(2, 'default parameters (packed document lists)', [],
	{ '_fts_test' => <<EOF,
param varchar(16) binary  PRI 0|
value varchar(255) YES  |
EOF
	'_fts_test_data' => <<EOF,
word varchar(30) binary  PRI 0|
idx longblob   |
EOF
	});



test_one_type(6, 'column backend (unpacked document lists using indexes)',
	[ 'backend' => 'column' ],
	{ '_fts_test' => <<EOF,
param varchar(16) binary  PRI 0|
value varchar(255) YES  |
EOF
	'_fts_test_data' => <<EOF,
word_id smallint(5) unsigned  MUL 0|
doc_id smallint(5) unsigned  MUL 0|
count tinyint(3) unsigned YES  |
EOF
	'_fts_test_words' => <<EOF,
word varchar(30) binary  UNI |
id smallint(5) unsigned  PRI 0|
EOF
	});


test_one_type(11, 'column backend with unstandard storage widths',
	[ 'backend' => 'column', 'doc_id_bits' => 32,
		'word_id_bits' => 8, 'count_bits' => 24 ],
	{ '_fts_test' => <<EOF,
param varchar(16) binary  PRI 0|
value varchar(255) YES  |
EOF
	'_fts_test_data' => <<EOF,
word_id tinyint(3) unsigned  MUL 0|
doc_id int(10) unsigned  MUL 0|
count mediumint(8) unsigned YES  |
EOF
	'_fts_test_words' => <<EOF,
word varchar(30) binary  UNI |
id tinyint(3) unsigned  PRI 0|
EOF
	});



test_one_type(16, 'column backend and string frontend',
	[ 'backend' => 'column', 'frontend' => 'string',
		'count_bits' => 16, 'name_length' => 63 ],
	{ '_fts_test' => <<EOF,
param varchar(16) binary  PRI 0|
value varchar(255) YES  |
EOF
	'_fts_test_data' => <<EOF,
word_id smallint(5) unsigned  MUL 0|
doc_id smallint(5) unsigned  MUL 0|
count smallint(5) unsigned YES  |
EOF
	'_fts_test_words' => <<EOF,
word varchar(30) binary  UNI |
id smallint(5) unsigned  PRI 0|
EOF
	'_fts_test_docid' => <<EOF,
name varchar(63) binary  UNI |
id smallint(5) unsigned  PRI 0|
EOF

	});


test_one_type(22, 'blob backend and string frontend',
	[ 'backend' => 'blob', 'frontend' => 'string',
		'word_length' => 34 ],
	{ '_fts_test' => <<EOF,
param varchar(16) binary  PRI 0|
value varchar(255) YES  |
EOF
	'_fts_test_data' => <<EOF,
word varchar(34) binary  PRI 0|
idx longblob   |
EOF
	'_fts_test_docid' => <<EOF,
name varchar(255) binary  UNI |
id smallint(5) unsigned  PRI 0|
EOF
	});


test_one_type(27, 'blob backend and string frontend, null count info',
	[ 'backend' => 'blob', 'frontend' => 'string',
		'word_length' => 20, 'name_length' => 16,
		'count_bits' => 0, 'doc_id_bits' => 24  ],
	{ '_fts_test' => <<EOF,
param varchar(16) binary  PRI 0|
value varchar(255) YES  |
EOF
	'_fts_test_data' => <<EOF,
word varchar(20) binary  PRI 0|
idx longblob   |
EOF
	'_fts_test_docid' => <<EOF,
name varchar(16) binary  UNI |
id mediumint(8) unsigned  PRI 0|
EOF
	});


test_one_type(32, 'column backend and string frontend, null count info',
	[ 'backend' => 'column', 'frontend' => 'string',
		'word_length' => 20, 'name_length' => 6,
		'count_bits' => 0, 'doc_id_bits' => 24  ],
	{ '_fts_test' => <<EOF,
param varchar(16) binary  PRI 0|
value varchar(255) YES  |
EOF
	'_fts_test_data' => <<EOF,
word_id smallint(5) unsigned  MUL 0|
doc_id mediumint(8) unsigned  MUL 0|
EOF
	'_fts_test_words' => <<EOF,
word varchar(20) binary  UNI |
id smallint(5) unsigned  PRI 0|
EOF
	'_fts_test_docid' => <<EOF,
name varchar(6) binary  UNI |
id mediumint(8) unsigned  PRI 0|
EOF
	});


test_one_type(38, 'column backend and table (_fts_test_the_table) frontend',
	[ 'backend' => 'column', 'frontend' => 'table',
		'table_name' => '_fts_test_the_table',
		'column_name' => 't_data'
		],
	{ '_fts_test' => <<EOF,
param varchar(16) binary  PRI 0|
value varchar(255) YES  |
EOF
	'_fts_test_data' => <<EOF,
word_id smallint(5) unsigned  MUL 0|
doc_id mediumint(8) unsigned  MUL 0|
count tinyint(3) unsigned YES  |
EOF
	'_fts_test_words' => <<EOF,
word varchar(30) binary  UNI |
id smallint(5) unsigned  PRI 0|
EOF
	'_fts_test_the_table' => <<EOF,
id mediumint(9)  PRI 0|
t_data varchar(255) YES  |
EOF
	},
	q!
	create table _fts_test_the_table (id mediumint not null,
			t_data varchar(255),
			primary key(id))
	!);


test_one_type(45, 'blob and table (_fts_test_the_table) with strings',
	[ 'frontend' => 'table',
		'table_name' => '_fts_test_the_table',
		'column_name' => 't_data', 'word_length' => '48'
		],
	{ '_fts_test' => <<EOF,
param varchar(16) binary  PRI 0|
value varchar(255) YES  |
EOF
	'_fts_test_data' => <<EOF,
word varchar(48) binary  PRI 0|
idx longblob   |
EOF
	'_fts_test_the_table' => <<EOF,
id varchar(16)  PRI 0|
t_data varchar(255) YES  |
EOF
	'_fts_test_docid' => <<EOF,
name varchar(16) binary  UNI |
id smallint(5) unsigned  PRI 0|
EOF
	},
	q!
	create table _fts_test_the_table (id varchar(16) not null,
			t_data varchar(255),
			primary key(id))
	!);

