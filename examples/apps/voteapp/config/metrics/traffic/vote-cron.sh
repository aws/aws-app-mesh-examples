#!/bin/bash
sudo yum -y install expect
trap "exit" INT
while true
do
  ./vote-expect.sh
  #sleep $(( ( RANDOM % 10 )  + 1 ))
  sleep 1
done
trap 'exit 143' SIGTERM # exit = 128 + 15 (SIGTERM)
tail -f /dev/null & wait ${!}
