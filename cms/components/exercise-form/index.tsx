'use client';

import { FormEvent, useCallback, useEffect, useRef, useState } from 'react';
import { useS } from '../../lib/i18n';
import { adminFetch } from '../../lib/api';
import { PoslechFields } from './PoslechFields';
import { CteniFields } from './CteniFields';
import { SpeakingFields } from './SpeakingFields';
import { WritingFields } from './WritingFields';
import { validateExercise } from './validation';
import {
  adminApi,
  appendLineIfMissing,
  assetPreviewSrc,
  badgeStyle,
  buildCreatePayload,
  buildUpdatePayload,
  CmsModule,
  createInitialFormState,
  Exercise,
  exerciseTypeOptions,
  ExerciseFormState,
  ExerciseType,
  eyebrowStyle,
  fieldHintStyle,
  fieldLabelStyle,
  fieldStyle,
  formStateFromExercise,
  PromptAsset,
  secondaryActionStyle,
  SKILL_KIND_EXERCISE_TYPES,
  SKILL_KIND_META,
} from '../exercise-utils';

type Props = {
  open: boolean;
  editingItem: Exercise | null;
  modules: CmsModule[];
  onSaved: () => void;
  onDeleted: (id: string) => void;
  onClose: () => void;
};

function WizardTypeStep({
  form,
  onSelectType,
  onBack,
}: {
  form: ExerciseFormState;
  onSelectType: (type: ExerciseType) => void;
  onBack: () => void;
}) {
  const kind = form.skillKind;
  const meta = SKILL_KIND_META[kind as keyof typeof SKILL_KIND_META];
  const typeOptions = (SKILL_KIND_EXERCISE_TYPES[kind] ?? [])
    .map((v) => exerciseTypeOptions.find((o) => o.value === v))
    .filter((o): o is NonNullable<typeof o> => o != null);

  return (
    <div
      style={{
        display: 'grid',
        gap: 16,
        padding: 24,
        borderRadius: 28,
        background: 'var(--surface)',
        border: '1px solid var(--border)',
        boxShadow: 'var(--shadow)',
      }}
    >
      <div>
        <p
          style={{
            margin: '0 0 4px',
            fontSize: 11,
            fontWeight: 700,
            letterSpacing: 1,
            color: 'var(--primary)',
            textTransform: 'uppercase',
          }}
        >
          Bước 2 / 3
        </p>
        <h2 style={{ margin: '0 0 4px', fontSize: 22 }}>Chọn dạng bài</h2>
        <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: 14 }}>
          Kỹ năng:{' '}
          <strong style={{ color: meta?.color }}>
            {meta?.icon} {meta?.label}
          </strong>
        </p>
      </div>
      <div style={{ display: 'grid', gap: 8 }}>
        {typeOptions.map((opt) => (
          <button
            key={opt.value}
            type="button"
            onClick={() => onSelectType(opt.value)}
            style={{
              textAlign: 'left',
              padding: '12px 16px',
              borderRadius: 12,
              border: `2px solid ${form.exerciseType === opt.value ? 'var(--primary)' : 'var(--border)'}`,
              background:
                form.exerciseType === opt.value ? 'rgba(255,106,20,0.08)' : 'var(--surface-muted)',
              cursor: 'pointer',
            }}
          >
            <div style={{ fontWeight: 700, fontSize: 14, marginBottom: 2 }}>{opt.label}</div>
            <div style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{opt.hint}</div>
          </button>
        ))}
      </div>
      <button
        type="button"
        onClick={onBack}
        style={{
          alignSelf: 'start',
          background: 'none',
          border: 'none',
          color: 'var(--text-secondary)',
          cursor: 'pointer',
          fontSize: 13,
          padding: 0,
        }}
      >
        ← Quay lại chọn kỹ năng
      </button>
    </div>
  );
}

