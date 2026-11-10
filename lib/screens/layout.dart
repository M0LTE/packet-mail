import 'package:flutter/material.dart';

import '../theme.dart';

/// Windows at least this wide (iPads, Android tablets, unfolded foldables)
/// get the sidebar and two panes; narrower ones get the phone layout.
const twoPaneMinWidth = 820.0;

/// Whether the window is wide enough for the sidebar and two panes.
bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= twoPaneMinWidth;

/// Whether the screen holding [context] offers a way back. A screen shown
/// in the right-hand pane has none: choosing something else replaces it.
bool showsBackLink(BuildContext context) => ModalRoute.of(context)?.impliesAppBarDismissal ?? true;

/// What one section (Mail, Bulletins, Contacts, Settings) has open beside its
/// list. On a wide window it fills the right-hand pane; on a narrow one it is
/// pushed over the list as on a phone, and is remembered so it can move to
/// the pane if the window widens.
class PaneController extends ChangeNotifier {
  /// The right-hand pane's navigator, with a quiet placeholder at the bottom.
  final detailNavigator = GlobalKey<NavigatorState>();

  var _wide = false;
  Object? _selected;
  WidgetBuilder? _builder;

  /// On a narrow window, the route the list was on when the detail opened.
  Route<void>? _narrowBase;

  bool get wide => _wide;

  /// The key of what is open, for highlighting its row on a wide window.
  Object? get selected => _selected;

  void _set(Object? key, WidgetBuilder? builder) {
    if (_selected == key && _builder == builder) return;
    _selected = key;
    _builder = builder;
    notifyListeners();
  }

  /// Closes whatever is open.
  void clear() {
    if (_wide) detailNavigator.currentState?.popUntil((r) => r.isFirst);
    _narrowBase = null;
    _set(null, null);
  }

  void _openWide(Object key, WidgetBuilder builder) {
    _set(key, builder);
    detailNavigator.currentState?.pushAndRemoveUntil(_DetailRoute<void>(builder: builder), (r) => r.isFirst);
  }

  /// Called once the window has switched layout, with [list] the section's
  /// own navigator: moves the open detail between the pane and the list.
  void switchLayout({required bool wide, required NavigatorState? list}) {
    if (wide == _wide) return;
    _wide = wide;
    final builder = _builder;
    if (wide) {
      final base = _narrowBase;
      _narrowBase = null;
      if (builder == null || list == null || base == null || !base.isActive || base.isCurrent) {
        _set(null, null);
        notifyListeners();
        return;
      }
      list.popUntil((r) => r == base);
      detailNavigator.currentState?.push(_DetailRoute<void>(builder: builder));
    } else {
      if (builder == null || list == null) {
        _set(null, null);
        notifyListeners();
        return;
      }
      _narrowBase = _top(list);
      list.push(_InstantRoute<void>(builder: builder));
    }
    notifyListeners();
  }

  /// Clears the selection once the pane is back to its placeholder.
  void _checkEmpty() {
    if (!_wide) return;
    final nav = detailNavigator.currentState;
    if (nav != null && !nav.canPop()) _set(null, null);
  }
}

Route<dynamic>? _top(NavigatorState nav) {
  Route<dynamic>? top;
  nav.popUntil((r) {
    top = r;
    return true;
  });
  return top;
}

/// Makes a section's [PaneController] available to its screens.
class PaneScope extends InheritedNotifier<PaneController> {
  const PaneScope({super.key, required PaneController controller, required super.child}) : super(notifier: controller);

  static PaneController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PaneScope>()?.notifier;
}

/// Opens [builder] beside the list on a wide window, or over it on a narrow
/// one. [key] names what is open, so its row can be highlighted.
Future<void> openDetail(BuildContext context, {required Object key, required WidgetBuilder builder}) async {
  final pane = context.getInheritedWidgetOfExactType<PaneScope>()?.notifier;
  if (pane == null) {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
    return;
  }
  if (pane.wide) {
    pane._openWide(key, builder);
    return;
  }
  pane._narrowBase = ModalRoute.of(context);
  pane._set(key, builder);
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
}

/// Opens a compose screen or an editor: full screen on a narrow window (on
/// the root navigator if [rootNavigator]), and as a sheet over both panes
/// on a wide one.
Future<T?> openSheet<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool rootNavigator = false,
  bool fullscreenDialog = false,
}) {
  if (!isWide(context)) {
    return Navigator.of(
      context,
      rootNavigator: rootNavigator,
    ).push<T>(MaterialPageRoute<T>(fullscreenDialog: fullscreenDialog, builder: builder));
  }
  return Navigator.of(context, rootNavigator: true).push<T>(_SheetRoute<T>(builder));
}

/// A detail in the right-hand pane: it appears at once, and has no back
/// button, since the list beside it is how you move on.
class _DetailRoute<T> extends MaterialPageRoute<T> {
  _DetailRoute({required super.builder});

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  bool get impliesAppBarDismissal => false;
}

