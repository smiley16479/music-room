import 'package:flutter/widgets.dart';

/// Global route observer used across the app for route-aware widgets.
/// Import this file and use `routeObserver` to subscribe/unsubscribe.
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

/// A small helper mixin to make subscribing/unsubscribing a bit easier.
mixin RouteObserverAware<T extends StatefulWidget> on State<T>, RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      routeObserver.subscribe(this, ModalRoute.of(context)!);
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      routeObserver.unsubscribe(this);
    } catch (_) {}
    super.dispose();
  }
}
