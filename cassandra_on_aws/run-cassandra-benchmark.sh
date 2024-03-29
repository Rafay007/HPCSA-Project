
# Set the AWS region and ECS cluster name
AWS_REGION="eu-central-1"
ECS_CLUSTER_NAME="cassandra-cluster"
CASSANDRA_CONTACT_POINT=$(aws ecs describe-clusters --region $AWS_REGION --clusters $ECS_CLUSTER_NAME --query "clusters[0].registeredContainerInstances[0].ec2InstanceId" --output text | xargs aws ec2 describe-instances --region $AWS_REGION --instance-ids | jq -r ".Reservations[].Instances[].PrivateIpAddress")

# Get the Task Service IP address of Cassandra cluster
TASK_IP=$(aws ecs describe-tasks --cluster <cluster-name> --tasks <task-id> --query "tasks[0].attachments[0].details[?name=='privateIPv4Address'].value" --output text)


# Set the Docker image and container name
DOCKER_IMAGE="cassandra:latest"
DOCKER_CONTAINER_NAME="cassandra-container"
SUSY_DATASET_URL="https://archive.ics.uci.edu/ml/machine-learning-databases/00279/SUSY.csv.gz"

# Set the Docker network name
DOCKER_NETWORK_NAME="cassandra-network"

# Set the Cassandra keyspace and table name
# CASSANDRA_KEYSPACE="mykeyspace"
# TABLE_NAME="mytable"



# # Create a keyspace and table in Cassandra
# echo "Creating keyspace and table in Cassandra..."
# docker exec $DOCKER_CONTAINER_NAME-1 cqlsh -e "CREATE KEYSPACE $KEYSPACE WITH replication = {'class': 'SimpleStrategy', 'replication_factor': $CASSANDRA_NODES};"
# docker exec $DOCKER_CONTAINER_NAME-1 cqlsh -e "CREATE TABLE $KEYSPACE.$TABLE_NAME (id int primary key, value text);"

# # Download the SUSY dataset and load it into Cassandra
# echo "Downloading and loading SUSY dataset into Cassandra..."
# wget $SUSY_DATASET_URL -O $SUSY_DATASET_FILE
# zcat $SUSY_DATASET_FILE | awk -F',' '{print "INSERT INTO '$KEYSPACE'.'$TABLE_NAME' (id, value) VALUES ("NR-1", "$0");"}' | docker exec -i $DOCKER_CONTAINER_NAME-1 cqlsh


# # Set the Cassandra stress options
# CASSANDRA_STRESS_CONCURRENCY="10"
# CASSANDRA_STRESS_ITERATIONS="10000"
# CASSANDRA_STRESS_COMMAND="cql3 user=$CASSANDRA_KEYSPACE -schema \"replication(factor=1)\" -rate threads=100 -node $CASSANDRA_CONTACT_POINT"

# # Run the benchmark test with cassandra-stress
# cassandra-stress $CASSANDRA_STRESS_COMMAND n=$CASSANDRA_STRESS_ITERATIONS -pop seq=1..1000000 -mode native cql3 -log file=/tmp/stress.log -graph file=/tmp/stress.html -col n=val1..val50


# Run the benchmark on YCSB benchmark framework and dataset
git clone https://github.com/brianfrankcooper/YCSB.git


# Run the below commands in cqlsh shell
# docker exec $DOCKER_CONTAINER_NAME-1 cqlsh -e "create keyspace ycsb WITH REPLICATION = {'class' : 'SimpleStrategy', 'replication_factor': 3 }; USE ycsb; create table usertable ( y_id varchar primary key, field0 varchar, field1 varchar, field2 varchar, field3 varchar, field4 varchar, field5 varchar, field6 varchar, field7 varchar, field8 varchar, field9 varchar);"



workloads=("workloada" "workloadb" "workloadc" "workloadd" "workloade" "workloadf")

repeatrun=3
records=300000000
operations=10000000
threads=400
driver="cassandra-cql"
hosts=$TASK_IP

for work in "${workloads[@]}"
do
        echo "Loading data for" $work
        ./bin/ycsb load $driver -P ./workloads/$work -p hosts=$hosts -p recordcount=$records -threads 40 > $work"_load.log"

        echo "Running tests"
        for r in `seq 1 $repeatrun`
        do
                ./bin/ycsb run $driver -P ./workloads/$work -p hosts=$hosts -p recordcount=$records -p operationcount=$operations -threads $threads > $work"_run_"$r".log"
        done
        #Truncate table and start over
        cqlsh -f cassandra_truncate $hosts
done


