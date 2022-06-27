#!/usr/bin/env python3

try:
    import os
    import requests
    import json
    from http.server import BaseHTTPRequestHandler, HTTPServer
except Exception as e:
    print(f'[ERROR] {e}')

COLOR = os.environ.get('COLOR', 'no color!')
print(f'COLOR is {COLOR}')

PORT = int(os.environ.get('PORT', '8080'))
print(f'PORT is {PORT}')

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/ping':
            self.send_response(200)
            self.end_headers()
            return

        location = "AZ"
        try:
            location = requests.get('http://169.254.169.254/latest/meta-data/placement/availability-zone').content.decode()
        except Exception as e:
            location = "Error occured while querying meta-data for az"
            print(f'[ERROR] {e}')
        self.send_response(200)
        self.end_headers()
        self.wfile.write(json.dumps({"Color": COLOR, "Location": str(location)}).encode("utf-8"))

print('starting server...')
httpd = HTTPServer(('', PORT), Handler)
print('running server...')
httpd.serve_forever()
