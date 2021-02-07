#!/bin/sh
#
#By: Alfred Adib
#Date: May 1st, 2020
#Description: This script is written to help IBM consultants build OpenShift mirror registries at customer sites with no internet access.
#The consultant builds the registry on a server that has internet and then runs this script to export the registry into a single tar file
#The consultatnt then copies the tar file and the script to the customer server and runs the script to import the tar file into customer registry
#
#Example:
#Openshift mirror registry is running on server aa.bb.cc and we want to install the same registry at customer offline server xx.yy.zz. Perform the following steps:
#1- run script with options import and registry name (./migrate_registry.sh export mirror-registry) on server aa.bb.cc
#2- Script will run for about an hour and output a tar file. While it is running it will ask for registry username and password and the customer target server FQDN 
#3- Work with customer to get tar file and script installed on target server xx.yy.zz.
#4- Execute script with import option and registry name (./migrate_registry.sh import mirror-registry) on server xx.yy.zz.
#5- Script will run for about 20 minutes and will detect the tar file and load it onto the target registry
#
#Prerequisetes:
#1- You have a running registry on source server with all images for a specific OpenShift version loaded
#2- You have at least 50GB of space available on source and target servers
#3- You have a running registry on target server that is empty
#
#Update Log:
#Date		Name		Summary
#May 1st, 2020 	Alfred Adib 	Updated xyz

usage(){
if [ $# -ne 2 ]; then
  echo "usage: $0 <export/import> <registry_name>"
  exit 1
else
  action=$1; registry=$2
  echo $action | egrep -q "export|import" 2>/dev/null; rc=$?
  if [ $rc -ne 0 ]; then
    echo "$action is not an expected action, please correct!!!"
    exit 3
  fi
  port=$(podman ps | grep " ${registry}$" | awk '{print $(NF-1)}' | cut -d"-" -f1 | cut -d":" -f2)
  if [ -z "$port" ]; then
    echo "$registry is not a valid registry name, please correct!!!"
    exit 5
  fi
fi
}

get_server_name(){
echo;echo "Getting server FQDN..."
hostname=$(hostname)
server=$(nslookup $hostname | grep ^Name | awk '{print $2}' 2>/dev/null)
if [ -z "$server" ]; then
  echo "$hostname is not a valid DNS name, please correct!!!"
  exit 7
else
  echo "FQDN of server is $server"
fi
}

get_credentials(){
echo;echo "Please enter username and password for $server:$port"
echo -n "username: "; read username
echo -n "password: "; stty -echo; read password; stty echo; echo
}

get_repo(){
echo;echo "Getting repo name..."
echo -n "Enter target server name: "; read server1
repo=$(curl -u $username:$password https://$server:$port/v2/_catalog 2>/dev/null | grep -v error | tr -d '"|[|]|{|}' | cut -d":" -f2)
if [ -z "$repo" ]; then
  echo "Please check repo username and password!!!"
  exit 9
fi
}

pull_images(){
echo;echo "Logging into $server:$port/$repo and pulling images..."
podman login -u $username -p $password $server:$port
tag_list=$(curl -u $username:$password -X GET https://$server:$port/v2/$repo/tags/list 2>/dev/null| tr ":|," "\n" | tr -d '"|{|}|[|]' | egrep -v ^"name|ocp4/openshift4|tags" | grep ^[0-9])
tt=$(echo $tag_list | wc -w); c=1
for t in $(echo $tag_list);do
  echo;echo "Pulling $c of $tt"
  podman pull $server:$port/$repo:$t
  c=$(expr $c + 1)
done
}

retag_images(){
echo;echo "Retagging images with target server name $server1..."
c=1
for t in $(echo $tag_list);do
  echo "Tagging $server:$port/$repo:$t ($c of $tt)"
  podman tag $server:$port/$repo:$t $server1:$port/$repo:$t
  c=$(expr $c + 1)
done
}

save_compress_remove(){
echo;echo "Saving images, zipping and deleting images..."
c=1
for t in $(echo $tag_list);do
  echo;echo "Saving, zipping and deleting image $t ($c of $tt)"
  podman save $server1:$port/$repo:$t -o $t.tar
  gzip $t.tar
  podman rmi $server:$port/$repo:$t
  podman rmi $server1:$port/$repo:$t
  c=$(expr $c + 1)
done
}

create_tar(){
echo;echo "Taring up all $t images..."
version=$(ls *gz | cut -d"-" -f1 | sort -u)
tar cvf $server1-$version.tar *.gz
rm -f *.gz
echo; echo "$server1-$version.tar created and ready for being transfered to target system $server1"
}

untar(){
tar_filename=$(ls $server*.tar)
if [ ! -f $tar_filename ]; then
  echo "Could not find tar file, please correct!!!"
  exit 11
fi
tt=$(tar tvf $tar_filename | wc -l)
echo;echo "Untaring $tar_filename ($tt images)..."
tar xvf $tar_filename; rc=$?
if [ "$rc" -eq 0 ]; then
  rm -f $tar_filename
else
  echo "Could not untar $tar_filename, please correct!!!"
  exit 13
fi
}

unzip_load(){
echo;echo "Unzipping, loading images and deleting tar file..."
c=1
for t in $(ls *gz | sed "s:.tar.gz::g");do
  echo;echo "Unzipping, loading and deleting $t.tar.gz ($c of $tt)"
  gunzip $t.tar.gz
  podman load -i $t.tar
  rm -f $t.tar
  c=$(expr $c + 1)
done
}

push_images(){
echo;echo "Pushing images to $server:$port/$repo and removing images locally..."
repo=$(curl -u $username:$password https://$server:$port/v2/_catalog 2>/dev/null | grep -v error | tr -d '"|[|]|{|}' | cut -d":" -f2)
podman login -u $username -p $password $server:$port
c=1
for t in $(podman images | grep $server:$port/$repo | awk '{print $2}'); do
  echo;echo "Pushing $server:$port/$repo:$t and deleting locally ($c of $tt)"
  podman push $server:$port/$repo:$t
  podman rmi $server:$port/$repo:$t
  c=$(expr $c + 1)
done
}

verify_push(){
echo;echo "Verifying images successfully pushed to https://$server:$port..."
tag_list=$(curl -u $username:$password -X GET https://$server:$port/v2/$repo/tags/list 2>/dev/null | tr ":|," "\n" | tr -d '"|{|}|[|]' | egrep -v ^"name|ocp4/openshift4|tags" | grep ^[0-9])
tt1=$(echo $tag_list | wc -w)
if [ $tt -eq $tt1 ]; then
  echo "Verified $tt images pushed to https://$server:$port"
  echo $tag_list | tr " " "\n"
else
  echo "No of images mismatch: tar file had $tt images, $tt1 images pushed to repo"
fi
}

#Main
usage $*
get_server_name
get_credentials
if [ "$action" = "export" ]; then
  get_repo
  pull_images
  retag_images
  save_compress_remove
  create_tar
else
  untar
  unzip_load
  push_images
  verify_push
fi
