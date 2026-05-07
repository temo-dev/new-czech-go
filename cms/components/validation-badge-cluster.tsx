'use client';

import { badgeStyle, flagsToBadges, type ValidationFlags } from './validation-badges';

// V23 Phase H4 — shared inline badge cluster used by the exercise
// list row and the quick-fix modal. Variants:
//   - "row" — small chips wrapped onto multiple lines so a long
//     "Thiếu sentence audio" label does not push out of the
//     status grid column
//   - "modal" — slightly larger chips for the in-modal flag list

type Props = {
  flags: ValidationFlags | undefined;
  variant?: 'row' | 'modal';
};

export function ValidationBadgeCluster({ flags, variant = 'row' }: Props) {
  const badges = flagsToBadges(flags);
  if (badges.length === 0) return null;

  const isModal = variant === 'modal';
  return (
    <div
      style={{
        display: 'flex',
        gap: 4,
        flexWrap: 'wrap',
      }}
    >
      {badges.map((b, i) => {
        const colors = isModal
          ? { background: 'var(--surface-alt)', color: 'var(--ink-2)' }
          : badgeStyle(b.variant);
        return (
          <span
            key={i}
            title={b.tooltip}
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: isModal ? 4 : 3,
              fontSize: isModal ? 12 : 10,
              fontWeight: isModal ? 600 : 700,
              padding: isModal ? '3px 9px' : '2px 6px',
              borderRadius: 99,
              letterSpacing: 0.3,
              background: colors.background,
              color: colors.color,
              maxWidth: '100%',
            }}
          >
            <span aria-hidden="true">{b.icon}</span>
            <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {b.label}
            </span>
          </span>
        );
      })}
    </div>
  );
}
