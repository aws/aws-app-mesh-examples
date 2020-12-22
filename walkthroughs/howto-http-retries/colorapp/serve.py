#!/usr/bin/env python3

try:
    import time
    import os
    from http.server import BaseHTTPRequestHandler, HTTPServer
except Exception as e:
    print(f'[ERROR] {e}')

FAULT_TIME = 1

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

        req_time = float(self.headers.get('req-time'))
        curr_time = time.time()
        time_diff = curr_time - req_time

        if time_diff > FAULT_TIME :
            print('success!')
            self.send_response(200)
        else :
            print('maybe next time!')
            self.send_response(503)

        self.end_headers()
        self.wfile.write(bytes(COLOR, 'utf8'))

print('starting server...')
httpd = HTTPServer(('', PORT), Handler)
print('running server...')
httpd.serve_forever()
