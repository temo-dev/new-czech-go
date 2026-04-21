'use client';

import { FormEvent, useEffect, useState } from 'react';

type Exercise = {
  id: string;
  title: string;
  exercise_type: string;
  short_instruction: string;
  status?: string;
};

const apiBase = process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:8080';
const adminToken = process.env.NEXT_PUBLIC_ADMIN_TOKEN ?? 'dev-admin-token';

export function ExerciseDashboard() {
  const [items, setItems] = useState<Exercise[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [form, setForm] = useState({
    title: 'Pocasi 2',
    shortInstruction: 'Tra loi ngan gon va ro y.',
    learnerInstruction: 'Ban hay tra loi ngan gon theo chu de thoi tiet.',
    moduleId: 'module-day-1',
    questions:
      'Jake pocasi mate dnes?\nCo delate, kdyz je venku hezky?\nMate rad/a zimu?\nJake pocasi bude zitra?',
  });

  async function loadExercises() {
    setLoading(true);
    setError(null);
    try {
      const response = await fetch(`${apiBase}/v1/admin/exercises`, {
        headers: {
          Authorization: `Bearer ${adminToken}`,
        },
      });
      const payload = await response.json();
      if (!response.ok) {
        throw new Error(payload.error?.message ?? 'Could not load exercises.');
      }
      setItems(payload.data ?? []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadExercises();
  }, []);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setError(null);

    try {
      const response = await fetch(`${apiBase}/v1/admin/exercises`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${adminToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          module_id: form.moduleId,
          exercise_type: 'uloha_1_topic_answers',
          title: form.title,
          short_instruction: form.shortInstruction,
          learner_instruction: form.learnerInstruction,
          estimated_duration_sec: 90,
          prep_time_sec: 10,
          recording_time_limit_sec: 45,
          sample_answer_enabled: true,
          questions: form.questions.split('\n').map((line) => line.trim()).filter(Boolean),
        }),
      });

      const payload = await response.json();
      if (!response.ok) {
        throw new Error(payload.error?.message ?? 'Could not create exercise.');
      }

      setForm((current) => ({ ...current, title: `${current.title} moi` }));
      await loadExercises();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setSaving(false);
    }
  }

  return (
    <main style={{ display: 'grid', gap: 24 }}>
      <section
        style={{
          display: 'grid',
          gap: 18,
          padding: 28,
          borderRadius: 28,
          background: 'var(--surface)',
          border: '1px solid var(--border)',
          boxShadow: 'var(--shadow)',
        }}
      >
        <div style={{ display: 'grid', gap: 8 }}>
          <p style={eyebrowStyle}>A2 Mluveni CMS</p>
          <h1 style={{ margin: 0, fontSize: 'clamp(2.2rem, 3vw, 3.5rem)', lineHeight: 1.02 }}>
            Calm content ops for the first oral slice
          </h1>
          <p style={{ margin: 0, maxWidth: 760, color: 'var(--text-secondary)', fontSize: 16, lineHeight: 1.55 }}>
            This desk keeps the first speaking workflow light and focused. The goal is to create and review `Uloha 1`
            content fast, while the learner app stays centered on one task at a time.
          </p>
        </div>

        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
            gap: 14,
          }}
        >
          <div style={metricCardStyle}>
            <span style={metricLabelStyle}>Current slice</span>
            <strong style={metricValueStyle}>Uloha 1</strong>
            <span style={metricHintStyle}>Topic answers only</span>
          </div>
          <div style={metricCardStyle}>
            <span style={metricLabelStyle}>Content status</span>
            <strong style={metricValueStyle}>{items.length}</strong>
            <span style={metricHintStyle}>Exercises in admin list</span>
          </div>
          <div style={metricCardStyle}>
            <span style={metricLabelStyle}>Working mode</span>
            <strong style={metricValueStyle}>Single task</strong>
            <span style={metricHintStyle}>Low-noise CMS panel</span>
          </div>
        </div>
      </section>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'minmax(320px, 420px) minmax(0, 1fr)',
          gap: 20,
          alignItems: 'start',
        }}
      >
        <form
          onSubmit={handleSubmit}
          style={{
            display: 'grid',
            gap: 14,
            padding: 24,
            borderRadius: 28,
            background: 'var(--surface)',
            border: '1px solid var(--border)',
            boxShadow: 'var(--shadow)',
          }}
        >
          <div style={{ display: 'grid', gap: 6 }}>
            <span style={eyebrowStyle}>Create content</span>
            <h2 style={{ margin: 0, fontSize: 24 }}>Create `Uloha 1`</h2>
            <p style={{ margin: 0, color: 'var(--text-secondary)', lineHeight: 1.5 }}>
              Keep prompts short, specific, and easy to scan so learners can stay calm inside the speaking flow.
            </p>
          </div>

          <label style={{ display: 'grid', gap: 6 }}>
            <span style={fieldLabelStyle}>Title</span>
            <input
              value={form.title}
              onChange={(event) => setForm({ ...form, title: event.target.value })}
              style={fieldStyle}
            />
          </label>

          <label style={{ display: 'grid', gap: 6 }}>
            <span style={fieldLabelStyle}>Short instruction</span>
            <input
              value={form.shortInstruction}
              onChange={(event) => setForm({ ...form, shortInstruction: event.target.value })}
              style={fieldStyle}
            />
          </label>

          <label style={{ display: 'grid', gap: 6 }}>
            <span style={fieldLabelStyle}>Learner instruction</span>
            <textarea
              rows={4}
              value={form.learnerInstruction}
              onChange={(event) => setForm({ ...form, learnerInstruction: event.target.value })}
              style={fieldStyle}
            />
          </label>

          <label style={{ display: 'grid', gap: 6 }}>
            <span style={fieldLabelStyle}>Question prompts</span>
            <textarea
              rows={6}
              value={form.questions}
              onChange={(event) => setForm({ ...form, questions: event.target.value })}
              style={fieldStyle}
            />
          </label>

          <button
            type="submit"
            disabled={saving}
            style={{
              border: 0,
              borderRadius: 18,
              background: saving ? 'color-mix(in srgb, var(--primary) 55%, white)' : 'var(--primary)',
              color: 'white',
              padding: '14px 18px',
              cursor: saving ? 'wait' : 'pointer',
              fontWeight: 700,
              boxShadow: '0 16px 28px rgba(240, 90, 40, 0.18)',
            }}
          >
            {saving ? 'Saving...' : 'Create exercise'}
          </button>
        </form>

        <section
          style={{
            display: 'grid',
            gap: 14,
            padding: 24,
            borderRadius: 28,
            background: 'var(--surface)',
            border: '1px solid var(--border)',
            boxShadow: 'var(--shadow)',
            minHeight: 420,
          }}
        >
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12 }}>
            <div>
              <span style={eyebrowStyle}>Current inventory</span>
              <h2 style={{ margin: '6px 0 0' }}>Exercises</h2>
              <p style={{ margin: '6px 0 0', color: 'var(--text-secondary)' }}>Pulled from `/v1/admin/exercises`.</p>
            </div>
            <button
              type="button"
              onClick={loadExercises}
              style={{
                borderRadius: 16,
                border: '1px solid var(--border)',
                background: 'var(--surface-muted)',
                padding: '10px 14px',
                cursor: 'pointer',
                fontWeight: 600,
              }}
            >
              Refresh
            </button>
          </div>

          {error ? <p style={{ margin: 0, color: 'var(--danger)' }}>{error}</p> : null}

          {loading ? <p style={{ margin: 0 }}>Loading exercises...</p> : null}

          <div style={{ display: 'grid', gap: 12 }}>
            {items.map((item) => (
              <article
                key={item.id}
                style={{
                  display: 'grid',
                  gap: 10,
                  padding: 18,
                  borderRadius: 20,
                  background: 'var(--surface-muted)',
                  border: '1px solid var(--border)',
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12 }}>
                  <strong style={{ fontSize: 18 }}>{item.title}</strong>
                  <span style={badgeStyle}>{item.status ?? 'draft'}</span>
                </div>
                <span style={{ color: 'var(--accent)', fontWeight: 700 }}>{item.exercise_type}</span>
                <p style={{ margin: 0, color: 'var(--text-secondary)', lineHeight: 1.5 }}>{item.short_instruction}</p>
                <code style={{ color: 'var(--text-secondary)' }}>{item.id}</code>
              </article>
            ))}
          </div>
        </section>
      </section>
    </main>
  );
}

