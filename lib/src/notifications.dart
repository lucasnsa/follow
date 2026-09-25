part of '../follow.dart';

/// Never notify in the calling build stack. Initial root attachment can build
/// widgets even while the scheduler is idle, outside a scheduled frame.
void _scheduleNotification(VoidCallback notify) {
  final phase = SchedulerBinding.instance.schedulerPhase;
  if (phase == SchedulerPhase.persistentCallbacks ||
      phase == SchedulerPhase.midFrameMicrotasks) {
    WidgetsBinding.instance.addPostFrameCallback((_) => notify());
  } else {
    // No frame is guaranteed in idle. A microtask lets synchronous mounting
    // finish without leaving the notification waiting for an unrelated frame.
    scheduleMicrotask(notify);
    // Request the frame now, so callers pumping the next frame also render
    // provisional routes before a subsequent navigation can cancel them.
    SchedulerBinding.instance.ensureVisualUpdate();
  }
}
