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

import time
import requests
import jmespath
from .base import BaseProvider

class GenericProvider(BaseProvider):
    """
    A generic search provider driven by YAML configuration.
    It constructs HTTP requests dynamically and maps responses using JMESPath.
    """

    def __init__(self, config):
        """
        Initialize the provider with a configuration dictionary.
        
        Args:
            config (dict): Configuration containing url, headers, params, and mapping rules.
        """
        self.config = config
        self.session = requests.Session()  # Persistent connection session
        self._connection_ready = False     # Connection ready status
        self._last_url = None              # Last used URL tracker

    def _fill_template(self, template_obj, **kwargs):
        """
        Recursively replaces placeholders (e.g., {query}) in dictionaries or strings 
        with values provided in kwargs.
        
        Args:
            template_obj (dict | str): The structure containing placeholders.
            **kwargs: Key-value pairs to inject into the template.
            
        Returns:
            The structure with placeholders replaced by actual values.
        """
        if isinstance(template_obj, str):
            # Treat None values as empty strings to prevent "None" appearing in URLs
            safe_kwargs = {k: (v if v is not None else '') for k, v in kwargs.items()}
            try:
                return template_obj.format(**safe_kwargs)
            except KeyError:
                # Return original string if a placeholder key is missing in kwargs
                return template_obj
        elif isinstance(template_obj, dict):
            return {k: self._fill_template(v, **kwargs) for k, v in template_obj.items()}
        return template_obj

    def _ensure_connection(self, url, headers):
        """
        Pre-warm HTTPS connection and verify availability.
        Uses lightweight HEAD request to verify connection without fetching response body.

        Args:
            url (str): Target URL
            headers (dict): Request headers

        Returns:
            bool: Whether connection is ready
        """
        # Re-warm if URL changed or connection not ready
        if url != self._last_url or not self._connection_ready:
            try:
                # Verify connection using HEAD request (no response body)
                self.session.head(url, headers=headers, timeout=5)
                self._connection_ready = True
                self._last_url = url
                print(f'  [Connection Pool] Connected to: {url}')
            except Exception as e:
                self._connection_ready = False
                print(f'  [Connection Pool] Connection warm-up failed: {e}')
                raise

    def search(self, query, api_key, **kwargs):
        # 1. Extract parameters with defaults
        limit = kwargs.get('limit', '10')
        language = kwargs.get('language', 'en-US')
        custom_url = kwargs.get('api_url', '').strip()

        # 2. Determine configuration
        url = custom_url if custom_url else self.config.get('url')
        method = self.config.get('method', 'GET')
        
        # 3. Prepare context for template injection
        context = {
            'query': query,
            'api_key': api_key,
            'limit': limit,
            'language': language
        }

        # 4. construct request components
        headers = self._fill_template(self.config.get('headers', {}), **context)
        params = self._fill_template(self.config.get('params', {}), **context)
        json_body = self._fill_template(self.config.get('payload', {}), **context)

        # Logging (Masking sensitive API keys)
        print(f'[{self.config.get("name", "Unknown")}] Search:')
        print(f'  URL: {url} | Method: {method}')
        
        # Ensure connection is pre-warmed (use HEAD request to verify availability)
        # Pre-warming is not counted in request latency, only verifies connection
        try:
            self._ensure_connection(url, headers)
        except Exception as e:
            print(f"Connection Warm-up Error: {e}")
            return {
                "error": f"Connection failed: {str(e)}",
                "results": [],
                "metrics": {"latency_ms": 0, "size_bytes": 0}
            }

        start_time = time.time()

        try:
            req_args = {'headers': headers, 'timeout': 30}
            if params:
                req_args['params'] = params
            if json_body:
                req_args['json'] = json_body

            # Use Session to send request (connection is reused)
            if method.upper() == 'GET':
                response = self.session.get(url, **req_args)
            else:
                response = self.session.post(url, **req_args)

            response.raise_for_status()
        except Exception as e:
            print(f"Request Error: {e}")
            return {
                "error": str(e),
                "results": [],
                "metrics": {"latency_ms": 0, "size_bytes": 0}
            }

        end_time = time.time()

        # 5. Parse and Normalize Response
        try:
            raw_data = response.json()
        except Exception as e:
            print(f"JSON Parse Error: {e}")
            raw_data = {}

        mapping = self.config.get('response_mapping', {})
        # Use JMESPath to find the list of results
        root_list = jmespath.search(mapping.get('root_path', '@'), raw_data) or []

        normalized_results = []
        field_map = mapping.get('fields', {})

        for item in root_list:
            entry = {}
            # Map specific fields (title, url, etc.) based on config
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
