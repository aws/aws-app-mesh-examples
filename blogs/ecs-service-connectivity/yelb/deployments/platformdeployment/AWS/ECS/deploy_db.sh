export YELB_DB_ENDPOINT=$(aws cloudformation describe-stacks --stack-name yelb-fargate --query "Stacks[0].Outputs[?OutputKey=='YelbDBEndpointUrl'].OutputValue" --output text)
export POSTGRES_PASSWORD=postgres_password

sudo yum install -y postgresql postgresql-server postgresql-devel postgresql-contrib postgresql-docs
sudo service postgresql initdb
#!/bin/bash
set -e

PGPASSWORD=$POSTGRES_PASSWORD psql --host=$YELB_DB_ENDPOINT --port=5432 --username=postgres <<-EOSQL
    \connect yelbdatabase;
	CREATE TABLE restaurants (
    	name        char(30),
    	count       integer,
    	PRIMARY KEY (name)
	);
	INSERT INTO restaurants (name, count) VALUES ('outback', 0);
	INSERT INTO restaurants (name, count) VALUES ('bucadibeppo', 0);
	INSERT INTO restaurants (name, count) VALUES ('chipotle', 0);
	INSERT INTO restaurants (name, count) VALUES ('ihop', 0);
EOSQL

