#!/bin/bash

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

COVERITY_PATH=coverity
if [[ ! -d $COVERITY_PATH ]]; then
	mkdir $COVERITY_PATH
	# get coverity tarball
	wget https://scan.coverity.com/download/linux64 --post-data "token=$TOKEN&project=node.gl" -O coverity_tool.tgz
	echo "untar coverity into volume 'coverity' "
	# untar coverity into coverity volume
	tar -xvzf coverity_tool.tgz -C $COVERITY_PATH
fi

BUILD_SCRIPT_PATH=nodegl-build
if [[ ! -d $BUILD_SCRIPT_PATH ]]; then
	mkdir $BUILD_SCRIPT_PATH
	copy nodegl build script into build-script volume and give it execution rights
 	echo "copy cnodegl build script into volume 'build-script' "
 	cp nodegl-build.sh $BUILD_SCRIPT_PATH
 	chmod -x $BUILD_SCRIPT_PATH/nodegl-build.sh
fi


# start docker container used for build and running tests
echo "start container"
ABSOLUTE_PATH=$(pwd)
docker run -d --name nodegl-build -t --mount type=bind,src=$ABSOLUTE_PATH/$COVERITY_PATH,dst=/home/root/coverity --mount type=bind,src=$ABSOLUTE_PATH/$BUILD_SCRIPT_PATH,dst=/home/root/build-script nodegl:CI

# launch build and tests
echo "launch build and test on container"
docker exec --workdir /home/root/build-script nodegl-build sh nodegl-build.sh

# get results from docker volumes
echo "recover test results artifacts"
cp -R $COVERITY_PATH/cov-int .
cp -R $BUILD_SCRIPT_PATH/tests-results .
tar cvzf cov-int.tgz cov-int

# upload results
echo "upload result to coverity scan"
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
rm -rf $COVERITY_PATH/cov-int $BUILD_SCRIPT_PATH/tests-results ./cov-int

