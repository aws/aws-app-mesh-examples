#!/bin/bash
curl web.default.svc.cluster.local:9901/stats/prometheus -o file.out
sed -e 's/|/_/g' file.out > front.out
#sed -e 's/_/|/g' file.out > front.out
java -jar prom-stats.jar &
trap "exit" INT
while true
do
  echo "call curl"
  curl web.default.svc.cluster.local:9901/stats/prometheus -o file.out
  sed -e 's/|/_/g' file.out > front.out
  #sed -e 's/_/|/g' file.out > front.out
  echo "called curl"
  sleep 5
  echo "sleep 5"
done

trap 'exit 143' SIGTERM # exit = 128 + 15 (SIGTERM)
tail -f /dev/null & wait ${!}
