require 'rubygems'
require 'httparty'


def getrecipe()
       recipeurl = '{"recipelink_pancakes": "'+ getrecipeurl('pancake') + '", ' + 
      '"recipelink_burritos": "' + getrecipeurl('burritos') + '", ' +
      '"recipelink_steak": "' + getrecipeurl('steak') + '", ' +
      '"recipelink_lasagne": "' + getrecipeurl('lasagne') + '" ' + "}"
       return recipeurl
end

def getrecipeurl(item)
    url = 'http://www.recipepuppy.com/api/?q=' + item
    response = HTTParty.get(url)
    responseurl = JSON.parse(response.body)["results"][0]["href"]
    return responseurl
end