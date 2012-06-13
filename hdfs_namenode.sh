#!/bin/sh -x

# condor_chirp in /usr/libexec/condor
export PATH=$PATH:/usr/libexec/condor

HADOOP_TARBALL=$1

# Note: bin/hadoop uses JAVA_HOME to find the runtime and tools.jar,
#       except tools.jar does not seem necessary therefore /usr works
#       (there's no /usr/lib/tools.jar, but there is /usr/bin/java)
export JAVA_HOME=/usr

# When we get SIGTERM, which Condor will send when
# we are kicked, kill off the namenode
function term {
   ./bin/hadoop-daemon.sh stop namenode
}

# Unpack
tar xzfv $HADOOP_TARBALL

# Move into tarball, inefficiently
cd $(tar tzf $HADOOP_TARBALL | head -n1)

# Configure,
#  . fs.default.name,dfs.http.address must be set to port 0 (ephemeral)
#  . dfs.name.dir must be in _CONDOR_SCRATCH_DIR for cleanup
# FIX: Figure out why a hostname is required, instead of 0.0.0.0:0 for
#      fs.default.name
cat > conf/hdfs-site.xml <<EOF
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
    <name>fs.default.name</name>
    <value>hdfs://$HOSTNAME:0</value>
  </property>
  <property>
    <name>dfs.name.dir</name>
    <value>$_CONDOR_SCRATCH_DIR/name</value>
  </property>
  <property>
    <name>dfs.http.address</name>
    <value>0.0.0.0:0</value>
  </property>
</configuration>
EOF

# Try to shutdown cleanly
trap term SIGTERM

export HADOOP_CONF_DIR=$PWD/conf
export HADOOP_LOG_DIR=$_CONDOR_SCRATCH_DIR/logs
export HADOOP_PID_DIR=$PWD

./bin/hadoop namenode -format
./bin/hadoop-daemon.sh start namenode

# Wait for pid file
PID_FILE=$(echo hadoop-*-namenode.pid)
while [ ! -s $PID_FILE ]; do sleep 1; done
PID=$(cat $PID_FILE)

# Wait for the log
LOG_FILE=$(echo $HADOOP_LOG_DIR/hadoop-*-namenode-*.log)
while [ ! -s $LOG_FILE ]; do sleep 1; done

# It would be nice if there were a way to get these without grepping logs
while [ ! $(grep "IPC Server listener on" $LOG_FILE) ]; do sleep 1; done
IPC_PORT=$(grep "IPC Server listener on" $LOG_FILE | sed 's/.* on \(.*\):.*/\1/')
while [ ! $(grep "Jetty bound to port" $LOG_FILE) ]; do sleep 1; done
HTTP_PORT=$(grep "Jetty bound to port" $LOG_FILE | sed 's/.* to port \(.*\)$/\1/')

# Record the port number where everyone can see it
condor_chirp set_job_attr NameNodeIPCAddress \"hdfs://$(hostname -f):$IPC_PORT\"
condor_chirp set_job_attr NameNodeHTTPAddress \"http://$(hostname -f):$HTTP_PORT\"

# While namenode is running, collect and report back stats
while kill -0 $PID; do
   # Collect stats and chirp them back into the job ad
   # Nothing to do.
   sleep 30
done
