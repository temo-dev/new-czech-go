// Screens 5-7 + Mock Exam + Mock Result

// ───── Recording orb (animated) ──────────────────────────
function RecordingOrb({ recording, variant = 'A' }) {
  const [t, setT] = React.useState(0);
  React.useEffect(() => {
    if (!recording) return;
    const id = setInterval(() => setT(x => x + 1), 80);
    return () => clearInterval(id);
  }, [recording]);

  if (variant === 'B') {
    // Waveform bars
    const bars = 28;
    return (
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4, height: 110 }}>
        {Array.from({length: bars}).map((_, i) => {
          const phase = (t + i * 2) * 0.3;
          const amp = recording
            ? 8 + Math.abs(Math.sin(phase)) * 50 + Math.abs(Math.sin(phase * 1.7)) * 25
            : 8 + Math.abs(Math.sin(i * 0.5)) * 6;
          return (
            <div key={i} style={{
              width: 4, height: amp, borderRadius: 4,
              background: recording ? T.rec : T.ink4,
              transition: 'height .12s ease, background .3s',
            }} />
          );
        })}
      </div>
    );
  }

  // Variant A — pulsing orb
  const scale = recording ? 1 + Math.sin(t * 0.3) * 0.08 : 1;
  return (
    <div style={{ position: 'relative', width: 220, height: 220, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      {recording && [0, 1, 2].map(i => (
        <div key={i} style={{
          position: 'absolute', width: 220, height: 220, borderRadius: 999,
          background: T.rec, opacity: 0.12 - i * 0.03,
          transform: `scale(${1 + Math.sin((t + i * 8) * 0.15) * 0.15 + i * 0.1})`,
          transition: 'transform .15s linear',
        }} />
      ))}
      <div style={{
        width: 140, height: 140, borderRadius: 999,
        background: recording ? T.rec : T.ink,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: '#fff', boxShadow: T.shadowLg,
        transform: `scale(${scale})`,
        transition: 'transform .12s linear, background .3s',
      }}>
        <Icon name="mic-fill" size={56} color="#fff" />
      </div>
    </div>
  );
}

// ───── Screen 5: Recording / Exercise ────────────────────
function RecordingScreen({ go, exercise, variant = 'A' }) {
  const ex = exercise || MOCK.EXERCISES[0];
  const [recording, setRecording] = React.useState(false);
  const [hasRec, setHasRec] = React.useState(false);
  const [secs, setSecs] = React.useState(0);

  React.useEffect(() => {
    if (!recording) return;
    const id = setInterval(() => setSecs(s => s + 1), 1000);
    return () => clearInterval(id);
  }, [recording]);

  const fmt = s => `${String(Math.floor(s/60)).padStart(2,'0')}:${String(s%60).padStart(2,'0')}`;

  const start = () => { setRecording(true); setHasRec(false); setSecs(0); };
  const stop = () => { setRecording(false); setHasRec(true); };

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: T.bg }}>
      <div style={{ padding: '8px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <NavIconBtn icon="x" onClick={() => go('exercise-list')} />
        <span style={{ fontSize: 12, fontWeight: 600, color: T.ink3 }}>Bài {ex.n}/{MOCK.EXERCISES.length}</span>
        <NavIconBtn icon="sparkles" />
      </div>

      <div style={{ padding: '14px 20px 0' }}>
        <Pill tone="warm" size="sm">{ex.uloha} · {ex.dur}</Pill>
        <div style={{ fontFamily: T.display, fontSize: 22, fontWeight: 600, color: T.ink, letterSpacing: -0.3, lineHeight: 1.2, marginTop: 10 }}>
          {ex.title}
        </div>
      </div>

      <div style={{ margin: '16px 20px 0', padding: 16, background: T.surface, border: '1px solid ' + T.border, borderRadius: T.r3 }}>
        <div style={{ fontSize: 11, fontWeight: 700, color: T.brand, letterSpacing: 0.6, textTransform: 'uppercase', marginBottom: 6 }}>Yêu cầu</div>
        <div style={{ fontSize: 14, color: T.ink, lineHeight: 1.55 }}>
          Hãy tự giới thiệu trong <b>1–2 phút</b>. Nói về:
        </div>
        <ul style={{ margin: '8px 0 0', padding: '0 0 0 18px', fontSize: 13, color: T.ink2, lineHeight: 1.7 }}>
          <li>Tên, tuổi, quốc tịch (jméno, věk, národnost)</li>
          <li>Nơi ở và thời gian sống ở Séc</li>
          <li>Công việc và gia đình</li>
          <li>Sở thích và hoạt động cuối tuần</li>
        </ul>
      </div>

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 24, padding: '0 20px' }}>
        <RecordingOrb recording={recording} variant={variant} />
        <div style={{ textAlign: 'center' }}>
          <div style={{ fontFamily: T.display, fontSize: 38, fontWeight: 600, color: recording ? T.rec : T.ink, letterSpacing: -1, lineHeight: 1, fontVariantNumeric: 'tabular-nums' }}>
            {fmt(secs)}
          </div>
          <div style={{ fontSize: 12, color: T.ink3, marginTop: 6 }}>
            {recording ? 'Đang ghi âm…' : (hasRec ? 'Đã ghi xong' : 'Sẵn sàng ghi âm')}
          </div>
        </div>
      </div>

      <div style={{ padding: '0 20px 36px' }}>
        {!recording && !hasRec && (
          <Button variant="danger" size="lg" full icon="mic-fill" onClick={start}>Bắt đầu ghi âm</Button>
        )}
        {recording && (
          <Button variant="inverse" size="lg" full icon="stop" onClick={stop}>Dừng ghi âm</Button>
        )}
        {!recording && hasRec && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <AudioBar duration={Math.max(secs, 8)} label="Bản ghi của bạn" />
            <div style={{ display: 'flex', gap: 10 }}>
              <Button variant="ghost" size="md" icon="redo" onClick={start} style={{ flex: 1 }}>Ghi lại</Button>
              <Button variant="primary" size="md" iconRight="sparkles" onClick={() => go('analyzing')} style={{ flex: 2 }}>Phân tích</Button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

// ───── Screen 6: Analyzing ───────────────────────────────
function AnalyzingScreen({ go }) {
  const [step, setStep] = React.useState(0);
  const steps = [
    'Đang nhận dạng giọng nói…',
    'Đang đối chiếu với chuẩn A2…',
    'Đang chuẩn bị phản hồi…',
  ];
  React.useEffect(() => {
    const id = setInterval(() => setStep(s => s + 1), 1100);
    const done = setTimeout(() => go('result'), 3300);
    return () => { clearInterval(id); clearTimeout(done); };
  }, []);

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '0 32px', background: T.bg }}>
      {/* orbiting circle */}
      <div style={{ position: 'relative', width: 160, height: 160, marginBottom: 36 }}>
        <svg width="160" height="160" style={{ position: 'absolute', inset: 0, animation: 'spin 2.5s linear infinite' }}>
          <defs>
            <linearGradient id="ag" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stopColor={T.brand} stopOpacity="0"/>
              <stop offset="100%" stopColor={T.brand} stopOpacity="1"/>
            </linearGradient>
          </defs>
          <circle cx="80" cy="80" r="68" fill="none" stroke="rgba(40,32,20,0.06)" strokeWidth="2"/>
          <circle cx="80" cy="80" r="68" fill="none" stroke="url(#ag)" strokeWidth="2.5" strokeDasharray="140 999" strokeLinecap="round"/>
        </svg>
        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <div style={{ width: 76, height: 76, borderRadius: 999, background: T.brandSoft, color: T.brand, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: T.shadowMd }}>
            <Icon name="sparkles" size={32} />
          </div>
        </div>
      </div>

      <div style={{ fontFamily: T.display, fontSize: 22, fontWeight: 600, color: T.ink, letterSpacing: -0.3, marginBottom: 28, textAlign: 'center' }}>
        Đang phân tích bài nói…
      </div>

      <div style={{ width: '100%', maxWidth: 280, display: 'flex', flexDirection: 'column', gap: 12 }}>
        {steps.map((s, i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, opacity: step >= i ? 1 : 0.35, transition: 'opacity .4s' }}>
            <div style={{
              width: 22, height: 22, borderRadius: 999, flexShrink: 0,
              background: step > i ? T.ready : (step === i ? T.brandSoft : 'rgba(40,32,20,0.06)'),
              color: step > i ? '#fff' : T.brand,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              {step > i ? <Icon name="check" size={13} /> : (step === i ? <span style={{ width: 8, height: 8, borderRadius: 999, background: T.brand, animation: 'pulse 1s infinite' }}/> : null)}
            </div>
            <span style={{ fontSize: 13.5, color: T.ink2, fontWeight: step === i ? 600 : 400 }}>{s}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

// ───── Screen 7: Result ──────────────────────────────────
function ResultScreen({ go, variant = 'A' }) {
  const [tab, setTab] = React.useState('feedback'); // feedback | transcript | sample
  const score = 76;
  const level = 'almost';

  return (
    <div style={{ paddingBottom: 110 }}>
      <div style={{ padding: '8px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <NavIconBtn icon="chevron-left" onClick={() => go('exercise-list')} />
        <span style={{ fontSize: 12, fontWeight: 600, color: T.ink3 }}>Kết quả</span>
        <NavIconBtn icon="sparkles" />
      </div>

      {/* Hero */}
      <div style={{ padding: '20px 20px 0', textAlign: 'center' }}>
        <ReadinessBadge level={level} />
        <div style={{ fontFamily: T.display, fontSize: 56, fontWeight: 600, color: T.ink, letterSpacing: -2, lineHeight: 1, marginTop: 16, fontVariantNumeric: 'tabular-nums' }}>
          {score}<span style={{ fontSize: 24, color: T.ink3, fontWeight: 400 }}> / 100</span>
        </div>
        <div style={{ fontSize: 13.5, color: T.ink2, marginTop: 10, lineHeight: 1.5, maxWidth: 320, margin: '10px auto 0' }}>
          Bạn nói khá tự nhiên và đủ ý. Cần chú ý <b>cách 2 (genitiv)</b> với số thứ tự để qua được mức READY.
        </div>
      </div>

      {/* Score breakdown */}
      <div style={{ margin: '22px 16px 0', display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 6 }}>
        {[
          { l: 'Nội dung', n: 22, m: 25 },
          { l: 'Ngữ pháp', n: 16, m: 25 },
          { l: 'Từ vựng', n: 20, m: 25 },
          { l: 'Phát âm', n: 18, m: 25 },
        ].map(s => (
          <div key={s.l} style={{ padding: '10px 8px', background: T.surface, border: '1px solid ' + T.border, borderRadius: T.r2, textAlign: 'center' }}>
            <div style={{ fontFamily: T.display, fontSize: 18, fontWeight: 600, color: T.ink, lineHeight: 1, fontVariantNumeric: 'tabular-nums' }}>{s.n}<span style={{ fontSize: 11, color: T.ink3, fontWeight: 400 }}>/{s.m}</span></div>
            <div style={{ fontSize: 10, color: T.ink2, marginTop: 4, fontWeight: 600 }}>{s.l}</div>
          </div>
        ))}
      </div>

      {/* Audio */}
      <div style={{ padding: '16px 16px 0' }}>
        <AudioBar duration={42} label="Bản ghi của bạn · 42 giây" />
      </div>

      {/* Tabs */}
      <div style={{ padding: '20px 16px 0' }}>
        <div style={{ display: 'flex', gap: 4, padding: 4, background: 'rgba(40,32,20,0.05)', borderRadius: 999 }}>
          {[
            { id: 'feedback', l: 'Phản hồi' },
            { id: 'transcript', l: 'Lời ghi' },
            { id: 'sample', l: 'Bài mẫu' },
          ].map(t => (
            <button key={t.id} onClick={() => setTab(t.id)} style={{
              flex: 1, padding: '8px 0', borderRadius: 999, border: 'none',
              background: tab === t.id ? T.surface : 'transparent',
              color: tab === t.id ? T.ink : T.ink2,
              fontWeight: 600, fontSize: 13, cursor: 'pointer',
              boxShadow: tab === t.id ? T.shadowSm : 'none',
            }}>{t.l}</button>
          ))}
        </div>
      </div>

      <div style={{ padding: '16px 16px 0' }}>
        {tab === 'feedback' && <FeedbackTab />}
        {tab === 'transcript' && <TranscriptTab />}
        {tab === 'sample' && <SampleTab />}
      </div>

      <div style={{ padding: '20px 16px 0', display: 'flex', gap: 10 }}>
        <Button variant="ghost" size="md" icon="redo" onClick={() => go('exercise')} style={{ flex: 1 }}>Luyện lại</Button>
        <Button variant="primary" size="md" iconRight="arrow-right" onClick={() => go('exercise-list')} style={{ flex: 1 }}>Bài tiếp</Button>
      </div>
    </div>
  );
}

function FeedbackTab() {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
      <Card>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
          <div style={{ width: 24, height: 24, borderRadius: 6, background: T.readyBg, color: T.ready, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="check" size={14} />
          </div>
          <div style={{ fontSize: 14, fontWeight: 700, color: T.ink }}>Điểm mạnh</div>
        </div>
        <ul style={{ margin: 0, padding: '0 0 0 6px', listStyle: 'none', display: 'flex', flexDirection: 'column', gap: 8 }}>
          {MOCK.STRENGTHS.map((s, i) => (
            <li key={i} style={{ display: 'flex', gap: 8, fontSize: 13.5, color: T.ink, lineHeight: 1.5 }}>
              <span style={{ color: T.ready, marginTop: 2 }}>•</span>{s}
            </li>
          ))}
        </ul>
      </Card>

      <Card>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
          <div style={{ width: 24, height: 24, borderRadius: 6, background: T.needsBg, color: T.needs, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="pencil" size={13} />
          </div>
          <div style={{ fontSize: 14, fontWeight: 700, color: T.ink }}>Cần cải thiện</div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {MOCK.IMPROVEMENTS.map((s, i) => (
            <div key={i} style={{ display: 'flex', gap: 10 }}>
              <Pill tone="warm" size="sm">{s.tag}</Pill>
              <div style={{ flex: 1, fontSize: 13, color: T.ink, lineHeight: 1.5 }}>{s.text}</div>
            </div>
          ))}
        </div>
      </Card>

      <Card style={{ background: T.brandSoft, border: '1px solid ' + T.brandSoft }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
          <Icon name="sparkles" size={16} style={{ color: T.brand }} />
          <div style={{ fontSize: 12, fontWeight: 700, color: T.brandInk, letterSpacing: 0.5, textTransform: 'uppercase' }}>Lời khuyên cho lần sau</div>
        </div>
        <ul style={{ margin: 0, padding: '0 0 0 16px', display: 'flex', flexDirection: 'column', gap: 6 }}>
          {MOCK.TIPS.map((t, i) => <li key={i} style={{ fontSize: 13.5, color: T.brandInk, lineHeight: 1.5 }}>{t}</li>)}
        </ul>
      </Card>
    </div>
  );
}

function TranscriptTab() {
  return (
    <Card>
      <div style={{ fontSize: 11, fontWeight: 700, color: T.ink3, letterSpacing: 0.6, textTransform: 'uppercase', marginBottom: 10 }}>Văn bản nhận dạng</div>
      <div style={{ fontSize: 15, lineHeight: 1.75, color: T.ink, fontFamily: T.body }}>
        {MOCK.TRANSCRIPT_FIXED.map((seg, i) => {
          if (seg.fix) {
            return (
              <span key={i} style={{ display: 'inline' }}>
                <span style={{ textDecoration: 'line-through', color: T.notReady, textDecorationColor: T.notReady }}>{seg.t}</span>
                <span style={{ background: T.readyBg, color: T.readyInk, padding: '1px 5px', borderRadius: 4, fontWeight: 600, marginLeft: 2 }}>{seg.fix}</span>
              </span>
            );
          }
          return <span key={i} style={{ background: seg.note ? '#FFF6DA' : 'transparent', borderBottom: seg.note ? '1.5px solid ' + T.needs : 'none' }}>{seg.t}</span>;
        })}
      </div>
      <div style={{ marginTop: 14, padding: 10, background: T.bg, borderRadius: T.r2, display: 'flex', gap: 8 }}>
        <Icon name="sparkles" size={14} style={{ color: T.needs, marginTop: 2, flexShrink: 0 }} />
        <div style={{ fontSize: 12, color: T.ink2, lineHeight: 1.5 }}>
          <b style={{ color: T.ink }}>2 chỉnh sửa</b> được áp dụng. Nhấn vào từ được tô để xem giải thích.
        </div>
      </div>
    </Card>
  );
}

function SampleTab() {
  return (
    <Card>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
        <div>
          <div style={{ fontSize: 11, fontWeight: 700, color: T.ink3, letterSpacing: 0.6, textTransform: 'uppercase' }}>Bài mẫu A2</div>
          <div style={{ fontSize: 15, fontWeight: 600, color: T.ink, marginTop: 2 }}>Giới thiệu bản thân</div>
        </div>
        <Pill tone="ready" size="sm">READY</Pill>
      </div>
      <div style={{ fontSize: 14.5, lineHeight: 1.7, color: T.ink, fontStyle: 'italic', padding: '12px 0' }}>
        „Dobrý den, jmenuju se Lan. Je mi třicet pět let, jsem z Vietnamu a v Praze žiju už pět let.
        Pracuju jako účetní v malé firmě v Karlíně. Můj manžel je kuchař a máme jednu dceru — chodí <b style={{ color: T.ready, fontStyle: 'normal' }}>do druhé třídy</b>.
        Ráda vařím a o víkendu jezdíme s rodinou na výlety za město."
      </div>
      <div style={{ marginTop: 6 }}>
        <AudioBar duration={28} label="Phát âm chuẩn · giáo viên Séc" />
      </div>
    </Card>
  );
}

// ───── Screen 8c: Mock Exam ──────────────────────────────
function MockExamScreen({ go, test }) {
  const t = test || MOCK.MOCK_TESTS[0];
  return (
    <div style={{ paddingBottom: 24, height: '100%', display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '8px 20px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <NavIconBtn icon="x" onClick={() => go('mock-intro')} />
        <span style={{ fontSize: 12, fontWeight: 600, color: T.ink2 }}>Mock {String(t.id).padStart(2,'0')} · Phần 3/4</span>
        <span style={{ fontFamily: T.mono, fontSize: 13, fontWeight: 700, color: T.rec }}>06:42</span>
      </div>

      <div style={{ padding: '14px 20px 0' }}>
        {/* Progress dots */}
        <div style={{ display: 'flex', gap: 4, marginBottom: 18 }}>
          {[1,2,3,4].map(i => (
            <div key={i} style={{
              flex: 1, height: 4, borderRadius: 2,
              background: i < 3 ? T.ready : (i === 3 ? T.brand : 'rgba(40,32,20,0.1)'),
            }}/>
          ))}
        </div>

        <div style={{ fontFamily: T.display, fontSize: 22, fontWeight: 600, color: T.ink, letterSpacing: -0.3, lineHeight: 1.2 }}>
          Mock Test 01
        </div>
        <div style={{ fontSize: 13, color: T.ink2, marginTop: 4 }}>Hoàn thành 4 phần liên tiếp.</div>
      </div>

      <div style={{ flex: 1, padding: '20px 16px 0', display: 'flex', flexDirection: 'column', gap: 8 }}>
        {MOCK.MOCK_PARTS.map(p => {
          const done  = p.status === 'done';
          const doing = p.status === 'doing';
          return (
            <div key={p.n} style={{
              padding: 14, background: T.surface,
              border: '1px solid ' + (doing ? T.brand : T.border),
              borderRadius: T.r3,
              boxShadow: doing ? '0 0 0 3px ' + T.brandSoft : 'none',
              display: 'flex', alignItems: 'center', gap: 12,
              opacity: p.status === 'todo' ? 0.55 : 1,
            }}>
              <div style={{
                width: 38, height: 38, borderRadius: 999, flexShrink: 0,
                background: done ? T.readyBg : (doing ? T.brand : T.surfaceAlt),
                color: done ? T.ready : (doing ? '#fff' : T.ink3),
                border: '1px solid ' + (done ? T.readyBg : (doing ? T.brand : T.borderStrong)),
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontFamily: T.display, fontSize: 15, fontWeight: 600,
              }}>
                {done ? <Icon name="check" size={18} /> : p.n}
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ display: 'flex', gap: 6, alignItems: 'center', marginBottom: 2 }}>
                  <span style={{ fontSize: 11, fontWeight: 700, color: T.ink3, letterSpacing: 0.4 }}>{p.uloha.toUpperCase()}</span>
                  {done && <Pill tone="ready" size="sm">ĐÃ GHI · {p.score}/{p.max}</Pill>}
                  {doing && <Pill tone="brand" size="sm"><span style={{ width: 5, height: 5, borderRadius: 999, background: T.brand, animation: 'pulse 1s infinite' }}/> ĐANG GHI</Pill>}
                  {p.status === 'todo' && <Pill tone="neutral" size="sm">CHỜ</Pill>}
                </div>
                <div style={{ fontSize: 14, fontWeight: 600, color: T.ink }}>{p.name}</div>
                <div style={{ fontSize: 11.5, color: T.ink3, marginTop: 1 }}>{p.dur} · tối đa {p.max} điểm</div>
              </div>
              {doing && (
                <div style={{ width: 36, height: 36, borderRadius: 999, background: T.rec, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Icon name="mic-fill" size={16} color="#fff" />
                </div>
              )}
            </div>
          );
        })}
      </div>

      <div style={{ padding: '20px 20px 28px' }}>
        <Button variant="danger" size="lg" full icon="stop" onClick={() => go('analyzing-mock')}>Dừng phần 3 & tiếp tục</Button>
      </div>
    </div>
  );
}

// ───── Screen 8d: Mock Result ────────────────────────────
function MockResultScreen({ go }) {
  const total = 28, max = 40, pass = 24;
  const passed = total >= pass;
  return (
    <div style={{ paddingBottom: 110 }}>
      <div style={{ padding: '8px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <NavIconBtn icon="chevron-left" onClick={() => go('mock-list')} />
        <span style={{ fontSize: 12, fontWeight: 600, color: T.ink3 }}>Mock 01 — Kết quả</span>
        <NavIconBtn icon="sparkles" />
      </div>

      <div style={{ margin: '18px 16px 0', padding: '24px 20px', borderRadius: T.r4,
        background: passed ? '#1F4D38' : '#5C2A22', color: '#fff',
        position: 'relative', overflow: 'hidden',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <span style={{
            display: 'inline-flex', alignItems: 'center', gap: 6,
            padding: '5px 11px', borderRadius: 999,
            background: passed ? '#2D7050' : '#7E3B30',
            fontSize: 11, fontWeight: 700, letterSpacing: 0.8,
          }}>
            <Icon name={passed ? 'check' : 'x'} size={12} />
            {passed ? 'PASS' : 'FAIL'}
          </span>
          <Pill tone="warm" size="sm">Mock 01</Pill>
        </div>
        <div style={{ marginTop: 18, display: 'flex', alignItems: 'baseline', gap: 4 }}>
          <span style={{ fontFamily: T.display, fontSize: 72, fontWeight: 600, letterSpacing: -3, lineHeight: 1, fontVariantNumeric: 'tabular-nums' }}>{total}</span>
          <span style={{ fontFamily: T.display, fontSize: 28, opacity: 0.6, fontWeight: 400 }}>/ {max}</span>
        </div>
        <div style={{ fontSize: 13, opacity: 0.85, marginTop: 4 }}>
          Đạt yêu cầu (≥ {pass}). Bạn đã sẵn sàng cho kỳ thi nếu giữ phong độ này.
        </div>
        {/* Sparkle */}
        <div style={{ position: 'absolute', top: -20, right: -20, width: 140, height: 140, borderRadius: 999, background: 'rgba(255,255,255,0.04)' }} />
      </div>

      <div style={{ padding: '18px 16px 0' }}>
        <SectionTitle eyebrow="Phân tích" title="Theo phần thi" />
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 12 }}>
          {[
            { ...MOCK.MOCK_PARTS[0], score: 7,  level: 'ready'  },
            { ...MOCK.MOCK_PARTS[1], score: 6,  level: 'almost' },
            { ...MOCK.MOCK_PARTS[2], score: 8,  level: 'almost' },
            { ...MOCK.MOCK_PARTS[3], score: 7,  level: 'needs'  },
          ].map(p => {
            const pct = p.score / p.max;
            return (
              <Card key={p.n} onClick={() => go('result')} padded={false}
                style={{ padding: 14, display: 'flex', alignItems: 'center', gap: 12 }}>
                <div style={{ width: 32, height: 32, borderRadius: 999, background: T.surfaceAlt, color: T.ink2, border: '1px solid ' + T.borderStrong, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: T.display, fontSize: 14, fontWeight: 600 }}>{p.n}</div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 13.5, fontWeight: 600, color: T.ink, marginBottom: 4 }}>{p.uloha} · {p.name}</div>
                  <div style={{ height: 4, background: 'rgba(40,32,20,0.06)', borderRadius: 999, overflow: 'hidden' }}>
                    <div style={{ width: `${pct*100}%`, height: '100%', background: pct >= 0.75 ? T.ready : pct >= 0.5 ? T.almost : T.needs, borderRadius: 999 }} />
                  </div>
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4 }}>
                  <span style={{ fontFamily: T.mono, fontSize: 13, fontWeight: 700, color: T.ink }}>{p.score}<span style={{ color: T.ink3, fontWeight: 400 }}>/{p.max}</span></span>
                  <ReadinessBadge level={p.level} size="sm" />
                </div>
              </Card>
            );
          })}
        </div>

        <Card style={{ marginTop: 16, background: T.brandSoft, border: '1px solid ' + T.brandSoft }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
            <Icon name="sparkles" size={16} style={{ color: T.brand }} />
            <div style={{ fontSize: 12, fontWeight: 700, color: T.brandInk, letterSpacing: 0.5, textTransform: 'uppercase' }}>Nhận xét tổng</div>
          </div>
          <div style={{ fontSize: 13.5, color: T.brandInk, lineHeight: 1.6 }}>
            Phần 1 và 3 ổn định ở mức READY. Phần 2 (mô tả ảnh) và Phần 4 (tình huống) cần luyện thêm về <b>cách 2/4</b> và <b>liên từ</b> để nâng độ trôi chảy.
          </div>
        </Card>

        <div style={{ display: 'flex', gap: 10, marginTop: 18 }}>
          <Button variant="ghost" size="md" icon="redo" onClick={() => go('mock-intro')} style={{ flex: 1 }}>Thi lại</Button>
          <Button variant="primary" size="md" iconRight="arrow-right" onClick={() => go('mock-list')} style={{ flex: 1 }}>Đề khác</Button>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, {
  RecordingScreen, AnalyzingScreen, ResultScreen,
  MockExamScreen, MockResultScreen, RecordingOrb,
  FeedbackTab, TranscriptTab, SampleTab,
});
