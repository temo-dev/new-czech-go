// Main app — router + Tweaks + Design Canvas

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "recordingVariant": "B",
  "resultVariant": "A",
  "frame": "iOS"
}/*EDITMODE-END*/;

// Single phone — used inside artboards
function Phone({ initial = 'course-list', startState = {} }) {
  const [tweaks] = window.useTweaks ? window.useTweaks(TWEAK_DEFAULTS) : [TWEAK_DEFAULTS, () => {}];
  const [screen, setScreen] = React.useState(initial);
  const [state, setState] = React.useState(startState);
  const [tab, setTab] = React.useState('home');

  const go = (s, st = {}) => {
    setState(prev => ({ ...prev, ...st }));
    setScreen(s);
    if (s === 'history') setTab('history');
    else if (['course-list','module-list','module-detail','exercise-list','exercise','analyzing','result','mock-list','mock-intro','mock-exam','mock-result'].includes(s)) setTab('home');
  };

  // analyzing fallthrough
  React.useEffect(() => {
    if (screen === 'analyzing-mock') {
      const id = setTimeout(() => setScreen('mock-result'), 3300);
      return () => clearTimeout(id);
    }
  }, [screen]);

  const renderScreen = () => {
    const showTab = !['exercise','analyzing','analyzing-mock','mock-exam','mock-intro'].includes(screen);
    let content;
    if (tab === 'history' && showTab) content = <HistoryScreen go={go} />;
    else switch (screen) {
      case 'course-list':    content = <CourseListScreen go={go} />; break;
      case 'module-list':    content = <ModuleListScreen go={go} course={state.course} />; break;
      case 'module-detail':  content = <ModuleDetailScreen go={go} module={state.module} course={state.course} />; break;
      case 'exercise-list':  content = <ExerciseListScreen go={go} skill={state.skill} />; break;
      case 'exercise':       content = <RecordingScreen go={go} exercise={state.exercise} variant={tweaks.recordingVariant} />; break;
      case 'analyzing':      content = <AnalyzingScreen go={go} />; break;
      case 'analyzing-mock': content = <AnalyzingScreen go={() => setScreen('mock-result')} />; break;
      case 'result':         content = <ResultScreen go={go} variant={tweaks.resultVariant} />; break;
      case 'history':        content = <HistoryScreen go={go} />; break;
      case 'mock-list':      content = <MockListScreen go={go} />; break;
      case 'mock-intro':     content = <MockIntroScreen go={go} test={state.test} />; break;
      case 'mock-exam':      content = <MockExamScreen go={go} test={state.test} />; break;
      case 'mock-result':    content = <MockResultScreen go={go} />; break;
      default:               content = <CourseListScreen go={go} />;
    }
    return (
      <div style={{ height: '100%', position: 'relative', background: T.bg }}>
        {content}
        {showTab && <TabBar active={tab} onTab={(id) => { setTab(id); if (id === 'home') setScreen('course-list'); }} />}
      </div>
    );
  };

  return (
    <IOSDevice width={390} height={844}>
      {renderScreen()}
    </IOSDevice>
  );
}

// Standalone phone holder used as the "hero" prototype.
function HeroPhone() {
  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '40px 20px' }}>
      <Phone initial="course-list" />
    </div>
  );
}

// Static-screen artboard (no chrome around — we put each in IOSDevice for fidelity)
function ScreenFrame({ initial, startState }) {
  return (
    <div style={{ pointerEvents: 'auto' }}>
      <Phone initial={initial} startState={startState} />
    </div>
  );
}

