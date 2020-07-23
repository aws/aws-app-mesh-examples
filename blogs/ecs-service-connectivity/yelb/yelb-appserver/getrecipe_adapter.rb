require_relative 'modules/getrecipe'

def getrecipe_adapter(event:, context:)
    $recipeendpoint = ENV['recipeendpoint']
    recipelinkenv = getrecipe()
    # use the return JSON command when you want the API Gateway to manage the http communication  
    # return JSON.parse(recipe) 
    { statusCode: 200,
        body: recipelinkenv,
        headers: {
          'content_type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Headers':  'Authorization,Accepts,Content-Type,X-CSRF-Token,X-Requested-With',
          'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
        }
    }

end

