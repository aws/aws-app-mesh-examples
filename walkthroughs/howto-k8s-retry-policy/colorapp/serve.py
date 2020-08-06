#!/usr/bin/env python3

try:
    import os
    import random
    from http.server import BaseHTTPRequestHandler, HTTPServer
except Exception as e:
    print(f'[ERROR] {e}')

FAULT_RATE = 50

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
        r = random.randint(1, 100)
        status_code=200
        if r <= FAULT_RATE:
            status_code=503
        self.send_response(status_code)
        self.end_headers()
        self.wfile.write(bytes(COLOR, 'utf8'))

print('starting server...')
httpd = HTTPServer(('', PORT), Handler)
print('running server...')
httpd.serve_forever()
