#!/bin/bash

#SOLR_VERSION=8.3.1
#SOLR_APP_DIR=/opt/solr
#SOLR_DATA_DIR=/store/data
#SOLR_LOG_DIR=/store/logs
#ZOO_SERVERS="zkensemble-0.zkensemble.default.svc.cluster.local:2181,zkensemble-1.zkensemble.default.svc.cluster.local:2181,zkensemble-2.zkensemble.default.svc.cluster.local:2181"
#SOLR_XMX=512m
#NODE_EXPORTER_VERSION=0.18.1
#JMX_EXPORTER_VERSION=0.12.0
#GO_VERSION=1.13.5


useradd -d /home/solr solr

NAMESPACE="$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)"
SOLR_ID="$((${HOSTNAME##*-}+1))"
SOLR_DATA_DIR="$SOLR_DATA_DIR/solr$SOLR_ID"

cd /tmp
wget https://archive.apache.org/dist/lucene/solr/$SOLR_VERSION/solr-$SOLR_VERSION.tgz
tar xzf solr-$SOLR_VERSION.tgz && rm solr-$SOLR_VERSION.tgz
mv solr-$SOLR_VERSION $SOLR_APP_DIR
chown -R solr: $SOLR_APP_DIR
mkdir -p $SOLR_DATA_DIR/data
mkdir -p $SOLR_DATA_DIR/logs
cp -r $SOLR_APP_DIR/server/solr/* $SOLR_DATA_DIR/data/.
chmod -R go+rw $SOLR_DATA_DIR

cd /tmp/solrcloud_kubernetes
cp resources/solr/solr /etc/init.d/.
chown root: /etc/init.d/solr
chmod +x /etc/init.d/solr

CONFIG="/etc/default/solr.in.sh"
if [[ ! -f "$CONFIG" ]]; then
    echo "SOLR_HEAP=$SOLR_XMX" >> "$CONFIG"
    echo "ZK_CLIENT_TIMEOUT=\"30000\"" >> "$CONFIG"
    echo "SOLR_HOST=\"solrcloud-$((${HOSTNAME##*-})).solrcloud.default.svc.cluster.local\"" >> "$CONFIG"
    echo "SOLR_PORT=\"8983\"" >> "$CONFIG"
	echo "SOLR_HOME=\"$SOLR_DATA_DIR/data\"" >> "$CONFIG"
	echo "SOLR_PID_DIR=\"$SOLR_DATA_DIR/data\"" >> "$CONFIG"
	echo "SOLR_LOGS_DIR=\"$SOLR_DATA_DIR/logs\"" >> "$CONFIG"
	echo "ZK_HOST=\"$ZOO_SERVERS\"" >> "$CONFIG"
	echo "SOLR_OPTS=\"$SOLR_OPTS -javaagent:$SOLR_APP_DIR/jmx-exporter/jmx_prometheus_javaagent-0.12.0.jar=8080:$SOLR_APP_DIR/jmx-exporter/solr-jmx-exporter.yml\"" >> "$CONFIG"
fi
sed -i "s/\.default\./.$NAMESPACE./g" $CONFIG
chmod +x $CONFIG


# prometheus jmx-exporter
cd /tmp
mkdir $SOLR_APP_DIR/jmx-exporter
wget https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/$JMX_EXPORTER_VERSION/jmx_prometheus_javaagent-$JMX_EXPORTER_VERSION.jar
mv jmx_prometheus_javaagent-$JMX_EXPORTER_VERSION.jar $SOLR_APP_DIR/jmx-exporter/.
touch $SOLR_APP_DIR/jmx-exporter/solr-jmx-exporter.yml
chown -R solr: $SOLR_APP_DIR/jmx-exporter


# prometheus node-exporter
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v$NODE_EXPORTER_VERSION/node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
tar xzf node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
rm node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
mv node_exporter-$NODE_EXPORTER_VERSION.linux-amd64 $ZOO_APP_DIR/node_exporter
chown -R solr: $ZOO_APP_DIR/node_exporter
cp /tmp/solrcloud_kubernetes/resources/init.d/node_exporter /etc/init.d/.
chmod +x /etc/init.d/node_exporter
sed -i "s#^APP_DIR.*#APP_DIR=$ZOO_APP_DIR/node_exporter#" /etc/init.d/node_exporter
sed -i "s#^RUNAS.*#RUNAS=solr#" /etc/init.d/node_exporter
#$ZOO_APP_DIR/node_exporter/node_exporter > /dev/null 2>&1 &


# prometheus solr-exporter
cd /tmp
cp /tmp/solrcloud_kubernetes/resources/init.d/solr_exporter /etc/init.d/.
chmod +x /etc/init.d/solr_exporter
sed -i "s#^APP_DIR.*#APP_DIR=$SOLR_APP_DIR/contrib/prometheus-exporter#" /etc/init.d/solr_exporter
sed -i "s#^ZOO_SERVERS.*#ZOO_SERVERS=$ZOO_SERVERS#" /etc/init.d/solr_exporter
sed -i "s#^RUNAS.*#RUNAS=solr#" /etc/init.d/solr_exporter
