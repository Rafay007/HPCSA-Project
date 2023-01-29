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
docker network create --driver overlay hadoop-net

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
	--network swarm-net \
	--endpoint-mode dnsrr \
	--env ZOO_MY_ID=1 \
	--env ZOO_SERVERS="server.1=zookeeper-node1:2888:3888 server.2=zookeeper-node2:2888:3888 server.3=zookeeper-node3:2888:3888" \
	zookeeper:3.4

docker service create \
	--name zookeeper-node2 \
	--hostname zookeeper-node2 \
	--detach=true \
	--replicas 1 \
	--network swarm-net \
	--endpoint-mode dnsrr \
	--env ZOO_MY_ID=2 \
	--env ZOO_SERVERS="server.1=zookeeper-node1:2888:3888 server.2=zookeeper-node2:2888:3888 server.3=zookeeper-node3:2888:3888" \
	zookeeper:3.4

docker service create \
	--name zookeeper-node3 \
	--hostname zookeeper-node3 \
	--replicas 1 \
	--detach=true \
	--network swarm-net \
	--endpoint-mode dnsrr \
	--env ZOO_MY_ID=3 \
	--env ZOO_SERVERS="server.1=zookeeper-node1:2888:3888 server.2=zookeeper-node2:2888:3888 server.3=zookeeper-node3:2888:3888" \
	zookeeper:3.4


docker service create \
	--name hadoop-master \
	--hostname hadoop-master \
	--network swarm-net \
	--replicas 1 \
	--detach=true \
	--endpoint-mode dnsrr \
	newnius/hadoop:2.7.4


docker service create \
	--name hadoop-slave1 \
	--hostname hadoop-slave1 \
	--network swarm-net \
	--replicas 1 \
	--detach=true \
	--endpoint-mode dnsrr \
	newnius/hadoop:2.7.4

docker service create \
	--name hadoop-slave2 \
	--hostname hadoop-slave2 \
	--network swarm-net \
	--replicas 1 \
	--detach=true \
	--endpoint-mode dnsrr \
	newnius/hadoop:2.7.4

docker service create \
	--name hadoop-slave3 \
	--hostname hadoop-slave3 \
	--network swarm-net \
	--replicas 1 \
	--detach=true \
	--endpoint-mode dnsrr \
	newnius/hadoop:2.7.4


docker service create \
	--replicas 1 \
	--name proxy_docker \
	--network swarm-net \
	-p 7001:7001 \
	newnius/docker-proxy


docker service create \
	--name hbase-master \
	--hostname hbase-master \
	--network swarm-net \
	--replicas 1 \
	--detach=true \
	--endpoint-mode dnsrr \
	newnius/hbase:1.2.6




for i in $(eval echo {1..$1})
do
    echo "Welcome $i times"
    echo "$(docker service create --name hbase-slave$i --hostname hbase-slave1 --network swarm-net --replicas 1 --detach=true --endpoint-mode dnsrr newnius/hbase:1.2.6)"
done




docker exec -it hadoop-master.1.$(docker service ps hadoop-master --no-trunc | tail -n 1 | awk '{print $1}' ) /bin/sh -c "sbin/stop-yarn.sh;sbin/stop-dfs.sh;bin/hadoop namenode -format;sbin/start-dfs.sh;sbin/start-yarn.sh;"

docker exec -it hbase-master.1.$(docker service ps hbase-master --no-trunc | tail -n 1 | awk '{print $1}' ) /bin/sh -c "bin/start-hbase.sh;bin/hbase-daemon.sh start thrift;"
