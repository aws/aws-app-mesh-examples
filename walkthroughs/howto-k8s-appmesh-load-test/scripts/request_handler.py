from flask import Flask, request, abort, jsonify
import os
import json
import logging

import aiohttp
import asyncio
 
app = Flask(__name__)
 
async def fetch(session, url):
    async with session.get(url) as response:
        resp = await response.json()
        return response


async def fetch_all(backends):
    async with aiohttp.ClientSession() as session:
        tasks = []
        for url in backends:
            tasks.append(fetch(session,url))
        responses = await asyncio.gather(*tasks, return_exceptions=True)
        return responses


@app.route('/health', methods = ['GET'])
def health():
    return f"Alive. Backends -: {os.getenv('BACKENDS')}"
 
@app.route('/', methods = ['GET'])
def wrk():
    if(os.getenv('BACKENDS') and os.getenv('BACKENDS') != ""):
        backends = os.getenv('BACKENDS').split(",")
    else:
        backends = ""

    if(backends):
        responses = asyncio.run(fetch_all(backends))
        for i in responses:
            print(f"Status = {i.status}, reason = {i.reason}, real_url = {i.real_url}")

        retcode = 200 if(set([response.status for response in responses]) == set([200])) else 500
        msg = "backends Success" if retcode == 200 else "error when calling backends"
    else:
        retcode = 200
        msg = "Success"

    print(msg, retcode)

    return jsonify(msg), retcode
 

if __name__ == "__main__":
    logging.getLogger().setLevel(logging.INFO)
    app.run(host='0.0.0.0', debug=True, threaded=True)