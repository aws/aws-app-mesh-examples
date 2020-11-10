from flask import Flask, request, abort, jsonify
from subprocess import PIPE, run
import socket
import os
import sys
import requests
import time
import json
import logging

app = Flask(__name__)

@app.route('/', methods = ['GET'])
def health():
    return 'Alive!'

@app.route('/wrk', methods = ['GET', 'POST'])
def wrk():
    if request.method == 'GET':
        return ('Hello from behind wrk2 host! hostname: {} resolved'
                ' hostname: {}\n'.format(socket.gethostname(),
                                        socket.gethostbyname(socket.gethostname())))
    if request.method == 'POST':
        logging.info('Input json: %s', request.data)
        params = json.loads(request.data)
        connections = duration = threads = timeout = ''

        if 'connections' in params:
            connections = '-c ' + params['connections']
        if 'duration' in params:
            duration = '-d ' + params['duration']
        if 'threads' in params:
            threads = '-t ' + params['threads']
        if 'timeout' in params:
            timeout = '--timeout '  + params['timeout']
        if 'rate' in params:
            rate = '-R ' + params['rate']
        else:
            abort(400, 'Required param \'rate\' not specified')
        if 'url' in params:
            url = params['url']
        else:
            abort(400, 'Required param \'url\' not specified')

        command = 'wrk {} {} {} {} {} {}'.format(connections, rate, duration, threads, timeout, url)
        out = run(command, stdout=PIPE, stderr=PIPE, universal_newlines=True, shell=True)
        logging.info('Result: %s', out)
        return jsonify({'out': out.stdout, 'err': out.stderr, 'code': out.returncode})

if __name__ == "__main__":
    logging.getLogger().setLevel(logging.INFO)
    app.run(host='0.0.0.0', port=80, debug=True, threaded=True)
