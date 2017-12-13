# SFTP Copy Patron Data #

Perl program that copies text files from any SFTP source to a location on the local file system. It also keeps tracks which files have been copied before in a separate history file. 

### Copy process ###

* SFTP connection to remote server is established 
* all files in one directory will be read out (subdirectories will be ignored)
* all files will be download the location defined in *local_path+
* each file name is checked against the *history_file*, if already in history_file the file will not be moved to the *pickup* folder
* each file moved to *pickup* folder will be added to the *history_file*

### Start progam ###

* perl $local_betrieb/nebis/sftp_copy_patrondata/sftpcopy.pl config.ini
* better use small shell scripts that can run the programm e.g. epfltest_sftpcopy

~~~~
#!/bin/csh -f 
 
perl $local_betrieb/nebis/sftp_copy_patrondata/sftpcopy.pl epfl.ini
echo "Finished"
~~~~


### Config files ###

* all config files are located in config/
* all config files should end with ini
* Example default.ini

~~~~
job_name = 'Default Job'
host = 'hostname'
host_user = 'hostpass'
host_password = 'XXXXXXXXX'
remote_path = '/path/on/sftp/'
file_ending = 'csv'
local_path = '/local/path/'
pickup = 'pickup/'
done = 'done/'
history_file = 'history-donotdelete.txt'
~~~~

