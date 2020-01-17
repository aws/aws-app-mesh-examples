#!/usr/bin/env python3

try:
    import time
    import os
    from http.server import BaseHTTPRequestHandler, HTTPServer
except Exception as e:
    print(f'[ERROR] {e}')


PORT = int(os.environ.get('PORT', '8080'))
print(f'PORT is {PORT}')

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/ping':
            self.send_response(200)
            self.end_headers()
            return

        latency = self.headers.get('latency')
        if latency is not None:
            print("sleeping for " + latency + " sec(s)")
            time.sleep(int(latency))
             
        self.send_response(200)
        self.end_headers()
        self.wfile.write(bytes("red", 'utf8'))

print('starting server...')
httpd = HTTPServer(('', PORT), Handler)
print('running server...')
httpd.serve_forever()
