# Set the AWS region and ECS cluster name
AWS_REGION="eu-central-1"
ECS_CLUSTER_NAME="hbase-cluster"

# Set the Docker image and container name
DOCKER_IMAGE="newnius/hbase:1.2.6"
DOCKER_CONTAINER_NAME="hbase-container"

# Set the Docker network name
DOCKER_NETWORK_NAME="hbase-network"


if [ -x "$(command -v docker)" ]; then
    echo "Update docker"
    echo "Current docker version installed is $(command docker -v)"
    echo "Total number of nodes to be: $1"
	docker service rm $(docker service ls -q)
else
    echo "Installing docker"
	curl -fsSL https://get.docker.com | bash
	sudo usermod -aG docker $USER
	sudo systemctl start docker
fi

docker swarm init --listen-addr $(hostname -I)
# Create the Docker network
docker network create $DOCKER_NETWORK_NAME

# pull required docker images
docker build --tag newnius/hadoop:2.7.4 .
docker pull zookeeper:3.4
docker pull newnius/hbase:1.2.6
docker pull newnius/port-forward
docker pull newnius/docker-proxy


docker service create \
	--name zookeeper-node1 \
	--hostname zookeeper-node1 \
	--detach=true \
	--replicas 1 \
	--network $DOCKER_NETWORK_NAME \
	--endpoint-mode dnsrr \
	--env ZOO_MY_ID=1 \
	--env ZOO_SERVERS="server.1=zookeeper-node1:2888:3888 server.2=zookeeper-node2:2888:3888 server.3=zookeeper-node3:2888:3888" \
	zookeeper:3.4

docker service create \
	--name zookeeper-node2 \
	--hostname zookeeper-node2 \
	--detach=true \
	--replicas 1 \
	--network $DOCKER_NETWORK_NAME \
	--endpoint-mode dnsrr \
	--env ZOO_MY_ID=2 \
	--env ZOO_SERVERS="server.1=zookeeper-node1:2888:3888 server.2=zookeeper-node2:2888:3888 server.3=zookeeper-node3:2888:3888" \
	zookeeper:3.4

docker service create \
	--name zookeeper-node3 \
	--hostname zookeeper-node3 \
	--replicas 1 \
	--detach=true \
	--network $DOCKER_NETWORK_NAME \
	--endpoint-mode dnsrr \
	--env ZOO_MY_ID=3 \
	--env ZOO_SERVERS="server.1=zookeeper-node1:2888:3888 server.2=zookeeper-node2:2888:3888 server.3=zookeeper-node3:2888:3888" \
	zookeeper:3.4


docker service create \
	--name hadoop-master \
	--hostname hadoop-master \
	--network $DOCKER_NETWORK_NAME \
	--replicas 1 \
	--detach=true \
	--endpoint-mode dnsrr \
	newnius/hadoop:2.7.4


docker service create \
	--name hadoop-slave1 \
	--hostname hadoop-slave1 \
	--network $DOCKER_NETWORK_NAME \
	--replicas 1 \
	--detach=true \
	--endpoint-mode dnsrr \
	newnius/hadoop:2.7.4

docker service create \
	--name hadoop-slave2 \
	--hostname hadoop-slave2 \
	--network $DOCKER_NETWORK_NAME \
	--replicas 1 \
	--detach=true \
	--endpoint-mode dnsrr \
	newnius/hadoop:2.7.4

docker service create \
	--name hadoop-slave3 \
	--hostname hadoop-slave3 \
	--network $DOCKER_NETWORK_NAME \
	--replicas 1 \
	--detach=true \
	--endpoint-mode dnsrr \
	newnius/hadoop:2.7.4


docker service create \
	--replicas 1 \
	--name proxy_docker \
	--network $DOCKER_NETWORK_NAME \
	-p 7001:7001 \
	newnius/docker-proxy


# start hadoop by getting into hadoop master container
docker exec -it hadoop-master.1.$(docker service ps hadoop-master --no-trunc | tail -n 1 | awk '{print $1}' ) /bin/sh -c "sbin/stop-yarn.sh;sbin/stop-dfs.sh;bin/hadoop namenode -format;sbin/start-dfs.sh;sbin/start-yarn.sh;"



# Launch the HBase nodes
for ((i=1;i<=$1;i++)); do
    echo "Launching HBase node $i..."
    docker run -d \
        --name "$DOCKER_CONTAINER_NAME-$i" \
        --network $DOCKER_NETWORK_NAME \
        -p "16010:$((16010 + $i - 1))" \
        -p "9090:$((9090 + $i - 1))" \
        -p "2181:$((2181 + $i - 1))" \
        -e "HBASE_MANAGES_ZK=false" \
        -e "HBASE_REGIONSERVERS=$1" \
        -e "HBASE_HEAPSIZE=2G" \
        -e "HBASE_MASTER_HOST=$DOCKER_CONTAINER_NAME-1" \
        -e "HBASE_MASTER_PORT=16000" \
        -e "ZOOKEEPER_QUORUM=$DOCKER_CONTAINER_NAME-1,$DOCKER_CONTAINER_NAME-2,$DOCKER_CONTAINER_NAME-3" \
        -e "ZOOKEEPER_CLIENT_PORT=$((2181 + $i - 1))" \
        "$DOCKER_IMAGE" \
        "/usr/local/hbase/bin/hbase-region-server start"
done

# Launch the HBase master
echo "Launching HBase master..."
docker run -d \
    --name "$DOCKER_CONTAINER_NAME-1" \
    --network $DOCKER_NETWORK_NAME \
    -p "16000:16000" \
    -p "16010:16010" \
    -p "9090:9090" \
    -p "2181:2181" \
    -e "HBASE_MANAGES_ZK=true" \
    -e "HBASE_REGIONSERVERS=$1" \
    -e "HBASE_HEAPSIZE=4G" \
    -e "ZOOKEEPER_QUORUM=$DOCKER_CONTAINER_NAME-1,$DOCKER_CONTAINER_NAME-2,$DOCKER_CONTAINER_NAME-3" \
    -e "ZOOKEEPER_CLIENT_PORT=2181" \
    "$DOCKER_IMAGE" \
    "/usr/local/hbase/bin/hbase master start"

# Wait for the HBase nodes to start up
echo "Waiting for HBase nodes to start up..."
for ((i=1;i<=$1;i++)); do
    while ! docker exec "$DOCKER_CONTAINER_NAME-$i" /usr/local/hbase/bin/hbase shell -n 'list'; do
        sleep 10
    done
done