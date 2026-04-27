// Screens 1-4 + History + Mock list/intro

// ───── Screen 1: Course List ─────────────────────────────
function CourseListScreen({ go }) {
  return (
    <div style={{ paddingBottom: 110 }}>
      <AppNav
        title="Chào, Lan 👋"
        subtitle="Tiếp tục lộ trình A2 — bạn đang đi đúng hướng."
        rightAction={<NavIconBtn icon="sparkles" />}
      />

      {/* Streak strip */}
      <div style={{ margin: '0 16px 14px', padding: '12px 14px', borderRadius: T.r3, background: T.surface, border: '1px solid ' + T.border, display: 'flex', alignItems: 'center', gap: 12 }}>
        <div style={{ width: 38, height: 38, borderRadius: 999, background: '#FFE5D2', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20 }}>🔥</div>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 13.5, fontWeight: 700, color: T.ink }}>Liên tiếp 4 ngày</div>
          <div style={{ fontSize: 11.5, color: T.ink3 }}>Học hôm nay để giữ chuỗi.</div>
        </div>
        <span style={{ fontFamily: T.display, fontSize: 22, fontWeight: 600, color: T.brand, fontVariationSettings: '"opsz" 144' }}>12′</span>
      </div>

      <div style={{ padding: '4px 16px 0', display: 'flex', flexDirection: 'column', gap: 14 }}>
        {MOCK.COURSES.map(c => (
          <div key={c.id} onClick={() => !c.locked && go('module-list', { course: c })}
            style={{
              background: T.surface, borderRadius: T.r4,
              border: '1px solid ' + T.border,
              cursor: c.locked ? 'default' : 'pointer',
              position: 'relative', overflow: 'hidden',
              boxShadow: T.shadowSm,
            }}>
            {/* Hero illustrated band */}
            <div style={{ height: 110, background: c.illoBg, position: 'relative', overflow: 'hidden' }}>
              {/* Cut-out shapes for Babbel-style decoration */}
              <div style={{ position: 'absolute', top: -30, right: -20, width: 120, height: 120, borderRadius: 999, background: 'rgba(255,255,255,0.18)' }} />
              <div style={{ position: 'absolute', bottom: -40, right: 50, width: 80, height: 80, borderRadius: 999, background: 'rgba(255,255,255,0.12)' }} />
              <div style={{ position: 'absolute', top: 14, left: 18 }}>
                <Pill tone={c.locked ? 'neutral' : (c.progress > 0 ? 'brand' : 'warm')} size="sm">
                  {c.locked && <Icon name="lock" size={11} />}
                  {c.badge}
                </Pill>
              </div>
              <div style={{ position: 'absolute', bottom: 14, right: 18, fontSize: 56, lineHeight: 1, transform: 'rotate(-8deg)' }}>{c.emoji}</div>
            </div>

            <div style={{ padding: '16px 18px 18px' }}>
              <div style={{ fontSize: 11, color: c.accent, fontWeight: 700, letterSpacing: 0.6, textTransform: 'uppercase', marginBottom: 4 }}>{c.sub}</div>
              <div style={{ fontFamily: T.display, fontSize: 24, fontWeight: 600, color: T.ink, letterSpacing: -0.5, lineHeight: 1.1, marginBottom: 8, fontVariationSettings: '"opsz" 144, "SOFT" 50' }}>
                {c.title}
              </div>
              <div style={{ fontSize: 13.5, color: T.ink2, lineHeight: 1.5, marginBottom: 14 }}>{c.desc}</div>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <div style={{ display: 'flex', gap: 14, fontSize: 12, color: T.ink2 }}>
                  <span><b style={{ color: T.ink, fontWeight: 700 }}>{c.weeks}</b> tuần</span>
                  <span><b style={{ color: T.ink, fontWeight: 700 }}>{c.modules}</b> module</span>
                </div>
                {c.progress > 0 && !c.locked && (
                  <span style={{ fontSize: 12, color: c.accent, fontWeight: 700 }}>{Math.round(c.progress*100)}%</span>
                )}
              </div>
              {c.progress > 0 && !c.locked && (
                <div style={{ marginTop: 10, height: 6, background: 'rgba(40,32,20,0.06)', borderRadius: 999, overflow: 'hidden' }}>
                  <div style={{ width: `${c.progress*100}%`, height: '100%', background: c.accent, borderRadius: 999 }} />
                </div>
              )}
            </div>
          </div>
        ))}

        <Card style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 4, background: T.surfaceAlt }}>
          <div style={{ width: 40, height: 40, borderRadius: 12, background: T.brandSoft, display: 'flex', alignItems: 'center', justifyContent: 'center', color: T.brand }}>
            <Icon name="trophy" size={20} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 14, fontWeight: 600, color: T.ink }}>Đề thi mô phỏng</div>
            <div style={{ fontSize: 12, color: T.ink2 }}>3 đề chuẩn NPI · luyện trước ngày thi</div>
          </div>
          <Button variant="ghost" size="sm" onClick={() => go('mock-list')} iconRight="chevron-right">Xem</Button>
        </Card>
      </div>
    </div>
  );
}

