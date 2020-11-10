require_relative 'restaurantsdbread'
require_relative 'restaurantsdbupdate'

def restaurantsupdate(restaurant)
        restaurantsdbupdate(restaurant)
        restaurantcount = restaurantsdbread(restaurant)
        return restaurantcount
end