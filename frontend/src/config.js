// API configuration for different environments

// Function to get API base URL
function getApiBaseUrl() {
  // In Android/Capacitor environment, we need to explicitly point to localhost Flask server
  // Check if we're in Capacitor
  const isCapacitor = typeof window !== 'undefined' && window.Capacitor;

  if (isCapacitor) {
    // Get platform from Capacitor
    try {
      const platform = window.Capacitor.getPlatform ? window.Capacitor.getPlatform() : null;
      if (platform === 'android') {
        console.log('[Config] Running on Android, using localhost Flask server');
        return 'http://127.0.0.1:8889';
      }
    } catch (e) {
      console.warn('[Config] Error detecting platform:', e);
    }
  }

  // Check user agent as fallback
  if (typeof navigator !== 'undefined' && navigator.userAgent) {
    const ua = navigator.userAgent.toLowerCase();
    if (ua.includes('android') && (ua.includes('wv') || isCapacitor)) {
      console.log('[Config] Detected Android WebView, using localhost Flask server');
      return 'http://127.0.0.1:8889';
    }
  }

  // Default: use relative URLs (web browser)
  console.log('[Config] Running in browser, using relative URLs');
  return '';
}

const API_BASE_URL = getApiBaseUrl();

export default API_BASE_URL;
