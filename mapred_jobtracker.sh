#!/bin/sh -x

# condor_chirp in /usr/libexec/condor
export PATH=$PATH:/usr/libexec/condor

HADOOP_TARBALL=$1
NAMENODE_ENDPOINT=$2

# Note: bin/hadoop uses JAVA_HOME to find the runtime and tools.jar,
#       except tools.jar does not seem necessary therefore /usr works
#       (there's no /usr/lib/tools.jar, but there is /usr/bin/java)
export JAVA_HOME=/usr

# When we get SIGTERM, which Condor will send when
# we are kicked, kill off the namenode
function term {
   ./bin/hadoop-daemon.sh stop jobtracker
}

# Unpack
tar xzfv $HADOOP_TARBALL

# Move into tarball, inefficiently
cd $(tar tzf $HADOOP_TARBALL | head -n1)

# Configure,
#  . http.address must be set to port 0 (ephemeral)
cat > conf/mapred-site.xml <<EOF
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
    <name>mapred.job.tracker</name>
    <value>0.0.0.0:0</value>
  </property>
  <property>
    <name>mapred.job.tracker.http.address</name>
    <value>0.0.0.0:0</value>
  </property>
  <property>
    <name>fs.default.name</name>
    <value>$NAMENODE_ENDPOINT</value>
  </property>
</configuration>
EOF

# Try to shutdown cleanly
trap term SIGTERM

export HADOOP_CONF_DIR=$PWD/conf
export HADOOP_LOG_DIR=$_CONDOR_SCRATCH_DIR/logs
export HADOOP_PID_DIR=$PWD

./bin/hadoop-daemon.sh start jobtracker

# Wait for pid file
PID_FILE=$(echo hadoop-*-jobtracker.pid)
while [ ! -s $PID_FILE ]; do sleep 1; done
PID=$(cat $PID_FILE)

# Wait for the log
LOG_FILE=$(echo $HADOOP_LOG_DIR/hadoop-*-jobtracker-*.log)
while [ ! -s $LOG_FILE ]; do sleep 1; done

# It would be nice if there were a way to get these without grepping logs
while [ ! $(grep "JobTracker up at" $LOG_FILE) ]; do sleep 1; done
IPC_PORT=$(grep "JobTracker up at" $LOG_FILE | sed 's/.* up at: \(.*\)$/\1/')
while [ ! $(grep "JobTracker webserver" $LOG_FILE) ]; do sleep 1; done
HTTP_PORT=$(grep "JobTracker webserver" $LOG_FILE | sed 's/.* webserver: \(.*\)$/\1/')

# Record the port number where everyone can see it
condor_chirp set_job_attr JobTrackerIPCAddress \"maprfs://$(hostname -f):$IPC_PORT\"
condor_chirp set_job_attr JobTrackerHTTPAddress \"http://$(hostname -f):$HTTP_PORT\"

# While namenode is running, collect and report back stats
while kill -0 $PID; do
   # Collect stats and chirp them back into the job ad
   # Nothing to do.
   sleep 30
done