/// A detail moved over the list when the window narrows: no slide in, but
/// the usual slide out.
class _InstantRoute<T> extends MaterialPageRoute<T> {
  _InstantRoute({required super.builder});

  @override
  Duration get transitionDuration => Duration.zero;
}

/// The right-hand pane: [placeholder] until something is opened.
class DetailPane extends StatefulWidget {
  const DetailPane({super.key, required this.controller, required this.placeholder});

  final PaneController controller;
  final Widget placeholder;

  @override
  State<DetailPane> createState() => _DetailPaneState();
}

class _DetailPaneState extends State<DetailPane> {
  late final _observer = _PaneObserver(widget.controller);

  @override
  Widget build(BuildContext context) => Navigator(
    key: widget.controller.detailNavigator,
    observers: [_observer],
    onGenerateRoute: (_) =>
        PageRouteBuilder<void>(pageBuilder: (_, _, _) => widget.placeholder, transitionDuration: Duration.zero),
  );
}

class _PaneObserver extends NavigatorObserver {
  _PaneObserver(this.controller);
  final PaneController controller;

  void _later() => WidgetsBinding.instance.addPostFrameCallback((_) => controller._checkEmpty());

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _later();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _later();
}

/// The empty right-hand pane: one quiet line.
class PanePlaceholder extends StatelessWidget {
  const PanePlaceholder({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('pane-placeholder'),
    color: Logbook.paper,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: Logbook.rule),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Logbook.inkFaint)),
        ],
      ),
    ),
  );
}

/// A row whose detail is open in the right-hand pane gets a shaded background.
class PaneHighlight extends StatelessWidget {
  const PaneHighlight({super.key, required this.detail, required this.child});

  /// The key the row opens its detail with.
  final Object detail;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pane = PaneScope.maybeOf(context);
    if (pane == null || !pane.wide || pane.selected != detail) return child;
    return Material(key: const ValueKey('pane-selected'), color: Logbook.paperDeep, child: child);
  }
}

/// Compose and editors on a wide window: a card over both panes, with its
/// own navigator so previews and swaps stay inside it.
class _SheetRoute<T> extends PopupRoute<T> {
  _SheetRoute(this.builder);

  final WidgetBuilder builder;

  @override
  Color get barrierColor => const Color(0x59000000);

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      _Sheet<T>(route: this);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}

class _Sheet<T> extends StatefulWidget {
  const _Sheet({super.key, required this.route});
  final _SheetRoute<T> route;

  @override
  State<_Sheet<T>> createState() => _SheetState<T>();
}

class _SheetState<T> extends State<_Sheet<T>> {
  final _nav = GlobalKey<NavigatorState>();
  T? _result;
  var _closing = false;

  /// Back at the empty route under the screen: the screen has closed, so
  /// the sheet goes too, with the screen's result.
  void _closed() {
    if (_closing) return;
    _closing = true;
    final route = widget.route;
    final outer = route.navigator;
    if (outer == null || !route.isActive) return;
    if (route.isCurrent) {
      outer.pop(_result);
    } else {
      outer.removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      curve: Curves.decelerate,
      padding: media.viewInsets + media.padding + const EdgeInsets.all(24),
      child: MediaQuery.removeViewInsets(
        context: context,
        removeLeft: true,
        removeTop: true,
        removeRight: true,
        removeBottom: true,
        child: MediaQuery.removePadding(
          context: context,
          removeLeft: true,
          removeTop: true,
          removeRight: true,
          removeBottom: true,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 620, maxHeight: size.height < 900 ? double.infinity : 860),
              child: Material(
                key: const ValueKey('sheet'),
                color: Logbook.paper,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Logbook.rule),
                ),
                clipBehavior: Clip.antiAlias,
                child: NavigatorPopHandler<Object?>(
                  onPopWithResult: (_) => _nav.currentState?.maybePop(),
                  child: Navigator(
                    key: _nav,
                    observers: [_SheetObserver(_closed)],
                    onGenerateInitialRoutes: (_, _) {
                      final screen = MaterialPageRoute<T>(fullscreenDialog: true, builder: widget.route.builder);
                      screen.popped.then((r) => _result = r);
                      return [
                        PageRouteBuilder<void>(
                          pageBuilder: (_, _, _) => const SizedBox.shrink(),
                          transitionDuration: Duration.zero,
                        ),
                        screen,
                      ];
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetObserver extends NavigatorObserver {
  _SheetObserver(this.onEmpty);
  final VoidCallback onEmpty;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute?.isFirst ?? false) WidgetsBinding.instance.addPostFrameCallback((_) => onEmpty());
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute?.isFirst ?? false) WidgetsBinding.instance.addPostFrameCallback((_) => onEmpty());
  }
}
