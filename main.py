# Copyright (c) 2026 QUERIT PRIVATE LIMITED
#
# Android entry point for Search API WebUI using Kivy + Buildozer
# This file enables packaging the Flask app into an Android APK

import os
from threading import Thread

if 'ANDROID_ARGUMENT' in os.environ:
    app_files_dir = os.environ.get('ANDROID_PRIVATE')
    if app_files_dir:
        print(f'Setting HOME to Android private files dir: {app_files_dir}')
        os.environ['HOME'] = app_files_dir
        os.environ['XDG_CONFIG_HOME'] = app_files_dir

from kivy.app import App
from kivy.clock import Clock
from kivy.core.window import Window
from android.runnable import run_on_ui_thread
from android.permissions import request_permissions, Permission
from jnius import autoclass

# Import the Flask app
from search_api_webui.app import app as flask_app


# Request Android permissions at startup
def request_android_permissions():
    '''
    Request necessary Android permissions for network access.
    '''
    try:
        request_permissions([Permission.INTERNET])
    except Exception as e:
        print(f'Permission request error: {e}')


# Android WebView classes
WebView = autoclass('android.webkit.WebView')
WebViewClient = autoclass('android.webkit.WebViewClient')
WebSettings = autoclass('android.webkit.WebSettings')
Activity = autoclass('org.kivy.android.PythonActivity')
Intent = autoclass('android.content.Intent')
Uri = autoclass('android.net.Uri')


class SearchWebViewApp(App):
    '''
    Main Kivy application that runs Flask in background
    and displays it in an Android WebView.
    '''

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.webview = None
        self.flask_port = 5000
        self.flask_ready = False
        self.last_url = None

    def build(self):
        '''
        Build the application UI.
        Called by Kivy framework when app starts.
        '''
        # Set window background color
        Window.clearcolor = (1, 1, 1, 1)

        # Start Flask server in background thread
        Thread(target=self.start_flask_server, daemon=True).start()

        # Schedule WebView creation after Flask starts
        Clock.schedule_once(self.create_webview, 2)

        # Return a placeholder widget
        from kivy.uix.label import Label
        return Label(text='Loading...')

    def start_flask_server(self):
        '''
        Start Flask development server in background.
        Runs in a separate daemon thread.
        '''
        try:
            flask_app.run(
                host='0.0.0.0',
                port=self.flask_port,
                debug=False,
                use_reloader=False,
                threaded=True,
            )
        except Exception as e:
            print(f'Flask server error: {e}')

    def create_webview(self, dt):
        '''
        Create and configure Android WebView.
        Must run on UI thread.
        '''
        self.setup_webview()

    @run_on_ui_thread
    def setup_webview(self):
        '''
        Initialize WebView on Android UI thread.
        Configures WebView settings and loads the Flask app.
        '''
        try:
            # Create WebView instance
            context = Activity.mActivity
            self.webview = WebView(context)

            # Configure WebView settings
            settings = self.webview.getSettings()
            settings.setJavaScriptEnabled(True)
            settings.setDomStorageEnabled(True)
            settings.setDatabaseEnabled(True)
            settings.setAllowFileAccess(True)
            settings.setAllowContentAccess(True)

            # Set cache mode to default
            settings.setCacheMode(WebSettings.LOAD_DEFAULT)

            # Enable zoom controls (optional)
            settings.setBuiltInZoomControls(False)

            # Set WebViewClient to handle navigation
            self.webview.setWebViewClient(WebViewClient())

            # Load the Flask app
            url = f'http://localhost:{self.flask_port}'
            self.webview.loadUrl(url)

            # Start URL monitoring
            Clock.schedule_interval(self.check_url, 0.5)

            # Replace root widget with WebView
            Activity.mActivity.setContentView(self.webview)

            print(f'WebView loaded: {url}')

        except Exception as e:
            print(f'WebView setup error: {e}')

    @run_on_ui_thread
    def check_url(self, dt):
        '''
        Periodically check WebView URL and open external browser if needed.
        '''
        if self.webview:
            try:
                current_url = self.webview.getUrl()
                if current_url and current_url != self.last_url:
                    print(f'[URL Monitor] URL changed to: {current_url}')
                    self.last_url = current_url

                    # Check if URL contains google.com
                    if 'google.com' in current_url and 'localhost' not in current_url:
                        print(f'[URL Monitor] Google URL detected, opening in browser')
                        try:
                            context = Activity.mActivity
                            intent = Intent()
                            intent.setAction(Intent.ACTION_VIEW)
                            intent.setData(Uri.parse(current_url))
                            context.startActivity(intent)
                            print('[URL Monitor] Browser intent sent')

                            # Navigate back to localhost
                            self.webview.loadUrl(f'http://localhost:{self.flask_port}')
                        except Exception as e:
                            print(f'[URL Monitor] Error opening browser: {e}')
            except Exception as e:
                pass  # Silently ignore errors during URL check

    def on_pause(self):
        '''
        Called when app goes to background.
        Return True to allow app to pause.
        '''
        return True

    def on_resume(self):
        '''
        Called when app returns from background.
        '''
        pass


def main():
    '''
    Application entry point.
    '''
    # Request permissions before starting app
    request_android_permissions()

    # Start the Kivy app
    SearchWebViewApp().run()


if __name__ == '__main__':
    main()
