package ai.querit.searchapi;

import android.content.pm.ApplicationInfo;
import android.os.Bundle;
import android.os.Build;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.util.Log;
import android.webkit.WebView;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsControllerCompat;
import com.getcapacitor.BridgeActivity;
import com.chaquo.python.Python;
import com.chaquo.python.android.AndroidPlatform;
import com.chaquo.python.PyObject;
import java.net.HttpURLConnection;
import java.net.URL;

public class MainActivity extends BridgeActivity {
    private static final String TAG = "MainActivity";
    private Thread flaskThread;
    private static final int FLASK_PORT = 8889;
    private static final String FLASK_HOST = "127.0.0.1";
    private static final int MAX_STARTUP_WAIT = 30; // seconds

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Enable edge-to-edge display
        setupEdgeToEdge();

        // Enable WebView debugging in debug builds
        if (0 != (getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE)) {
            WebView.setWebContentsDebuggingEnabled(true);
        }

        // Initialize Python runtime if not already started
        if (!Python.isStarted()) {
            Log.i(TAG, "Starting Python runtime...");
            Python.start(new AndroidPlatform(this));
        }

        // Start Flask server in background thread
        startFlaskServer();

        // Wait for server to be ready, then load WebView
        waitForServerAndLoad();
    }

    /**
     * Setup edge-to-edge display (status bar overlay)
     */
    private void setupEdgeToEdge() {
        Window window = getWindow();

        // Enable drawing behind system bars
        WindowCompat.setDecorFitsSystemWindows(window, false);

        // Set status bar to transparent
        window.setStatusBarColor(android.graphics.Color.TRANSPARENT);
        window.setNavigationBarColor(android.graphics.Color.TRANSPARENT);

        // Set status bar icons to dark (for light background)
        WindowInsetsControllerCompat controller = WindowCompat.getInsetsController(window, window.getDecorView());
        if (controller != null) {
            controller.setAppearanceLightStatusBars(true); // Dark icons on light background
            controller.setAppearanceLightNavigationBars(true);
        }
    }

    /**
     * Start Flask server in a background thread
     */
    private void startFlaskServer() {
        flaskThread = new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    Log.i(TAG, "Starting Flask server on " + FLASK_HOST + ":" + FLASK_PORT);
                    Python py = Python.getInstance();

                    // Import the Flask app module
                    PyObject appModule = py.getModule("search_api_webui.app");

                    // Call the main function with arguments
                    // Equivalent to: python -m search_api_webui.app --host 127.0.0.1 --port 8889
                    PyObject sys = py.getModule("sys");
                    PyObject argv = sys.get("argv");

                    // Set command line arguments
                    argv.callAttr("clear");
                    argv.callAttr("append", "app.py");
                    argv.callAttr("append", "--host");
                    argv.callAttr("append", FLASK_HOST);
                    argv.callAttr("append", "--port");
                    argv.callAttr("append", String.valueOf(FLASK_PORT));

                    // Run the Flask app
                    appModule.callAttr("main");

                } catch (Exception e) {
                    Log.e(TAG, "Error starting Flask server", e);
                    runOnUiThread(() -> {
                        showErrorPage("Failed to start server: " + e.getMessage());
                    });
                }
            }
        });

        flaskThread.setDaemon(true);
        flaskThread.start();
    }

    /**
     * Wait for Flask server to be ready, then load the WebView
     */
    private void waitForServerAndLoad() {
        new Thread(() -> {
            String serverUrl = "http://" + FLASK_HOST + ":" + FLASK_PORT;
            String healthUrl = serverUrl + "/api/providers";

            Log.i(TAG, "Waiting for server to start...");

            for (int i = 0; i < MAX_STARTUP_WAIT * 2; i++) {
                try {
                    URL url = new URL(healthUrl);
                    HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                    conn.setConnectTimeout(1000);
                    conn.setReadTimeout(1000);
                    conn.setRequestMethod("GET");

                    int responseCode = conn.getResponseCode();
                    conn.disconnect();

                    if (responseCode >= 200 && responseCode < 300) {
                        Log.i(TAG, "Server is ready! Loading WebView from Capacitor assets...");

                        runOnUiThread(() -> {
                            // Load Capacitor app from assets
                            // Capacitor will load from assets/public/index.html
                            // and the frontend will call Flask API at localhost:8889
                            bridge.getWebView().loadUrl("https://localhost/index.html");
                        });
                        return;
                    }
                } catch (Exception e) {
                    // Server not ready yet, continue waiting
                    Log.d(TAG, "Server not ready yet (attempt " + (i + 1) + "/" + (MAX_STARTUP_WAIT * 2) + ")");
                }

                try {
                    Thread.sleep(500);
                } catch (InterruptedException e) {
                    Log.w(TAG, "Wait interrupted", e);
                    break;
                }
            }

            // Timeout - server didn't start in time
            Log.e(TAG, "Server startup timeout after " + MAX_STARTUP_WAIT + " seconds");
            runOnUiThread(() -> {
                showErrorPage("Server failed to start within " + MAX_STARTUP_WAIT + " seconds");
            });
        }).start();
    }

    /**
     * Show an error page in the WebView
     */
    private void showErrorPage(String errorMessage) {
        String html = "<html><body style='font-family: sans-serif; padding: 20px; text-align: center;'>" +
                "<h1>Error</h1>" +
                "<p>" + errorMessage + "</p>" +
                "<p>Please restart the app.</p>" +
                "</body></html>";

        bridge.getWebView().loadData(html, "text/html", "UTF-8");
    }

    @Override
    public void onDestroy() {
        super.onDestroy();

        // Note: Flask server will continue running until the process is killed
        // This is acceptable as Android will manage the process lifecycle
        Log.i(TAG, "Activity destroyed");
    }
}

