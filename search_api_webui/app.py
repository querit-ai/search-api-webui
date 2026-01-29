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

import json
import logging
import os
import platform
import socket
import sys
import threading
import time
import webbrowser
from pathlib import Path

from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS

from search_api_webui.providers import load_providers

try:
    import webview
    WEBVIEW_AVAILABLE = True
except ImportError:
    WEBVIEW_AVAILABLE = False


# Auto-enable webview mode when running as packaged executable
# This replaces the need for a separate PyInstaller runtime hook
if (
    getattr(sys, 'frozen', False)
    and platform.system() in ('Windows', 'Darwin')
    and '-w' not in sys.argv
    and '--webview' not in sys.argv
):
    sys.argv.append('-w')


# Configure logging based on Flask debug mode or environment variable
log_level = logging.DEBUG if os.getenv('FLASK_DEBUG') or os.getenv('FLASK_ENV') == 'development' else logging.INFO
logging.basicConfig(
    level=log_level,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
)
logger = logging.getLogger(__name__)


def get_resource_path(relative_path):
    '''Get absolute path to resource, works for dev and for PyInstaller.'''
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = Path(sys._MEIPASS)
    except Exception:
        base_path = Path(__file__).resolve().parent

    return base_path / relative_path


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

# Use get_resource_path for providers.yaml
PROVIDERS_YAML = get_resource_path('providers.yaml')
USER_CONFIG_DIR = Path.home() / '.search-api-webui'
USER_CONFIG_JSON = USER_CONFIG_DIR / 'config.json'

if not USER_CONFIG_DIR.exists():
    USER_CONFIG_DIR.mkdir(parents=True, exist_ok=True)

if PROVIDERS_YAML.exists():
    provider_map = load_providers(str(PROVIDERS_YAML))
else:
    logger.error(f'Configuration file not found at {PROVIDERS_YAML}')
    provider_map = {}


