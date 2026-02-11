# Copyright (c) 2026 QUERIT PRIVATE LIMITED
#
# Android entry point for Search API WebUI using Kivy + Buildozer
# This file enables packaging the Flask app into an Android APK

import os
from threading import Thread, Timer

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
        self.last_title = None
        self.monitor_running = False

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

            # Start URL and title monitoring with Timer
            self.monitor_running = True
            self.start_monitor_timer()
            print('[WebView] Started page monitoring with Timer')

            # Replace root widget with WebView
            Activity.mActivity.setContentView(self.webview)

            print(f'WebView loaded: {url}')

        except Exception as e:
            print(f'WebView setup error: {e}')

    def start_monitor_timer(self):
        '''
        Start monitoring timer.
        '''
        if self.monitor_running:
            Timer(0.5, self.monitor_page).start()

    def monitor_page(self):
        '''
        Monitor page and reschedule.
        '''
        if not self.monitor_running:
            return

        # Do the actual check
        self.do_check_page()

        # Reschedule
        self.start_monitor_timer()

    def check_page(self, dt):
        '''
        Periodically check WebView title and URL for browser open signal.
        '''
        # Schedule the actual check on UI thread
        self.do_check_page()

    @run_on_ui_thread
    def do_check_page(self):
        '''
        Actual page checking logic, runs on UI thread.
        '''
        if not self.webview:
            return

        try:
            # Check title for special marker
            title = self.webview.getTitle()
            if title and title != self.last_title:
                print(f'[Page Monitor] Title changed to: {title}')
                self.last_title = title

                if title and title.startswith('OPEN_BROWSER:'):
                    url = title.replace('OPEN_BROWSER:', '')
                    print(f'[Page Monitor] Browser signal detected, opening: {url}')
                    self.open_in_browser(url)
                    return

            # Also check URL
            current_url = self.webview.getUrl()
            if current_url and current_url != self.last_url:
                print(f'[Page Monitor] URL changed to: {current_url}')
                self.last_url = current_url

                # Check if URL contains google.com
                if 'google.com' in current_url and 'localhost' not in current_url:
                    print(f'[Page Monitor] Google URL detected, opening in browser')
                    self.open_in_browser(current_url)

        except Exception as e:
            print(f'[Page Monitor] Error: {e}')
            import traceback
            traceback.print_exc()

    @run_on_ui_thread
    def open_in_browser(self, url):
        '''
        Open URL in external browser on UI thread.
        '''
        try:
            print(f'[Browser] Opening URL: {url}')
            context = Activity.mActivity
            intent = Intent()
            intent.setAction(Intent.ACTION_VIEW)
            intent.setData(Uri.parse(url))
            context.startActivity(intent)
            print('[Browser] Intent sent successfully')

            # Navigate WebView back to localhost after a short delay
            Clock.schedule_once(lambda dt: self.reset_webview(), 0.5)
        except Exception as e:
            print(f'[Browser] Error: {e}')
            import traceback
            traceback.print_exc()

    @run_on_ui_thread
    def reset_webview(self):
        '''
        Reset WebView to localhost.
        '''
        if self.webview:
            self.webview.loadUrl(f'http://localhost:{self.flask_port}')
            self.last_title = None
            print('[Browser] WebView reset to localhost')

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
