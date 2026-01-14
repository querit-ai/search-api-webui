import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import SearchPage from './SearchPage';
import ConfigPage from './ConfigPage';
import './App.css';

function App() {
  return (
      <Router>
          <div className="app-wrapper">
              <Routes>
                  <Route path="/" element={<SearchPage />} />
                  <Route path="/config" element={<ConfigPage />} />
              </Routes>
          </div>
      </Router>
  );
}

export default App;
