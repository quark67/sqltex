################################################################################
#
# SQLTeX - SQL preprocessor for Latex
#
# File:		SQLTeX
# =====
#
# Purpose:	This script is a preprocessor for LaTeX. It reads a LaTeX file
# ========	containing SQL commands, and replaces them their values.
#
# This software is subject to the terms of the LaTeX Project Public License; 
# see http://www.ctan.org/tex-archive/help/Catalogue/licenses.lppl.html.
#
# Copyright:  (c) 2001-2015, Oscar van Eijk, Oveas Functionality Provider
# ==========                 oscar@oveas.com
#
################################################################################
#
use strict;
use DBI;
use Getopt::Std;

#####
# Find out if any command-line options have been given
# Parse them using 'Getopt'
#
sub parse_options {

	$main::NULLallowed = 0;

	if (!getopts ('c:E:NPU:Ve:fhmo:p:r:qs:u', \%main::options)) {
		print (&short_help (1));
		exit(1);
	}

	if (defined $main::options{'h'}) {
		&print_help;
		exit(0);
	}
	if (defined $main::options{'V'}) {
		&print_version;
		exit(0);
	}

	my $optcheck = 0;
	$optcheck++ if (defined $main::options{'E'});
	$optcheck++ if (defined $main::options{'e'});
	$optcheck++ if (defined $main::options{'o'});
	die ("options \"-E\", \"-e\" and \"-o\" cannot be combined\n") if ($optcheck > 1);

	$optcheck = 0;
	$optcheck++ if (defined $main::options{'m'});
	$optcheck++ if (defined $main::options{'o'});
	die ("options \"-m\" and \"-o\" cannot be combined\n") if ($optcheck > 1);

	$main::NULLallowed = 1 if (defined $main::options{'N'});
	$main::configuration{'cmd_prefix'} = $main::options{'p'} if (defined $main::options{'p'});

	$main::multidoc_cnt = 0;
	$main::multidoc = (defined $main::options{'m'});
	$main::multidoc_id = '';

	if ($main::multidoc) {
		$main::multidoc_id = '_#M#';
	}

}

#####
# Print the Usage: line on errors and after the '-h' switch
#
sub short_help ($) {
	my $onerror = shift;
	my $helptext = "usage: $main::myself [-cENPUVefhmopqs] <file[.$main::configuration{'texex'}]> [parameter...]\n";
	$helptext .= "       type \"$main::myself -h\" for help\n" if ($onerror);
	return ($helptext);
}


