// CMS Exercise Editor — the workhorse screen

function ExerciseEditor({ go, exerciseId }) {
  const [tab, setTab] = React.useState('prompt');
  const [scoring, setScoring] = React.useState({ pron: 30, fluency: 25, grammar: 20, content: 25 });
  const total = scoring.pron + scoring.fluency + scoring.grammar + scoring.content;

  return (
    <div>
      {/* Header */}
      <div style={{ padding: '20px 24px 16px', display: 'flex', alignItems: 'flex-start', gap: 16, borderBottom: '1px solid ' + C.border, background: C.bg, position: 'sticky', top: 56, zIndex: 9 }}>
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
            <Tag tone="brand" size="sm">Úloha 4</Tag>
            <Tag tone="needs" size="sm">Speaking · A2</Tag>
            <Tag tone="almost" size="sm">Đang viết</Tag>
            <span style={{ fontSize: 11.5, color: C.ink3 }}>Lan đang chỉnh · auto-save 12s trước</span>
          </div>
          <input defaultValue="Khiếu nại tiền nhà với chủ nhà người Séc" style={{ width: '100%', maxWidth: 720, fontFamily: C.display, fontSize: 26, fontWeight: 600, letterSpacing: -0.5, background: 'transparent', border: 'none', outline: 'none', padding: 0, color: C.ink, fontVariationSettings: '"opsz" 144, "SOFT" 50' }} />
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <Btn variant="text" icon="copy" size="md">Nhân bản</Btn>
          <Btn variant="ghost" icon="eye" size="md">Xem trên app</Btn>
          <Btn variant="inverse" icon="save" size="md">Lưu nháp</Btn>
          <Btn variant="primary" size="md">Publish</Btn>
        </div>
      </div>

      {/* Tabs */}
      <div style={{ padding: '0 24px', borderBottom: '1px solid ' + C.border, display: 'flex', gap: 22, background: C.bg, position: 'sticky', top: 137, zIndex: 8 }}>
        {[
          { id: 'prompt', label: 'Đề bài & ngữ cảnh' },
          { id: 'sample', label: 'Bài mẫu' },
          { id: 'rubric', label: 'Rúbric chấm', count: 4 },
          { id: 'ai', label: 'AI prompt', tag: <CIcon name="sparkles" size={12} color={C.brand} /> },
          { id: 'meta', label: 'Metadata' },
        ].map(t => (
          <button key={t.id} onClick={() => setTab(t.id)} style={{ padding: '12px 0', background: 'none', border: 'none', borderBottom: tab === t.id ? '2px solid ' + C.brand : '2px solid transparent', color: tab === t.id ? C.ink : C.ink3, fontWeight: tab === t.id ? 600 : 500, fontSize: 13.5, cursor: 'pointer', marginBottom: -1, display: 'inline-flex', alignItems: 'center', gap: 6 }}>
            {t.tag}
            {t.label}
            {t.count !== undefined && <span style={{ fontSize: 10.5, color: C.ink3, fontFamily: C.mono }}>{t.count}</span>}
          </button>
        ))}
      </div>

      <div style={{ padding: '20px 24px 28px', display: 'grid', gridTemplateColumns: '1fr 380px', gap: 20 }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          {tab === 'prompt' && <PromptTab />}
          {tab === 'sample' && <SampleTab />}
          {tab === 'rubric' && <RubricTab scoring={scoring} setScoring={setScoring} total={total} />}
          {tab === 'ai' && <AITab />}
          {tab === 'meta' && <MetaTab />}
        </div>

        {/* Right rail — live preview */}
        <div style={{ position: 'sticky', top: 192, alignSelf: 'flex-start' }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: C.ink3, letterSpacing: 1, textTransform: 'uppercase', marginBottom: 8 }}>Xem trước trên iPhone</div>
          <div style={{ background: C.ink, borderRadius: 32, padding: 12, boxShadow: C.shadowLg }}>
            <div style={{ background: C.bg, borderRadius: 22, overflow: 'hidden', height: 540, display: 'flex', flexDirection: 'column' }}>
              <div style={{ padding: '14px 14px 6px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <CIcon name="x" size={18} color={C.ink2} />
                <div style={{ flex: 1, height: 4, background: 'rgba(20,18,14,0.08)', borderRadius: 999, margin: '0 12px' }}><div style={{ width: '75%', height: '100%', background: C.brand, borderRadius: 999 }} /></div>
                <span style={{ fontFamily: C.mono, fontSize: 11, fontWeight: 700, color: C.ink2 }}>3/4</span>
              </div>
              <div style={{ padding: '14px 18px', flex: 1, overflow: 'auto' }} className="scrollarea">
                <Tag tone="brand" size="sm">ÚLOHA 4 · 90 GIÂY</Tag>
                <div style={{ fontFamily: C.display, fontSize: 22, fontWeight: 600, letterSpacing: -0.4, lineHeight: 1.15, marginTop: 10, marginBottom: 12 }}>Khiếu nại tiền nhà</div>
                <div style={{ fontSize: 13, color: C.ink2, lineHeight: 1.55, marginBottom: 14 }}>Bạn nhận hóa đơn tiền nhà tháng này cao bất thường. Gọi cho chủ nhà người Séc và:</div>
                <div style={{ background: C.surface, borderRadius: 12, padding: 14, border: '1px solid ' + C.border, marginBottom: 12 }}>
                  {['Chào hỏi & tự giới thiệu', 'Nói rõ vấn đề bạn gặp', 'Đề nghị giải pháp', 'Cảm ơn & tạm biệt'].map((b, i) => (
                    <div key={i} style={{ display: 'flex', alignItems: 'flex-start', gap: 8, padding: '5px 0', fontSize: 12.5, color: C.ink }}>
                      <div style={{ width: 18, height: 18, borderRadius: 999, background: C.brandSoft, color: C.brandInk, fontSize: 10, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, marginTop: 1 }}>{i + 1}</div>
                      {b}
                    </div>
                  ))}
                </div>
                <div style={{ fontSize: 11.5, color: C.ink3, fontStyle: 'italic' }}>Mẹo: dùng "Mám problém s..." để mở vấn đề.</div>
              </div>
              <div style={{ padding: 14, borderTop: '1px solid ' + C.border, display: 'flex', justifyContent: 'center' }}>
                <div style={{ width: 64, height: 64, borderRadius: 999, background: C.brand, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 4px 0 ' + C.brandDeep }}>
                  <CIcon name="mic" size={28} color="#fff" />
                </div>
              </div>
            </div>
          </div>
          <div style={{ marginTop: 12, padding: 12, background: C.surface, borderRadius: 10, border: '1px solid ' + C.border, fontSize: 11.5, color: C.ink2, lineHeight: 1.5 }}>
            <strong style={{ color: C.ink }}>Auto-save</strong> · mọi thay đổi tự lưu lên staging. Bấm Publish để đẩy bản này lên app.
          </div>
        </div>
      </div>
    </div>
  );
}

function Field({ label, hint, children, required }) {
  return (
    <div style={{ marginBottom: 16 }}>
      <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 6 }}>
        <label style={{ fontSize: 12, fontWeight: 700, color: C.ink, letterSpacing: 0.2 }}>
          {label} {required && <span style={{ color: C.brand }}>*</span>}
        </label>
        {hint && <span style={{ fontSize: 11, color: C.ink3 }}>{hint}</span>}
      </div>
      {children}
    </div>
  );
}

function PromptTab() {
  return (
    <>
      <Card>
        <div style={{ fontFamily: C.display, fontSize: 17, fontWeight: 600, marginBottom: 14 }}>Đề bài</div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, marginBottom: 4 }}>
          <Field label="Tiêu đề tiếng Việt" required>
            <div className="input-focus" style={{ borderRadius: 9, border: '1px solid ' + C.border, background: C.surface }}>
              <input defaultValue="Khiếu nại tiền nhà" style={{ ...inputStyle, border: 'none', background: 'transparent' }} />
            </div>
          </Field>
          <Field label="Tiêu đề tiếng Séc">
            <div className="input-focus" style={{ borderRadius: 9, border: '1px solid ' + C.border, background: C.surface }}>
              <input defaultValue="Reklamace nájemného" style={{ ...inputStyle, border: 'none', background: 'transparent' }} />
            </div>
          </Field>
        </div>
        <Field label="Ngữ cảnh / câu chuyện" hint="Học viên thấy đoạn này trên đầu màn ghi âm" required>
          <div className="input-focus" style={{ borderRadius: 9, border: '1px solid ' + C.border, background: C.surface }}>
            <textarea defaultValue="Bạn nhận hóa đơn tiền nhà tháng này cao bất thường. Gọi cho chủ nhà người Séc và xử lý vấn đề." rows={3} style={{ ...inputStyle, border: 'none', background: 'transparent' }} />
          </div>
        </Field>
        <Field label="4 ý chính cần nói (bullets)" hint="Tối đa 5 mục, học viên đối chiếu khi nói">
          <div style={{ background: C.surface, border: '1px solid ' + C.border, borderRadius: 9, padding: 6 }}>
            {['Chào hỏi & tự giới thiệu', 'Nói rõ vấn đề bạn gặp', 'Đề nghị giải pháp', 'Cảm ơn & tạm biệt'].map((b, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 8px', borderRadius: 6 }}>
                <CIcon name="drag" size={14} color={C.ink4} />
                <div style={{ width: 20, height: 20, borderRadius: 999, background: C.brandSoft, color: C.brandInk, fontSize: 10.5, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{i + 1}</div>
                <input defaultValue={b} style={{ flex: 1, border: 'none', outline: 'none', background: 'transparent', fontSize: 13, color: C.ink, padding: 4 }} />
                <button style={{ padding: 4, background: 'none', border: 'none', cursor: 'pointer', color: C.ink3 }}><CIcon name="x" size={13} /></button>
              </div>
            ))}
            <button style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '6px 10px', background: 'none', border: 'none', color: C.ink3, fontSize: 12, fontWeight: 500, cursor: 'pointer' }}>
              <CIcon name="plus" size={12} /> Thêm ý
            </button>
          </div>
        </Field>
      </Card>

      <Card>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
          <div>
            <div style={{ fontFamily: C.display, fontSize: 17, fontWeight: 600 }}>Audio prompt (tùy chọn)</div>
            <div style={{ fontSize: 12, color: C.ink3, marginTop: 2 }}>Câu mở đầu bằng giọng người Séc — phát trước khi học viên ghi âm</div>
          </div>
          <Btn variant="ghost" size="sm" icon="upload">Tải lên</Btn>
        </div>
        <div style={{ background: C.bg, borderRadius: 10, padding: 12, display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 36, height: 36, borderRadius: 999, background: C.ink, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}><CIcon name="play" size={14} color="#fff" /></div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 12.5, fontWeight: 600, color: C.ink }}>karlin-pronajem-petr.mp3</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 4 }}>
              <div style={{ flex: 1, height: 3, background: C.borderStrong, borderRadius: 999 }}><div style={{ width: '0%', height: '100%', background: C.brand, borderRadius: 999 }} /></div>
              <span style={{ fontFamily: C.mono, fontSize: 10.5, color: C.ink3 }}>0:00 / 0:08</span>
            </div>
          </div>
          <span style={{ fontSize: 11, color: C.ink3 }}>Petr Novák · CZ-M</span>
        </div>
      </Card>
    </>
  );
}

