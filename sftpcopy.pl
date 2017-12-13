#!/usr/bin/perl

use strict;
use warnings;


use File::Copy;
use Net::SFTP;
use Config::Simple;
use Data::Dumper;

$|=1;


my $config_base_path = 'config/';
my $cfg;

#main sub
sub main
{
	my $config_file = $ARGV[0];
	my $config_path = $config_base_path.$config_file;
	
	checkConfigFile($config_path);
	$cfg = new Config::Simple(filename=>$config_path);
	printLogLine("Job: ".$cfg->param("job_name"));

	checkLocalPaths();
	downloadFilesFromSftp();
	moveFilesToPickup();
}


#moves retrieved file to pickup and old
#checks correct file ending and removes doubles if needed
sub moveFilesToPickup
{
	my $allowedFileEnding = $cfg->param("file_ending");
	my $retrieveDir = $cfg->param("local_path");
	my $pickup_folder = $retrieveDir.$cfg->param("pickup");
	my $done_folder = $retrieveDir.$cfg->param("done");
	my @oldFilesArray = @{getFileArrayFromHistory()};
	
	opendir(DIR, $retrieveDir) or die $!;

	while(my $singleFile = readdir(DIR))
	{
		next unless($singleFile =~ m/$allowedFileEnding$/);
		
		unless (grep /$singleFile/, @oldFilesArray)
		{
			#copy to corresponding locations
			copyFileAndLog($retrieveDir, $singleFile, $pickup_folder);
			addFileToHistory($singleFile);

			#but also copy into done directory for backup
			copyFileAndLog($retrieveDir, $singleFile, $done_folder);

		}

		unlink $retrieveDir.$singleFile;
	}
}


#add a line (file name) to history file
sub addFileToHistory
{
	my $line = shift;
	my $historyFile = $cfg->param("local_path").$cfg->param("history_file");

	open(my $fh, '>>', $historyFile) or die "Cannot open $historyFile";
	print $fh $line."\n";	

	close $fh
}


#extracts array of all file names in history file
#returns referenced array
sub getFileArrayFromHistory
{
	my @returnArray;
	my $historyFile = $cfg->param("local_path").$cfg->param("history_file");

	open(my $fh, '<', $historyFile) or die "Cannot open $historyFile";
	chomp(@returnArray = <$fh>);
	close $fh;

	#print Dumper(@returnArray);
	return \@returnArray;
}


#copies file from source to target and adds log entry
sub copyFileAndLog
{
	my $sourceDir = shift;
	my $sourceFile = shift;
	my $targetDir = shift;

	copy $sourceDir.$sourceFile, $targetDir;
	printLogLine($sourceFile." copied to ".$targetDir);
}

#download available files with correct extension to local path
sub downloadFilesFromSftp
{
	my $filesRef = getFilesArrayFromSftp();
	printLogLine("Retrieved file list");
	retrieveFilesFromSftp($filesRef);
}


#connects to SFTP host
#retrieve all files with correct file endings
#give correct local rights
sub retrieveFilesFromSftp
{
	my $filesRef = shift;
	my @filesToDownload = @{$filesRef};
	my %host_params = (user => $cfg->param("host_user"),
			password => $cfg->param("host_password"));

	if(scalar(@filesToDownload) == 0)
	{
		printLogLine("Nothing to download");
	}
	else
	{
		my $sftp = Net::SFTP->new($cfg->param("host"), %host_params);
		
		foreach(@filesToDownload)
		{
			my $singleFile = $_;
			
			$sftp->get($cfg->param("remote_path").$singleFile, $cfg->param("local_path").$singleFile);
			#add deletion
			#$sftp->remove($cfg->param("remote_path").$singleFile)
			if(-e $cfg->param("local_path").$singleFile)
			{
				chmod 0664, $cfg->param("local_path").$singleFile;
				printLogLine("File $singleFile transferred to ".$cfg->param("local_path"));
			}
		}
	}
}


#returns files in ref array that correspond extension
sub getFilesArrayFromSftp
{
	my @csv_files;
	my %host_params = (user => $cfg->param("host_user"),
                        password => $cfg->param("host_password"));
	my $sftp = Net::SFTP->new($cfg->param("host"), %host_params);
	my @directory_listing = $sftp->ls($cfg->param("remote_path"));
	my $file_ending = $cfg->param("file_ending");

	my $file_hash;
	my $i = 0;

	#iterate over directory listing
	foreach(@directory_listing) 
	{		
		$file_hash = $_;
		#only files, no directories
		unless($file_hash->{longname} =~ /^d.*/)
		{
			#file has the correct extension
			if($file_hash->{filename} =~ /\.$file_ending$/)
			{
				$csv_files[$i] = $file_hash->{filename};
				$i++;
			}
		}
	}

	return \@csv_files;
}


#checks if all needed dirs exists
#creates them if needed
sub checkLocalPaths
{
	my @foldersToCheck = (	$cfg->param("local_path"),
				$cfg->param("local_path").$cfg->param("pickup"),
				$cfg->param("local_path").$cfg->param("done"),
				);

	foreach(@foldersToCheck)
	{
		unless(-e $_)
		{
			mkdir($_);
			printLogLine($_." did not exist. It is created now");
		}
	}

	checkHistoryFile();

}


#checks if history_file exists and dies if no
sub checkHistoryFile
{
	my $historyFile = $cfg->param("local_path").$cfg->param("history_file");

	unless(-e $historyFile)
	{
		printLogLine("history file could not be found");
		
        	open(my $fh, '>', $historyFile) or die "Cannot create $historyFile";
	        close $fh;

		printLogLine("Empty history file created at $historyFile");
	}
}


#check if config.ini exists
#if not stops programm
sub checkConfigFile
{
	my $config_file = shift;

	unless(-e $config_file)
	{
		die "Config file '$config_file' does not exist.\n";
	}
}


#formats single statement into a useful log entry
#with leading timestamp
sub printLogLine
{
	my $logData = shift;
	print localtime(time)." - ".$logData."\n";
}


main();
