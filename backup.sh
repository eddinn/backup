#!/bin/bash
#
# Backupscript for rdiff-backup with mysqlhotcopy and mysqldump
# Author: Edvin Dunaway - edvin@eddinn.net
#

### SETTINGS ###

# Define program paths, terminal type and date, you need to adjust PATH to your systems environment
export PATH=/bin:/sbin:/usr/sbin:/usr/bin:/usr/local/bin

# Set the hostname
HOSTNAME=$(hostname -f)
export HOSTNAME

# Backup paths settings and filelist (one item/path per line for the rdiff-backup --include-globbing-filelist)
export BACKUP_PATH="/"
export BACKUP_DEST_PATH="/path/to/backups"
export FILE_LIST="/path/to/backup-include-list"

# MySQL settings
export MYSQL_DIR='/var/lib/mysql'
export MYSQL_BACKUP_DIR="$BACKUP_DEST_PATH/mysql"

# What to output of the mysql hotcopy.
# 0: Only errors, 1: "Pretty" output, 2: Everything
OUTPUT_LEVEL=1

# Set rdiff-backup cleanup setting (removes all older then n days)
# The time interval is an integer followed by the character s, m, h, D, W, M, or  Y,
# indicating seconds, minutes, hours, days, weeks, months, or years respectively, or a number of these concatenated.
# For example: 32m means 32 minutes, and 3W2D10h7s means 3 weeks, 2 days, 10 hours, and 7 seconds.
# In this context, a month means 30 days, a year is 365 days, and a day is always 86400 seconds.
DAYS=1M

### END SETTINGS ###

# Beginning backup
echo -e "\\nBackup starting at $DATE to $BACKUP_DEST_PATH \\n"

# Lets check if the directory structure for our backup destinations exists, else it gets created
echo "Testing directories:"
export DIRS="$BACKUP_DEST_PATH $MYSQL_BACKUP_DIR"
for DIR in $DIRS; do
	if [ -d "$DIR" ] && [ -w "$DIR" ]; then
		echo -e "The directory \"$DIR\" exists and is writable"
	else
		mkdir -p "$DIR"
		echo -e "Created directory \"$DIR\""
	fi
done

# Lets check if the directory structure for the mysql DBs exists, else it gets created
cd $MYSQL_BACKUP_DIR || exit
# Here we find and list up all DBs into an array and use that for our directory tests and later for our DBs exports
_DBS=$(find $MYSQL_DIR -mindepth 1 -maxdepth 1 -type d ! -name performance_schema ! -name test -printf '%f ')
for DIR in $_DBS; do
	if [ -d "$DIR" ] && [ -w "$DIR" ]; then
		echo -e "The directory \"$DIR\" exists in \"$MYSQL_BACKUP_DIR\" and is writable"
	else
		mkdir -p "$DIR"
		echo -e "Created directory \"$DIR\" in \"$MYSQL_BACKUP_DIR\""
	fi
done

# Hotcopying and manually exporting all DBs (except test and performance_schema) to MYSQL_BACKUP_DIR
echo -e "\\nStarting hotcopying DBs and then we'll also do a manual export of the DBs into .sql files:"  
for DB in $_DBS; do
	if [ $OUTPUT_LEVEL -eq 1 ]; then echo -n "Hotcopying and exporting of DB $DB"; fi
	if [ $OUTPUT_LEVEL -le 1 ]; then QUIET='-q'; fi

	_DBEXPORT=$(mysqlhotcopy --allowold $QUIET "$DB" "$MYSQL_BACKUP_DIR"/"$DB" && mysqldump "$DB" > "$MYSQL_BACKUP_DIR"/"$DB"/"$DB".sql 2>&1)
	_EXIT=$?
	_FAILED=0

	# Validate the exit code
	if [ $_EXIT -eq 0 ]; then
		if [ $OUTPUT_LEVEL -eq 1 ]; then 
			echo -e " finished!"
		elif [ $OUTPUT_LEVEL -eq 2 ]; then
			echo -e "$_DBEXPORT"
		fi
	else
		_FAILED=$(( _FAILED + 1 ))
		if [ $OUTPUT_LEVEL -eq 1 ]; then
			echo -e " failed!"
			echo -e "$_DBEXPORT" 1>&2
		else
			echo -e "$_DBEXPORT" 1>&2
		fi
	fi
done

# Show results
if [ "$_FAILED" -eq 0 ]; then
	if [ "$OUTPUT_LEVEL" -ge 1 ]; then echo -e "\\nMySQL DB export"; fi
else
	echo -e "\\nFailed to hotcopy and export $_FAILED DBs!"
fi

echo -e "\\nMySQL backup finished; Now running rdiff-backup on system data:"
# Running the rdiff-backup
rdiff-backup --print-statistics --include-globbing-filelist "$FILE_LIST" --include-symbolic-links --exclude-sockets --exclude '**' "$BACKUP_PATH" "$BACKUP_DEST_PATH"/"$HOSTNAME"

# Removing backups older then 30 days 
echo -e "\\nNow when the rdiff-backup is done, we need to clean up after ourselves:"
rdiff-backup --print-statistics --remove-older-than "$DAYS" "$BACKUP_DEST_PATH"/"$HOSTNAME"

# Now we purge disk buffers so it isn't readable later for security reasons
echo -e "\\nMaking sure that all disk buffers are purged:"
dd if=/dev/zero of="$BACKUP_DEST_PATH"/disk-temp_buf count=256K bs=1024

# Make sure the buffer file was created and then remove it
if [ -e "$BACKUP_DEST_PATH"/disk-temp_buf ]; then
	echo "Removing $BACKUP_DEST_PATH/disk-temp_buf"
	rm -f "$BACKUP_DEST_PATH"/disk-temp_buf;
else
	echo -e "Buffer file does not exist!"
fi
echo -e "\\nDisk buffers should be purged now.."

# All finished!
echo -e "\\nBackup done at $(date -R) \\n"
exit
