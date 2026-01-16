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

class BaseProvider(ABC):
    """
    Abstract base class for all search providers.
    Enforces a standard interface for executing search queries.
    """

    @abstractmethod
    def search(self, query, api_key, **kwargs):
        """
        Execute a search request against the provider.

        Args:
            query (str): The search keywords.
            api_key (str): The API Key required for authentication.
            **kwargs: Arbitrary keyword arguments (e.g., 'limit', 'language', 'api_url').

        Returns:
            dict: A standardized dictionary containing:
                - 'results': List of dicts with 'title', 'url', 'snippet'.
                - 'metrics': Dict with 'latency_ms' and 'size_bytes'.
                - 'error': (Optional) Error message string if occurred.
        """
        pass
