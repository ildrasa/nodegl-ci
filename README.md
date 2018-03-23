# Nodegl CI 

## Prerequisite
- docker
- bash
- tar
- wget
- curl
 
## Usage
Ensure you have access right to docker volumes directory.
Launch script nodegl-sh-ci.sh `<coverity upload token> <email account for coverity scan>`.
```shell
./nodegl-sh-ci.sh "$MY_TOKEN" "$MAIL"
```

## Results
Coverity scan results are in archive cov-int.tgz, this archive is also uploaded to coverity site.
Nodegl unitary and functional tests results are stored in directory tests-results
