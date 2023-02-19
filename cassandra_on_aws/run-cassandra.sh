
# Set the AWS region and ECS cluster name
AWS_REGION="eu-central-1"
ECS_CLUSTER_NAME="cassandra-cluster"

# Set the Docker image and container name
DOCKER_IMAGE="cassandra:latest"
DOCKER_CONTAINER_NAME="cassandra-container"


# Set the Docker network name
DOCKER_NETWORK_NAME="cassandra-network"

# Set the Cassandra keyspace and table name
KEYSPACE="mykeyspace"
TABLE_NAME="mytable"

# Set the SUSY dataset URL and file name
SUSY_DATASET_URL="https://archive.ics.uci.edu/ml/machine-learning-databases/00279/SUSY.csv.gz"
SUSY_DATASET_FILE="SUSY.csv.gz"

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



# Set the path to the cqlsh command-line tool
CQLSH_PATH="/usr/bin/cqlsh"

# Set the path to the ccm command-line tool
CCM_PATH="/usr/local/bin/ccm"

# Create a new ECS cluster
echo "Creating new ECS cluster..."
aws ecs create-cluster --cluster-name $ECS_CLUSTER_NAME --region $AWS_REGION

# Create the Docker network
docker network create $DOCKER_NETWORK_NAME

# Launch the Cassandra nodes
echo "Launching $CASSANDRA_NODES Cassandra nodes..."
for (( i=1; i<=$CASSANDRA_NODES; i++ ))
do
    docker run -d \
        --name $DOCKER_CONTAINER_NAME-$i \
        --network $DOCKER_NETWORK_NAME \
        -e CASSANDRA_SEEDS=$DOCKER_CONTAINER_NAME-1 \
        -e CASSANDRA_CLUSTER_NAME=$ECS_CLUSTER_NAME \
        -e CASSANDRA_DC=dc1 \
        -e CASSANDRA_RACK=rack1 \
        $DOCKER_IMAGE
done

# Wait for the Cassandra nodes to start up
echo "Waiting for Cassandra nodes to start up..."
for (( i=1; i<=$CASSANDRA_NODES; i++ ))
do
    until docker exec $DOCKER_CONTAINER_NAME-$i nodetool status | grep -q "^UN"
    do
        sleep 10
    done
done
