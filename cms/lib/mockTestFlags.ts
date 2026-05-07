// V21 MockTest promotion / placement flag helpers.
//
// Centralises the mutex + validation logic for is_promotion / is_placement
// / target_level so the form code can stay declarative and the rules are
// unit-testable without rendering React components.

import { CEFR_LEVELS, type CefrLevel, isCefrLevel } from './level';

export type MockTestFlagsState = {
  is_promotion: boolean;
  is_placement: boolean;
  target_level: '' | CefrLevel;
};

export const emptyMockTestFlags = (): MockTestFlagsState => ({
  is_promotion: false,
  is_placement: false,
  target_level: '',
});

// togglePromotion flips is_promotion. Because is_promotion and is_placement
// are mutually exclusive (enforced by mock_tests_promotion_placement_mutex
// in migration 025), turning promotion ON also turns placement OFF.
// Turning promotion OFF clears target_level so a subsequent re-toggle does
// not silently inherit a stale target.
export function togglePromotion(state: MockTestFlagsState, value: boolean): MockTestFlagsState {
  if (!value) {
    return { ...state, is_promotion: false, target_level: '' };
  }
  // Preserve any pre-typed target_level so admins don't lose work when
  // toggling the promotion flag.
  return { ...state, is_promotion: true, is_placement: false };
}

// togglePlacement is the mirror of togglePromotion. Placement mocks never
// declare a target_level — turning placement ON forces target_level to
// empty (anything else would be invalid against the V21 spec).
export function togglePlacement(state: MockTestFlagsState, value: boolean): MockTestFlagsState {
  if (!value) {
    return { ...state, is_placement: false };
  }
  return { ...state, is_placement: true, is_promotion: false, target_level: '' };
}

// setTargetLevel writes the target_level field, coercing unknown values to
// empty so the form never round-trips an invalid level back to the server.
export function setTargetLevel(state: MockTestFlagsState, value: string): MockTestFlagsState {
  if (value === '' || isCefrLevel(value)) {
    return { ...state, target_level: value as MockTestFlagsState['target_level'] };
  }
  return { ...state, target_level: '' };
}

// validateMockTestFlags returns an error message when the flag combination
// would be rejected by the server CHECK constraints, or null when the
// combination is valid.
export function validateMockTestFlags(state: MockTestFlagsState): string | null {
  if (state.is_promotion && state.is_placement) {
    return 'Mock không thể vừa là promotion vừa là placement.';
  }
  if (state.is_promotion && !isCefrLevel(state.target_level)) {
    return 'Promotion mock cần chọn target level (A0/A1/A2/B1).';
  }
  return null;
}

// mockTestFlagsPayload returns the shape the backend accepts. Empty
// target_level becomes undefined so the JSON does not carry a null field.
export function mockTestFlagsPayload(state: MockTestFlagsState): {
  is_promotion: boolean;
  is_placement: boolean;
  target_level?: CefrLevel;
} {
  const out: ReturnType<typeof mockTestFlagsPayload> = {
    is_promotion: state.is_promotion,
    is_placement: state.is_placement,
  };
  if (isCefrLevel(state.target_level)) {
    out.target_level = state.target_level;
  }
  return out;
}

// CefrLevelOptions is the dropdown source for the target_level select. We
// re-export from level.ts so the component never imports both modules.
export const CefrLevelOptions = CEFR_LEVELS;
