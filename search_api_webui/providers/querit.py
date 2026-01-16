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
import json
from querit import QueritClient
from querit.models.request import SearchRequest
from querit.errors import QueritError
from .base import BaseProvider

class QueritSdkProvider(BaseProvider):
    """
    Specialized provider implementation using the official Querit Python SDK.
    """

    def __init__(self, config):
        self.config = config

    def search(self, query, api_key, **kwargs):
        """
        Executes a search using the Querit SDK.
        Handles the 'Bearer' prefix logic internally within the SDK.
        """
        try:
            # Initialize client with the raw API key
            client = QueritClient(
                api_key=api_key.strip(),
                timeout=30
            )

            limit = int(kwargs.get('limit', 10))

            request_model = SearchRequest(
                query=query,
                count=limit,
            )

            print(f'[Querit SDK] Searching: {query} (Limit: {limit})')

            start_time = time.time()
            
            # Execute search via SDK
            response = client.search(request_model)
            
            end_time = time.time()

            # Normalize results to standard format
            normalized_results = []
            if response.results:
                for item in response.results:
                    # Use getattr to safely access SDK object attributes
                    normalized_results.append({
                        "title": getattr(item, 'title', ''),
                        "url": getattr(item, 'url', ''),
                        # Fallback to description if snippet is missing
                        "snippet": getattr(item, 'snippet', '') or getattr(item, 'description', '')
                    })

            # Calculate estimated size for metrics (approximate JSON size)
            estimated_size = len(json.dumps([r for r in normalized_results]))

            return {
                "results": normalized_results,
                "metrics": {
                    "latency_ms": round((end_time - start_time) * 1000, 2),
                    "size_bytes": estimated_size
                }
            }

        except QueritError as e:
            print(f"Querit SDK Error: {e}")
            return {
                "error": f"Querit SDK Error: {str(e)}",
                "results": [],
                "metrics": {"latency_ms": 0, "size_bytes": 0}
            }
        except Exception as e:
            print(f"Unexpected Error: {e}")
            return {
                "error": f"Error: {str(e)}",
                "results": [],
                "metrics": {"latency_ms": 0, "size_bytes": 0}
            }
