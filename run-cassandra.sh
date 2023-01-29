if [ -x "$(command -v docker)" ]; then
    echo "Update docker"
    echo "Current docker version installed is $(command docker -v)"
    echo "Total number of nodes to be: $1"
else
    echo "Install docker"
fi

if [[ -n "$(docker images -q cassandra:latest)" ]]; then
  echo "Official latest Cassandra docker image exists"
else
    echo "Official latest Cassandra docker needs to be installed"
    echo "Installing cassandra docker image $(command docker pull cassandra:latest)"
fi

# Cassandra docker multi node cluster setup


for i in $(eval echo {1..$1})
do
    echo "Welcome $i times"
if [ $i == 1 ]; then
    echo "$(docker run --name cassandra-$i -p 9041:9041 -d cassandra)"
    instance=$(docker inspect --format="{{ .NetworkSettings.IPAddress }}" cassandra-$i)
    echo "INSTANCE-$i IP: ${instance}"
    echo "Container is started and running, above is the container id"
else
    echo "$(docker run --name cassandra-$i -p $(( $i + 9040 )):$(( $i + 9039 )) -d -e CASSANDRA_SEEDS=$instance cassandra)"
    instance=$(docker inspect --format="{{ .NetworkSettings.IPAddress }}" cassandra-$i)
    echo "INSTANCE-$i IP: ${instance}"
    echo "Container is started and running, above is the container id"
fi  
done

