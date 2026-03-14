class RouteTracker {
  RouteTracker._();

  static final RouteTracker instance = RouteTracker._();

  String? currentScreen;

  void update(String? screen) {
    if (screen == null || screen.trim().isEmpty) {
      return;
    }
    currentScreen = screen.trim();
  }
}
