
#!/bin/bash

START=`date +%Y-%m-%dT%H:%M:%S -d"-60 sec"`

JOBS=`/usr/bin/sacct -n -a -L -S $START --format=Cluster%64,User,UID,ElapsedRaw,JobID,Submit,Start,End,JobName,AllocNodes,AllocCPUS,State -P`

BIFS="$IFS"
IFS=$'\n'

##Generate query file

for job in $JOBS
do

echo "$job"
IFS='|' read Cluster UserName UserID ElapsedRaw JobID Submit StartTime EndTime JobName AllocNodes AllocCPUS State  <<< "$job"

read -r -d '' data << EOM
{
    "cluster":"$Cluster",
    "poolname":"$PW_POOL_NAME",
    "session_num":"$PW_SESSION",
    "username":"$UserName",
    "project":"$PW_GROUP",
    "job_name":"$JobName",
    "uid":"$UserID",
    "elapsed_sec":"$ElapsedRaw",
    "job_id":"$JobID",
    "submit_time":"$Submit",
    "start_time":"$StartTime",
    "end_time":"$EndTime",
    "nodes":"$AllocNodes",
    "cpus":"$AllocCPUS",
    "state":"$State"
}
EOM

# REST API POST REQUEST
echo
echo $data

curl -X POST -H "Content-Type: application/json" -d "$data" https://$PW_PLATFORM_HOST/api/v2/stats/slurm

done
