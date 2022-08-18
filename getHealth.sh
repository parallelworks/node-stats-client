#!/bin/bash
set +e
echo -n "pushing to pw node health monitor: "; date ;

checkDir=$PWD/checks

# cpu
cpu=$($checkDir/check_cpu -w 100 -c 100)
cpu_user=$(echo $cpu | awk '{print $5}' | cut -d '=' -f2 | sed 's|;||g' )
cpu_system=$(echo $cpu | awk '{print $6}' | cut -d '=' -f2 | sed 's|;||g' )
cpu_idle=$(echo $cpu | awk '{print $7}' | cut -d '=' -f2 | sed 's|;||g' )

# load
cpu_load_1=$(cat /proc/loadavg | awk '{print $1}')

# processes
num_proc=$($checkDir/check_procs | awk -F ' ' '{print $3}')

# memory
memory=$($checkDir/check_mem.pl -f -w 20 -c 10)

totalmemory=$(echo $memory | cut -d '|' -f2 | awk -F ' ' '{print $1}' | sed 's|TOTAL=||g' | cut -d 'K' -f1)
usedmemory=$(echo $memory | cut -d '|' -f2 | awk -F ' ' '{print $2}' | sed 's|USED=||g' | cut -d 'K' -f1)

memory_total=$(echo $totalmemory | awk '{ byte =$1 /1024/1024; printf "%.3f", byte }')
memory_used=$(echo $usedmemory | awk '{ byte =$1 /1024/1024; printf "%.3f", byte }')

# disk space

# root disk space
diskspace=$($checkDir/check_disk -w 100 -c 100 -p / --units=kB)
useddiskspace=$(echo $diskspace | cut -d '|' -f2 | awk -F ';' '{print $1}' | sed 's|\/=||g' | sed 's|kB||g' | sed 's| ||g')
totaldiskspace=$(echo $diskspace | cut -d '|' -f2 | awk -F ';' '{print $5}')

disk_used=$(echo $useddiskspace | awk '{ byte =$1 /1024/1024; printf "%.3f", byte }')
disk_total=$(echo $totaldiskspace | awk '{ byte =$1 /1024/1024; printf "%.3f", byte }')

# lustre disk space
lustrediskspace=$($checkDir/check_disk -w 100 -c 100 -p /lustre --units=kB)
usedlustrediskspace=$(echo $lustrediskspace | cut -d '|' -f2 | awk -F ';' '{print $1}' | sed 's|\/lustre=||g' | sed 's|kB||g' | sed 's| ||g')
totallustrediskspace=$(echo $lustrediskspace | cut -d '|' -f2 | awk -F ';' '{print $5}')

disk_lustre_used=$(echo $usedlustrediskspace | awk '{ byte =$1 /1024/1024; printf "%.3f", byte }')
disk_lustre_total=$(echo $totallustrediskspace | awk '{ byte =$1 /1024/1024; printf "%.3f", byte }')


# io 
rootdevice=$(lsblk -l | grep "./$" | awk '{print $1}')

# REQUIRES IOSTAT AND BC
io=$($checkDir/check_iostat -d $rootdevice -c 10000,10000,10000 -w 1000,1000,1000)

tps=$(echo $io | cut -d '|' -f2 | awk -F '=' '{print $2}' | cut -d ';' -f1)
rps=$(echo $io | cut -d '|' -f2 | awk -F '=' '{print $3}' | cut -d ';' -f1)
wps=$(echo $io | cut -d '|' -f2 | awk -F '=' '{print $4}' | cut -d ';' -f1)

# coaster port response time 
# /usr/lib/nagios/plugins/check_tcp -H localhost -p 64000

# get the slurm job if present
# slurmjob=$(/opt/slurm/current/bin/sacct -N $(/usr/bin/hostname) -s RUNNING --noheader | tail -n1 | awk '{print $1}' | sed 's/\.batch//')

# try alternative approach to getting slurmjob consistent across CSPs
# slurmdir="/opt/slurm/current/bin"
# allrows=$($slurmdir/squeue -o "%A %N" -h -a)
# host=$(hostname)
# slurmjob=""
# while IFS= read -r row; do
#     jobid=$(echo $row |  awk '{print $1}')
#     shortnodes=$(echo $row |  awk '{print $2}')
#     expandnodes=$($slurmdir/scontrol show hostname $shortnodes | paste -d, -s)
#     if [[ $expandnodes =~ "$host" ]];then
#         slurmjob=$jobid
#         break
#     fi
# done <<< "$allrows"
#echo $slurmjob

# add this script to crontab to run every minute

hostname=$(hostname)
private_ip=$(hostname -I | awk '{print $1}')
public_ip=$(curl -s ifconfig.me)



read -r -d '' data << EOM
{
    "hostname":"$hostname",
    "poolname":"$PW_POOL_NAME",
    "csp":"$PW_CSP",
    "user":"$PW_USER",
    "session":"$PW_SESSION",
    "public_ip":"$public_ip",
    "private_ip":"$private_ip",
    "project":"$PW_GROUP",
    "slurmjob":"$slurmjob",
    "num_proc":"$num_proc",
    "cpu_user":"$cpu_user",
    "cpu_system":"$cpu_system",
    "cpu_idle":"$cpu_idle",
    "cpu_load_1":"$cpu_load_1",
    "memory_used":"$memory_used",
    "memory_total":"$memory_total",
    "disk_total":"$disk_total",
    "disk_used":"$disk_used",
    "disk_lustre_total":"$disk_lustre_total",
    "disk_lustre_used":"$disk_lustre_used",
    "rps":"$rps",
    "wps":"$wps",
    "tps":"$tps"
}
EOM

# REST API POST REQUEST
echo
echo $data

curl -X POST -H "Content-Type: application/json" -d "$data" https://$PW_PLATFORM_HOST/api/v2/stats
