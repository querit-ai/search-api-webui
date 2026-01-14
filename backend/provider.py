from abc import ABC, abstractmethod
import jmespath
import os
import requests
import time
import yaml

class BaseProvider(ABC):
    """
    Abstract base class for search providers.
    """
    @abstractmethod
    def search(self, query, api_key, **kwargs):
        """
        Execute search request.

        Args:
            query (str): Search keywords.
            api_key (str): API Key for authentication.
            **kwargs: Additional parameters like 'limit', 'language', 'custom_url'.

        Returns:
            dict: Standardized result dict.
        """
        pass


class GenericProvider(BaseProvider):
    """
    Generic provider implementation driven by configuration.
    """
    def __init__(self, config):
        self.config = config

    def _fill_template(self, template_obj, **kwargs):
        """Recursively replace {key} in dict/str with values from kwargs."""
        if isinstance(template_obj, str):
            # Use safe formatting that treats None as empty string
            safe_kwargs = {k: (v if v is not None else '') for k, v in kwargs.items()}
            # We use a wrapper or careful logic to avoid KeyError if template has keys not in kwargs
            # For simplicity here, we assume providers.yaml keys match what we send.
            # If a key is missing in kwargs but present in template, .format() will raise KeyError.
            # To make it robust, we could use a defaultdict or similar, but let's stick to standard behavior
            # and ensure caller provides defaults.
            try:
                return template_obj.format(**safe_kwargs)
            except KeyError:
                # Fallback: return original if key missing (or handle gracefully)
                return template_obj
        elif isinstance(template_obj, dict):
            return {k: self._fill_template(v, **kwargs) for k, v in template_obj.items()}
        return template_obj

    def search(self, query, api_key, **kwargs):
        # Extract standard optional params with defaults
        limit = kwargs.get('limit', '10')
        language = kwargs.get('language', 'en-US')
        custom_url = kwargs.get('api_url', '').strip()

        # Determine URL: Custom overrides Config
        url = custom_url if custom_url else self.config.get('url')
        method = self.config.get('method', 'GET')

        # Prepare context for template replacement
        # This allows providers.yaml to use {limit}, {language}, etc.
        context = {
            'query': query,
            'api_key': api_key,
            'limit': limit,
            'language': language
        }

        headers = self._fill_template(self.config.get('headers', {}), **context)
        params = self._fill_template(self.config.get('params', {}), **context)
        json_body = self._fill_template(self.config.get('payload', {}), **context)

        print(f'[{self.config.get("name", "Unknown")}] Search:')
        print('  URL:', url)
        print('  Method:', method)
        safe_headers = headers.copy()
        if 'Authorization' in safe_headers:
            safe_headers['Authorization'] = 'Bearer ***'
        if 'X-API-Key' in safe_headers:
            safe_headers['X-API-Key'] = '***'
        print('  Headers:', safe_headers)
        print('  Params:', params)
        
        start_time = time.time()

        try:
            req_args = {
                'headers': headers,
                'timeout': 30
            }
            
            if params:
                req_args['params'] = params
            if json_body:
                req_args['json'] = json_body

            if method.upper() == 'GET':
                response = requests.get(url, **req_args)
            else:
                response = requests.post(url, **req_args)

            response.raise_for_status()
        except Exception as e:
            print(f"Request Error: {e}")
            return {
                "error": str(e),
                "results": [],
                "metrics": {"latency_ms": 0, "size_bytes": 0}
            }

        end_time = time.time()

        try:
            raw_data = response.json()
        except Exception as e:
            print(f"JSON Parse Error: {e}")
            print(f"Response Text: {response.text[:200]}...")
            raw_data = {}

        # Response Mapping
        mapping = self.config.get('response_mapping', {})
        root_list = jmespath.search(mapping.get('root_path', '@'), raw_data) or []

        normalized_results = []
        field_map = mapping.get('fields', {})

        for item in root_list:
            entry = {}
            for std_key, source_path in field_map.items():
                val = jmespath.search(source_path, item)
                entry[std_key] = val if val else ""
            normalized_results.append(entry)

        return {
            "results": normalized_results,
            "metrics": {
                "latency_ms": round((end_time - start_time) * 1000, 2),
                "size_bytes": len(response.content)
            }
        }


def load_providers(file_path='providers.yaml'):
    """
    Load providers from YAML file.
    """
    if not os.path.exists(file_path):
        return {}
    with open(file_path, 'r', encoding='utf-8') as f:
        configs = yaml.safe_load(f)

    providers = {}
    for name, conf in configs.items():
        # Inject name into config for logging purposes
        conf['name'] = name
        providers[name] = GenericProvider(conf)
    return providers