#####
# Print full help and after the '-h' switch
#
sub print_help {
	my $helptext = &short_help (0);
	$helptext .= "       Options:\n";
	$helptext .= "       -c file       SQLTeX configuration file.\n";
	$helptext .= "                     Default is \'$main::my_location/SQLTeX.cfg\'.\n";
	$helptext .= "       -E string     replace input file extension in outputfile:\n";
	$helptext .= "                     \'input.tex\' will be \'input.string\'\n";
	$helptext .= "                     For further notes, see option \'-e\' below\n";
	$helptext .= "       -N            NULL return values allowed. By default SQLTeX\n";
	$helptext .= "                     exits if a query returns an empty set\n";
	$helptext .= "       -P            prompt for database password\n";
	$helptext .= "       -U user       database username\n";
	$helptext .= "       -V            print version number and exit\n";
	$helptext .= "       -e string     add string to the output filename:\n";
	$helptext .= "                     \'input.tex\' will be \"inputstring.tex\"\n";
	$helptext .= "                     In \'string\', the values between curly braces \{\}\n";
	$helptext .= "                       will be substituted:\n";
	$helptext .= "                       Pn      parameter n\n";
	$helptext .= "                       M       current monthname (Mon)\n";
	$helptext .= "                       W       current weekday (Wdy)\n";
	$helptext .= "                       D       current date (yyyymmdd)\n";
	$helptext .= "                       DT      current date and time (yyyymmddhhmmss)\n";
	$helptext .= "                       T       current time (hhmmss)\n";
	$helptext .= "                     e.g., the command \'$main::myself -e _{P1}_{W} my_file code\'\n";
	$helptext .= "                     will read \'my_file.tex\' and write \'myfile_code_Tue.tex\'\n";
	$helptext .= "                     The same command, but with option \'-E\' would create the\n";
	$helptext .= "                     outputfile \'myfile._code_Tuesday\'\n";
	$helptext .= "                     By default (without \'-e\' or \'-E\') the outputfile\n";
	$helptext .= "                     \'myfile_stx.tex\' would have been written.\n";
	$helptext .= "                     The options \'-E\' and \'-e\' cannot be used together or with \'-o\'.\n";
	$helptext .= "       -f            force overwrite of existing files\n";
	$helptext .= "       -h            print this help message and exit\n";
	$helptext .= "       -m            Multidocument mode; create one document for each parameter that is\n";
	$helptext .= "                     retrieved from the database in the input document (see documentation)\n";
	$helptext .= "                     This option cannot be used with \'-o\'.\n";
	$helptext .= "       -o file       specify an output file. Cannot be used with \'-E\' or \'-e\'\n";
	$helptext .= "                     This option cannot be used with \'-m\'.\n";
	$helptext .= "       -p prefix     prefix used in the SQLTeX file. Default is \'sql\'\n";
	$helptext .= "                     (e.g. \\sqldb[user]{database}), but this can be overwritten\n";
	$helptext .= "                     if it conflicts with other user-defined commands.\n";
	$helptext .= "       -q            run in quiet mode\n";
	$helptext .= "       -r file       specify a file that contains replace characters. This is a list with\n";
	$helptext .= "                     two tab- seperated fields per line. The first field holds a string\n";
	$helptext .= "                     that will be replaced in the SQL output by the second string.\n";
	$helptext .= "                     By default the file \'$main::my_location/SQLTeX_r.dat\' is used.\n";
	$helptext .= "         -rn         do not use a replace file. -r file and -rn are handled in the same\n";
	$helptext .= "                     as they where specified on the command line.\n";
	$helptext .= "       -s server     SQL server to connect to. Default is \'localhost\'\n";
	$helptext .= "       -u            If the input file contains updates, execute them.\n";

	$helptext .= "\n       file          is the input file that should be read. By default,\n";
	$helptext .= "                     $main::myself looks for a file with extension \'.$main::configuration{'texex'}\'.\n";
	$helptext .= "\n       parameter(s)  are substituted in the SQL statements if they contain\n";
	$helptext .= "                     the string \$PAR[x] somewhere in the statement, where\n";
	$helptext .= "                     \'x\' is the number of the parameter.\n";

	if ($main::configuration{'less_av'}) {
		system ("echo \"$helptext\" | less");
	} elsif ($main::configuration{'more_av'}) {
		system ("echo \"$helptext\" | more");
	} else {
		print $helptext;
	}
}

#####
# Print the version number
#
sub print_version {
	print "$main::myself v$main::version - $main::rdate\n";
}

#####
# If we're not running in quiet mode (-q), this routine prints a message telling
# the user what's going on.
#
sub print_message ($) {
	my $message = shift;
	print "$message\n" unless (defined $main::options{'q'});
}


#####
# If we have to prompt for a password, disable terminal echo, get the password
# and return it to the caller
#
sub get_password ($$) {
	my ($usr, $srv) = @_;

	print "Password for $usr\@$srv : ";

	system('stty -echo');
	my $pwd = <STDIN>;
	chomp $pwd;
	system('stty echo');
	print "\n";

	return $pwd;
}