const fieldStyle = {
  width: '100%',
  padding: '14px 16px',
  borderRadius: 16,
  border: '1px solid var(--border)',
  background: 'var(--surface-muted)',
  color: 'var(--text)',
  lineHeight: 1.5,
} as const;

const badgeStyle = {
  alignSelf: 'start',
  padding: '6px 12px',
  borderRadius: 999,
  background: 'var(--primary-soft)',
  color: 'var(--primary-strong)',
  fontSize: 12,
  fontWeight: 700,
  textTransform: 'uppercase' as const,
  letterSpacing: '0.06em',
} as const;

const eyebrowStyle = {
  margin: 0,
  color: 'var(--accent)',
  fontSize: 12,
  fontWeight: 700,
  textTransform: 'uppercase' as const,
  letterSpacing: '0.12em',
} as const;

const fieldLabelStyle = {
  color: 'var(--text)',
  fontWeight: 700,
} as const;

const metricCardStyle = {
  display: 'grid',
  gap: 6,
  padding: 18,
  borderRadius: 22,
  border: '1px solid var(--border)',
  background: 'var(--surface-warm)',
} as const;

const metricLabelStyle = {
  color: 'var(--text-secondary)',
  fontSize: 12,
  fontWeight: 700,
  textTransform: 'uppercase' as const,
  letterSpacing: '0.08em',
} as const;

const metricValueStyle = {
  color: 'var(--text)',
  fontSize: 22,
  lineHeight: 1.1,
} as const;

const metricHintStyle = {
  color: 'var(--text-secondary)',
  fontSize: 14,
} as const;
