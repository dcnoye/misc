#!/bin/bash

# Simple Server Health Notification script
# Verifies Server health by querying IML and ACU
# and emails if a disk has failed or Caution/Critical message
# is found in Server Event Log (IML)
#
# Requires hp-health and hpacucli to be installed
# D.C. Noye - 06/02/2014
#################################################

# Global variables
ME=$0
MAILWHO=dcnoye
MAILWHOF="Server"
HPACUCLI='hpacucli controller slot=0 physicaldrive all show'
HPLOG='hplog -v'
HPACUCLI_TMP=/var/log/hpacucli.log
HPLOG_TMP=/var/log/hplog.log
SUBJECT="Error"

## IML GET DATA

$HPLOG | grep ':' > $HPLOG_TMP

## ARRAY GET DATA

$HPACUCLI | grep ':' > $HPACUCLI_TMP

if [ `cat $HPACUCLI_TMP | grep physicaldrive | grep -v OK | wc -l` -gt 0 ]
then
logger -p syslog.error -t $ME "$SUBJECT found. Please check Array status using hpacucli"
mail -a $HPACUCLI_TMP -s "$SUBJECT" "$MAILWHO" < /dev/null
fi
## looks for Caution and Critical messages only

if [ `cat $HPLOG_TMP | grep $(date +"%m/%d/%Y\s%H") | grep -e Critical -e Caution | wc -l` -gt 0 ]
then
logger -p syslog.error -t $ME "$SUBJECT found. Please check server status using hplog"
mail -r "$MAILWHOF" -a $HPLOG_TMP -s "$SUBJECT" "$MAILWHO" < $HPLOG_TMP
fi