def get_stored_config():
    if not USER_CONFIG_JSON.exists():
        return {}
    try:
        with open(USER_CONFIG_JSON, encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        logger.error(f'Error reading config: {e}')
        return {}


def save_stored_config(config_dict):
    try:
        with open(USER_CONFIG_JSON, 'w', encoding='utf-8') as f:
            json.dump(config_dict, f, indent=2)
    except Exception as e:
        logger.error(f'Error saving config: {e}')


@app.route('/api/providers', methods=['GET'])
def get_providers_list():
    stored_config = get_stored_config()
    providers_info = []

    for name, provider_instance in provider_map.items():
        config_details = provider_instance.config

        user_conf = stored_config.get(name, {})

        if isinstance(user_conf, str):
            user_conf = {'api_key': user_conf}

        has_key = bool(user_conf.get('api_key'))

        providers_info.append(
            {
                'name': name,
                'has_key': has_key,
                'details': config_details,
                'user_settings': {
                    'api_url': user_conf.get('api_url', ''),
                    'limit': user_conf.get('limit', '10'),
                    'language': user_conf.get('language'),
                    'use_proxy': user_conf.get('use_proxy', False),
                    'proxy_url': user_conf.get('proxy_url', ''),
                    'skip_warmup': user_conf.get('skip_warmup', False),
                },
            },
        )
    return jsonify(providers_info)


@app.route('/api/config', methods=['POST'])
def update_config():
    data = request.json
    provider_name = data.get('provider')

    if not provider_name:
        return jsonify({'error': 'Provider name is required'}), 400

    api_key = data.get('api_key')

    api_url = data.get('api_url', '').strip()
    limit = data.get('limit', '10')
    language = data.get('language')
    use_proxy = data.get('use_proxy', False)
    proxy_url = data.get('proxy_url', '').strip()
    skip_warmup = data.get('skip_warmup', False)

    all_config = get_stored_config()

    if provider_name in all_config and isinstance(all_config[provider_name], str):
        all_config[provider_name] = {'api_key': all_config[provider_name]}

    # Initialize provider config if not exists
    if provider_name not in all_config:
        all_config[provider_name] = {}

    # Update advanced settings, skip empty values
    if api_url:
        all_config[provider_name]['api_url'] = api_url
    elif 'api_url' in all_config[provider_name]:
        del all_config[provider_name]['api_url']

    if limit:
        all_config[provider_name]['limit'] = limit
    elif 'limit' in all_config[provider_name]:
        del all_config[provider_name]['limit']

    if language:
        all_config[provider_name]['language'] = language
    elif 'language' in all_config[provider_name]:
        del all_config[provider_name]['language']

    # Save proxy settings
    if use_proxy:
        all_config[provider_name]['use_proxy'] = True
        if proxy_url:
            all_config[provider_name]['proxy_url'] = proxy_url
    else:
        if 'use_proxy' in all_config[provider_name]:
            del all_config[provider_name]['use_proxy']
        if 'proxy_url' in all_config[provider_name]:
            del all_config[provider_name]['proxy_url']

    # Save warmup settings
    if skip_warmup:
        all_config[provider_name]['skip_warmup'] = True
    elif 'skip_warmup' in all_config[provider_name]:
        del all_config[provider_name]['skip_warmup']

    # Only update api_key if explicitly provided
    if api_key is not None:
        all_config[provider_name]['api_key'] = api_key

    # Clean up empty provider config
    if not all_config[provider_name]:
        del all_config[provider_name]

    save_stored_config(all_config)
    return jsonify({'status': 'success'})


@app.route('/api/search', methods=['POST'])
def search_api():
    data = request.json
    query = data.get('query')
    provider_name = data.get('provider', 'querit')

    api_key = data.get('api_key')

    stored_config = get_stored_config()
    provider_config = stored_config.get(provider_name, {})

    if isinstance(provider_config, str):
        provider_config = {'api_key': provider_config}

    if not api_key:
        api_key = provider_config.get('api_key')

    if not api_key:
        return (
            jsonify({'error': f'API Key for {provider_name} is missing. Please configure it.'}),
            401,
        )

    provider = provider_map.get(provider_name)
    if not provider:
        return jsonify({'error': 'Provider not found'}), 404

    search_kwargs = {
        'api_url': provider_config.get('api_url'),
        'limit': provider_config.get('limit'),
        'language': provider_config.get('language'),
        'proxy_url': provider_config.get('proxy_url') if provider_config.get('use_proxy') else None,
        'skip_warmup': provider_config.get('skip_warmup', False),
    }

    result = provider.search(query, api_key, **search_kwargs)
    return jsonify(result)


# Host React Frontend
@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def serve(path):
    if path != '' and (STATIC_FOLDER / path).exists():
        return send_from_directory(str(STATIC_FOLDER), path)
    else:
        return send_from_directory(str(STATIC_FOLDER), 'index.html')


def wait_for_server_ready(host, port):
    start_time = time.time()
    while time.time() - start_time < 10:
        try:
            with socket.create_connection((host, port), timeout=1):
                return True
        except (OSError, ConnectionRefusedError):
            time.sleep(0.1)
    return False


def main():
    import argparse

    parser = argparse.ArgumentParser(description='Search API WebUI')
    parser.add_argument('--port', type=int, default=8889, help='Port to run the server on')
    parser.add_argument('--host', type=str, default='localhost', help='Host to run the server on')
    parser.add_argument('-w', '--webview', action='store_true', help='Use webview to open the application')
    args = parser.parse_args()

    url = f'http://{args.host}:{args.port}'
    logger.info('Starting Search API WebUI...')
    logger.info(f'  - Config Storage: {USER_CONFIG_JSON}')
    logger.info(f'  - Serving on: {url}')
    if args.webview:
        logger.info('  - Mode: webview')

    if args.webview:
        if not WEBVIEW_AVAILABLE:
            logger.warning('webview library not installed. Falling back to webbrowser.')
            # Start server in background thread and wait for it to be ready
            server_thread = threading.Thread(
                target=lambda: app.run(
                    host=args.host, port=args.port, use_reloader=False,
                ),
                daemon=True,
            )
            server_thread.start()
            if wait_for_server_ready(args.host, args.port):
                logger.info(f'Server is ready! Opening browser: {url}')
                webbrowser.open(url)
            else:
                logger.error('Server took too long to start. Browser not opened.')
        else:
            # Start server in background thread and wait for it to be ready, then start webview
            server_thread = threading.Thread(
                target=lambda: app.run(
                    host=args.host, port=args.port, use_reloader=False,
                ),
                daemon=True,
            )
            server_thread.start()
            if wait_for_server_ready(args.host, args.port):
                logger.info('Server is ready! Using webview mode...')
                webview.create_window('Search API WebUI', url, width=1200, height=800)
                webview.start()
            else:
                logger.error('Server took too long to start. Webview not opened.')
    else:
        # Start a background thread to check server status and open the browser automatically
        def open_browser():
            if wait_for_server_ready(args.host, args.port):
                logger.info(f'Server is ready! Opening browser: {url}')
                webbrowser.open(url)
            else:
                logger.error('Server took too long to start. Browser not opened.')
        threading.Thread(target=open_browser, daemon=True).start()
        app.run(host=args.host, port=args.port)


if __name__ == '__main__':
    main()
