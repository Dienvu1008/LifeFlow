import 'dart:async';

import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:ui/ui.dart';

/// In-memory stand-in for the application ports. Like the real implementation
/// the task stream is bound to the profile that is active when it subscribes
/// (LF-INV-ID-002), so a UI that forgets to re-subscribe after a switch fails.
class FakeWorld
    implements TaskQueries, TaskService, ProfileService, AccountService {
  FakeWorld({
    required Map<String, List<TaskView>> tasks,
    required this.profiles,
    required this.activeId,
  }) : _tasks = tasks;

  final Map<String, List<TaskView>> _tasks;
  final List<ProfileView> profiles;
  String activeId;

  /// Every service call, in order, e.g. `create:Title:parentId`.
  final calls = <String>[];

  /// When set, the next write returns this failure instead of applying.
  CommandFailure? failNext;

  final _changes = StreamController<void>.broadcast();
  var _n = 0;

  List<TaskView> _mine() => _tasks[activeId]!;

  @override
  Stream<List<TaskView>> watchTasks() async* {
    final id = activeId; // bound at subscribe time
    yield List.of(_tasks[id]!);
    await for (final _ in _changes.stream) {
      yield List.of(_tasks[id]!);
    }
  }

  CommandResult? _failure() {
    final f = failNext;
    failNext = null;
    return f;
  }

  @override
  Future<CommandResult> create(String title, {String? parentId}) async {
    calls.add('create:$title:$parentId');
    final f = _failure();
    if (f != null) return f;
    final id = 'new${_n++}';
    _mine().add(TaskView(
        id: id,
        title: title,
        status: 'inbox',
        parentId: parentId,
        createdAt: DateTime(2026)));
    _changes.add(null);
    return CommandOk(id, Version.initial, const []);
  }

  @override
  Future<CommandResult> rename(String id, String title) async {
    calls.add('rename:$id:$title');
    final f = _failure();
    if (f != null) return f;
    _replace(id, (t) => _copy(t, title: title));
    return CommandOk(id, Version.initial, const []);
  }

  @override
  Future<CommandResult> complete(String id,
      {required bool withDescendants}) async {
    calls.add('complete:$id:$withDescendants');
    final f = _failure();
    if (f != null) return f;
    _replace(id, (t) => _copy(t, status: 'done'));
    if (withDescendants) {
      for (final c in _mine().where((t) => t.parentId == id).toList()) {
        _replace(c.id, (t) => _copy(t, status: 'done'));
      }
    }
    return CommandOk(id, Version.initial, const []);
  }

  @override
  Future<CommandResult> trash(String id) async {
    calls.add('trash:$id');
    final f = _failure();
    if (f != null) return f;
    _mine().removeWhere((t) => t.id == id);
    _changes.add(null);
    return CommandOk(id, Version.initial, const []);
  }

  @override
  Future<ProfileView?> active() async =>
      profiles.firstWhere((p) => p.id == activeId).asActive(true);

  @override
  Future<List<ProfileView>> list() async =>
      [for (final p in profiles) p.asActive(p.id == activeId)];

  @override
  Future<CommandResult> switchTo(String profileId) async {
    calls.add('switch:$profileId');
    final f = _failure();
    if (f != null) return f;
    activeId = profileId;
    return CommandOk(profileId, Version.initial, const []);
  }

  // --- AccountService (mirrors DriftAccountService's rules) -----------------

  @override
  bool signInAvailable = true;

  /// When set, the next sign-in fails with this message.
  String? signInFailure;
  String? _pendingProvider;

  String _providerOf(SignInRequest r) => switch (r) {
        EmailPasswordSignIn() => 'email',
        OAuthSignIn(:final provider) => provider,
      };

  @override
  Future<SignInOutcome> signIn(SignInRequest request) async {
    final provider = _providerOf(request);
    calls.add('signIn:$provider');
    final f = signInFailure;
    if (f != null) {
      signInFailure = null;
      return SignInFailed(f);
    }
    if (_mine().isEmpty) return _bind(provider, move: true);
    _pendingProvider = provider;
    return NeedsBindChoice(provider: provider);
  }

  @override
  Future<SignInOutcome> completeBind({required bool moveData}) async {
    calls.add('completeBind:$moveData');
    final provider = _pendingProvider!;
    _pendingProvider = null;
    return _bind(provider, move: moveData);
  }

  @override
  Future<void> cancelPendingBind() async {
    calls.add('cancelPendingBind');
    _pendingProvider = null;
  }

  @override
  Future<CommandResult> signOut() async {
    calls.add('signOut');
    _setProfile(activeId, bound: false, provider: null);
    return CommandOk(activeId, Version.initial, const []);
  }

  SignInOutcome _bind(String provider, {required bool move}) {
    if (move) {
      _setProfile(activeId, bound: true, provider: provider);
      return SignedIn(profiles.firstWhere((p) => p.id == activeId).asActive(true));
    }
    final id = 'acct${_n++}';
    profiles.add(ProfileView(
        id: id, displayName: '', isActive: false, isBound: true, provider: provider));
    _tasks[id] = [];
    activeId = id;
    return SignedIn(profiles.last.asActive(true), switchedProfile: true);
  }

  void _setProfile(String id, {required bool bound, String? provider}) {
    final i = profiles.indexWhere((p) => p.id == id);
    final p = profiles[i];
    profiles[i] = ProfileView(
        id: p.id,
        displayName: p.displayName,
        isActive: p.isActive,
        isBound: bound,
        provider: provider);
  }

  void _replace(String id, TaskView Function(TaskView) f) {
    final list = _mine();
    final i = list.indexWhere((t) => t.id == id);
    list[i] = f(list[i]);
    _changes.add(null);
  }

  TaskView _copy(TaskView t, {String? title, String? status}) => TaskView(
        id: t.id,
        title: title ?? t.title,
        status: status ?? t.status,
        parentId: t.parentId,
        createdAt: t.createdAt,
      );

  void dispose() => _changes.close();
}

extension on ProfileView {
  ProfileView asActive(bool active) => ProfileView(
        id: id,
        displayName: displayName,
        isActive: active,
        isBound: isBound,
        provider: provider,
      );
}

TaskView task(String id, String title,
        {String? parent, String status = 'inbox'}) =>
    TaskView(
        id: id,
        title: title,
        status: status,
        parentId: parent,
        createdAt: DateTime(2026));

ProfileView profile(String id, String name,
        {bool bound = false, String? provider}) =>
    ProfileView(
        id: id,
        displayName: name,
        isActive: false,
        isBound: bound,
        provider: provider);

/// The full app with the ports overridden by [world].
Widget appWith(FakeWorld world, {StorageNotice? notice}) => ProviderScope(
      overrides: [
        taskQueriesProvider.overrideWithValue(world),
        taskServiceProvider.overrideWithValue(world),
        profileServiceProvider.overrideWithValue(world),
        accountServiceProvider.overrideWithValue(world),
        storageNoticeProvider.overrideWithValue(notice),
      ],
      child: const LifeFlowApp(),
    );
