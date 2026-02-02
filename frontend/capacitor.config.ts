import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'ai.querit.searchapi',
  appName: 'Search API WebUI',
  webDir: 'dist',
  server: {
    // Point to localhost Flask server running on Android
    androidScheme: 'http',
    cleartext: true,
    allowNavigation: ['localhost', '127.0.0.1']
  },
  android: {
    allowMixedContent: true,
    captureInput: true,
    webContentsDebuggingEnabled: true
  }
};

export default config;
