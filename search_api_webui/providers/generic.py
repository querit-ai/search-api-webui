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

import html
import logging
import os
import time

import jmespath
import requests

from .base import BaseProvider, extract_domain_from_url, parse_server_latency

logger = logging.getLogger(__name__)


class GenericProvider(BaseProvider):
    '''
    A generic search provider driven by YAML configuration.
    It constructs HTTP requests dynamically and maps responses using JMESPath.
    '''

    def __init__(self, config):
        '''
        Initialize the provider with a configuration dictionary.

        Args:
            config (dict): Configuration containing url, headers, params, and mapping rules.
        '''
        self.config = config
        self.session = requests.Session()  # Persistent connection session
        self._connection_ready = False  # Connection ready status
        self._last_url = None  # Last used URL tracker

    def _fill_template(self, template_obj, **kwargs):
        '''
        Recursively replaces placeholders (e.g., {query}) in dictionaries or strings
        with values provided in kwargs.

        Args:
            template_obj (dict | str): The structure containing placeholders.
            **kwargs: Key-value pairs to inject into the template.

        Returns:
            The structure with placeholders replaced by actual values.
            Dict entries with empty values are removed.
            Pure numeric placeholders (e.g., "{limit}") are converted to int/float.
        '''
        if isinstance(template_obj, str):
            # Treat None values as empty strings to prevent "None" appearing in URLs
            safe_kwargs = {k: (v if v is not None else '') for k, v in kwargs.items()}
            try:
                result = template_obj.format(**safe_kwargs)
                # Convert to number if the result is a numeric string
                # and the original template was a pure placeholder like "{limit}"
                if template_obj.strip().startswith('{') and template_obj.strip().endswith('}'):
                    try:
                        # Try int first, then float
                        if '.' in result:
                            return float(result)
                        return int(result)
                    except (ValueError, AttributeError):
                        pass
                return result
            except KeyError:
                # Return original string if a placeholder key is missing in kwargs
                return template_obj
        elif isinstance(template_obj, list):
            # Handle list/array - recursively process each element
            return [self._fill_template(item, **kwargs) for item in template_obj]
        elif isinstance(template_obj, dict):
            result = {}
            for k, v in template_obj.items():
                filled = self._fill_template(v, **kwargs)
                # Skip entries with empty values (e.g., empty strings after template fill)
                if filled != '':
                    result[k] = filled
            return result
        return template_obj

    def _ensure_connection(self, url, headers):
        '''
        Pre-warm HTTPS connection and verify availability.
        Uses lightweight HEAD request to verify connection without fetching response body.

        Args:
            url (str): Target URL
            headers (dict): Request headers

        Returns:
            bool: Whether connection is ready
        '''
        # Re-warm if URL changed or connection not ready
        if url != self._last_url or not self._connection_ready:
            try:
                # Verify connection using HEAD request (no response body)
                self.session.head(url, headers=headers, timeout=5)
                self._connection_ready = True
                self._last_url = url
                logger.debug('[Connection Pool] Connected to: %s', url)
            except Exception as e:
                self._connection_ready = False
                logger.warning('[Connection Pool] Connection warm-up failed: %s', e)
                raise

    def search(self, query, api_key, **kwargs):
        '''
        Perform search using the configured API.

        Args:
            query: Search query string
            api_key: API key for authentication
            **kwargs: Additional parameters (limit, language, api_url, proxy_url, skip_warmup)

        Returns:
            dict: Search results with 'results' and 'metrics' keys
        '''
        # 1. Extract parameters with defaults
        limit = kwargs.get('limit', '10')
        language = kwargs.get('language')
        custom_url = kwargs.get('api_url')
        proxy_url = kwargs.get('proxy_url')
        skip_warmup = kwargs.get('skip_warmup', False)

        # 2. Configure proxy for this request if provided
        if proxy_url:
            self.session.proxies = {
                'http': proxy_url,
                'https': proxy_url,
            }
            logger.info('Using proxy: %s', proxy_url)

            # Disable SSL verification when using proxy
            self.session.verify = False
            # Suppress InsecureRequestWarning
            import urllib3
            urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        else:
            # Check environment variables if no user proxy configured
            env_proxy = os.environ.get('https_proxy') or os.environ.get('HTTPS_PROXY') or \
                        os.environ.get('http_proxy') or os.environ.get('HTTP_PROXY')
            if env_proxy:
                self.session.proxies = {
                    'http': env_proxy,
                    'https': env_proxy,
                }
                logger.info('Using proxy from environment: %s', env_proxy)
                self.session.verify = False
                import urllib3
                urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
            else:
                # No proxy, ensure normal SSL verification
                self.session.proxies = {}
                self.session.verify = True

        # 3. Determine configuration
        # Use custom api_url if provided, otherwise fallback to config url
        url = custom_url.strip() if custom_url else self.config.get('url')
        method = self.config.get('method', 'GET')

        # 4. Prepare context for template injection
        context = {
            'query': query,
            'api_key': api_key,
            'limit': limit,
        }
        # Only add language to context if provided
        if language:
            context['language'] = language

        # 5. construct request components
        headers = self._fill_template(self.config.get('headers', {}), **context)
        params = self._fill_template(self.config.get('params', {}), **context)
        json_body = self._fill_template(self.config.get('payload', {}), **context)

        logger.info('[%s] Search: URL=%s | Method=%s',
                  self.config.get('name', 'Unknown'), url, method)

        # Ensure connection is pre-warmed (use HEAD request to verify availability)
        # Pre-warming is not counted in request latency, only verifies connection
        # Skip connection warm-up if disabled in config or by user
        if not skip_warmup and not self.config.get('skip_connection_warmup', False):
            try:
                self._ensure_connection(url, headers)
            except Exception as e:
                logger.warning('Connection Warm-up Warning: %s (continuing anyway)', e)
                # Don't return error, continue with the actual request

        try:
            req_args = {'headers': headers, 'timeout': 30}
            if params:
                req_args['params'] = params
            if json_body:
                req_args['json'] = json_body

            # Use Session to send request (connection is reused)
            start_time = time.time()
            if method.upper() == 'GET':
                response = self.session.get(url, **req_args)
            else:
                response = self.session.post(url, **req_args)
            end_time = time.time()

            response.raise_for_status()
        except Exception as e:
            logger.error('Request Error: %s', e, f"args: {req_args}")
            return {
                'error': str(e),
                'results': [],
                'metrics': {'latency_ms': 0, 'server_latency_ms': None, 'size_bytes': 0},
            }

        # 5. Parse and Normalize Response
        try:
            raw_data = response.json()
        except Exception as e:
            logger.error('JSON Parse Error: %s', e)
            raw_data = {}

        logger.debug('Full response: %s', raw_data)

        mapping = self.config.get('response_mapping', {})
        # Use JMESPath to find the list of results
        root_list = jmespath.search(mapping.get('root_path', '@'), raw_data) or []

        normalized_results = []
        field_map = mapping.get('fields', {})
        # Define common fields that should be extracted as-is
        common_fields = {'title', 'url', 'site_name', 'site_icon', 'page_age'}

        # Collect all JMESPath source paths that are already mapped
        mapped_paths = set(field_map.values())

        for item in root_list:
            entry = {}
            snippet_fields = {}  # Collect unmapped fields from raw API response

            # Map specific fields (title, url, etc.) based on config
            for std_key, source_path in field_map.items():
                val = jmespath.search(source_path, item)
                # Decode HTML entities for site_name
                if std_key == 'site_name' and val:
                    val = html.unescape(val)

                # Only store common fields in entry
                if std_key in common_fields:
                    entry[std_key] = val if val else ''

            # Find all unmapped fields in the raw item
            # These are fields that exist in the API response but are not in field_map
            if isinstance(item, dict):
                for key, value in item.items():
                    # Check if this key is already mapped in config
                    # Include all unmapped fields, including nested objects and arrays
                    if key not in mapped_paths and value is not None:
                        snippet_fields[key] = value

            # Store snippet fields as JSON structure in snippet
            if snippet_fields:
                entry['snippet'] = snippet_fields
            else:
                entry['snippet'] = ''
            logger.debug('snippet_fields: %s', snippet_fields)
            normalized_results.append(entry)

        # Post-process: extract domain from URL if site_name is empty
        for entry in normalized_results:
            if not entry.get('site_name') and entry.get('url'):
                entry['site_name'] = extract_domain_from_url(entry['url']) or ''

        # Extract server latency from response if configured
        server_latency_path = mapping.get('server_latency_path')
        server_latency_ms = parse_server_latency(
            jmespath.search(server_latency_path, raw_data),
        ) if server_latency_path else None

        return {
            'results': normalized_results,
            'metrics': {
                'latency_ms': round((end_time - start_time) * 1000, 2),
                'server_latency_ms': server_latency_ms,
                'size_bytes': len(response.content),
            },
        }
