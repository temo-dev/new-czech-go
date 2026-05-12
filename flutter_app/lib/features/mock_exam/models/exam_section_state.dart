import '../../../models/models.dart';

/// V39 — visual state of a single section in the answer sheet.
///
/// Maps the server-side `status` string onto a 4-value visual enum that
/// also includes a transient `current` state (the section the learner is
/// looking at right now). `current` lives only on the client; the server
/// never serialises it.
enum SectionState {
  done, // status='completed'
  skipped, // status='skipped'
  empty, // status='pending'
  current, // pointer == this section's display_order
}

/// Map a `MockExamSection` to its visual state. `currentDisplayOrder` is
/// the section the learner is actively answering; matching display_order
/// flips the state to [SectionState.current] regardless of underlying
/// status (so the chip highlights the active question).
SectionState sectionStateFor(
  MockExamSection section, {
  required int currentDisplayOrder,
}) {
  if (section.displayOrder == currentDisplayOrder) {
    return SectionState.current;
  }
  if (section.isCompleted) return SectionState.done;
  if (section.isSkipped) return SectionState.skipped;
  return SectionState.empty;
}
