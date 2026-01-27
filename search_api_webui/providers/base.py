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

from abc import ABC, abstractmethod
from urllib.parse import urlparse


def extract_domain_from_url(url):
    '''
    Extract domain name from URL, removing 'www.' prefix.

    Args:
        url (str): The URL to extract domain from.

    Returns:
        str | None: The domain name without 'www.' prefix
                   (e.g., 'example.com' from 'https://www.example.com/path'),
                   or None if the URL is invalid or has no netloc.

    Examples:
        >>> extract_domain_from_url('https://www.example.com/path')
        'example.com'
        >>> extract_domain_from_url('http://example.com')
        'example.com'
        >>> extract_domain_from_url('invalid-url')
        None
    '''
    if not url or not isinstance(url, str):
        return None
    try:
        parsed = urlparse(url)
        domain = parsed.netloc if parsed.netloc else None
        if domain and domain.startswith('www.'):
            domain = domain[4:]
        return domain
    except Exception:
        return None


def parse_server_latency(latency_value):
    '''
    Parse server latency value from various formats to milliseconds.

    Args:
        latency_value: The latency value to parse. Can be:
            - int/float: A numeric value
            - str: A string with or without unit suffix (e.g., "123ms", "0.123s", "123")

    Returns:
        float | None: The latency in milliseconds, or None if parsing fails.

    Rules:
        1. If numeric (int/float):
           - If it's an integer, assume milliseconds
           - If it's a decimal (fractional), assume seconds and convert to ms
        2. If string:
           - If ends with 'ms' (case insensitive), parse as milliseconds
           - If ends with 's' (case insensitive), parse as seconds and convert to ms
           - If no suffix, convert to number and apply rule 1
    '''
    if latency_value is None:
        return None

    try:
        # Handle string input
        if isinstance(latency_value, str):
            value_str = latency_value.strip().lower()

            # Check for explicit unit suffix
            if value_str.endswith('ms'):
                return round(float(value_str[:-2]), 2)
            elif value_str.endswith('s'):
                return round(float(value_str[:-1]) * 1000, 2)
            else:
                # No suffix, convert to number and apply numeric logic
                num_value = float(value_str)
                if num_value.is_integer():
                    # Integer implies milliseconds
                    return round(num_value, 2)
                else:
                    # Decimal implies seconds, convert to ms
                    return round(num_value * 1000, 2)

        # Handle numeric input
        elif isinstance(latency_value, (int, float)):
            if float(latency_value).is_integer():
                # Integer implies milliseconds
                return round(float(latency_value), 2)
            else:
                # Decimal implies seconds, convert to ms
                return round(float(latency_value) * 1000, 2)

        return None
    except (ValueError, AttributeError):
        return None


class BaseProvider(ABC):
    '''
    Abstract base class for all search providers.
    Enforces a standard interface for executing search queries.
    '''

    @abstractmethod
    def search(self, query, api_key, **kwargs):
        '''
        Execute a search request against the provider.

        Args:
            query (str): The search keywords.
            api_key (str): The API Key required for authentication.
            **kwargs: Arbitrary keyword arguments (e.g., 'limit', 'language', 'api_url').

        Returns:
            dict: A standardized dictionary containing:
                - 'results': List of dicts with 'title', 'url', 'snippet'.
                - 'metrics': Dict with 'latency_ms' (client latency), 'server_latency_ms' (server reported latency),
                  and 'size_bytes'.
                - 'error': (Optional) Error message string if occurred.
        '''
        pass
