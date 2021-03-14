require 'socket'

def hostname()
        hostnamedata = Socket.gethostname        
        return hostnamedata
end