function SampleTab() {
  return (
    <Card>
      <div style={{ fontFamily: C.display, fontSize: 17, fontWeight: 600, marginBottom: 4 }}>Bài mẫu (sample answer)</div>
      <div style={{ fontSize: 12.5, color: C.ink3, marginBottom: 14 }}>Học viên nghe sau khi nộp bài. Highlight phần "ngữ pháp đáng học".</div>
      <div className="input-focus" style={{ borderRadius: 9, border: '1px solid ' + C.border, background: C.surface, padding: 14 }}>
        <div style={{ fontSize: 13.5, lineHeight: 1.7, color: C.ink, fontFamily: 'Georgia, serif' }}>
          „Dobrý den, tady <mark style={{ background: C.brandSoft, padding: '1px 3px', borderRadius: 3 }}>Phương Nguyenová</mark>, bydlím v Karlíně, Sokolovská 12. <mark style={{ background: C.brandSoft, padding: '1px 3px', borderRadius: 3 }}>Mám problém</mark> s nájmem za listopad. Účet je <mark style={{ background: C.brandSoft, padding: '1px 3px', borderRadius: 3 }}>o tisíc korun vyšší</mark>, než obvykle. Mohli bychom <mark style={{ background: C.brandSoft, padding: '1px 3px', borderRadius: 3 }}>se sejít</mark> a probrat to? Děkuji moc, na shledanou."
        </div>
      </div>
      <div style={{ display: 'flex', gap: 10, marginTop: 14 }}>
        <div style={{ flex: 1, background: C.bg, borderRadius: 10, padding: 12, display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ width: 32, height: 32, borderRadius: 999, background: C.ink, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><CIcon name="play" size={12} color="#fff" /></div>
          <div style={{ flex: 1, fontSize: 12, color: C.ink2 }}>Giọng nữ · 0:42</div>
          <Btn variant="text" size="sm">Re-record</Btn>
        </div>
        <div style={{ flex: 1, background: C.bg, borderRadius: 10, padding: 12, display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ width: 32, height: 32, borderRadius: 999, background: C.ink, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><CIcon name="play" size={12} color="#fff" /></div>
          <div style={{ flex: 1, fontSize: 12, color: C.ink2 }}>Giọng nam · 0:38</div>
          <Btn variant="text" size="sm">Re-record</Btn>
        </div>
      </div>
    </Card>
  );
}

function RubricTab({ scoring, setScoring, total }) {
  const cats = [
    { k: 'pron', l: 'Phát âm', d: 'Âm é, ř, š, č; trọng âm trên âm tiết đầu' },
    { k: 'fluency', l: 'Trôi chảy', d: 'Tốc độ, ngập ngừng, lấp đầy "no...", "uh..."' },
    { k: 'grammar', l: 'Ngữ pháp', d: 'Hoà hợp giống/cách, conjugation, prepositions' },
    { k: 'content', l: 'Nội dung', d: 'Trả lời đủ 4 ý, độ dài, độ rõ ràng' },
  ];
  return (
    <>
      <Card>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 4 }}>
          <div style={{ fontFamily: C.display, fontSize: 17, fontWeight: 600 }}>Trọng số 4 trục chấm</div>
          <Tag tone={total === 100 ? 'ready' : 'not'} size="md">Tổng: {total}{total !== 100 && ' / 100'}</Tag>
        </div>
        <div style={{ fontSize: 12.5, color: C.ink3, marginBottom: 16 }}>AI và reviewer đều dùng các trục này. Tổng phải bằng 100%.</div>
        {cats.map(c => (
          <div key={c.k} style={{ padding: '10px 0', borderTop: '1px solid ' + C.divider }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 6 }}>
              <div>
                <div style={{ fontSize: 13.5, fontWeight: 600 }}>{c.l}</div>
                <div style={{ fontSize: 11.5, color: C.ink3 }}>{c.d}</div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <input type="range" min="0" max="50" value={scoring[c.k]} onChange={e => setScoring({ ...scoring, [c.k]: +e.target.value })} style={{ width: 160, accentColor: C.brand }} />
                <div style={{ width: 50, textAlign: 'right', fontFamily: C.mono, fontSize: 13, fontWeight: 700 }}>{scoring[c.k]}%</div>
              </div>
            </div>
          </div>
        ))}
      </Card>
      <Card>
        <div style={{ fontFamily: C.display, fontSize: 17, fontWeight: 600, marginBottom: 4 }}>Ngưỡng đánh giá</div>
        <div style={{ fontSize: 12.5, color: C.ink3, marginBottom: 14 }}>Quy điểm tổng thành 4 nhãn READY / ALMOST / NEEDS / NOT</div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10 }}>
          {[
            { l: 'NOT READY', t: 'not', from: 0, to: 49 },
            { l: 'NEEDS', t: 'needs', from: 50, to: 69 },
            { l: 'ALMOST', t: 'almost', from: 70, to: 84 },
            { l: 'READY', t: 'ready', from: 85, to: 100 },
          ].map(s => (
            <div key={s.l} style={{ padding: 12, background: C.bg, borderRadius: 10 }}>
              <Tag tone={s.t} size="sm">{s.l}</Tag>
              <div style={{ fontFamily: C.mono, fontSize: 13, fontWeight: 700, marginTop: 8, color: C.ink }}>{s.from}–{s.to}</div>
            </div>
          ))}
        </div>
      </Card>
    </>
  );
}

