part of '../follow.dart';

class _Transaction {
  _Transaction(this.router);
  final _FollowRouter router;
  _FeatureNode? resetShell;
  bool animate = true;
  final drafts = <_FeatureNode, List<_RouteEntry>>{};
  final data = <_RouteEntry, RouteData>{};
  final arguments = <_RouteEntry, Object?>{};
  final restoringNodes = <_FeatureNode>{};
  final selections = <_FeatureNode, int>{};
  final staged = <_RouteEntry>[];
  final _cancelled = Completer<void>();
  bool get cancelled => _cancelled.isCompleted || router._disposed;
  void check() {
    if (cancelled) throw _Cancelled();
  }

  List<_RouteEntry> pages(_FeatureNode node) => drafts[node] ?? node.pages;
  Future<T> wait<T>(Future<T> future) => Future.any([
        future,
        _cancelled.future.then<T>((_) => throw _Cancelled()),
      ]);
  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
    clearDraft();
  }

  void clearDraft() {
    for (final entry in staged) {
      entry.owner.staging.remove(entry);
    }
    staged.clear();
    drafts.clear();
    data.clear();
    arguments.clear();
    restoringNodes.clear();
    selections.clear();
    router._changed();
  }

  void commit() {
    check();
    _RouteEntry? active(_FeatureNode node, bool after) {
      final entries = after ? pages(node) : node.pages;
      if (!node.isShell) return entries.lastOrNull;
      final index =
          after ? selections[node] ?? node.activeIndex : node.activeIndex;
      return entries.where((e) => node.branchIndex(e) == index).firstOrNull;
    }

    bool visible(_FeatureNode node, bool after) {
      final entry = node.entry;
      return entry == null ||
          (identical(active(entry.owner, after), entry) &&
              visible(entry.owner, after));
    }

    final switching = selections.keys
        .where((node) =>
            selections[node] != node.activeIndex && node.pages.isNotEmpty)
        .toSet();
    bool ancestorSwitches(_FeatureNode node) {
      for (var parent = node.entry?.owner;
          parent != null;
          parent = parent.entry?.owner) {
        if (switching.contains(parent)) return true;
      }
      return false;
    }

    for (final node in {...drafts.keys, ...selections.keys}) {
      final canAnimate = animate &&
          node.pages.isNotEmpty &&
          visible(node, false) &&
          visible(node, true) &&
          !ancestorSwitches(node);
      node.previousTopId = node.activeEntry?.id;
      node.animatePages = canAnimate;
      node.animateBranches = canAnimate && switching.contains(node);
      node.presentationSerial++;
    }
    for (final draft in drafts.entries) {
      draft.key.pages = draft.value;
    }
    for (final update in data.entries) {
      update.key.data = update.value;
    }
    for (final update in arguments.entries) {
      update.key.arguments = update.value;
    }
    for (final selection in selections.entries) {
      selection.key.activeIndex = selection.value;
    }
    clearDraft();
  }
}

class _Cancelled implements Exception {}

class _DeniedNavigation implements Exception {}

class _NotFoundNavigation implements Exception {}

class _RedirectNavigation implements Exception {
  _RedirectNavigation(this.uri);
  final Uri uri;
}
