# Search API WebUI

A lightweight, local WebUI for testing and visualizing Search APIs (Querit, YDC, etc.). 

## Features

- 🔍 **Search**: Support for Querit, You.com, and generic Search APIs via configuration.
- ⚡ **Performance Metrics**: Real-time display of request latency and payload size.
- 🎨 **Visual Rendering**: Renders standard search results (Title, Snippet, URL) in a clean card layout.
- 🛠️ **Configurable**: Easy-to-edit `providers.yaml` to add or modify search providers.
- 🔒 **Secure**: API Keys are stored locally in `user_config.json` and never committed.

## Quick Start

### Prerequisites

- Python 3.7+
- Node.js & npm (for building the frontend)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/querit-ai/search-api-webui.git
   cd search-api-webui
2. **Build Frontend**
   ```cd frontend
   npm install
   npm run build
   cd ..
3. **Install Backend**
   ```pip install -e .

### Usage
**Run the server:**
   ```python -m backend.app
Or if you installed via pip:
   ```search-api-webui

Open your browser at http://localhost:8889.

## Configuration
### Add API Keys
1. Open the WebUI settings page.
2. Enter your API Key for the selected provider (e.g., Querit).
3. Keys are saved locally in user_config.json.

### Add New Providers
Edit providers.yaml to add custom API endpoints. The system uses JMESPath to map JSON responses to the UI.
   ```my_custom_search:
         url: "https://api.example.com/search"
         method: "GET"
         ...
## Development
Backend: Flask (in backend/)
Frontend: React + Vite (in frontend/)
## License
MIT License. See LICENSE for details.
