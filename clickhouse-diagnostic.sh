#!/bin/bash
#
# name: clickhouse-diagnostic
# purpose: gather critical diagnostic data for ClickHouse
# initial date: 2021-11-29
# last update: 2021-12-07
# version: 0.2
#

### config start

DATE="`date +%Y%m%d-%H%M%S`"
NAME="clickhouse-diag"
DIR="/var/tmp"
DIR_FINAL="${DIR}/$NAME-${DATE}"
DIR_PERMS="700"

### config end

# path
PATH=/usr/bin:/bin:/usr/sbin:/usr/local/bin
export PATH

### initialize vars
VERBOSE=0
USELSOF=0
USEDBINFO=0
USETABLEINFO=0
COUNT="1"
INTERVAL="300"
###

# functions
exit_error()
{
   echo "Exit: error ${1}"
   exit 2
}

usage()
{
   echo "Usage: clickhouse-diagnostic.sh [-c <count>] [-i <interval>] [-d] [-t] [-l] [-v] [-h]"
   echo "   -c <count>    = number of loops"
   echo "   -i <interval> = interval in seconds between loops"
   echo "   -d            = get ClickHouse database metadata"
   echo "   -t            = get ClickHouse table metadata"
   echo "   -l            = use lsof"
   echo "   -v            = verbose / debug"
   echo "   -h            = this help page"
   echo ""
   echo "   One recommended method of running this is to put it in cron to run hourly, for example:"
   echo "      0 * * * *  <path>/bin/clickhouse-diagnostic.sh -i 900 -c 4 -d -t"
   exit 1
}

# get options
while [ $# -ge 1 ]; do
   case $1 in
      -c[0-z]*) COUNT=`echo $1 | cut -c3-`;;
      -c)       shift; COUNT="$1" ;;
      -v)       VERBOSE=1 ;;
      -h)       usage ;;
      -i[0-z]*) INTERVAL=`echo $1 | cut -c3-`;;
      -i)       shift; INTERVAL="$1" ;;
      -l)       USELSOF=1 ;;
      -d)       USEDBINFO=1 ;;
      -t)       USETABLEINFO=1 ;;
      -*)       usage ;;
      *)        usage ;;
   esac
   shift
done

if [ "$VERBOSE" -eq 1 ]; then
   echo "DEBUG:"
   echo " INTERVAL=$INTERVAL"
   echo " COUNT=$COUNT"
   echo " USELSOF=$USELSOF"
   echo " USEDBINFO=$USEDBINFO"
   echo " USETABLEINFO=$USETABLEINFO"
   echo ""
fi
#

# hostname
UNAME="`uname -s`"
UNAMEA="`uname -a`"
HOSTNAME="`uname -n`"

## default applications

# awk/nawk
case "$UNAME" in
   Darwin)         AWK=awk ;;
   FreeBSD)        AWK=awk ;;
   Linux)          AWK=awk ;;
   SunOS)          AWK=nawk ;;
   *)              AWK=awk ;;
esac

## 

# mkdir 
mkdir -m ${DIR_PERMS} ${DIR_FINAL} || exit_error "mkdir: $@"

# output
exec 6<&1 # save original STDOUT
exec 7<&2 # save original STDERR
exec 1>> "${DIR_FINAL}"/"${NAME}.log"
exec 2> >(tee -a "${DIR_FINAL}"/"${NAME}.log")

# system

# version
echo "Version:"
clickhouse-client --query="SELECT * FROM system.build_options"

# Databases
echo "Database:"
clickhouse-client --query='SHOW DATABASES;'

# tables
clickhouse-client --query="SELECT name,engine,tables,partitions,parts,formatReadableSize(bytes_on_disk) "disk_size" FROM system.databases db LEFT JOIN ( SELECT database,uniq(table) "tables",uniq(table,partition) "partitions",count() AS parts, sum(bytes_on_disk) "bytes_on_disk" FROM system.parts WHERE active GROUP BY database) AS db_stats ON db.name = db_stats.database ORDER BY bytes_on_disk DESC LIMIT 10"

# schemas


# close and exit
exec 1>&6
exec 2>&6
echo "Done: diagnostic saved to ${DIR_FINAL}"
exit 0

