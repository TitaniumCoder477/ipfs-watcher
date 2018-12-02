#!/bin/bash
#
# ipfs-watcher.sh
# 
# This script checks for presence of running ipfs daemon and starts it if not found. It also renews
# ipns for one or more hashes.
#
# Requires: Installed ipfs
#
# MIT License
#
# Copyright 2018 James Wilmoth
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and 
# associated documentation files (the "Software"), to deal in the Software without restriction, 
# including without limitation the rights to use, copy, modify, merge, publish, distribute, 
# sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or 
# substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT 
# NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT 
# OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# To attempt to start the daemon
#	./ipfs-watcher.sh
#
# To attempt to start the daemon and renew a ipns hash
#	./ipfs-watcher.sh hash
#
# To attempt to start the daemon and renew a list of ipns hashes
#	./ipfs-watcher.sh filename
#
# Example crontab entry
#	0 * * * * /home/jwilmoth/ipfs-watcher.sh /home/jwilmoth/ipfs-hashes.txt
#
#   where jwilmoth is your own home folder and ipfs-hashes.txt is a file with one or more hashes
#
# NOTE: hash is the 46 character hash only. Do not include the /ipfs/ prefix!
#

LOGFILE="/var/log/ipfs.log"
LOGFILESIZE=$(stat -c%s "$LOGFILE")
MAXLOGFILESIZE=10000000

#Log maintenance
if [ "$LOGFILESIZE" -gt $MAXLOGFILESIZE ]; then
	#Log to file
	DATE_WITH_TIME=`date "+%Y%m%d-%H%M%S"`
	echo "> $DATE_WITH_TIME | log file has exceeded 10MB; running cleanup" > $LOGFILE
fi

#Function to make code tidier
function logAndPrint {
	DATE_WITH_TIME=`date "+%Y%m%d-%H%M%S"`
	LINE="> $DATE_WITH_TIME | $1"
	printf "$LINE\n"
	echo $LINE >> $LOGFILE
}

#Function to make code tidier AND bail
function logAndPrintFail {
	logAndPrint $1
	exit 1
}

#Test that ipfs is available
IPFS_PATH="$(whereis ipfs | cut -d' ' -f2)"
if [ "$?" -ne 0 ]; then
	logAndPrint "ipfs does not appear to be installed. please install first. https://docs.ipfs.io/introduction/install/"
	exit $?
fi
	
#Check for presence of ipfs daemon and start it if not
pgrep -xf "$IPFS_PATH daemon"
if [ "$?" -ne 0 ]; then
	#Log to file	
	logAndPrint "ipfs daemon not running; starting"
	#Start
	nohup $IPFS_PATH daemon &>/var/log/ipfsdaemon.log &
	#Sleep a bit to make sure process is running before we move on
	logAndPrint "Sleeping for 20 seconds to give ipfs daemon a chance to start"
	sleep 20s
	
	#Check for presence of ipfs daemon and if not running now, log failure
	pgrep -xf "$IPFS_PATH daemon" &>/dev/null
	if [ "$?" -ne 0 ]; then
		#Log to file	
		logAndPrintFail "ipfs daemon not running; we tried to start it but failed. Aborting..."
	else
		#Log to file	
		logAndPrint "ipfs daemon is running"
	fi

else
	#Log to file	
	logAndPrint "ipfs daemon is already running"
fi

#Process one or more hashes for ipns
if [ "$#" -eq 1 ]; then
	logAndPrint "Parameter passed in"
	PARAMETER="$1"
	LENGTH=${#PARAMETER}	
	if [ "$LENGTH" -eq 46 ]; then		
		logAndPrint "Length of parameter is 46, so this is most likely a single hash"
		logAndPrint "Attempting to publish $PARAMETER"
		$IPFS_PATH name publish $PARAMETER &>/var/log/ipfsname.log &
		logAndPrint "Waiting on process $!"
		echo $! &>/dev/null
		wait "$!"
		if [ "$?" -ne 0 ]; then
			logAndPrintFail "Failure to publish $PARAMETER"
		else
			logAndPrint "Successfully published $PARAMETER"
		fi
	else
		HASHLIST="$PARAMETER"
		logAndPrint "Attempting to read parameter as a file of hashes"
		while IFS= read -r HASH; do
			LENGTH=${#HASH}
			if [ "$LENGTH" -eq 46 ]; then
				logAndPrint "Attempting to publish $HASH"
				$IPFS_PATH name publish "$HASH" &>/var/log/ipfsname.log &
				logAndPrint "Waiting on process $!"
				echo $! &>/dev/null
				wait "$!"
				if [ "$?" -ne 0 ]; then
					logAndPrint "Failure to publish $HASH"
				else
					logAndPrint "Successfully published $HASH"
				fi
			else
				logAndPrint "$HASH is not 46 characters in length and may be invalid. Skipping"
			fi
		done < "$HASHLIST"
	fi
fi

exit 0