#######
# Find the file extension for the outputfile
#
sub file_extension ($) {
	my $subst = shift;

	my %mn = ('Jan','01', 'Feb','02', 'Mar','03', 'Apr','04',
		  'May','05', 'Jun','06', 'Jul','07', 'Aug','08',
		  'Sep','09', 'Oct','10', 'Nov','11', 'Dec','12' );
	my $sydate = localtime (time);
	my ($wday, $mname, $dnum, $time, $year) = split(/\s+/,$sydate);
	$dnum = "0$dnum" if ($dnum < 10);
	while ($subst =~ /\{[a-zA-Z0-9]+\}/) {
		my $s1  = $`;
		my $sub = $&;
		my $s2  = $';
		$sub =~ s/[\{\}]//g;
		if ($sub =~ /P[0-9]/) {
			$sub =~ s/P//;
			die ("insuficient parameters to substitute \{P$sub\}\n") if ($sub > $#ARGV);
			$sub = $ARGV[$sub];
		} elsif ($sub eq 'M') {
			$sub = $mname;
		} elsif ($sub eq 'W') {
			$sub = $wday;
		} elsif ($sub eq 'D') {
			$sub = "$year$mn{$mname}$dnum";
		} elsif ($sub eq 'DT') {
			$sub = "$year$mn{$mname}$dnum$time";
			$sub =~ s/://g;
		} elsif ($sub eq 'T') {
			$sub = $time;
			$sub =~ s/://g;
		} else  {
			die ("unknown substitution code \{$sub\}\n");
		}
		$subst = "$s1$sub$s2";
	}
	return ($subst);
}

#####
# Declare the filenames to use in this run.
# If a file has been entered 
#
sub get_filenames {
	$main::inputfile = $ARGV[0] || die "no input file specified\n";

	$main::path = '';
	while ($main::inputfile =~ /\//) {
		$main::path .= "$`/";
		$main::inputfile =~ s/$`\///;
	}
	if ($main::inputfile =~/\./) {
		if ((!-e "$main::path$main::inputfile") && (-e "$main::path$main::inputfile.$main::configuration{'texex'}")) {
			$main::inputfile .= ".$main::configuration{'texex'}";
		}
	} else {
		$main::inputfile .= ".$main::configuration{'texex'}"
	} 
	die "File $main::path$main::inputfile does not exist\n" if (!-e "$main::path$main::inputfile");

	if (!defined $main::options{'o'}) {
		$main::inputfile =~ /\./;
		$main::outputfile = "$`";
		my $lastext = "$'";
		while ($' =~ /\./) {
			$main::outputfile .= ".$`";
			$lastext = "$'";
		}
		if (defined $main::options{'E'} || defined $main::options{'e'}) {
			$main::configuration{'stx'} = &file_extension ($main::options{'E'} || $main::options{'e'});
		}
		if (defined $main::options{'E'}) {
			$main::outputfile .= "$main::multidoc_id.$main::configuration{'stx'}";
		} else {
			$main::outputfile .= "$main::configuration{'stx'}$main::multidoc_id\.$lastext";
		}
	} else {
		$main::outputfile = $main::options{'o'};
	}

	if (defined $main::options{'c'}) {
		$main::configurationfile = $main::options{'c'};
	} else {
		$main::configurationfile = "$main::my_location/SQLTeX.cfg";
	}
	if (!-e $main::configurationfile) {
		die ("Configfile $main::configurationfile does not exist\n");
	}
	
	if (defined $main::options{'r'}) {
		$main::replacefile = $main::options{'r'};
	} else {
		$main::replacefile = "$main::my_location/SQLTeX_r.dat";
	}
	if (!-e $main::replacefile) {
		warn ("replace file $main::replacefile does not exist\n") unless ($main::replacefile eq "n");
		undef $main::replacefile;
	}
	

	return;
}

