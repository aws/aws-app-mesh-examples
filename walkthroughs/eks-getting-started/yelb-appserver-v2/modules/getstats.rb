require_relative 'hostname'
require_relative 'pageviews'

def getstats()
        hostname = hostname()
        pageviews = pageviews()
        stats = '{"hostname": "' + hostname + '"' + ", " + '"pageviews":' + pageviews + "}"
        return stats
end