#!/bin/sh -e
#
# Modified from original source: Elastic Search
# https://github.com/elasticsearch/elasticsearch
# Thank you to the Elastic Search authors
#
### BEGIN INIT INFO
# Provides:          opentsdb
# Required-Start:    $network $named $remote_fs $syslog
# Required-Stop:     $network $named $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Starts OpenTSDB TSD
# Description:       Starts an OpenTSDB time series daemon
### END INIT INFO

PATH=/bin:/usr/bin:/sbin:/usr/sbin
NAME=opentsdb
TSD_USER=opentsdb
TSD_GROUP=opentsdb

# Maximum number of open files
MAX_OPEN_FILES=65535

. /lib/lsb/init-functions

# The first existing directory is used for JAVA_HOME 
# (if JAVA_HOME is not defined in $DEFAULT)
JDK_DIRS="/usr/lib/jvm/java-7-oracle /usr/lib/jvm/java-7-openjdk \
   /usr/lib/jvm/java-7-openjdk-amd64/ /usr/lib/jvm/java-7-openjdk-i386/ \
   /usr/lib/jvm/java-6-sun /usr/lib/jvm/java-6-openjdk \
   /usr/lib/jvm/java-6-openjdk-amd64 /usr/lib/jvm/java-6-openjdk-i386"

# Look for the right JVM to use
for jdir in $JDK_DIRS; do
    if [ -r "$jdir/bin/java" -a -z "${JAVA_HOME}" ]; then
       JAVA_HOME="$jdir"
    fi
done

# Specify default logback.xml location.
LOGBACK_CONFIG=/etc/opentsdb/logback.xml

# Define other required variables
PID_FILE=/var/run/$NAME.pid

DAEMON=/usr/bin/tsdb
DAEMON_OPTS=tsd

## See if our executable actually exists and is executable
[ -x $DAEMON ] || exit 0

## Source in any optional config parameters or env variables
[ -r /etc/default/opentsdb ] && . /etc/default/opentsdb

export JAVA_HOME
export JAVA="$JAVA_HOME/bin/java"
export LOGBACK_CONFIG

case "$1" in
start)
 
	if [ -z "$JAVA_HOME" ]; then
		log_failure_msg "no JDK found - please set JAVA_HOME"
		exit 1
	fi

	log_action_begin_msg "Starting TSD"
	if start-stop-daemon --test --start --pidfile "$PID_FILE" \
		--user "$TSD_USER" --exec "$JAVA" \
		>/dev/null; then

		touch "$PID_FILE" && chown "$TSD_USER":"$TSD_GROUP" "$PID_FILE"
		
		if [ -n "$MAX_OPEN_FILES" ]; then
			ulimit -n $MAX_OPEN_FILES
		fi

		# start the daemon
		start-stop-daemon --start -b --user "$TSD_USER" -c "$TSD_USER" \
			--make-pidfile --pidfile "$PID_FILE" \
			--exec /bin/bash -- -c "$DAEMON $DAEMON_OPTS"

			sleep 1
			if start-stop-daemon --test --start --pidfile "$PID_FILE" \
				--user "$TSD_USER" --exec "$JAVA" \
				>/dev/null; then
			
				if [ -f "$PID_FILE" ]; then
            				rm -f "$PID_FILE"
          			fi
			
				log_failure_msg "Failed to start the TSD"
			else
				log_action_end_msg 0
			fi
	  
		else
			log_action_cont_msg "TSD is already running"

		log_action_end_msg 0
	fi
	;;

stop)
	log_action_begin_msg "Stopping TSD"
	set +e
	if [ -f "$PID_FILE" ]; then 
		start-stop-daemon --stop --pidfile "$PID_FILE" \
			--user "$TSD_USER" --retry=TERM/20/KILL/5 >/dev/null
		if [ $? -eq 1 ]; then
			log_action_cont_msg "TSD is not running but pid file exists, cleaning up"
		elif [ $? -eq 3 ]; then
			PID="`cat $PID_FILE`"
			log_failure_msg "Failed to stop TSD (pid $PID)"
			exit 1
		fi
		rm -f "$PID_FILE"
	else
		log_action_cont_msg "TSD was not running"
	fi
	log_action_end_msg 0
	set -e
	;;

restart|force-reload)
  if [ -f "$PID_FILE" ]; then
		$0 stop
		sleep 1
	fi
	$0 start
	;;
*)
	echo "Usage: /etc/init.d/opentsdb {start|stop|restart}"
	exit 1
	;;
esac

exit 0
