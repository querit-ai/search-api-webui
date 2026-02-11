# Copyright (c) 2026 QUERIT PRIVATE LIMITED
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

import logging
import os
import sys
from pathlib import Path

from flask import Flask, send_from_directory
from flask_cors import CORS


# Configure logging
log_level = logging.DEBUG if os.getenv('FLASK_DEBUG') or os.getenv('FLASK_ENV') == 'development' else logging.INFO
logging.basicConfig(
    level=log_level,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
)
logger = logging.getLogger(__name__)


CURRENT_DIR = Path(__file__).resolve().parent

# Handle static folder for both dev and packaged app
if hasattr(sys, '_MEIPASS'):
    # Running in PyInstaller bundle
    STATIC_FOLDER = Path(sys._MEIPASS) / 'static'
else:
    # Running in development
    STATIC_FOLDER = CURRENT_DIR / 'static'
    if not STATIC_FOLDER.exists():
        DEV_FRONTEND_DIST = CURRENT_DIR.parent / 'frontend' / 'dist'
        if DEV_FRONTEND_DIST.exists():
            STATIC_FOLDER = DEV_FRONTEND_DIST

app = Flask(__name__, static_folder=str(STATIC_FOLDER))
CORS(app)


# Host React Frontend
@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def serve(path):
    if path != '' and (STATIC_FOLDER / path).exists():
        return send_from_directory(str(STATIC_FOLDER), path)
    else:
        return send_from_directory(str(STATIC_FOLDER), 'index.html')


def main():
    import argparse

    parser = argparse.ArgumentParser(description='Search API WebUI')
    parser.add_argument('--port', type=int, default=8889, help='Port to run the server on')
    parser.add_argument('--host', type=str, default='localhost', help='Host to run the server on')
    args = parser.parse_args()

    url = f'http://{args.host}:{args.port}'
    logger.info('Starting Search API WebUI...')
    logger.info(f'  - Serving on: {url}')

    app.run(host=args.host, port=args.port)


if __name__ == '__main__':
    main()
