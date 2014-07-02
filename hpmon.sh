#!/bin/bash

# Simple Server Health script
# Verifies Server health by querying IML and ACU
# and emails if a disk has failed or Caution/Critical message
# is found in Server Event Log (IML)
#
# Requires hp-health and hpacucli to be installed
# Darryl C. Noye - 06/02/2014
#################################################

# Global variables
ME=$0
MAILWHO=@gmail.com
HPACUCLI='hpacucli controller slot=0 physicaldrive all show'
HPLOG='hplog -v'
HPACUCLI_TMP=/var/log/hpacucli.log
HPLOG_TMP=/var/log/hplog.log


## IML GET DATA

$HPLOG | grep ':'  > $HPLOG_TMP

## ARRAY GET DATA

$HPACUCLI | grep ':'  > $HPACUCLI_TMP

if [ `cat $HPACUCLI_TMP | grep physicaldrive | grep -v OK | wc -l` -gt 0 ]
then
SUBJECT=”RAID Controller Errors”
logger -p syslog.error -t $ME “$SUBJECT found. Please check Array status using hpacucli”
mail -s “$HOSTNAME: $SUBJECT” “$MAILWHO” $HPACUCLI_TMP
fi
## looks for Caution and Critical messages only

if [ `cat $HPLOG_TMP | grep -e Critical -e Caution | wc -l` -gt 0 ]
then
SUBJECT=”IML Errors”
logger -p syslog.error -t $ME “$SUBJECT found. Please check server status using hplog -v”
mail -s “$HOSTNAME: $SUBJECT” “$MAILWHO” $HPLOG_TMP
fi
