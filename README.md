# Search API WebUI

A lightweight, local WebUI for testing and visualizing Search APIs (Querit, YDC, etc.).

(images)

## Features

* **Search**: Support for Querit, You.com, and generic Search APIs via configuration.
* **Performance Metrics**: Real-time display of request latency and payload size.
* **Visual Rendering**: Renders standard search results (Title, Snippet, URL) in a clean card layout.
* **Configurable**: Easy-to-edit providers.yaml to add or modify search providers.
* **Secure**: API Keys are stored locally in your $HOME folder.
## Installation

Use this method if you just want to run the tool without modifying the code.

### Prerequisites

Python 3.7+
### Install via Pip

```
pip install search-api-webui
```

### Run the Server

```
search-api-webui
```

Open your browser at http://localhost:8889.

## Development

Use this method if you want to contribute to the code or build from source.

### Prerequisites

Python 3.7+
Node.js & npm (for building the frontend)
### Setup Steps

**Clone the repository**
```
git clone https://github.com/querit-ai/search-api-webui.git
cd search-api-webui
```

**Build Frontend**
```
cd frontend
npm install
npm run build
cd …
```

**Install Backend (Editable Mode)**
```
pip install -e .
```

**Run the Server**
```
python -m backend.app
```

## Configuration

### Add API Keys

Open the WebUI settings page (click the gear icon).
Enter your API Key for the selected provider (e.g., Querit).
Keys are saved locally in user_config.json.
### Add New Providers

Edit providers.yaml in the root directory to add custom API endpoints. The system uses JMESPath to map JSON responses to the UI.

```
my_custom_search:
url: “https://api.example.com/search”
method: “GET”
headers:
Authorization: “Bearer {api_key}”
params:
q: “{query}”
response_mapping:
root_path: “data.items”
fields:
title: “title”
url: “link”
snippet: “snippet”
```

## License

MIT License. See LICENSE for details.
