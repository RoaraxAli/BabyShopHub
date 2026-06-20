import 'dart:html' as html;

void closeWebWindow() {
  try {
    html.window.close();
  } catch (e) {
    // Fail-safe in case browser blocks window.close()
  }
}

String getBrowserUrl() {
  return html.window.location.href;
}