function AITab() {
  return (
    <>
      <Card style={{ background: C.ink, color: '#fff', border: 'none' }}>
        <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
          <CIcon name="sparkles" size={20} color={C.brand} />
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily: C.display, fontSize: 16, fontWeight: 600, marginBottom: 4 }}>AI rubric prompt — v3</div>
            <div style={{ fontSize: 12.5, color: 'rgba(255,255,255,0.7)', lineHeight: 1.5 }}>Áp dụng cho mọi bài Speaking ở module này. Có thể override riêng.</div>
          </div>
          <Tag tone="brand" size="sm">Đang áp dụng</Tag>
        </div>
      </Card>
      <Card padded={false}>
        <div style={{ padding: '14px 18px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', borderBottom: '1px solid ' + C.divider }}>
          <div style={{ fontSize: 12.5, fontWeight: 600, color: C.ink2, fontFamily: C.mono }}>system_prompt.md</div>
          <Btn size="sm" variant="text" icon="copy">Copy</Btn>
        </div>
        <div style={{ padding: 16, fontFamily: C.mono, fontSize: 12.5, lineHeight: 1.7, color: C.ink, whiteSpace: 'pre-wrap' }}>
{`You are a Czech A2 examiner reviewing a Vietnamese learner.
Score on FOUR axes (weights set in CMS):
  • PRON  — clarity of /é/, /ř/, /š/; first-syllable stress
  • FLUE  — pace, hesitations, filler words
  • GRAM  — gender agreement, case endings, prepositions
  • CONT  — covers all 4 bullets in prompt

OUTPUT JSON:
  { "scores": { "pron": 0-100, ... }, "label": "READY|ALMOST|NEEDS|NOT",
    "highlights": [...], "say_instead": [...] }

Tone: encouraging, Vietnamese L1. Highlight ONE quick win.`}
        </div>
      </Card>
      <Card>
        <div style={{ fontFamily: C.display, fontSize: 16, fontWeight: 600, marginBottom: 12 }}>Test prompt với bản ghi mẫu</div>
        <div style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
          <select style={{ ...inputStyle, flex: 1 }}>
            <option>Mai - "Bydlim v Karlin..." (đã chấm READY)</option>
            <option>Long - "Dobrý den, mám..." (đã chấm NEEDS)</option>
          </select>
          <Btn variant="primary" icon="sparkles">Chạy thử</Btn>
        </div>
        <div style={{ background: C.bg, borderRadius: 10, padding: 14, fontFamily: C.mono, fontSize: 12, color: C.ink2 }}>{`> Đang chờ chạy...`}</div>
      </Card>
    </>
  );
}

function MetaTab() {
  return (
    <Card>
      <div style={{ fontFamily: C.display, fontSize: 17, fontWeight: 600, marginBottom: 14 }}>Metadata</div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
        <Field label="Loại bài"><select style={inputStyle}><option>Speaking · Úloha 4</option></select></Field>
        <Field label="Cấp độ CEFR"><select style={inputStyle}><option>A2</option><option>A2+</option></select></Field>
        <Field label="Thời lượng (giây)"><input type="number" defaultValue="90" style={inputStyle} /></Field>
        <Field label="Khó (1-5)"><input type="number" defaultValue="4" style={inputStyle} /></Field>
        <Field label="Tag chủ đề" hint="Cách nhau bằng dấu phẩy"><input defaultValue="nhà ở, hợp đồng, khiếu nại, công sở" style={inputStyle} /></Field>
        <Field label="Sách giáo khoa tham chiếu"><input defaultValue="Czech Step by Step A2 · Lesson 12" style={inputStyle} /></Field>
      </div>
    </Card>
  );
}

window.ExerciseEditor = ExerciseEditor;