#######
# Connect to the database
#
sub db_connect($$) {
	my ($up, $db) = @_;
	my $data_source;

	$main::line =~ s/\[?$up\]?\{$db\}//;

	my $un = '';
	my $pw = '';
	my $hn = '';
	my @opts = split(',', $up);
	for(my $idx = 0; $idx <= $#opts; $idx++) {
		my $opt = $opts[$idx];
		if ($opt =~ /=/) {
			if ($` eq 'user') {
				$un = $';
			} elsif ($` eq 'passwd') {
				$pw = $';
			} elsif ($` eq 'host') {
				$hn = $';
			}
		} else {
			if ($idx == 0) {
				$un = $opt;
			} elsif ($idx == 1) {
				$pw = $opt;
			} elsif ($idx == 2) {
				$hn = $opt;
			}
		}
	}

	$un = $main::options{'U'} if (defined $main::options{'U'});
	$pw = &get_password ($un, $main::options{'s'} || 'localhost') if (defined $main::options{'P'});
	$hn = $main::options{'s'} if (defined $main::options{'s'});

	if ($main::configuration{'dbdriver'} eq "Pg") {
		$data_source = "DBI:$main::configuration{'dbdriver'}:dbname=$db";
		$data_source .= ";host=$hn" unless ($hn eq "");
	} elsif ($main::configuration{'dbdriver'} eq "Oracle") {
		$data_source = "DBI:$main::configuration{'dbdriver'}:$db";
		$data_source .= ";host=$hn;sid=$main::configuration{'oracle_sid'}" unless ($hn eq "");
		$data_source .= ";sid=$main::configuration{'oracle_sid'}";
	} elsif ($main::configuration{'dbdriver'} eq "Ingres") {
		$data_source = "DBI:$main::configuration{'dbdriver'}";
		$data_source .= ":$hn" unless ($hn eq "");
		$data_source .= ":$db";
	} elsif ($main::configuration{'dbdriver'} eq "Sybase") {
		$data_source = "DBI:$main::configuration{'dbdriver'}:$db";
		$data_source .= ";server=$hn" unless ($hn eq "");
	} else { # MySQL, mSQL, ...
		$data_source = "DBI:$main::configuration{'dbdriver'}:database=$db";
		$data_source .= ";host=$hn" unless ($hn eq "");
	}

	if (!defined $main::options{'q'}) {
		my $msg = "Connect to database $db on ";
		$msg .= $hn|| 'localhost';
		$msg .= " as user $un" unless ($un eq '');
		$msg .= " using a password" unless ($pw eq '');
		&print_message ($msg);
	}

	$main::db_handle = DBI->connect ($data_source, $un, $pw, { RaiseError => 0, PrintError => 1 }) || &just_died (1);
	return;
}

#####
# Execute the SQL query and return the result in an array
#
sub execute_query ($) {
	my $query = shift;
	my (@result, @res);
	return @result;
}

#####
# Check if the SQL statement contains options
# Supported options are:
#   setvar=<i>, where <i> is the list location to store the variable.
#   setarr=<i>
#
sub check_options ($) {
	my $options = shift;
	return if ($options eq '');
	$options =~ s/\[//;
	$options =~ s/\]//;

	my @optionlist = split /,/, $options;
	while (@optionlist) {
		my $opt = shift @optionlist;
		if ($opt =~ /^setvar=/i) {
			$main::var_no = $';
			$main::setvar = 1;
		}
		if ($opt =~ /^setarr=/i) {
			$main::arr_no = $';
			$main::setarr = 1;
		}
		if ($opt =~ /^fldsep=/i) {
			$main::fldsep = qq{$'};
			if ($main::fldsep eq 'NEWLINE') {
				$main::fldsep = "\n";
			}
		}
		if ($opt =~ /^rowsep=/i) {
			$main::rowsep = qq{$'};
			if ($main::rowsep eq 'NEWLINE') {
				$main::rowsep = "\n";
			}
		}
	}
}

#####
# Replace values from the query result as specified in the replace files.
# This is done in two steps, to prevent characters from being replaces again
# if they occus both as key and as value.
#
sub replace_values ($) {
	my $sqlresult = shift;
	my $rk;

	foreach $rk (@main::repl_order) {
		$sqlresult =~ s/\Q$rk\E/$main::repl_key{$rk}/g;
	}

	foreach $rk (keys %main::repl_key) {
		$sqlresult =~ s/$main::repl_key{$rk}/$main::repl_val{$main::repl_key{$rk}}/g;
	}
	return ($sqlresult);
}

#####
# Select multiple rows from the database. This function can have
# the [fldsep=s] and [rowsep=s] options to define the string which
# should be used to seperate the fields and rows.
# By default, fields are seperated with a comma and blank (', '), and rows
# are seperated with a newline character ('\\')
#
sub sql_row ($$) {
	my ($options, $query) = @_;
	local $main::fldsep = ', ';
	local $main::rowsep = "\\\\";
	local $main::setarr = 0;	
	my (@values, @return_values, $rc, $fc);

	&check_options ($options);

	&print_message ("Retrieving row(s) with \"$query\"");
	$main::sql_statements++;
	my $stat_handle = $main::db_handle->prepare ($query);
	$stat_handle->execute ();

	if ($main::setarr) {
		&just_died (7) if (defined $main::arr[$main::arr_no]);
		@main::arr[$main::arr_no] = ();
		while (my $ref = $stat_handle->fetchrow_hashref()) {
			foreach my $k (keys %$ref) {
				$ref->{$k}  = replace_values ($ref->{$k});
			}
			push @{$main::arr[$main::arr_no]},$ref;
		}
		$stat_handle->finish ();
		return ();
	}
	
	while (@values = $stat_handle->fetchrow_array ()) {
		$fc = $#values + 1;
		if (defined $main::replacefile) {
			my $list_cnt = 0;
			foreach (@values) {
				$values[$list_cnt] = replace_values ($values[$list_cnt]);
				$list_cnt++;
			}
		}
		push @return_values, (join "$main::fldsep", @values);
	}
	$stat_handle->finish ();

	if ($#return_values < 0) {
		&just_died (4);
	}

	$rc = $#return_values + 1;
	if ($rc == 1) {
		&print_message ("Found $rc row with $fc field(s)");
	} else {
		&print_message ("Found $rc rows with $fc fields each");
	}

	return (join "$main::rowsep", @return_values);

}


#####
# Select a single field from the database. This function can have
# the [setvar=n] option to define an internal variable
#
sub sql_field ($$) {
	my ($options, $query) = @_;
	local $main::setvar = 0;

	&check_options ($options);

	$main::sql_statements++;

	&print_message ("Retrieving field with \"$query\"");
	my $stat_handle = $main::db_handle->prepare ($query);
	$stat_handle->execute ();
	my @result = $stat_handle->fetchrow_array ();
	$stat_handle->finish ();

	if ($#result < 0) {
		&just_died (4);
	} elsif ($#result > 0) {
		&just_died (5);
	} else {
		&print_message ("Found 1 value: \"$result[0]\"");
		if ($main::setvar) {
			&just_died (7) if (defined $main::var[$main::var_no]);
			$main::var[$main::var_no] = $result[0];
			return '';
		} else {
			if (defined $main::replacefile) {
				return (replace_values ($result[0]));
			} else {
				return ($result[0]);
			}
		}
	}
}

#####
# Start a section that will be repeated for evey row that is on stack
#
sub sql_start ($) {
	my $arr_no = shift;
	&just_died (11) if (!defined $main::arr[$arr_no]);
	if (@main::current_array) {
		@main::current_array = ();
	}
	@main::loop_data = ();
	push @main::current_array,$arr_no;
}

#####
# Stop processing the current array
#
sub sql_use ($$) {
	my ($field, $loop) = @_;
	return $main::arr[$#main::current_array][$loop]->{$field};
}


#####
# Stop processing the current array
#
sub sql_end () {
	my $result = '';

	for (my $cnt = 0; $cnt < $#{$main::arr[$#main::current_array]}; $cnt++) {
		for (my $lines = 0; $lines < $#{$main::loop_data[$#main::current_array]}; $lines++) {
			my $buffered_line = ${$main::loop_data[$#main::current_array]}[$lines];
			my $cmdPrefix = $main::configuration{'alt_cmd_prefix'};
			while (($buffered_line  =~ /\\$cmdPrefix[a-z]+(\[|\{)/) && !($buffered_line  =~ /\\\\$cmdPrefix[a-z]+(\[|\{)/)) {
				my $cmdfound = $&;
				$cmdfound =~ s/\\//;

				$buffered_line  =~ /\\$cmdfound/;
				my $lin1 = $`;
				$buffered_line = $';
				$buffered_line =~ /\}/;
				my $statement = $`;
				my $lin2 = $';
			 	if ($cmdfound =~ /$main::configuration{'sql_use'}/) {
					$buffered_line = $lin1 . &sql_use($statement, $cnt) . $lin2;
				}
		 	}
		 	$result .= $buffered_line;
		}
	}
	
	pop @main::current_array;
	return $result;
}



#####
# Select a (list of) single field(s) from the database. This list is used in
# multidocument mode as the first parameter in all queries.
# Currently, only 1 parameter per run is supported.
#
sub sql_setparams ($$) {
	my ($options, $query) = @_;
	my (@values, @return_values, $rc);

	&check_options ($options);

	&print_message ("Retrieving parameter list with \"$query\"");
	$main::sql_statements++;
	my $stat_handle = $main::db_handle->prepare ($query);
	$stat_handle->execute ();

	while (@values = $stat_handle->fetchrow_array ()) {
		&just_died (9) if ($#values > 0); # Only one allowed
		push @return_values, @values;
	}
	$stat_handle->finish ();

	if ($#return_values < 0) {
		&just_died (8);
	}

	$rc = $#return_values + 1;
	&print_message ("Multidocument parameters found; $rc documents will be created");

	return (@return_values);
}


#####
# Select a (list of) single field(s) from the database. This list is used in
# multidocument mode as the first parameter in all queries.
# Currently, only 1 parameter per run is supported.
#
sub sql_update ($$) {
	my ($options, $query) = @_;
	local $main::setvar = 0;

	if (!defined $main::options{'u'}) {
		&print_message ("Updates will be ignored");
		return;
	}
	&check_options ($options);

	&print_message ("Updating values with \"$query\"");
	my $rc = $main::db_handle->do($query);
	&print_message ("$rc rows updated");
}

##### 
# Some error handling (mainly cleanup stuff)
# Files will be closed if opened, and if no sql output was written yet,
# the outputfile will be removed.
#
sub just_died ($) {
	my $step = shift;
	my $Resurect = 0;

	$Resurect = 1 if ($step == 4 && $main::NULLallowed);

	if ($step >= 1 && !$Resurect) {
		close FI;
		close FO;
	}
	if ($step > 2 && !$Resurect) {
		$main::db_handle->disconnect();
	}
	if ($step >= 1 && $step <= 2 && !$Resurect) {
		unlink ("$main::path$main::outputfile");
	}

	#####
	# Step specific exit
	#
	if ($step == 2) {
		warn ("no database opened at line $main::lcount\n");
	} elsif ($step == 3) {
		warn ("insufficient parameters to substitute variable on line $main::lcount\n");
	} elsif ($step == 4) {
		warn ("no result set found on line $main::lcount\n");
	} elsif ($step == 5) {
		warn ("result set too big on line $main::lcount\n");
	} elsif ($step == 6) {
		warn ("trying to substitute with non existing on line $main::lcount\n");
	} elsif ($step == 7) {
		warn ("trying to overwrite an existing variable on line $main::lcount\n");
	} elsif ($step == 8) {
		warn ("no parameters for multidocument found on line $main::lcount\n");
	} elsif ($step == 9) {
		warn ("too many fields returned in multidocument mode on $main::lcount\n");
	} elsif ($step == 10) {
		warn ("unrecognized command on line $main::lcount\n");
	} elsif ($step == 11) {
		warn ("start using a non-existing array on line $main::lcount\n");
	} elsif ($step == 12) {
		warn ("\\sqluse command encountered outside looop context on line $main::lcount\n");
	}
	return if ($Resurect);
	exit (1);
}

#####
# An SQL statement was found in the input file. If multiple lines are
# used for this query, they will be read until the '}' is found, after which
# the query will be executed.
#
sub parse_command ($$) {
	my $cmdfound = shift;
	my $multidoc_par = shift;
	my $options = '';
	my $varallowed = 1;

	$varallowed = 0 if ($cmdfound =~ /$main::configuration{'sql_open'}/);

	chop $cmdfound;
	$cmdfound =~ s/\\//;

	$main::line =~ /\\$cmdfound/;
	my $lin1 = $`;
	$main::line = $';

	while (!($main::line =~ /\}/)) {
		chomp $main::line;
		$main::line .= ' ';
		$main::line .= <FI>;
		$main::lcount++;
	}

	$main::line =~ /\}/;
	my $statement = $`;
	my $lin2 = $';

	$statement =~ s/(\[|\{)//g;
	if ($statement =~ /\]/) {
		$options = $`;
		$statement = $';
	}

	if ($varallowed) {
		if (($main::multidoc_cnt > 0) && $main::multidoc) {
			$statement =~ s/\$PAR1/$multidoc_par/g;
		} else {
			for (my $i = 1; $i <= $#ARGV; $i++) {
				$statement =~ s/\$PAR$i/$ARGV[$i]/g;
			}
		}
		while ($statement =~ /\$VAR[0-9]/) {
			my $varno = $&;
			$varno =~ s/\$VAR//;
			&just_died (6) if (!defined ($main::var[$varno]));
			$statement =~ s/\$VAR$varno/$main::var[$varno]/g;
		}
		&just_died (3) if ($statement =~ /\$PAR/);
		$statement =~ s/\{//;
	}

	if ($cmdfound =~ /$main::configuration{'sql_open'}/) {
		&db_connect($options, $statement);
		$main::db_opened = 1;
		return 0;
	}

	&just_died (2) if (!$main::db_opened);

	if ($cmdfound =~ /$main::configuration{'sql_field'}/) {
		$main::line = $lin1 . &sql_field($options, $statement) . $lin2;
	} elsif ($cmdfound =~ /$main::configuration{'sql_row'}/) {
		$main::line = $lin1 . &sql_row($options, $statement) . $lin2;
	} elsif ($cmdfound =~ /$main::configuration{'sql_params'}/) {
		if ($main::multidoc) { # Ignore otherwise
			@main::parameters = &sql_setparams($options, $statement);
			$main::line = $lin1 . $lin2;
			return 1; # Finish this run
		} else {
			$main::line = $lin1 . $lin2;
		}
	} elsif ($cmdfound =~ /$main::configuration{'sql_update'}/) {
		&sql_update($options, $statement);
		$main::line = $lin1 . $lin2;
	} elsif ($cmdfound =~ /$main::configuration{'sql_start'}/) {
		&sql_start($statement);
		$main::line = $lin1 . $lin2;
	} elsif ($cmdfound =~ /$main::configuration{'sql_use'}/) {
		&just_died (12) if (!@main::current_array);
		$main::line = $lin1 . "\\" . $main::configuration{'alt_cmd_prefix'} . $main::configuration{'sql_use'} . "{" . $statement . "}" . $lin2; # Restore the line, will be processed later
	} elsif ($cmdfound =~ /$main::configuration{'sql_end'}/) {
		$main::line = $lin1 . &sql_end() . $lin2;
	} else {
		&just_died (10);
	}

	return 0;
}

