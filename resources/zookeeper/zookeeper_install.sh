#!/bin/bash

#ZOO_VERSION=3.5.5
#ZOO_APP_DIR=/opt/zookeeper
#ZOO_DATA_DIR=/store/data
#ZOO_SERVERS="server.1=zkensemble-0.zkensemble.default.svc.cluster.local:2888:3888 server.2=zkensemble-1.zkensemble.default.svc.cluster.local:2888:3888 server.3=zkensemble-2.zkensemble.default.svc.cluster.local:2888:3888"
#ZOO_XMX=512m
#NODE_EXPORTER_VERSION=0.18.1
#JMX_EXPORTER_VERSION=0.12.0
#GO_VERSION=1.13.5


useradd -d /home/zookeeper zookeeper

NAMESPACE="$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)"
MYID="$((${HOSTNAME##*-}+1))"

ZOO_DATA_DIR="$ZOO_DATA_DIR/$NAMESPACE/$MYID"

mkdir -p $ZOO_DATA_DIR/data
mkdir -p $ZOO_DATA_DIR/datalog
mkdir -p $ZOO_DATA_DIR/log

cd /tmp
wget http://miroir.univ-lorraine.fr/apache/zookeeper/zookeeper-$ZOO_VERSION/apache-zookeeper-$ZOO_VERSION-bin.tar.gz
tar xzf apache-zookeeper-$ZOO_VERSION-bin.tar.gz && rm apache-zookeeper-$ZOO_VERSION-bin.tar.gz
mv apache-zookeeper-$ZOO_VERSION-bin $ZOO_APP_DIR

cd /tmp/solrcloud_kubernetes
cp resources/zookeeper/zookeeper /etc/init.d/.
chown root: /etc/init.d/zookeeper
chmod +x /etc/init.d/zookeeper

CONFIG="$ZOO_APP_DIR/conf/zoo.cfg"
if [[ ! -f "$CONFIG" ]]; then
    echo "tickTime=2000" >> "$CONFIG"
    echo "initLimit=10" >> "$CONFIG"
    echo "syncLimit=5" >> "$CONFIG"
    echo "maxClientCnxns=60" >> "$CONFIG"
    echo "clientPort=2181" >> "$CONFIG"
    echo "autopurge.snapRetainCount=3" >> "$CONFIG"
    echo "autopurge.purgeInterval=1" >> "$CONFIG"
    echo "dataDir=$ZOO_DATA_DIR/data" >> "$CONFIG"
    echo "dataLogDir=$ZOO_DATA_DIR/datalog" >> "$CONFIG"
    echo "4lw.commands.whitelist=mntr, ruok, conf" >> "$CONFIG"
    for server in $ZOO_SERVERS; do
        echo "$server" >> "$CONFIG"
    done
fi
sed -i "s/\.default\./.$NAMESPACE./g" $CONFIG

if [[ ! -f "$ZOO_DATA_DIR/data/myid" ]]; then
    echo "$MYID" > "$ZOO_DATA_DIR/data/myid"
fi

ZOOKEEPER_ENV="$ZOO_APP_DIR/conf/zookeeper-env.sh"
if [[ ! -f "$ZOOKEEPER_ENV" ]]; then
    echo "ZOO_LOG_DIR=\"${ZOO_DATA_DIR}/log\"" >> "$ZOOKEEPER_ENV"
    echo 'ZOO_LOG4J_PROP="WARN, ROLLINGFILE"' >> "$ZOOKEEPER_ENV"
    echo "SERVER_JVMFLAGS=\"-Xmx${ZOO_XMX} -javaagent:${ZOO_APP_DIR}/jmx-exporter/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar=8080:${ZOO_APP_DIR}/conf/zookeeper-jmx-exporter.yml\"" >> "$ZOOKEEPER_ENV"
    echo 'JMXDISABLE=true' >> "$ZOOKEEPER_ENV"
    echo 'JMXPORT=10900' >> "$ZOOKEEPER_ENV"
    echo 'SERVER_JVMFLAGS="$SERVER_JVMFLAGS -XX:+UseG1GC -XX:MaxGCPauseMillis=100"' >> "$ZOOKEEPER_ENV"
    echo "SERVER_JVMFLAGS=\"$SERVER_JVMFLAGS -Xlog:gc*:file=${ZOO_DATA_DIR}/log/zookeeper-gc.log:time,uptime:filecount=10,filesize=20M\"" >> "$ZOOKEEPER_ENV"
fi

chmod +x $ZOOKEEPER_ENV

chmod -R go+rw $ZOO_DATA_DIR
chown -R zookeeper: $ZOO_DATA_DIR
chown -R zookeeper: $ZOO_APP_DIR


# prometheus jmx-exporter
cd /tmp
mkdir $ZOO_APP_DIR/jmx-exporter
wget https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/$JMX_EXPORTER_VERSION/jmx_prometheus_javaagent-$JMX_EXPORTER_VERSION.jar
mv jmx_prometheus_javaagent-$JMX_EXPORTER_VERSION.jar $ZOO_APP_DIR/jmx-exporter/.
touch $ZOO_APP_DIR/conf/zookeeper-jmx-exporter.yml
chown -R zookeeper: $ZOO_APP_DIR/jmx-exporter
chown -R zookeeper: $ZOO_APP_DIR/conf/zookeeper-jmx-exporter.yml


# prometheus node-exporter
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v$NODE_EXPORTER_VERSION/node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
tar xzf node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
rm node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
mv node_exporter-$NODE_EXPORTER_VERSION.linux-amd64 $ZOO_APP_DIR/node_exporter
chown -R zookeeper: $ZOO_APP_DIR/node_exporter
cp /tmp/solrcloud_kubernetes/resources/init.d/node_exporter /etc/init.d/.
chmod +x /etc/init.d/node_exporter
sed -i sed -i "s#^APP_DIR.*#APP_DIR=$ZOO_APP_DIR/node_exporter#" /etc/init.d/node_exporter
#$ZOO_APP_DIR/node_exporter/node_exporter > /dev/null 2>&1 &


# prometheus zk-exporter
cd /tmp
wget https://dl.google.com/go/go$GO_VERSION.linux-amd64.tar.gz
tar -C /usr/local -xzf go$GO_VERSION.linux-amd64.tar.gz
PATH=$PATH:$HOME/bin:/usr/local/go/bin
rm go$GO_VERSION.linux-amd64.tar.gz
go get -u github.com/lucianjon/zk-exporter
mkdir $ZOO_APP_DIR/zk-exporter
mv /root/go/bin/zk-exporter $ZOO_APP_DIR/zk-exporter/.
rm -rf /root/go
chown -R zookeeper: $ZOO_APP_DIR/zk-exporter
cp /tmp/solrcloud_kubernetes/resources/init.d/zk_exporter /etc/init.d/.
chmod +x /etc/init.d/zk_exporter
sed -i "s#^APP_DIR.*#APP_DIR=$ZOO_APP_DIR/zk-exporter#" /etc/init.d/zk_exporter
#$ZOO_APP_DIR/zk-exporter/zk-exporter -port 7080 -servers localhost:2181 -pollinterval 15s > /dev/null 2>&1 &






