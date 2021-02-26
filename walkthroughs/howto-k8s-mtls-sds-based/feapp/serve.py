#!/usr/bin/env python3

try:
    import os
    import socket
    from http.server import BaseHTTPRequestHandler, HTTPServer
    from urllib.request import Request, urlopen
    from urllib.error import URLError, HTTPError
except Exception as e:
    print(f'[ERROR] {e}')

COLOR_HOST = os.environ.get('COLOR_HOST')
print(f'COLOR_HOST is {COLOR_HOST}')

PORT = int(os.environ.get('PORT', '8080'))
print(f'PORT is {PORT}')

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/ping':
            self.send_response(200)
            self.end_headers()
            return

        try:
            print('Trying to hit ' + COLOR_HOST.split(':')[0])
            print(socket.gethostbyname(COLOR_HOST.split(':')[0]))
            req = Request(f'http://{COLOR_HOST}')
            cool_header = self.headers.get('color_header')
            if cool_header is not None:
                req.add_header('color_header', cool_header)
            res = urlopen(req)
            self.send_response(200)
            self.end_headers()
            self.wfile.write(res.read())

        except HTTPError as e:
            print(f'[ERROR] {e}')
            self.send_error(e.code, e.reason)

        except Exception as e:
            print(f'[ERROR] {e}')
            self.send_error(500, b'Something really bad happened')

print('starting server...')
httpd = HTTPServer(('', PORT), Handler)
print('running server...')
httpd.serve_forever()
