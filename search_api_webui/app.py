import json
import os
import webbrowser
from pathlib import Path
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from search_api_webui.providers import load_providers

CURRENT_DIR = Path(__file__).resolve().parent

STATIC_FOLDER = CURRENT_DIR / 'static'
if not STATIC_FOLDER.exists():
    DEV_FRONTEND_DIST = CURRENT_DIR.parent / 'frontend' / 'dist'
    if DEV_FRONTEND_DIST.exists():
        STATIC_FOLDER = DEV_FRONTEND_DIST

app = Flask(__name__, static_folder='static')
CORS(app)

PROVIDERS_YAML = CURRENT_DIR / 'providers.yaml'
USER_CONFIG_DIR = Path.home() / '.search-api-webui'
USER_CONFIG_JSON = USER_CONFIG_DIR / 'config.json'

if not USER_CONFIG_DIR.exists():
    USER_CONFIG_DIR.mkdir(parents=True, exist_ok=True)

if PROVIDERS_YAML.exists():
    provider_map = load_providers(str(PROVIDERS_YAML))
else:
    print(f"Error: Configuration file not found at {PROVIDERS_YAML}")
    provider_map = {}

def get_stored_config():
    if not USER_CONFIG_JSON.exists():
        return {}
    try:
        with open(USER_CONFIG_JSON, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error reading config: {e}")
        return {}

def save_stored_config(config_dict):
    try:
        with open(USER_CONFIG_JSON, 'w', encoding='utf-8') as f:
            json.dump(config_dict, f, indent=2)
    except Exception as e:
        print(f"Error saving config: {e}")

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

        providers_info.append({
            "name": name,
            "has_key": has_key,
            "details": config_details,
            "user_settings": {
                "api_url": user_conf.get('api_url', ''),
                "limit": user_conf.get('limit', '10'),
                "language": user_conf.get('language', 'en-US')
            }
        })
    return jsonify(providers_info)

@app.route('/api/config', methods=['POST'])
def update_config():
    data = request.json
    provider_name = data.get('provider')

    if not provider_name:
        return jsonify({"error": "Provider name is required"}), 400

    if 'api_key' not in data:
        return jsonify({"error": "API Key field is missing"}), 400

    api_key = data.get('api_key')

    api_url = data.get('api_url', '').strip()
    limit = data.get('limit', '10')
    language = data.get('language', 'en-US')

    all_config = get_stored_config()

    if provider_name in all_config and isinstance(all_config[provider_name], str):
        all_config[provider_name] = {'api_key': all_config[provider_name]}

    if not api_key:
        if provider_name in all_config:
            all_config[provider_name]['api_key'] = ""
    else:
        if provider_name not in all_config:
            all_config[provider_name] = {}

        all_config[provider_name]['api_key'] = api_key
        all_config[provider_name]['api_url'] = api_url
        all_config[provider_name]['limit'] = limit
        all_config[provider_name]['language'] = language

    save_stored_config(all_config)
    return jsonify({"status": "success"})

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
        return jsonify({"error": f"API Key for {provider_name} is missing. Please configure it."}), 401

    provider = provider_map.get(provider_name)
    if not provider:
        return jsonify({"error": "Provider not found"}), 404

    search_kwargs = {
        'api_url': provider_config.get('api_url'),
        'limit': provider_config.get('limit'),
        'language': provider_config.get('language')
    }

    result = provider.search(query, api_key, **search_kwargs)
    return jsonify(result)

# Host React Frontend
@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def serve(path):
    if path != "" and (STATIC_FOLDER / path).exists():
        return send_from_directory(str(STATIC_FOLDER), path)
    else:
        return send_from_directory(str(STATIC_FOLDER), 'index.html')

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Search API WebUI")
    parser.add_argument("--port", type=int, default=8889, help="Port to run the server on")
    parser.add_argument("--host", type=str, default="127.0.0.1", help="Host to run the server on")
    args = parser.parse_args()

    url = f"http://{args.host}:{args.port}"
    print(f"Starting Search API WebUI...")
    print(f"  - Config Storage: {USER_CONFIG_JSON}")
    print(f"  - Serving on: {url}")

    # Open browser automatically after a short delay to ensure server is ready
    webbrowser.open(url)

    app.run(host=args.host, port=args.port)

if __name__ == "__main__":
    main()
