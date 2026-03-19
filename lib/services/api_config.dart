class ApiConfig {
  /// Toggle for backend environment: false = local, true = Render (online).
  static const bool useRenderBackend =
      true; // change this to true to use Render backend

  /// Local AFPApi - used when developing locally. Run API with: uvicorn main:app --reload (from AFPApi folder).
  static const String _localBaseUrl = 'http://localhost:8000/api';

  /// Render (production) - used when you want to hit the deployed API.
  static const String _renderBaseUrl = 'https://afpapi.onrender.com/api';

  /// Base URL that the rest of the app should use. It picks between local and Render based on [useRenderBackend].
  static String get baseUrl =>
      useRenderBackend ? _renderBaseUrl : _localBaseUrl;
}