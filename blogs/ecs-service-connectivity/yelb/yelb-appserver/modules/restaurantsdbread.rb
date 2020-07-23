require 'pg'
require 'pg_ext'
require 'aws-sdk-dynamodb'

def restaurantsdbread(restaurant)
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
    else 
        con = PG.connect  :host => $yelbdbhost,
                        :port => $yelbdbport,
                        :dbname => 'yelbdatabase',
                        :user => 'postgres',
                        :password => 'postgres_password'
        con.prepare('statement1', 'SELECT count FROM restaurants WHERE name =  $1')
        res = con.exec_prepared('statement1', [ restaurant ])
        restaurantcount = res.getvalue(0,0)
        con.close
    end
    return restaurantcount.to_s
end 