// ───── Screen 2: Course Detail / Module List ─────────────
function ModuleListScreen({ go, course }) {
  const c = course || MOCK.COURSES[0];
  return (
    <div style={{ paddingBottom: 110 }}>
      <AppNav
        title={c.title}
        subtitle={c.desc}
        leftAction={<NavIconBtn icon="chevron-left" onClick={() => go('course-list')} />}
        rightAction={<NavIconBtn icon="sparkles" />}
      />

      {/* progress strip */}
      <div style={{ margin: '4px 20px 18px', padding: 14, background: T.surface, borderRadius: T.r3, border: '1px solid ' + T.border, display: 'flex', alignItems: 'center', gap: 14 }}>
        <div style={{ width: 46, height: 46, borderRadius: 999, background: c.accentBg, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative' }}>
          <svg width="46" height="46" style={{ position: 'absolute', inset: 0, transform: 'rotate(-90deg)' }}>
            <circle cx="23" cy="23" r="20" fill="none" stroke={c.accent} strokeWidth="3" strokeOpacity="0.15" />
            <circle cx="23" cy="23" r="20" fill="none" stroke={c.accent} strokeWidth="3" strokeDasharray={`${2*Math.PI*20*c.progress} 999`} strokeLinecap="round" />
          </svg>
          <span style={{ fontSize: 12, fontWeight: 700, color: c.accent }}>{Math.round(c.progress*100)}%</span>
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 13, color: T.ink2 }}>Module 3/8 · Tuần này</div>
          <div style={{ fontSize: 14.5, fontWeight: 600, color: T.ink, marginTop: 2 }}>Còn 22 bài để hoàn thành tuần.</div>
        </div>
      </div>

      <div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 0, position: 'relative' }}>
        <div style={{ position: 'absolute', left: 36, top: 24, bottom: 24, width: 2, background: T.divider }} />
        {MOCK.MODULES.map((m, i) => {
          const locked = m.status === 'locked';
          const done   = m.status === 'done';
          const active = m.status === 'active';
          return (
            <div key={m.n} onClick={() => active && go('module-detail', { module: m, course: c })}
              style={{
                display: 'flex', gap: 14, padding: '12px 4px',
                cursor: active ? 'pointer' : 'default',
                opacity: locked ? 0.55 : 1,
              }}>
              <div style={{
                width: 40, height: 40, borderRadius: 999, flexShrink: 0,
                background: done ? c.accentBg : (active ? c.accent : T.surface),
                color: done ? c.accent : (active ? '#fff' : T.ink3),
                border: '1px solid ' + (active ? c.accent : T.borderStrong),
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontFamily: T.display, fontSize: 16, fontWeight: 600,
                position: 'relative', zIndex: 1,
                boxShadow: active ? T.shadowMd : 'none',
              }}>
                {done ? <Icon name="check" size={18} /> : (locked ? <Icon name="lock" size={14} /> : m.n)}
              </div>
              <div style={{ flex: 1, paddingTop: 2, paddingBottom: 4 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 3 }}>
                  <span style={{ fontSize: 11, fontWeight: 700, color: T.ink3, letterSpacing: 0.6, textTransform: 'uppercase' }}>Tuần {m.n}</span>
                  {active && <Pill tone="brand" size="sm">Đang học</Pill>}
                  {done && <Pill tone="ready" size="sm"><Icon name="check" size={10}/> Hoàn thành</Pill>}
                </div>
                <div style={{ fontSize: 16, fontWeight: 600, color: T.ink, marginBottom: 4 }}>{m.title}</div>
                <div style={{ fontSize: 13, color: T.ink2, lineHeight: 1.4 }}>{m.desc}</div>
                <div style={{ fontSize: 12, color: T.ink3, marginTop: 6 }}>{m.skills} kỹ năng</div>
              </div>
              {active && <Icon name="chevron-right" size={18} style={{ color: T.ink3, alignSelf: 'center' }} />}
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ───── Screen 3: Module Detail / Skill Cards ─────────────
function ModuleDetailScreen({ go, module, course }) {
  const m = module || MOCK.MODULES[2];
  const c = course || MOCK.COURSES[0];
  return (
    <div style={{ paddingBottom: 110 }}>
      <div style={{ padding: '8px 20px 18px', background: c.accentBg }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', minHeight: 32 }}>
          <NavIconBtn icon="chevron-left" onClick={() => go('module-list', { course: c })} />
          <span style={{ fontSize: 12, fontWeight: 700, color: c.accent, letterSpacing: 0.6 }}>TUẦN {m.n} · {m.skills} KỸ NĂNG</span>
          <div style={{ width: 34 }} />
        </div>
        <div style={{ fontFamily: T.display, fontSize: 28, fontWeight: 600, color: T.ink, letterSpacing: -0.5, lineHeight: 1.1, marginTop: 16 }}>
          {m.title}
        </div>
        <div style={{ fontSize: 13.5, color: T.ink2, marginTop: 6, marginBottom: 4 }}>{m.desc}</div>
      </div>

      <div style={{ padding: '18px 16px 0' }}>
        <SectionTitle eyebrow="Kỹ năng" title="Chọn để bắt đầu" />
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginTop: 14 }}>
          {MOCK.SKILLS.map(sk => (
            <div key={sk.id} onClick={() => sk.active && go('exercise-list', { skill: sk })}
              style={{
                background: T.surface, border: '1px solid ' + T.border, borderRadius: T.r3,
                padding: 14, cursor: sk.active ? 'pointer' : 'default',
                opacity: sk.active ? 1 : 0.65, position: 'relative',
                boxShadow: sk.active ? T.shadowSm : 'none',
                minHeight: 140,
                display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
              }}>
              <div>
                <div style={{
                  width: 40, height: 40, borderRadius: 12,
                  background: sk.soft, color: sk.accent,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  marginBottom: 10,
                }}>
                  <Icon name={sk.icon} size={22} />
                </div>
                <div style={{ fontSize: 15, fontWeight: 600, color: T.ink }}>{sk.name}</div>
                <div style={{ fontSize: 11.5, color: T.ink3, fontStyle: 'italic', marginTop: 2 }}>{sk.cz}</div>
              </div>
              <div style={{ marginTop: 10 }}>
                {sk.active ? (
                  <span style={{ fontSize: 11.5, color: sk.accent, fontWeight: 600 }}>{sk.count} bài luyện →</span>
                ) : (
                  <Pill tone="neutral" size="sm"><Icon name="lock" size={10} /> Sắp ra mắt</Pill>
                )}
              </div>
            </div>
          ))}
        </div>

        <div style={{ marginTop: 22, padding: 14, background: T.surface, border: '1px dashed ' + T.borderStrong, borderRadius: T.r3, display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 38, height: 38, borderRadius: 999, background: T.brandSoft, color: T.brand, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="trophy" size={18} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 13.5, fontWeight: 600, color: T.ink }}>Mock Test cho tuần này</div>
            <div style={{ fontSize: 11.5, color: T.ink3 }}>Hoàn thành 4 kỹ năng để mở khóa</div>
          </div>
          <Icon name="lock" size={16} style={{ color: T.ink3 }} />
        </div>
      </div>
    </div>
  );
}

// ───── Screen 4: Exercise List ───────────────────────────
function ExerciseListScreen({ go, skill }) {
  const sk = skill || MOCK.SKILLS[0];
  return (
    <div style={{ paddingBottom: 110 }}>
      <AppNav
        title={`Luyện ${sk.name}`}
        subtitle={`${sk.cz} · ${MOCK.EXERCISES.length} bài luyện`}
        leftAction={<NavIconBtn icon="chevron-left" onClick={() => go('module-detail')} />}
        rightAction={<NavIconBtn icon="sparkles" />}
      />

      <div style={{ padding: '0 16px', display: 'flex', gap: 8, marginBottom: 14, overflowX: 'auto' }}>
        {['Tất cả', 'Úloha 1', 'Úloha 2', 'Úloha 3', 'Úloha 4'].map((f, i) => (
          <button key={f} style={{
            padding: '7px 13px', borderRadius: 999, border: '1px solid ' + (i===0 ? T.ink : T.borderStrong),
            background: i===0 ? T.ink : 'transparent', color: i===0 ? '#fff' : T.ink2,
            fontSize: 12.5, fontWeight: 600, cursor: 'pointer', whiteSpace: 'nowrap',
          }}>{f}</button>
        ))}
      </div>

      <div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        {MOCK.EXERCISES.map(ex => (
          <Card key={ex.n} onClick={() => go('exercise', { exercise: ex })} padded={false}
            style={{ padding: '14px 14px 14px 14px', display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{
              width: 38, height: 38, borderRadius: 10, flexShrink: 0,
              background: ex.done ? T.brandSoft : 'rgba(40,32,20,0.04)',
              color: ex.done ? T.brand : T.ink2,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontFamily: T.display, fontSize: 16, fontWeight: 600,
            }}>
              {ex.done ? <Icon name="check" size={18} /> : ex.n}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: 'flex', gap: 6, alignItems: 'center', marginBottom: 3 }}>
                <Pill tone="warm" size="sm">{ex.uloha}</Pill>
                <span style={{ fontSize: 11, color: T.ink3 }}>· {ex.dur}</span>
              </div>
              <div style={{ fontSize: 14.5, fontWeight: 600, color: T.ink, marginBottom: 2 }}>{ex.title}</div>
              <div style={{ fontSize: 12, color: T.ink2, lineHeight: 1.4, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{ex.desc}</div>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 6 }}>
              {ex.level && <ReadinessBadge level={ex.level} size="sm" />}
              <Icon name="chevron-right" size={16} style={{ color: T.ink3 }} />
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}

// ───── Screen 9: History ─────────────────────────────────
function HistoryScreen({ go }) {
  return (
    <div style={{ paddingBottom: 110 }}>
      <AppNav title="Lịch sử" subtitle="6 lần luyện gần đây · Liên tiếp 4 ngày 🔥" />

      <div style={{ padding: '0 16px 16px' }}>
        <div style={{ display: 'flex', gap: 10, marginBottom: 16 }}>
          {[
            { n: '14', l: 'Bài tuần này', c: T.brand },
            { n: '4', l: 'Ngày liên tiếp', c: '#7A5A2E' },
            { n: '72%', l: 'Đạt READY', c: T.ready },
          ].map(s => (
            <div key={s.l} style={{ flex: 1, padding: 12, background: T.surface, border: '1px solid ' + T.border, borderRadius: T.r3 }}>
              <div style={{ fontFamily: T.display, fontSize: 22, fontWeight: 600, color: s.c, lineHeight: 1 }}>{s.n}</div>
              <div style={{ fontSize: 11, color: T.ink2, marginTop: 5, lineHeight: 1.3 }}>{s.l}</div>
            </div>
          ))}
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {MOCK.HISTORY.map(h => (
            <Card key={h.id} padded={false} onClick={() => go('result')}
              style={{ padding: 14, display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{ width: 36, height: 36, borderRadius: 10, background: h.uloha === 'Mock' ? T.brandSoft : 'rgba(40,32,20,0.04)', color: h.uloha === 'Mock' ? T.brand : T.ink2, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Icon name={h.uloha === 'Mock' ? 'trophy' : 'mic'} size={16} />
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 2 }}>
                  <Pill tone={h.uloha === 'Mock' ? 'brand' : 'warm'} size="sm">{h.uloha}</Pill>
                  {h.score && <span style={{ fontFamily: T.mono, fontSize: 11, color: T.ink2, fontWeight: 700 }}>{h.score}</span>}
                </div>
                <div style={{ fontSize: 14, fontWeight: 600, color: T.ink, lineHeight: 1.2 }}>{h.title}</div>
                <div style={{ fontSize: 11.5, color: T.ink3, marginTop: 2 }}>{h.when}</div>
              </div>
              <ReadinessBadge level={h.level} size="sm" />
            </Card>
          ))}
        </div>
      </div>
    </div>
  );
}

// ───── Screen 8a: Mock Test List ─────────────────────────
function MockListScreen({ go }) {
  return (
    <div style={{ paddingBottom: 110 }}>
      <AppNav
        title="Mock Test"
        subtitle="Đề thi mô phỏng theo chuẩn NPI ČR. Luyện thi như thật."
        leftAction={<NavIconBtn icon="chevron-left" onClick={() => go('course-list')} />}
      />

      <div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {MOCK.MOCK_TESTS.map(t => (
          <Card key={t.id} onClick={() => go('mock-intro', { test: t })} padded={false}
            style={{ padding: 16 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
              <div style={{ display: 'flex', gap: 6 }}>
                <Pill tone="brand" size="sm"><Icon name="trophy" size={11} /> Mock {String(t.id).padStart(2,'0')}</Pill>
                {t.tag && <Pill tone="warm" size="sm">{t.tag}</Pill>}
              </div>
              <Icon name="chevron-right" size={16} style={{ color: T.ink3 }} />
            </div>
            <div style={{ fontFamily: T.display, fontSize: 18, fontWeight: 600, color: T.ink, lineHeight: 1.2, marginBottom: 12 }}>
              {t.title}
            </div>
            <div style={{ display: 'flex', gap: 16, fontSize: 12, color: T.ink2 }}>
              <span><Icon name="clock" size={12}/> {t.dur} phút</span>
              <span><Icon name="cards" size={12}/> {t.parts} phần</span>
              <span><Icon name="flag" size={12}/> Đạt {t.pass}/{t.max}</span>
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}

// ───── Screen 8b: Mock Test Intro ────────────────────────
function MockIntroScreen({ go, test }) {
  const t = test || MOCK.MOCK_TESTS[0];
  return (
    <div style={{ paddingBottom: 24, height: '100%', display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '8px 20px 0' }}>
        <NavIconBtn icon="chevron-left" onClick={() => go('mock-list')} />
      </div>

      <div style={{ flex: 1, padding: '20px 20px 0', display: 'flex', flexDirection: 'column' }}>
        <Pill tone="brand"><Icon name="trophy" size={11}/> MOCK TEST {String(t.id).padStart(2,'0')}</Pill>
        <div style={{ fontFamily: T.display, fontSize: 28, fontWeight: 600, color: T.ink, letterSpacing: -0.5, lineHeight: 1.15, marginTop: 14 }}>
          {t.title}
        </div>
        <div style={{ fontSize: 14, color: T.ink2, marginTop: 8, lineHeight: 1.5 }}>
          Đề thi mô phỏng đầy đủ 4 phần như kỳ thi thật. Bạn cần ghi âm liên tục, không tạm dừng giữa chừng.
        </div>

        <div style={{ display: 'flex', gap: 8, marginTop: 22 }}>
          {[
            { n: t.dur, l: 'phút', c: T.brand },
            { n: t.max, l: 'điểm tối đa', c: T.ink },
            { n: t.pass, l: 'điểm đạt', c: T.ready },
          ].map(s => (
            <div key={s.l} style={{ flex: 1, padding: '14px 12px', background: T.surface, border: '1px solid ' + T.border, borderRadius: T.r3, textAlign: 'center' }}>
              <div style={{ fontFamily: T.display, fontSize: 26, fontWeight: 600, color: s.c, lineHeight: 1 }}>{s.n}</div>
              <div style={{ fontSize: 11, color: T.ink2, marginTop: 4 }}>{s.l}</div>
            </div>
          ))}
        </div>

        <div style={{ marginTop: 22, marginBottom: 8, fontSize: 11, fontWeight: 700, color: T.ink3, letterSpacing: 0.8 }}>4 PHẦN THI</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          {MOCK.MOCK_PARTS.map(p => (
            <div key={p.n} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 12px', background: T.surface, border: '1px solid ' + T.border, borderRadius: T.r2 }}>
              <div style={{ width: 28, height: 28, borderRadius: 999, background: T.brandSoft, color: T.brand, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: T.display, fontSize: 14, fontWeight: 600 }}>{p.n}</div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 13.5, fontWeight: 600, color: T.ink }}>{p.uloha} · {p.name}</div>
                <div style={{ fontSize: 11.5, color: T.ink3 }}>{p.dur}</div>
              </div>
              <span style={{ fontFamily: T.mono, fontSize: 12, fontWeight: 700, color: T.ink2 }}>{p.max} đ</span>
            </div>
          ))}
        </div>
      </div>

      <div style={{ padding: '18px 20px 28px' }}>
        <Button variant="inverse" size="lg" full icon="mic-fill" onClick={() => go('mock-exam', { test: t })}>
          Bắt đầu thi
        </Button>
        <div style={{ fontSize: 11, color: T.ink3, textAlign: 'center', marginTop: 10 }}>
          Hãy đeo tai nghe và ngồi ở nơi yên tĩnh.
        </div>
      </div>
    </div>
  );
}

Object.assign(window, {
  CourseListScreen, ModuleListScreen, ModuleDetailScreen, ExerciseListScreen,
  HistoryScreen, MockListScreen, MockIntroScreen,
});
