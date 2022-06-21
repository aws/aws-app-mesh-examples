import os
from re import I
import requests
import config
import json
from flask import Flask, request
from aws_xray_sdk.core import xray_recorder, patch_all
from aws_xray_sdk.ext.flask.middleware import XRayMiddleware
from http.client import HTTPConnection
HTTPConnection._http_vsn_str = "HTTP/1.1"

app = Flask(__name__)

xray_recorder.configure(
    context_missing='LOG_ERROR',
    service=config.XRAY_APP_NAME,
)
patch_all()
XRayMiddleware(app, xray_recorder)


@app.route('/ping')
def ping():
    return 'Pong'


@app.route('/test')
def test():
    return 'It works :)'


@app.route('/color')
def color():
    print(request.headers)
    response = requests.get(f'http://{config.COLOR_HOST}')

    resp_dict = {'response': response.text,
                 'reason': response.reason,
                 'resp_headers': str(response.headers),
                 'req_headers': str(request.headers),
                 'host': config.COLOR_HOST,
                 'req_url': request.url,
                 'status_code': response.status_code}

    return json.dumps(resp_dict, indent=2)


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=config.PORT, debug=config.DEBUG_MODE)