#####
# Process the input file
# When multiple documents should be written, this routine is
# multiple times.
# The first time, it only builds a list with parameters that will be
# used for the next executions
#
sub process_file {
	my $multidoc_par = '';

	if ($main::multidoc && ($main::multidoc_cnt > 0)) {
		$main::saved_outfile_template = $main::outputfile if ($main::multidoc_cnt == 1); # New global name; should be a static
		$main::outputfile = $main::saved_outfile_template if ($main::multidoc_cnt > 1);
		$main::outputfile =~ s/\#M\#/$main::multidoc_cnt/;
		$multidoc_par = @main::parameters[$main::multidoc_cnt - 1];
	}

	open (FI, "<$main::path$main::inputfile");
	open (FO, ">$main::path$main::outputfile") unless ($main::multidoc && ($main::multidoc_cnt == 0));

	$main::sql_statements = 0;
	$main::db_opened = 0;
	$main::lcount = 0;

	while ($main::line = <FI>) {
		$main::lcount++;

		my $cmdPrefix = $main::configuration{'cmd_prefix'};
		while (($main::line =~ /\\$cmdPrefix[a-z]+(\[|\{)/) &&
		 !($main::line =~ /\\\\$cmdPrefix[a-z]+(\[|\{)/)) {
			if (&parse_command($&, $multidoc_par) && $main::multidoc && ($main::multidoc_cnt == 0)) {
				$main::multidoc_cnt++; # Got the input data, next run writes the first document
				close FI;
				return;
			}
		}
		if (@main::current_array && $#main::current_array >= 0) {
			push @{$main::loop_data[$#main::current_array]}, $main::line;
		} else {	
			print FO "$main::line" unless ($main::multidoc && ($main::multidoc_cnt == 0));
		}
	}

	if ($main::multidoc) {
		$main::multidoc = 0 if (($main::multidoc_cnt++) > $#main::parameters);
	}

	close FI;
	close FO;
}

## Main:

#####
# Default config values, will be overwritten with SQLTeX.cfg
#
%main::configuration = (
	 'dbdriver'			=> 'mysql'
	,'oracle_sid'		=> 'ORASID'
	,'texex'			=> 'tex'
	,'stx'				=> '_stx'
	,'rfile_comment'	=> ';'
	,'cmd_prefix'		=> 'sql'
	,'sql_open'			=> 'db'
	,'sql_field'		=> 'field'
	,'sql_row'			=> 'row'
	,'sql_params'   	=> 'setparams'
	,'sql_update'   	=> 'update'
	,'sql_start'    	=> 'start'
	,'sql_end'      	=> 'end'
	,'sql_use'      	=> 'use'
	,'less_av'			=> 1
	,'more_av'			=> 1
	,'repl_step'		=> 'OSTX'
	,'alt_cmd_prefix' 	=> 'processedsqlcommand'
);

#####
# Some globals
#
{
	my @dir_list = split /\//, $0;
	pop @dir_list;
	$main::my_location = join '/', @dir_list;
}

# Check config
# Used for loops, should not start with $main::configuration{'cmd_prefix'} !!
if ($main::configuration{'alt_cmd_prefix'} =~ /^$main::configuration{'cmd_prefix'}/) {
	die "\$main::configuration{'alt_cmd_prefix'} cannot start with $main::configuration{'cmd_prefix'}";
}

$main::myself = $ENV{'_'};
while ($main::myself =~ /\//) { $main::myself = $'; }
$main::version = '1.x';

my $rdate   = '$Date$';
my ($dum1, $act, $rest_of_line ) = split (/ /, $rdate);
$main::rdate = $act;

&parse_options;
&get_filenames;

if (!$main::multidoc && -e "$main::path$main::outputfile") {
	die ("outputfile $main::path$main::outputfile already exists\n")
		unless (defined $main::options{'f'});
}

if (defined $main::configurationfile) {
	open (CF, "<$main::configurationfile");
	while ($main::line = <CF>) {
		next if ($main::line =~ /^\s*#/);
		chomp $main::line;
		my ($ck, $cv) = split /=/, $main::line;
		$ck =~ s/\s//g;
		$cv =~ s/\s//g;
		if ($cv ne '') {
			$main::configuration{$ck} = $cv;
		}
	}
	close CF;
}

if (defined $main::replacefile) {
	my $repl_cnt = '000';
	@main::repl_order = ();
	open (RF, "<$main::replacefile");
	while ($main::line = <RF>) {
		next if ($main::line =~ /^\s*$main::configuration{'rfile_comment'}/);
		chomp $main::line;
		$main::line =~ s/\t+/\t/;
		my ($rk, $rv) = split /\t/, $main::line;
		if ($rk ne '') {
			push @main::repl_order, $rk;
			$main::repl_key{$rk} = "$main::configuration{'repl_step'}$repl_cnt";
			$main::repl_val{"$main::configuration{'repl_step'}$repl_cnt"} = $rv;
			$repl_cnt++;
		}
	}
	close RF;
}

# Start processing
do {
	&process_file;

	if ($main::sql_statements == 0) {
		unlink ("$main::path$main::outputfile");
		print "no sql statements found in $main::path$main::inputfile\n";
		$main::multidoc = 0; # Problem in the input, useless to continue
	} else {
		print "$main::sql_statements queries executed - TeX file $main::path$main::outputfile written\n"
			unless ($main::multidoc && ($main::multidoc_cnt == 1)); # Counter was just increased.
	}
} while ($main::multidoc); # Set to false when done

$main::db_handle->disconnect() if ($main::db_opened);
exit (0);

#
# And that's about it.
#####