// ─── Design tokens artboard ──────────────────────────────
function TokensArtboard() {
  const swatch = (label, value) => (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
      <div style={{ width: 48, height: 48, borderRadius: 10, background: value, border: '1px solid rgba(0,0,0,0.06)' }} />
      <div>
        <div style={{ fontSize: 12, fontWeight: 600, color: T.ink }}>{label}</div>
        <div style={{ fontFamily: T.mono, fontSize: 10.5, color: T.ink3 }}>{value}</div>
      </div>
    </div>
  );
  return (
    <div style={{ width: 880, padding: 32, background: T.bg, fontFamily: T.body, color: T.ink }}>
      <div style={{ fontSize: 11, fontWeight: 700, color: T.ink3, letterSpacing: 1, textTransform: 'uppercase' }}>Design system</div>
      <div style={{ fontFamily: T.display, fontSize: 36, fontWeight: 600, letterSpacing: -0.6, marginTop: 4 }}>A2 Mluvení Sprint</div>
      <div style={{ fontSize: 14, color: T.ink2, marginTop: 6, maxWidth: 600 }}>
        Quiet productivity. Warm paper background, deep indigo accent, Playfair Display for moments of weight, Inter for everything else.
      </div>

      <div style={{ marginTop: 28, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24 }}>
        {/* Type */}
        <div>
          <div style={{ fontSize: 11, fontWeight: 700, color: T.ink3, letterSpacing: 0.8, textTransform: 'uppercase', marginBottom: 12 }}>Typography</div>
          <div style={{ background: T.surface, padding: 20, borderRadius: T.r3, border: '1px solid ' + T.border }}>
            <div style={{ fontFamily: T.display, fontSize: 44, fontWeight: 600, letterSpacing: -1, lineHeight: 1 }}>76 / 100</div>
            <div style={{ fontSize: 11, color: T.ink3, marginTop: 4 }}>Playfair Display 600 · score / hero</div>
            <div style={{ height: 1, background: T.divider, margin: '16px 0' }} />
            <div style={{ fontFamily: T.display, fontSize: 24, fontWeight: 600, letterSpacing: -0.3 }}>Tuần 3: Nhà ở</div>
            <div style={{ fontSize: 11, color: T.ink3, marginTop: 4 }}>Playfair Display 600 · screen titles</div>
            <div style={{ height: 1, background: T.divider, margin: '16px 0' }} />
            <div style={{ fontSize: 16, fontWeight: 600 }}>Giới thiệu bản thân</div>
            <div style={{ fontSize: 11, color: T.ink3, marginTop: 4 }}>Inter 600 · list items, buttons</div>
            <div style={{ height: 1, background: T.divider, margin: '16px 0' }} />
            <div style={{ fontSize: 14 }}>Hãy tự giới thiệu trong 1–2 phút. Nói về tên, tuổi, quốc tịch.</div>
            <div style={{ fontSize: 11, color: T.ink3, marginTop: 4 }}>Inter 400 · body</div>
          </div>
        </div>

        {/* Colors */}
        <div>
          <div style={{ fontSize: 11, fontWeight: 700, color: T.ink3, letterSpacing: 0.8, textTransform: 'uppercase', marginBottom: 12 }}>Colors</div>
          <div style={{ background: T.surface, padding: 20, borderRadius: T.r3, border: '1px solid ' + T.border, display: 'flex', flexDirection: 'column', gap: 14 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              {swatch('Background', T.bg)}
              {swatch('Surface', T.surface)}
              {swatch('Ink', T.ink)}
              {swatch('Brand', T.brand)}
            </div>
            <div style={{ height: 1, background: T.divider }} />
            <div style={{ fontSize: 11, fontWeight: 700, color: T.ink3, letterSpacing: 0.5 }}>READINESS</div>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <ReadinessBadge level="ready"/>
              <ReadinessBadge level="almost"/>
              <ReadinessBadge level="needs"/>
              <ReadinessBadge level="not"/>
            </div>
          </div>
        </div>
      </div>

      <div style={{ marginTop: 24 }}>
        <div style={{ fontSize: 11, fontWeight: 700, color: T.ink3, letterSpacing: 0.8, textTransform: 'uppercase', marginBottom: 12 }}>Components</div>
        <div style={{ background: T.surface, padding: 20, borderRadius: T.r3, border: '1px solid ' + T.border, display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
            <Button variant="primary" icon="mic-fill">Bắt đầu ghi âm</Button>
            <Button variant="inverse" icon="stop">Dừng</Button>
            <Button variant="ghost" icon="redo">Ghi lại</Button>
            <Button variant="soft" iconRight="chevron-right">Xem kết quả</Button>
            <Button variant="danger" icon="mic-fill">Recording</Button>
          </div>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <Pill tone="brand">Mock 01</Pill>
            <Pill tone="warm">Úloha 2</Pill>
            <Pill tone="ready">Đã hoàn thành</Pill>
            <Pill tone="needs">Cần ôn thêm</Pill>
            <Pill tone="rec">Đang ghi</Pill>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <AudioBar duration={28} label="Bản ghi của bạn"/>
            <Card>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <div style={{ width: 36, height: 36, borderRadius: 10, background: T.brandSoft, color: T.brand, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Icon name="mic" size={18}/>
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 13.5, fontWeight: 600 }}>Nói · Mluvení</div>
                  <div style={{ fontSize: 11, color: T.ink3 }}>12 bài luyện</div>
                </div>
                <Icon name="chevron-right" size={16} style={{ color: T.ink3 }}/>
              </div>
            </Card>
          </div>
        </div>
      </div>
    </div>
  );
}

window.Phone = Phone;
window.HeroPhone = HeroPhone;
window.ScreenFrame = ScreenFrame;
window.TokensArtboard = TokensArtboard;
window.TWEAK_DEFAULTS = TWEAK_DEFAULTS;
