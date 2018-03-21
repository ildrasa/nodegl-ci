#!/bin/bash

set -e

printHelp() {
  echo "Usage: nodegl-sh-ci.sh <coverity token> <email>"
  echo ""
}

if [ $# -eq 0 ]; then
  printHelp
  exit 0
fi
if [ $# -ne 2 ]; then
  echo "ERROR: wrong number of arguments"
  printHelp
  exit 0
fi

TOKEN=$1
MAIL=$2

# Verify parameters
if [ -z "${MAIL}" ] ; then
  echo "MAIL is not specified"
  exit 1;
fi 
if [ -z "${TOKEN}" ] ; then
  echo "TOKEN is not specified"
  exit 1;
fi 

# clean previous results
rm -rf ./cov-int.tgz ./test-results

echo "manage docker image"
# check if docker image is already built
if [[ "$(docker images -q nodegl:CI 2> /dev/null)" == "" ]]; then
	echo "docker image nodegl:CI not built yet; will be built"
	docker build -f nodegl-dockerfile -t nodegl:CI .
fi


echo "manage docker volumes"
# get "coverity" docker volume path; create it if it does not exists yet
COVERITY_PATH=$(docker volume inspect --format '{{ .Mountpoint }}' coverity)
if [[ -z "$COVERITY_PATH" ]]; then
	echo "Docker volume 'coverity' not found. It will de be created"
	docker volume create coverity
	COVERITY_PATH=$(docker volume inspect --format '{{ .Mountpoint }}' coverity)
	# get coverity tarball
	wget https://scan.coverity.com/download/linux64 --post-data "token=$TOKEN&project=node.gl" -O coverity_tool.tgz
	# get tarbell hash
	wget https://scan.coverity.com/download/linux64 --post-data "token=$TOKEN&project=node.gl&md5=1" -O coverity_tool.md5
	# verify coverity download
	if[ "$(md5sum /home/path/file1.txt |awk '{print $1)')" == "$(md5sum /home/path/file2.txt |awk '{print $1}')" ]; then
		echo "untar coverity into volume 'coverity' "
		# untar coverity into coverity volume
		tar -xvzf coverity_tool.tgz -C $COVERITY_PATH
		echo "Docker volume 'coverity' created at $COVERITY_PATH."
	else
		docker volume rm coverity
		echo "coverity download failed"
		exit 1
	fi
else
	echo "Docker volume 'coverity' found at $COVERITY_PATH."
fi



# get "build-script" docker volume path; create it if it does not exists yet
BUILD_SCRIPT_PATH=$(docker volume inspect --format '{{ .Mountpoint }}' build-script)
if [[ -z "$BUILD_SCRIPT_PATH" ]]; then
	echo "Docker volume 'build-script' not found. It will de be created"
	docker volume create build-script
	BUILD_SCRIPT_PATH=$(docker volume inspect --format '{{ .Mountpoint }}' build-script)
	# copy nodegl build script into build-script volume and give it execution rights
	echo "copy cnodegl build script into volume 'build-script' "
	cp nodegl-build.sh $BUILD_SCRIPT_PATH
	chmod -x $BUILD_SCRIPT_PATH/nodegl-build.sh
fi
echo "Docker volume 'build-script' found at $BUILD_SCRIPT_PATH."

# start docker container used for build and running tests
echo "start container"
docker run -d --name nodegl-build -t --mount source=coverity,destination=/home/root/coverity --mount source=build-script,destination=/home/root/build-script nodegl:CI -e TOKEN=$TOKEN -e MAIL=$MAIL

# launch build and tests
echo "launch build and test on container"
docker exec --workdir /home/root/build-script nodegl-build sh nodegl-build.sh

# get results from docker volumes
echo "recover test results artifacts"
cp -R $COVERITY_PATH/cov-int .
cp -R $BUILD_SCRIPT_PATH/tests-results .
tar cvzf cov-int.tgz cov-int

# upload results
echo "upload result to coverity scan
curl --form token=$TOKEN \
  --form email=$MAIL \
  --form file=@cov-int.tgz \
  --form version="Version" \
  --form description="Description" \
  https://scan.coverity.com/builds?project=node.gl

# clean for next run
echo "clean build artifacts"
docker stop nodegl-build
docker rm nodegl-build
rm -rf $COVERITY_PATH/cov-int $BUILD_SCRIPT_PATH/test-results ./cov-int

