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