export function ExerciseSlideOver({ open, editingItem, modules, onSaved, onDeleted, onClose }: Props) {
  const S = useS();

  const [form, setForm] = useState<ExerciseFormState>(createInitialFormState);
  const [wizardStep, setWizardStep] = useState<'skill' | 'type' | 'content'>('skill');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [assetUploading, setAssetUploading] = useState(false);
  const [assetError, setAssetError] = useState<string | null>(null);
  const [audioGenerating, setAudioGenerating] = useState(false);
  const [audioGenMsg, setAudioGenMsg] = useState<string | null>(null);
  const [showConfirmClose, setShowConfirmClose] = useState(false);
  const [draftToast, setDraftToast] = useState(false);
  const initialFormSnap = useRef<string>('');

  const editingId = editingItem?.id ?? null;
  const currentAssets = editingItem?.assets ?? [];

  // Sync form when editingItem changes or panel opens
  useEffect(() => {
    if (!open) return;
    if (editingItem) {
      const state = formStateFromExercise(editingItem);
      setForm(state);
      initialFormSnap.current = JSON.stringify(state);
      setWizardStep('content');
    } else {
      const initial = createInitialFormState();
      setForm(initial);
      initialFormSnap.current = JSON.stringify(initial);
      setWizardStep('skill');
    }
    setError(null);
    setAssetError(null);
    // Check for stale draft on open
    if (!editingItem && localStorage.getItem('ef-draft-v2')) {
      setDraftToast(true);
    }
  }, [open, editingItem]);

  // Autosave every 10s while panel is open
  useEffect(() => {
    if (!open) return;
    const id = setInterval(() => {
      localStorage.setItem('ef-draft-v2', JSON.stringify({ form, editingId, wizardStep }));
    }, 10000);
    return () => clearInterval(id);
  }, [open, form, editingId, wizardStep]);

  const requestClose = useCallback(() => {
    const snap = initialFormSnap.current;
    const dirty = snap !== '' && JSON.stringify(form) !== snap;
    if (dirty) {
      setShowConfirmClose(true);
    } else {
      doClose();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [form]);

  function doClose() {
    setShowConfirmClose(false);
    setDraftToast(false);
    initialFormSnap.current = '';
    localStorage.removeItem('ef-draft-v2');
    onClose();
  }

  function handleModuleChange(moduleId: string) {
    setForm((f) => ({ ...f, moduleId, skillKind: '' }));
  }

  async function handleAssetUpload(file: File) {
    if (!editingId) {
      setAssetError('Save the exercise first before uploading images.');
      return;
    }
    setAssetUploading(true);
    setAssetError(null);
    try {
      const formData = new FormData();
      formData.set('file', file);
      formData.set('asset_kind', 'image');
      formData.set('sequence_no', String(currentAssets.length + 1));
      const response = await adminFetch(`${adminApi}/${editingId}/assets/upload`, {
        method: 'POST',
        body: formData,
      });
      const payload = await response.json();
      if (!response.ok) throw new Error(payload.error?.message ?? 'Could not upload asset.');
      const assetId = payload.data?.asset?.id as string | undefined;
      onSaved(); // reload so assets appear
      if (assetId && form.exerciseType === 'uloha_3_story_narration') {
        setForm((current) => ({
          ...current,
          imageAssetIds: appendLineIfMissing(current.imageAssetIds, assetId),
        }));
      }
    } catch (err) {
      setAssetError(err instanceof Error ? err.message : 'Unknown asset upload error');
    } finally {
      setAssetUploading(false);
    }
  }

  async function handleCopyAssetId(assetId: string) {
    try {
      await navigator.clipboard.writeText(assetId);
      setAssetError(`Copied ${assetId}.`);
    } catch {
      setAssetError(`Copy failed. Asset id: ${assetId}`);
    }
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setError(null);
    try {
      const response = await adminFetch(editingId ? `${adminApi}/${editingId}` : adminApi, {
        method: editingId ? 'PATCH' : 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(editingId ? buildUpdatePayload(form) : buildCreatePayload(form)),
      });
      const payload = await response.json();
      if (!response.ok) {
        throw new Error(
          payload.error?.message ??
            (editingId ? 'Could not update exercise.' : 'Could not create exercise.'),
        );
      }
      localStorage.removeItem('ef-draft-v2');
      onSaved();
      doClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete() {
    if (!editingId) return;
    if (!window.confirm(S.exercise.deleteConfirm)) return;
    try {
      const response = await adminFetch(`${adminApi}/${editingId}`, { method: 'DELETE' });
      const payload = await response.json();
      if (!response.ok) throw new Error(payload.error?.message ?? 'Could not delete exercise.');
      onDeleted(editingId);
      doClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    }
  }

  const validationErrors: string[] = (() => {
    if (wizardStep !== 'content' && !editingId) return [];
    try {
      const payload = buildCreatePayload(form);
      return validateExercise(form.exerciseType, payload as Record<string, unknown>);
    } catch (e) {
      return [e instanceof Error ? e.message : 'Format nhập liệu không hợp lệ.'];
    }
  })();

  return (
    <>
      {/* Backdrop */}
      {open && (
        <div
          onClick={requestClose}
          style={{ position: 'fixed', inset: 0, zIndex: 100, background: 'rgba(20,18,14,0.4)' }}
        />
      )}

      {/* Slide-over panel */}
      <aside
        style={{
          position: 'fixed',
          top: 0,
          right: 0,
          bottom: 0,
          zIndex: 101,
          width: 'min(80vw, 960px)',
          background: 'var(--surface)',
          borderLeft: '1px solid var(--border)',
          boxShadow: '-8px 0 32px rgba(20,18,14,0.12)',
          overflowY: 'auto',
          transform: open ? 'translateX(0)' : 'translateX(110%)',
          transition: 'transform 250ms ease-out',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        {/* Panel header */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '14px 24px',
            borderBottom: '1px solid var(--border)',
            position: 'sticky',
            top: 0,
            background: 'var(--surface)',
            zIndex: 1,
            flexShrink: 0,
          }}
        >
          <h2 style={{ margin: 0, fontSize: 17, fontWeight: 700, color: 'var(--ink)' }}>
            {editingId ? 'Chỉnh sửa bài tập' : 'Tạo bài tập mới'}
          </h2>
          <button
            type="button"
            onClick={requestClose}
            aria-label="Đóng panel"
            style={{
              background: 'none',
              border: '1px solid var(--border)',
              borderRadius: 8,
              padding: '5px 12px',
              cursor: 'pointer',
              fontSize: 13,
              color: 'var(--ink-2)',
              display: 'flex',
              alignItems: 'center',
              gap: 4,
            }}
          >
            Đóng <span aria-hidden>×</span>
          </button>
        </div>

        {/* Draft restore toast */}
        {draftToast && (
          <div
            style={{
              margin: '12px 24px 0',
              padding: '10px 14px',
              background: 'var(--brand-soft)',
              borderRadius: 10,
              display: 'flex',
              gap: 8,
              alignItems: 'center',
              fontSize: 13,
              border: '1px solid var(--brand)',
            }}
          >
            <span style={{ flex: 1, color: 'var(--brand-ink)' }}>
              Có bản nháp chưa lưu. Khôi phục không?
            </span>
            <button
              onClick={() => {
                const raw = localStorage.getItem('ef-draft-v2');
                if (raw) {
                  try {
                    const {
                      form: f,
                      editingId: eid,
                      wizardStep: ws,
                    } = JSON.parse(raw) as {
                      form: ExerciseFormState;
                      editingId: string | null;
                      wizardStep: 'skill' | 'type' | 'content';
                    };
                    setForm(f);
                    if (eid) {
                      /* editingId is controlled by parent; skip */
                    }
                    if (ws) setWizardStep(ws);
                    void eid; // suppress unused warning
                  } catch {
                    /* ignore corrupt draft */
                  }
                }
                setDraftToast(false);
              }}
              style={{
                background: 'var(--brand)',
                color: '#fff',
                border: 'none',
                borderRadius: 6,
                padding: '4px 10px',
                cursor: 'pointer',
                fontSize: 12,
                fontWeight: 600,
              }}
            >
              Khôi phục
            </button>
            <button
              onClick={() => {
                localStorage.removeItem('ef-draft-v2');
                setDraftToast(false);
              }}
              style={{
                background: 'none',
                border: 'none',
                cursor: 'pointer',
                fontSize: 12,
                color: 'var(--ink-3)',
                padding: '4px 6px',
              }}
            >
              Bỏ qua
            </button>
          </div>
        )}

        {/* Panel body */}
        <div style={{ padding: 24, display: 'grid', gap: 16, flex: 1 }}>
          {/* Wizard step 1: pick skill */}
          {!editingId && wizardStep === 'skill' && (
            <div
              style={{
                display: 'grid',
                gap: 16,
                padding: 20,
                borderRadius: 28,
                background: 'var(--surface)',
                border: '1px solid var(--border)',
                boxShadow: 'var(--shadow)',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                {[1, 2, 3].map((n) => (
                  <div
                    key={n}
                    style={{
                      width: n === 1 ? 24 : 8,
                      height: 8,
                      borderRadius: 99,
                      background: n === 1 ? 'var(--primary)' : 'var(--border)',
                      transition: 'all 0.2s',
                    }}
                  />
                ))}
                <span
                  style={{
                    fontSize: 11,
                    fontWeight: 700,
                    letterSpacing: 0.8,
                    color: 'var(--primary)',
                    textTransform: 'uppercase',
                    marginLeft: 4,
                  }}
                >
                  Bước 1 / 3
                </span>
              </div>
              <div>
                <h2 style={{ margin: '0 0 4px', fontSize: 22 }}>Chọn kỹ năng</h2>
                <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: 14 }}>
                  Bài tập sẽ được gắn vào kỹ năng này.
                </p>
              </div>
              <div style={{ display: 'grid', gap: 12 }}>
                {(['noi', 'viet', 'nghe', 'doc', 'tu_vung', 'ngu_phap'] as const).map((kind) => {
                  const meta = SKILL_KIND_META[kind as keyof typeof SKILL_KIND_META];
                  if (!meta) return null;
                  return (
                    <button
                      key={kind}
                      type="button"
                      onClick={() => {
                        setForm((f) => ({
                          ...f,
                          skillKind: kind,
                          exerciseType: SKILL_KIND_EXERCISE_TYPES[kind]?.[0] ?? f.exerciseType,
                        }));
                        setWizardStep('type');
                      }}
                      onMouseEnter={(e) => {
                        (e.currentTarget as HTMLButtonElement).style.background = 'var(--primary)';
                        (e.currentTarget as HTMLButtonElement).style.borderColor = 'var(--primary)';
                        (e.currentTarget as HTMLButtonElement).style.color = '#fff';
                      }}
                      onMouseLeave={(e) => {
                        (e.currentTarget as HTMLButtonElement).style.background = 'var(--surface-muted)';
                        (e.currentTarget as HTMLButtonElement).style.borderColor = 'var(--border)';
                        (e.currentTarget as HTMLButtonElement).style.color = '';
                      }}
                      style={{
                        textAlign: 'left',
                        padding: '10px 14px',
                        borderRadius: 10,
                        border: '1px solid var(--border)',
                        background: 'var(--surface-muted)',
                        cursor: 'pointer',
                        transition: 'background 0.15s, border-color 0.15s, color 0.15s',
                      }}
                    >
                      <div style={{ fontWeight: 600, fontSize: 13 }}>
                        {meta.icon} {meta.label}
                      </div>
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {/* Wizard step 2: pick type */}
          {!editingId && wizardStep === 'type' && (
            <WizardTypeStep
              form={form}
              onSelectType={(type) => {
                setForm((f) => ({ ...f, exerciseType: type }));
                setWizardStep('content');
              }}
              onBack={() => setWizardStep('skill')}
            />
          )}

          {/* Step 3: content form */}
          {(editingId || wizardStep === 'content') && (
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
                <span style={eyebrowStyle}>{S.exercise.editorEyebrow}</span>
                <h2 style={{ margin: 0, fontSize: 24 }}>
                  {editingId ? 'Chỉnh sửa ' : 'Tạo '}
                  {form.exerciseType === 'uloha_1_topic_answers'
                    ? '`Uloha 1`'
                    : form.exerciseType === 'uloha_2_dialogue_questions'
                      ? '`Uloha 2`'
                      : form.exerciseType === 'uloha_3_story_narration'
                        ? '`Uloha 3`'
                        : form.exerciseType === 'uloha_4_choice_reasoning'
                          ? '`Uloha 4`'
                          : form.exerciseType === 'psani_1_formular'
                            ? '`Psaní 1 — Formulář`'
                            : form.exerciseType === 'psani_2_email'
                              ? '`Psaní 2 — E-mail`'
                              : form.exerciseType.startsWith('poslech_')
                                ? `\`${form.exerciseType.replace('_', ' ').toUpperCase()}\``
                                : form.exerciseType.startsWith('cteni_')
                                  ? `\`${form.exerciseType.replace('_', ' ').toUpperCase()}\``
                                  : '`Exercise`'}
                </h2>
                <p style={{ margin: 0, color: 'var(--text-secondary)', lineHeight: 1.5 }}>
                  {S.exercise.editorHint}
                </p>
              </div>

              {editingId && (
                <div
                  style={{
                    padding: '12px 14px',
                    borderRadius: 16,
                    background: 'var(--surface-muted)',
                    color: 'var(--text-secondary)',
                    fontSize: 14,
                  }}
                >
                  Editing <code>{editingId}</code>
                </div>
              )}

              {/* Type-specific content */}
              <div style={{ borderBottom: '1px solid var(--border)', paddingBottom: 16, marginBottom: 4 }}>
                <p
                  style={{
                    margin: '0 0 12px',
                    fontSize: 11,
                    fontWeight: 700,
                    letterSpacing: 0.8,
                    color: 'var(--ink-3)',
                    textTransform: 'uppercase',
                  }}
                >
                  Nội dung bài tập
                </p>

                {(['uloha_1_topic_answers', 'uloha_2_dialogue_questions', 'uloha_3_story_narration', 'uloha_4_choice_reasoning'] as string[]).includes(form.exerciseType) && (
                  <SpeakingFields form={form as never} setForm={setForm as never} />
                )}

                {(form.exerciseType === 'psani_1_formular' || form.exerciseType === 'psani_2_email') && (
                  <WritingFields form={form as never} setForm={setForm as never} />
                )}

                {form.exerciseType.startsWith('poslech_') && (
                  <PoslechFields
                    exerciseType={form.exerciseType as 'poslech_1' | 'poslech_2' | 'poslech_3' | 'poslech_4' | 'poslech_5'}
                    initialData={form.typePayload ?? {}}
                    onChange={(payload) => setForm((f) => ({ ...f, typePayload: payload }))}
                    editingId={editingId}
                    audioGenerating={audioGenerating}
                    audioGenMsg={audioGenMsg}
                    onGenerateAudio={async () => {
                      if (!editingId) { setAudioGenMsg('Lưu bài trước khi tạo audio.'); return; }
                      setAudioGenerating(true);
                      setAudioGenMsg(null);
                      try {
                        const saveRes = await adminFetch(`${adminApi}/${editingId}`, {
                          method: 'PATCH',
                          headers: { 'Content-Type': 'application/json' },
                          body: JSON.stringify(buildUpdatePayload(form)),
                        });
                        if (!saveRes.ok) throw new Error('Lưu thất bại trước khi tạo audio.');
                        const res = await adminFetch(`${adminApi}/${editingId}/generate-audio`, {
                          method: 'POST',
                        });
                        const j = await res.json();
                        if (!res.ok) throw new Error(j.error?.message ?? 'Failed');
                        setAudioGenMsg('Đã tạo audio.');
                      } catch (e) {
                        setAudioGenMsg(e instanceof Error ? e.message : 'Error');
                      } finally {
                        setAudioGenerating(false);
                      }
                    }}
                  />
                )}

                {form.exerciseType.startsWith('cteni_') && (
                  <CteniFields
                    exerciseType={form.exerciseType as 'cteni_1' | 'cteni_2' | 'cteni_3' | 'cteni_4' | 'cteni_5'}
                    initialData={form.typePayload ?? {}}
                    onChange={(payload) => setForm((f) => ({ ...f, typePayload: payload }))}
                  />
                )}

                {(form.exerciseType === 'uloha_3_story_narration' ||
                  form.exerciseType === 'uloha_4_choice_reasoning' ||
                  form.exerciseType === 'psani_2_email') && (
                  <section
                    style={{
                      display: 'grid',
                      gap: 12,
                      padding: 16,
                      borderRadius: 20,
                      background: 'var(--surface-muted)',
                      border: '1px solid var(--border)',
                    }}
                  >
                    <div style={{ display: 'grid', gap: 4 }}>
                      <span style={fieldLabelStyle}>{S.exercise.fieldPromptAssets}</span>
                      <span style={fieldHintStyle}>
                        Upload ảnh sau khi đã save draft. Uloha 3: id tự động thêm vào danh sách.
                        Psaní 2: copy id vào trường &quot;Asset IDs&quot;.
                      </span>
                    </div>
                    {!editingId ? (
                      <p style={{ margin: 0, color: 'var(--text-secondary)' }}>
                        Save this draft first, then come back to attach images.
                      </p>
                    ) : (
                      <>
                        <label style={{ display: 'grid', gap: 8 }}>
                          <span style={fieldLabelStyle}>Upload image</span>
                          <input
                            type="file"
                            accept="image/*"
                            onChange={(event) => {
                              const file = event.target.files?.[0];
                              if (file) void handleAssetUpload(file);
                              event.currentTarget.value = '';
                            }}
                          />
                        </label>
                        {assetError && (
                          <p
                            style={{
                              margin: 0,
                              color: assetError.startsWith('Copied ')
                                ? 'var(--text-secondary)'
                                : 'var(--danger)',
                            }}
                          >
                            {assetError}
                          </p>
                        )}
                        {assetUploading && (
                          <p style={{ margin: 0, color: 'var(--text-secondary)' }}>Uploading asset...</p>
                        )}
                        <div style={{ display: 'grid', gap: 12 }}>
                          {currentAssets.length === 0 ? (
                            <p style={{ margin: 0, color: 'var(--text-secondary)' }}>
                              {S.exercise.noAssets}
                            </p>
                          ) : (
                            currentAssets.map((asset: PromptAsset) => (
                              <article
                                key={asset.id}
                                style={{
                                  display: 'grid',
                                  gap: 10,
                                  padding: 14,
                                  borderRadius: 18,
                                  border: '1px solid var(--border)',
                                  background: 'var(--surface)',
                                }}
                              >
                                {asset.mime_type?.startsWith('image/') && (
                                  // eslint-disable-next-line @next/next/no-img-element
                                  <img
                                    src={assetPreviewSrc(editingId, asset)}
                                    alt={asset.id}
                                    style={{
                                      width: '100%',
                                      maxHeight: 180,
                                      objectFit: 'cover',
                                      borderRadius: 14,
                                      border: '1px solid var(--border)',
                                    }}
                                  />
                                )}
                                <div style={{ display: 'grid', gap: 4 }}>
                                  <strong>{asset.id}</strong>
                                  <span style={fieldHintStyle}>{asset.storage_key}</span>
                                </div>
                                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                                  <span style={badgeStyle}>{asset.asset_kind}</span>
                                  <span style={badgeStyle}>seq {asset.sequence_no ?? 0}</span>
                                </div>
                                <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                                  {(form.exerciseType === 'uloha_3_story_narration' ||
                                    form.exerciseType === 'psani_2_email') && (
                                    <button
                                      type="button"
                                      onClick={() =>
                                        setForm((current) => ({
                                          ...current,
                                          imageAssetIds: appendLineIfMissing(
                                            current.imageAssetIds,
                                            asset.id,
                                          ),
                                        }))
                                      }
                                      style={secondaryActionStyle}
                                    >
                                      Insert into image list
                                    </button>
                                  )}
                                  <button
                                    type="button"
                                    onClick={() => void handleCopyAssetId(asset.id)}
                                    style={secondaryActionStyle}
                                  >
                                    Copy asset id
                                  </button>
                                </div>
                              </article>
                            ))
                          )}
                        </div>
                      </>
                    )}
                  </section>
                )}
              </div>

              {/* Common fields */}
              <div style={{ display: 'grid', gap: 12 }}>
                <p
                  style={{
                    margin: 0,
                    fontSize: 11,
                    fontWeight: 700,
                    letterSpacing: 0.8,
                    color: 'var(--ink-3)',
                    textTransform: 'uppercase',
                  }}
                >
                  Thông tin chung
                </p>
                <label style={{ display: 'grid', gap: 6 }}>
                  <span style={fieldLabelStyle}>{S.exercise.fieldTitle} *</span>
                  <input
                    value={form.title}
                    onChange={(e) => setForm({ ...form, title: e.target.value })}
                    style={fieldStyle}
                  />
                </label>
                <label style={{ display: 'grid', gap: 6 }}>
                  <span style={fieldLabelStyle}>{S.exercise.fieldShortInstruction}</span>
                  <input
                    value={form.shortInstruction}
                    onChange={(e) => setForm({ ...form, shortInstruction: e.target.value })}
                    style={fieldStyle}
                  />
                </label>
                <label style={{ display: 'grid', gap: 6 }}>
                  <span style={fieldLabelStyle}>{S.exercise.fieldLearnerInstruction}</span>
                  <textarea
                    rows={3}
                    value={form.learnerInstruction}
                    onChange={(e) => setForm({ ...form, learnerInstruction: e.target.value })}
                    style={fieldStyle}
                  />
                </label>
              </div>

              {/* Sample answer */}
              <details style={{ borderRadius: 12, border: '1px solid var(--border)', padding: '0' }}>
                <summary
                  style={{
                    padding: '10px 14px',
                    cursor: 'pointer',
                    fontSize: 13,
                    fontWeight: 600,
                    color: 'var(--ink-2)',
                    userSelect: 'none',
                    listStyle: 'none',
                    display: 'flex',
                    justifyContent: 'space-between',
                  }}
                >
                  <span>
                    📝 Bài mẫu <span style={{ fontWeight: 400, color: 'var(--ink-4)' }}>(tùy chọn)</span>
                  </span>
                  <span style={{ fontSize: 11, color: 'var(--ink-4)' }}>▼</span>
                </summary>
                <div style={{ padding: '0 14px 14px', display: 'grid', gap: 8 }}>
                  <textarea
                    rows={4}
                    value={form.sampleAnswerText}
                    onChange={(e) => setForm({ ...form, sampleAnswerText: e.target.value })}
                    style={fieldStyle}
                    placeholder="Câu trả lời mẫu tiếng Czech. Để trống để AI tự sinh."
                  />
                  <span style={fieldHintStyle}>
                    Override LLM/rule-based model answer trong review artifact của học viên.
                  </span>
                </div>
              </details>

              {/* Publish settings */}
              <details open style={{ borderRadius: 12, border: '1px solid var(--border)' }}>
                <summary
                  style={{
                    padding: '10px 14px',
                    cursor: 'pointer',
                    fontSize: 13,
                    fontWeight: 600,
                    color: 'var(--ink-2)',
                    userSelect: 'none',
                    listStyle: 'none',
                    display: 'flex',
                    justifyContent: 'space-between',
                  }}
                >
                  <span>⚙️ Cài đặt xuất bản</span>
                  <span style={{ fontSize: 11, color: 'var(--ink-4)' }}>▼</span>
                </summary>
                <div style={{ padding: '0 14px 14px', display: 'grid', gap: 12 }}>
                  <label style={{ display: 'grid', gap: 6 }}>
                    <span style={fieldLabelStyle}>{S.exercise.fieldStatus} *</span>
                    <select
                      value={form.status}
                      onChange={(e) => setForm({ ...form, status: e.target.value })}
                      style={fieldStyle}
                    >
                      <option value="draft">Bản nháp (draft)</option>
                      <option value="published">Xuất bản (published)</option>
                      <option value="archived">Lưu trữ (archived)</option>
                    </select>
                    <span style={fieldHintStyle}>Chỉ published mới hiện trên Flutter app.</span>
                  </label>
                  <label style={{ display: 'grid', gap: 6 }}>
                    <span style={fieldLabelStyle}>{S.exercise.fieldPool}</span>
                    <select
                      value={form.pool}
                      onChange={(e) => setForm({ ...form, pool: e.target.value })}
                      style={fieldStyle}
                    >
                      <option value="course">Bài luyện khóa học (course)</option>
                      <option value="exam">Bài thi mock exam (exam)</option>
                    </select>
                  </label>
                  {form.pool === 'course' && (
                    <>
                      <label style={{ display: 'grid', gap: 6 }}>
                        <span style={fieldLabelStyle}>{S.exercise.fieldModule}</span>
                        <select
                          value={form.moduleId}
                          onChange={(e) => handleModuleChange(e.target.value)}
                          style={fieldStyle}
                        >
                          <option value="">{S.pick.module}</option>
                          {modules.map((m) => (
                            <option key={m.id} value={m.id}>{m.title}</option>
                          ))}
                        </select>
                      </label>
                      <label style={{ display: 'grid', gap: 6 }}>
                        <span style={fieldLabelStyle}>Skill Kind</span>
                        <select
                          value={form.skillKind}
                          onChange={(e) => setForm((f) => ({ ...f, skillKind: e.target.value }))}
                          style={fieldStyle}
                        >
                          <option value="">Auto (derived from exercise type)</option>
                          {['noi', 'nghe', 'doc', 'viet', 'tu_vung', 'ngu_phap'].map((k) => (
                            <option key={k} value={k}>{k}</option>
                          ))}
                        </select>
                        <span style={fieldHintStyle}>
                          Để trống → backend tự derive từ exercise type.
                        </span>
                      </label>
                    </>
                  )}
                </div>
              </details>

              {/* Validation errors */}
              {validationErrors.length > 0 && (
                <div
                  style={{
                    background: 'var(--error-bg)',
                    borderRadius: 10,
                    padding: '10px 14px',
                    display: 'grid',
                    gap: 4,
                  }}
                >
                  {validationErrors.map((e, i) => (
                    <span key={i} style={{ fontSize: 13, color: 'var(--error)' }}>• {e}</span>
                  ))}
                </div>
              )}

              {/* Error */}
              {error && (
                <p style={{ margin: 0, color: 'var(--error)', fontSize: 13 }}>{error}</p>
              )}

              {/* Submit */}
              <button
                type="submit"
                disabled={saving || validationErrors.length > 0}
                style={{
                  width: '100%',
                  border: 0,
                  borderRadius: 14,
                  background:
                    saving || validationErrors.length > 0
                      ? 'rgba(240, 90, 40, 0.35)'
                      : 'var(--brand)',
                  color: '#fff',
                  padding: '14px 18px',
                  cursor: saving || validationErrors.length > 0 ? 'not-allowed' : 'pointer',
                  fontWeight: 700,
                  fontSize: 15,
                  letterSpacing: 0.2,
                  boxShadow:
                    saving || validationErrors.length > 0
                      ? 'none'
                      : '0 4px 16px rgba(255,106,20,0.25)',
                  transition: 'box-shadow 150ms, opacity 150ms',
                }}
              >
                {saving
                  ? S.action.saving
                  : editingId
                    ? S.exercise.updateCta
                    : S.exercise.createCta}
              </button>

              {editingId ? (
                <>
                  <button
                    type="button"
                    onClick={doClose}
                    style={{
                      background: 'none',
                      border: 'none',
                      color: 'var(--ink-3)',
                      cursor: 'pointer',
                      fontSize: 13,
                      padding: '4px 0',
                      textAlign: 'center',
                      textDecoration: 'underline',
                      textDecorationColor: 'var(--border)',
                    }}
                  >
                    {S.exercise.cancelEditing}
                  </button>
                  <button
                    type="button"
                    onClick={handleDelete}
                    style={{
                      background: 'none',
                      border: 'none',
                      color: 'var(--error)',
                      cursor: 'pointer',
                      fontSize: 13,
                      padding: '4px 0',
                      textAlign: 'center',
                    }}
                  >
                    {S.action.delete} exercise
                  </button>
                </>
              ) : (
                <button
                  type="button"
                  onClick={() => setWizardStep('type')}
                  style={{
                    background: 'none',
                    border: 'none',
                    color: 'var(--text-secondary)',
                    cursor: 'pointer',
                    fontSize: 13,
                    padding: 0,
                    textAlign: 'left',
                  }}
                >
                  ← Quay lại chọn dạng bài
                </button>
              )}
            </form>
          )}
        </div>
      </aside>

      {/* Confirm close dialog */}
      {showConfirmClose && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            zIndex: 200,
            background: 'rgba(20,18,14,0.65)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <div
            style={{
              background: 'var(--surface)',
              borderRadius: 16,
              padding: 28,
              maxWidth: 380,
              width: '90%',
              display: 'grid',
              gap: 16,
              boxShadow: '0 16px 48px rgba(20,18,14,0.25)',
            }}
          >
            <h3 style={{ margin: 0, fontSize: 17, fontWeight: 700 }}>Đóng mà không lưu?</h3>
            <p style={{ margin: 0, fontSize: 14, color: 'var(--ink-3)', lineHeight: 1.5 }}>
              Bạn có thay đổi chưa lưu. Đóng sẽ mất các thay đổi này.
            </p>
            <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
              <button
                onClick={() => setShowConfirmClose(false)}
                style={{
                  background: 'none',
                  border: '1px solid var(--border)',
                  borderRadius: 8,
                  padding: '8px 16px',
                  cursor: 'pointer',
                  fontSize: 14,
                }}
              >
                Tiếp tục chỉnh sửa
              </button>
              <button
                onClick={doClose}
                style={{
                  background: 'var(--error)',
                  color: '#fff',
                  border: 'none',
                  borderRadius: 8,
                  padding: '8px 16px',
                  cursor: 'pointer',
                  fontSize: 14,
                  fontWeight: 600,
                }}
              >
                Đóng không lưu
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
