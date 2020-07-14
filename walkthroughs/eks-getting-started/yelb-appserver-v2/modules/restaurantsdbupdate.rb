require 'pg'
require 'pg_ext'
require 'aws-sdk-dynamodb'

def restaurantsdbupdate(restaurant)
    if ($yelbddbrestaurants != nil && $yelbddbrestaurants != "") then        
        dynamodb = Aws::DynamoDB::Client.new(region: $awsregion)
        params = {
            table_name: $yelbddbrestaurants,
            key: {
                name: restaurant
            }
        }
        restaurantrecord = dynamodb.get_item(params)
        restaurantcount = restaurantrecord.item['restaurantcount']
        restaurantcount += 1 
        params = {
                table_name: $yelbddbrestaurants,
                key: {
                    name: restaurant
                },
                update_expression: 'set restaurantcount = :c',
                expression_attribute_values: {':c' => restaurantcount},
                return_values: 'UPDATED_NEW'
        }
        restaurantrecord = dynamodb.update_item(params)
    else 
        con = PG.connect  :host => $yelbdbhost,
                      :port => $yelbdbport,
                      :dbname => 'yelbdatabase',
                      :user => 'postgres',
                      :password => 'postgres_password'
        con.prepare('statement1', 'UPDATE restaurants SET count = count +1 WHERE name = $1')
        res = con.exec_prepared('statement1', [ restaurant ])
        con.close
    end 
end 
