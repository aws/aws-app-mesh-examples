#/bin/sh
set -e

pkgs="database queue"

cd src
for p in $pkgs; do
    echo "test: $p"
    cd $p
    [ -f docker-compose.test.yml ] && docker-compose -f docker-compose.test.yml run --rm sut
    cd ..
done
