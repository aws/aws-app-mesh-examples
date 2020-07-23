require_relative 'modules/getvotes'

def getvotes_adapter(event:, context:)
    $yelbdbhost = ENV['yelbdbhost']
    $yelbdbport = 5432
    $yelbddbrestaurants = ENV['yelbddbrestaurants']
    $awsregion = ENV['awsregion']
    votes = getvotes()
    # use the return JSON command when you want the API Gateway to manage the http communication  
    # return JSON.parse(votes)
    { statusCode: 200,
        body: votes,
        headers: {
          'content_type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Headers':  'Authorization,Accepts,Content-Type,X-CSRF-Token,X-Requested-With',
          'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
        }
    }
end

