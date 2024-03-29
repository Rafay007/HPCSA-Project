# Set the AWS region and ECS cluster name
AWS_REGION="eu-central-1"
ECS_CLUSTER_NAME="hbase-cluster"

# Set the Docker image and container name
DOCKER_IMAGE="newnius/hbase:1.2.6"
DOCKER_CONTAINER_NAME="hbase-container"

# Set the Docker network name
DOCKER_NETWORK_NAME="hbase-network"

# # Set the data file URL
# DATA_URL="https://archive.ics.uci.edu/ml/machine-learning-databases/00279/SUSY.csv.gz"

# # Set the table name and column family
# TABLE_NAME="susy"
# COLUMN_FAMILY="cf"


# # Load data into the table
# echo "Loading data into HBase..."
# curl $DATA_URL | gunzip -c | awk -F "," '{print $0}' | while read LINE; do
#     docker exec -i $DOCKER_CONTAINER_NAME hbase shell -n <<-EOF
#     put '$TABLE_NAME',$(echo $LINE | cut -d "," -f 1),"$COLUMN_FAMILY:col1",$(echo $LINE | cut -d "," -f 2)
# EOF
# done


# # Run the benchmark
# echo "Running the benchmark..."
# docker run --rm \
#     --network $DOCKER_NETWORK_NAME \
#     --name hbase-benchmark \
#     -e "TABLE_NAME=$TABLE_NAME" \
#     -e "COLUMN_FAMILY=$COLUMN_FAMILY" \
#     -e "ZOOKEEPER_QUORUM=$DOCKER_CONTAINER_NAME-1,$DOCKER_CONTAINER_NAME-2,$DOCKER_CONTAINER_NAME-3" \
#     "$DOCKER_IMAGE" \
#     /usr/local/hbase/bin/hbase org.apache.hadoop.hbase.test.IntegrationTestBigLinkedList -Dmapred.map.tasks=50 -Dmapred.reduce.tasks=20 -Dhbase.IntegrationTestBigLinkedList.tableName=$TABLE_NAME -Dhbase.IntegrationTestBigLinkedList.columnFamily=$COLUMN_FAMILY


# # Run the benchmark on the data
# echo "Running the benchmark on the data..."
# docker run --rm -it \
#     --network $DOCKER_NETWORK_NAME \
#     $DOCKER_IMAGE \
#     /opt/hbase/bin/hbase org.apache.hadoop.hbase.PerformanceEvaluation \
#     randomWrite \
#     -writeThreads 100 \
#     -skipInitTable \
#     -table $TABLE_NAME \
#     -columnFamily $COLUMN_FAMILY \
#     -numKeys 100000 \
#     -keySize 10 \
#     -valueSize 100

# Download the YCSB benchmark framework and dataset repo
git clone https://github.com/brianfrankcooper/YCSB.git

#copy the hbase-site.xml into YCSB config folder
cp /etc/hbase/hbase.conf/hbase-site.xml ./YCSB/hbase10/conf


# Run the below command in hbase shell
create 'usertable', 'cf', {SPLITS => (1..200).map {|i| "user#{1000+i*(9999-1000)/200}"}, MAX_FILESIZE => 
4*1024**3}

workloads=("workloada" "workloadb" "workloadc" "workloadd" "workloade" "workloadf")

repeatrun=3
records=300000000
operations=10000000
threads=400
driver="hbase10"

for work in "${workloads[@]}"
do
        echo "Loading data for" $work
        ./bin/ycsb load $driver -P ./workloads/$work -p columnfamily=cf -p hbase.zookeeper.znode.parent=/hbase-unsecure -p recordcount=$records -threads 40 > $work"_load.log"
        echo "Running tests"
        for r in `seq 1 $repeatrun`
        do
                ./bin/ycsb run $driver -P ./workloads/$work -p columnfamily=cf -p hbase.zookeeper.znode.parent=/hbase-unsecure -p recordcount=$records -p operationcount=$operations -threads $threads > $work"_run_"$r".log"
        done
        #Truncate table and start over
        hbase shell ./hbase_truncate
done

