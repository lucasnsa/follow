part of '../follow.dart';

class _Transaction {
  _Transaction(this.router);
  final _FollowRouter router;
  final drafts = <_FeatureNode, List<_RouteEntry>>{};
  final data = <_RouteEntry, RouteData>{};
  final arguments = <_RouteEntry, Object?>{};
  final restoringNodes = <_FeatureNode>{};
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
    router._changed();
  }

  void commit() {
    check();
    for (final draft in drafts.entries) {
      draft.key.pages = draft.value;
    }
    for (final update in data.entries) {
      update.key.data = update.value;
    }
    for (final update in arguments.entries) {
      update.key.arguments = update.value;
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
