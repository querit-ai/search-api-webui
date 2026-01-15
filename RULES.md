# Project Coding Rules

## Python (Backend)

### Indentation
- Use **4 spaces** for indentation (no tabs)
- Configure editor: `indent_size = 4`

### Line Spacing
- Two blank lines between top-level class/function definitions
- One blank line between method definitions within a class
- One blank line between logical code blocks
- Maximum line length: 100 characters

### Comments
- **All comments must be in English**
- Use docstrings for all public classes, methods, and functions
- Inline comments for complex logic (explain "why", not "what")
- Example:
  ```python
  def process_data(self, data):
      """
      Process input data and return normalized result.
      
      Args:
          data: Raw input data dictionary
          
      Returns:
          Normalized data dict with default values applied
      """
      # Skip validation for cached data to improve performance
      if data.get('cached'):
          return data
      ...
  ```

### Naming Conventions
- **Classes**: `PascalCase` (e.g., `GenericProvider`)
- **Functions/Variables**: `snake_case` (e.g., `search_results`, `ensure_connection`)
- **Private Members**: Leading underscore (e.g., `_connection_ready`)
- **Constants**: `UPPER_SNAKE_CASE` (e.g., `DEFAULT_TIMEOUT`)

### Imports
- Standard library imports first, then third-party, then local
- Group imports with blank lines between groups
- Use absolute imports

### Error Handling
- Use specific exception types when possible
- Log errors with descriptive messages
- Return consistent error response format

---

## JavaScript/JSX (Frontend)

### Indentation
- Use **2 spaces** for indentation

### Comments
- **All comments must be in English**
- Use JSDoc for component props documentation

### Naming
- **Components**: `PascalCase` (e.g., `SearchBox`)
- **Variables/Functions**: `camelCase` (e.g., `handleSearch`, `searchResults`)
- **Constants**: `UPPER_SNAKE_CASE` or `camelCase` based on context

---

## YAML Configuration

### Indentation
- Use **2 spaces** for indentation

### Structure
- Clear hierarchical structure
- Use lowercase for all keys
- Descriptive key names

---

## General Rules

### Code Style
- Remove trailing whitespace
- Add newline at end of file
- Keep files focused (single responsibility)

### Version Control
- Meaningful commit messages
- Review before commit

### Testing
- Add tests for new functionality
- Run existing tests before pushing

---

## Tooling

### Pre-commit Hooks (Recommended)
```bash
# Install pre-commit
pip install pre-commit
pre-commit install
```

### Python Linting
```bash
pip install flake8
flake8 backend/ --max-line-length=100
```

### JavaScript Formatting
```bash
# In frontend/ directory
npm run format
```