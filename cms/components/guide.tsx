export function AdminGuide() {
  return (
    <div style={{ maxWidth: 760, margin: '0 auto' }}>

      {/* Header */}
      <div style={{ marginBottom: 40 }}>
        <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1, color: 'var(--brand)', textTransform: 'uppercase', marginBottom: 8 }}>
          HƯỚNG DẪN QUẢN TRỊ
        </div>
        <h1 style={{ margin: '0 0 12px', fontSize: 32, fontWeight: 700, fontFamily: 'Fraunces, serif', color: 'var(--ink)' }}>
          Nhập liệu CMS
        </h1>
        <p style={{ margin: 0, fontSize: 15, color: 'var(--ink-3)', lineHeight: 1.6 }}>
          Luồng chuẩn để tạo nội dung học. Có hai luồng: <b>Exercise thủ công</b> (nói, viết, nghe, đọc) và <b>AI-assisted</b> (từ vựng, ngữ pháp).
        </p>
      </div>

      {/* Flow diagrams */}
      <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 'var(--r3)', padding: '20px 24px', marginBottom: 40 }}>
        <div style={{ fontSize: 12, fontWeight: 700, letterSpacing: 0.8, color: 'var(--ink-3)', textTransform: 'uppercase', marginBottom: 16 }}>Luồng A — Exercise thủ công</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap', marginBottom: 20 }}>
          {[
            { num: '1', label: 'Course', href: '/courses', color: '#7c3aed' },
            { num: '2', label: 'Module', href: '/modules', color: '#0891b2' },
            { num: '3', label: 'Skill', href: '/skills', color: '#059669', note: 'manual' },
            { num: '4', label: 'Exercise', href: '/', color: 'var(--brand)' },
          ].map((step, i, arr) => (
            <div key={step.num} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <a href={step.href} style={{ display: 'flex', alignItems: 'center', gap: 8, textDecoration: 'none',
                background: step.color, color: '#fff', borderRadius: 'var(--r2)', padding: '8px 14px', fontSize: 14, fontWeight: 600 }}>
                <span style={{ opacity: 0.7, fontSize: 12 }}>{step.num}.</span>
                {step.label}
              </a>
              {i < arr.length - 1 && <span style={{ color: 'var(--ink-4)', fontSize: 20 }}>→</span>}
            </div>
          ))}
        </div>

        <div style={{ fontSize: 12, fontWeight: 700, letterSpacing: 0.8, color: 'var(--ink-3)', textTransform: 'uppercase', marginBottom: 16 }}>Luồng B — AI-assisted (Từ vựng / Ngữ pháp)</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap', marginBottom: 12 }}>
          {[
            { num: '1', label: 'Course', href: '/courses', color: '#7c3aed' },
            { num: '2', label: 'Module', href: '/modules', color: '#0891b2' },
            { num: 'B', label: 'Từ vựng / Ngữ pháp', href: '/vocabulary', color: '#059669' },
            { num: '⚡', label: 'AI Generate', href: '/vocabulary', color: '#ea580c' },
            { num: '✓', label: 'Review & Publish', href: '/vocabulary', color: '#0369a1' },
          ].map((step, i, arr) => (
            <div key={step.num} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <span style={{ display: 'flex', alignItems: 'center', gap: 8,
                background: step.color, color: '#fff', borderRadius: 'var(--r2)', padding: '8px 14px', fontSize: 13, fontWeight: 600 }}>
                <span style={{ opacity: 0.7, fontSize: 11 }}>{step.num}</span>
                {step.label}
              </span>
              {i < arr.length - 1 && <span style={{ color: 'var(--ink-4)', fontSize: 20 }}>→</span>}
            </div>
          ))}
        </div>
        <Callout type="info">
          Luồng B: Skill <Code>tu_vung</Code> / <Code>ngu_phap</Code> được <b>tự động tạo</b> khi tạo Vocabulary Set hoặc Grammar Rule. Không cần vào trang Skills.
        </Callout>

        <div style={{ marginTop: 16, padding: '10px 14px', background: 'rgba(255, 106, 20, 0.06)', borderRadius: 'var(--r2)', borderLeft: '3px solid var(--brand)' }}>
          <span style={{ fontSize: 13, color: 'var(--ink-2)' }}>
            <b>Mock Test</b> — luồng riêng: tạo exercises với <Code>pool = exam</Code>, sau đó vào{' '}
            <a href="/mock-tests" style={{ color: 'var(--brand)', fontWeight: 600 }}>Mock Test</a> để gán.
          </span>
        </div>
      </div>

      {/* Step 1 - Course */}
      <Section num="1" title="Tạo Course" href="/courses" color="#7c3aed">
        <p>Course là khóa học tổng. Một khóa gồm nhiều Module.</p>
        <FieldTable rows={[
          ['Tiêu đề', 'Tên khóa học', 'Ôn thi A2 — trvalý pobyt', true],
          ['Slug', 'URL-friendly ID (tự sinh nếu để trống)', 'on-thi-a2', false],
          ['Thứ tự', 'Thứ tự hiển thị', '1', false],
          ['Trạng thái', 'Phải là published để Flutter thấy', 'published', true],
        ]} />
      </Section>

      {/* Step 2 - Module */}
      <Section num="2" title="Tạo Module" href="/modules" color="#0891b2">
        <p>Module là một tuần học hoặc chủ đề. Mỗi Module thuộc một Course.</p>
        <Callout type="info">Trang Modules: chọn Course ở filter trước khi tạo.</Callout>
        <FieldTable rows={[
          ['Tiêu đề', 'Tên module', 'Tuần 1 · Giới thiệu bản thân', true],
          ['Course', 'Chọn course vừa tạo', '—', true],
          ['Thứ tự', 'Số thứ tự trong course', '1', true],
          ['Trạng thái', 'published để học viên thấy', 'published', true],
        ]} />
      </Section>

      {/* Step 3 - Skill */}
      <Section num="3" title="Tạo Skill (Luồng A)" href="/skills" color="#059669">
        <p>Skill xác định kỹ năng trong Module. <b>Chỉ cần tạo thủ công</b> cho các kỹ năng nói/viết/nghe/đọc. Kỹ năng từ vựng và ngữ pháp được <b>tự động tạo</b> khi dùng Luồng B.</p>
        <Callout type="info">Trang Skills: chọn Module ở filter trước khi tạo.</Callout>

        <SubSection title="Các loại skill và bài tập tương ứng">
          <div style={{ display: 'grid', gap: 8 }}>
            {[
              { kind: 'noi', label: '🎙️ nói', color: '#FF6A14', exercises: 'uloha_1 uloha_2 uloha_3 uloha_4', note: 'Ghi âm + AI feedback' },
              { kind: 'viet', label: '✏️ viet', color: '#0F3D3A', exercises: 'psani_1_formular psani_2_email', note: 'Viết văn bản + AI feedback' },
              { kind: 'nghe', label: '🎧 nghe', color: '#7C3AED', exercises: 'poslech_1 → poslech_5', note: 'Nghe audio + trắc nghiệm' },
              { kind: 'doc', label: '📖 doc', color: '#0369A1', exercises: 'cteni_1 → cteni_5', note: 'Đọc văn bản + trắc nghiệm' },
              { kind: 'tu_vung', label: '📚 tu_vung', color: '#059669', exercises: 'quizcard_basic matching fill_blank choice_word', note: 'Tự động tạo qua Luồng B' },
              { kind: 'ngu_phap', label: '📝 ngu_phap', color: '#DC2626', exercises: 'matching fill_blank choice_word', note: 'Tự động tạo qua Luồng B' },
            ].map(s => (
              <div key={s.kind} style={{ display: 'grid', gridTemplateColumns: '130px 1fr 1fr', gap: 12,
                padding: '10px 14px', background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 'var(--r2)', alignItems: 'center', fontSize: 13 }}>
                <span style={{ fontWeight: 700, color: s.color }}>{s.label}</span>
                <span style={{ fontFamily: 'monospace', fontSize: 11, color: 'var(--ink-3)' }}>{s.exercises}</span>
                <span style={{ color: 'var(--ink-2)', fontSize: 12 }}>{s.note}</span>
              </div>
            ))}
          </div>
        </SubSection>

        <FieldTable rows={[
          ['Loại kỹ năng', 'noi / viet / nghe / doc', 'noi', true],
          ['Tên kỹ năng', 'Tên hiển thị trong app', 'Nói — Tuần 1', true],
          ['Trạng thái', 'published', 'published', true],
        ]} />
      </Section>

      {/* Step 4 - Exercise (manual) */}
      <Section num="4" title="Tạo Exercise thủ công (Luồng A)" href="/" color="var(--brand)">
        <p>Exercise là bài tập cụ thể. Dùng wizard 3 bước: chọn Skill → chọn loại bài → nhập nội dung.</p>
        <Callout type="info">Nhấn <b>+ Tạo bài tập</b> ở trang Bài tập để mở wizard.</Callout>

        <SubSection title="Bước 1 — Chọn Skill">
          <p style={{ margin: 0, fontSize: 14, color: 'var(--ink-2)' }}>
            Chọn skill từ danh sách nhóm theo kỹ năng. Skill phải được tạo trước (Bước 3).
            Sau khi chọn skill, hệ thống chỉ hiện loại bài phù hợp.
          </p>
        </SubSection>

        <SubSection title="Bước 2 — Chọn loại bài">
          <div style={{ display: 'grid', gap: 10 }}>
            {[
              ['🎙️ Nói', 'Úloha 1', 'Trả lời 3–4 câu hỏi ngắn theo chủ đề'],
              ['🎙️ Nói', 'Úloha 2', 'Hội thoại — hỏi để lấy thông tin (slot_key | label | sample question)'],
              ['🎙️ Nói', 'Úloha 3', 'Kể chuyện theo tranh (story title + checkpoints + ảnh)'],
              ['🎙️ Nói', 'Úloha 4', 'Chọn 1/3 phương án và giải thích (option_key | label | description)'],
              ['✏️ Viết', 'Psaní 1', 'Điền form 3 câu hỏi (≥10 từ/câu)'],
              ['✏️ Viết', 'Psaní 2', 'Viết email từ 5 ảnh gợi ý (≥35 từ)'],
              ['🎧 Nghe', 'Poslech 1–5', '5 đoạn hội thoại → chọn A-D / ghép / điền'],
              ['📖 Đọc', 'Čtení 1–5', 'Văn bản → chọn A-D / ghép / điền'],
            ].map(([skill, type, desc]) => (
              <div key={`${skill}-${type}`} style={{ border: '1px solid var(--border)', borderRadius: 'var(--r2)', overflow: 'hidden' }}>
                <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start', padding: '10px 14px', background: 'var(--surface)' }}>
                  <span style={{ fontSize: 11, color: 'var(--ink-3)', flexShrink: 0, marginTop: 2, minWidth: 50 }}>{skill}</span>
                  <span style={{ background: 'var(--brand)', color: '#fff', fontSize: 11, fontWeight: 700,
                    borderRadius: 'var(--r1)', padding: '2px 8px', flexShrink: 0, marginTop: 1 }}>{type}</span>
                  <div style={{ fontSize: 13, color: 'var(--ink-2)' }}>{desc}</div>
                </div>
              </div>
            ))}
          </div>
        </SubSection>

        <SubSection title="Bước 3 — Nhập nội dung">
          <p style={{ margin: 0, fontSize: 14, color: 'var(--ink-2)' }}>
            Form hiện đúng fields cho loại bài đã chọn. Có 3 tab: <b>Đề bài</b> (nội dung chính), <b>Bài mẫu</b> (tùy chọn), <b>Siêu dữ liệu</b>.
          </p>
          <Callout type="warning">
            Tab Siêu dữ liệu — <b>Trạng thái phải là published</b>. Exercise <Code>draft</Code> không hiện trên Flutter.
          </Callout>
        </SubSection>
      </Section>

      {/* Step 5 - Vocabulary */}
      <Section num="5" title="Từ vựng — AI-assisted (Luồng B)" href="/vocabulary" color="#059669">
        <p>Admin nhập danh sách từ → AI generate bài tập nháp → Admin duyệt → Publish. Skill <Code>tu_vung</Code> tự động tạo.</p>

        <SubSection title="Bước 1 — Tạo bộ từ vựng">
          <FieldTable rows={[
            ['Tên bộ từ', 'Chủ đề từ vựng', 'Động từ di chuyển', true],
            ['Khóa học', 'Chọn course', '—', true],
            ['Module', 'Chọn module (cascade)', '—', true],
            ['Level', 'A1 / A2 / B1', 'A2', true],
            ['Ngôn ngữ GT', 'Ngôn ngữ giải thích', 'Tiếng Việt (vi)', false],
            ['Danh sách từ', 'Czech = Vietnamese (từng dòng)', 'chodím = đi bộ', true],
          ]} />
        </SubSection>

        <SubSection title="Bước 2 — Generate với AI">
          <p style={{ margin: 0, fontSize: 14, color: 'var(--ink-2)' }}>
            Sau khi lưu bộ từ, chọn loại bài và số lượng. Nhấn <b>⚡ Tạo bài tập với AI</b>.
            Hệ thống gọi Claude — có thể mất 30–90 giây tùy số lượng.
          </p>
          <div style={{ display: 'grid', gap: 6 }}>
            {[
              { type: 'Flashcard', color: '#059669', desc: 'Lật thẻ Czech → Vietnamese. Learner tự chấm biết/chưa biết.' },
              { type: 'Ghép đôi', color: '#7C3AED', desc: 'Ghép 4–6 từ Czech với nghĩa Vietnamese.' },
              { type: 'Điền từ', color: '#0369A1', desc: 'Câu có ___ — điền từ đúng.' },
              { type: 'Chọn từ', color: '#0F3D3A', desc: 'Câu hỏi + 4 lựa chọn A-D.' },
            ].map(t => (
              <div key={t.type} style={{ display: 'flex', gap: 12, alignItems: 'center',
                padding: '8px 14px', background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 'var(--r2)', fontSize: 13 }}>
                <span style={{ fontWeight: 700, color: t.color, minWidth: 80 }}>{t.type}</span>
                <span style={{ color: 'var(--ink-2)' }}>{t.desc}</span>
              </div>
            ))}
          </div>
        </SubSection>

        <SubSection title="Bước 3 — Review và Publish">
          <p style={{ margin: 0, fontSize: 14, color: 'var(--ink-2)', marginBottom: 8 }}>
            Sau khi AI tạo xong, màn hình hiện danh sách bài nháp. Kiểm tra từng bài:
          </p>
          <div style={{ display: 'grid', gap: 6 }}>
            {[
              ['Sửa nội dung', 'Chỉnh trực tiếp — front/back/explanation/options'],
              ['Xóa bài', 'Xóa bài không phù hợp trước khi publish'],
              ['Lưu nháp', 'Lưu chỉnh sửa mà chưa publish'],
              ['Publish', 'Validate tất cả → tạo exercises vào database. Không thể undo.'],
              ['Từ chối', 'Hủy job — tạo lại từ đầu nếu cần'],
            ].map(([action, desc]) => (
              <div key={action} style={{ display: 'grid', gridTemplateColumns: '100px 1fr', gap: 12,
                padding: '8px 14px', background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 'var(--r2)', fontSize: 13, alignItems: 'center' }}>
                <span style={{ fontWeight: 600, color: 'var(--ink)' }}>{action}</span>
                <span style={{ color: 'var(--ink-3)' }}>{desc}</span>
              </div>
            ))}
          </div>
          <Callout type="warning">
            Validation bắt buộc: choice_word cần ≥2 options và correct answer nằm trong options; fill_blank cần có <Code>___</Code>; tất cả loại cần có explanation.
          </Callout>
        </SubSection>
      </Section>

      {/* Step 6 - Grammar */}
      <Section num="6" title="Ngữ pháp — AI-assisted (Luồng B)" href="/grammar" color="#DC2626">
        <p>Nhập quy tắc ngữ pháp → AI generate bài điền từ và chọn từ có giải thích → Publish. Skill <Code>ngu_phap</Code> tự động tạo.</p>

        <SubSection title="Tạo quy tắc ngữ pháp">
          <FieldTable rows={[
            ['Tên quy tắc', 'Tên quy tắc ngữ pháp', 'Verb být — hiện tại', true],
            ['Module', 'Gắn vào module nào', '—', true],
            ['Level', 'A1 / A2 / B1', 'A1', false],
            ['Giải thích', 'Giải thích bằng tiếng Việt', 'Động từ být nghĩa là "là/ở"...', false],
            ['Bảng chia', 'Các cặp chủ ngữ → dạng', 'já → jsem, ty → jsi...', false],
            ['Ràng buộc', 'Hướng dẫn cho AI (tránh gì, dùng gì)', 'Câu đơn A1, tránh thì quá khứ', false],
          ]} />
        </SubSection>

        <Callout type="info">
          Grammar chỉ generate <b>fill_blank</b> và <b>choice_word</b>. Không có flashcard (flashcard dành cho từ vựng riêng lẻ, không phù hợp ngữ pháp).
          Flow review và publish giống Từ vựng.
        </Callout>
      </Section>

      {/* Mock Test */}
      <Section num="7" title="Tạo Mock Test" href="/mock-tests" color="#6b7280">
        <p>Mock Test dùng exercises riêng (pool = exam). Không dùng chung với exercises khóa học.</p>

        <SubSection title="Bước 1 — Tạo 4 exercises thi (pool = exam)">
          <p style={{ margin: '0 0 10px', fontSize: 14, color: 'var(--ink-2)' }}>
            Vào trang Bài tập, tạo 4 exercises. Trong wizard Bước 3 (Siêu dữ liệu) chọn:
          </p>
          <div style={{ padding: '10px 14px', background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 'var(--r2)', fontFamily: 'monospace', fontSize: 13, color: 'var(--ink-2)' }}>
            Pool: Bài thi mock exam (exam)<br />
            Status: published
          </div>
          <Callout type="info">Pool = exam không cần gắn Module / Skill. Hệ thống sẽ block nếu thử gán exercise từ vựng/ngữ pháp vào mock test (pool = exam không được phép cho 4 loại bài V6).</Callout>
        </SubSection>

        <SubSection title="Bước 2 — Tạo Mock Test và gán exercises">
          <div style={{ display: 'grid', gap: 6 }}>
            {[
              ['Section 1', 'Úloha 1', '8 điểm'],
              ['Section 2', 'Úloha 2', '12 điểm'],
              ['Section 3', 'Úloha 3', '10 điểm'],
              ['Section 4', 'Úloha 4', '7 điểm'],
            ].map(([sec, task, pts]) => (
              <div key={sec} style={{ display: 'flex', alignItems: 'center', gap: 12,
                padding: '8px 14px', background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 'var(--r2)', fontSize: 14 }}>
                <span style={{ fontWeight: 600, color: 'var(--ink)', minWidth: 80 }}>{sec}</span>
                <span style={{ color: 'var(--ink-2)' }}>{task}</span>
                <span style={{ marginLeft: 'auto', fontWeight: 700, color: 'var(--brand)' }}>{pts}</span>
              </div>
            ))}
          </div>
          <div style={{ marginTop: 12, fontSize: 13, color: 'var(--ink-3)' }}>
            Tổng: 37 điểm + 3 điểm phát âm = <b>40 điểm</b>. Đạt: <b>≥ 24 điểm</b>.
          </div>
        </SubSection>
      </Section>

      {/* Verify */}
      <div style={{ marginTop: 40, padding: '20px 24px', background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 'var(--r3)' }}>
        <div style={{ fontSize: 12, fontWeight: 700, letterSpacing: 0.8, color: 'var(--ink-3)', textTransform: 'uppercase', marginBottom: 12 }}>Kiểm tra kết quả</div>
        <ol style={{ margin: 0, padding: '0 0 0 20px', display: 'grid', gap: 8 }}>
          {[
            'Flutter app → Home → tap Course → Module → chọn Skill',
            'Skill "Nói": danh sách Úloha 1-4 → ghi âm → AI feedback',
            'Skill "Từ vựng": filter pills (Flashcard / Ghép đôi / Điền từ / Chọn từ) → làm bài',
            'Skill "Ngữ pháp": filter pills (Ghép đôi / Điền từ / Chọn từ) → làm bài',
            '"Bắt đầu tất cả": làm tuần tự từng bài trong skill, nút "Bài tiếp theo →"',
            'Nếu không thấy bài tập: kiểm tra exercise status = published và đúng pool',
          ].map((step, i) => (
            <li key={i} style={{ fontSize: 14, color: 'var(--ink-2)', lineHeight: 1.5 }}>{step}</li>
          ))}
        </ol>
      </div>

      {/* LLM config */}
      <details style={{ marginTop: 24 }}>
        <summary style={{ cursor: 'pointer', fontSize: 13, fontWeight: 600, color: 'var(--ink-3)', userSelect: 'none', padding: '8px 0' }}>
          Cấu hình AI Model (env vars)
        </summary>
        <div style={{ marginTop: 12, display: 'grid', gap: 8 }}>
          <p style={{ margin: 0, fontSize: 13, color: 'var(--ink-3)', lineHeight: 1.6 }}>
            Model và prompt được quản lý tập trung trong <Code>backend/internal/processing/llm_config.go</Code> và <Code>llm_prompts.go</Code>.
            Thay đổi model qua env var — không cần sửa code.
          </p>
          <div style={{ border: '1px solid var(--border)', borderRadius: 'var(--r2)', overflow: 'hidden', fontSize: 13 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '200px 1fr 200px', gap: 0, background: 'var(--surface-muted)', padding: '8px 14px', fontWeight: 700, color: 'var(--ink-3)', fontSize: 11, textTransform: 'uppercase' }}>
              <span>Env var</span><span>Mục đích</span><span>Default</span>
            </div>
            {[
              ['LLM_PROVIDER', 'Bật/tắt LLM feedback (claude hoặc để trống)', 'dev (tắt)'],
              ['LLM_MODEL', 'Model feedback nói/viết (real-time, per-attempt)', 'claude-haiku-4-5-20251001'],
              ['LLM_REVIEW_MODEL', 'Model review artifact generation', '→ LLM_MODEL'],
              ['LLM_CONTENT_MODEL', 'Model generate từ vựng/ngữ pháp (batch)', 'claude-haiku-4-5-20251001'],
              ['ANTHROPIC_API_KEY', 'API key của Anthropic — bắt buộc khi dùng Claude', '—'],
            ].map(([k, desc, def]) => (
              <div key={k} style={{ display: 'grid', gridTemplateColumns: '200px 1fr 200px', padding: '9px 14px', borderTop: '1px solid var(--border)', alignItems: 'center' }}>
                <Code>{k}</Code>
                <span style={{ color: 'var(--ink-3)', fontSize: 12 }}>{desc}</span>
                <span style={{ fontFamily: 'monospace', fontSize: 11, color: 'var(--ink-2)' }}>{def}</span>
              </div>
            ))}
          </div>
          <Callout type="info">
            Để thay đổi prompt (hướng dẫn AI), sửa file <Code>llm_prompts.go</Code> — tất cả prompt template nằm trong một file duy nhất.
          </Callout>
        </div>
      </details>

      {/* Troubleshooting */}
      <div style={{ marginTop: 24, padding: '20px 24px', background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 'var(--r3)' }}>
        <div style={{ fontSize: 12, fontWeight: 700, letterSpacing: 0.8, color: 'var(--ink-3)', textTransform: 'uppercase', marginBottom: 12 }}>Xử lý sự cố thường gặp</div>
        <div style={{ display: 'grid', gap: 10 }}>
          {[
            ['AI generate timeout', 'Gọi Claude có thể mất 60–120s cho nhiều bài. Nếu job "failed": thử tạo ít bài hơn mỗi lần (5-10 thay vì 20+).'],
            ['Bài tập không hiện trên Flutter', 'Kiểm tra: status = published, pool = course (không phải exam), skill đúng loại.'],
            ['Duplicate skill', 'Mỗi module chỉ nên có 1 skill của mỗi loại. Xóa skill thừa qua trang Skills.'],
            ['Validation error khi Publish', 'Kiểm tra từng bài: choice_word cần 4 options + correct answer trong options; fill_blank cần ___; tất cả cần explanation.'],
            ['AI tạo sai ngôn ngữ', 'Đặt Ngôn ngữ giải thích = Tiếng Việt khi tạo bộ từ. Với grammar thêm ràng buộc "All explanations in Vietnamese".'],
          ].map(([problem, solution]) => (
            <div key={problem} style={{ display: 'grid', gridTemplateColumns: '200px 1fr', gap: 12,
              padding: '10px 14px', background: 'var(--surface-alt)', border: '1px solid var(--border)', borderRadius: 'var(--r2)', fontSize: 13, alignItems: 'start' }}>
              <span style={{ fontWeight: 600, color: 'var(--ink)' }}>{problem}</span>
              <span style={{ color: 'var(--ink-3)', lineHeight: 1.5 }}>{solution}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Reset */}
      <details style={{ marginTop: 24 }}>
        <summary style={{ cursor: 'pointer', fontSize: 13, fontWeight: 600, color: 'var(--ink-3)', userSelect: 'none', padding: '8px 0' }}>
          Xóa toàn bộ data (reset)
        </summary>
        <div style={{ marginTop: 12, padding: '16px', background: '#1e1e2e', borderRadius: 'var(--r2)', fontFamily: 'monospace', fontSize: 12, color: '#cdd6f4', lineHeight: 1.7, overflowX: 'auto' }}>
          {'-- docker compose exec postgres psql -U postgres -d czech_go_system'}<br />
          {'TRUNCATE TABLE'}<br />
          {'  attempt_review_artifacts, attempt_feedback, attempt_audio,'}<br />
          {'  attempt_transcripts, attempts,'}<br />
          {'  mock_exam_sections, mock_exam_sessions,'}<br />
          {'  mock_test_sections, mock_tests,'}<br />
          {'  content_generation_jobs,'}<br />
          {'  vocabulary_items, vocabulary_sets,'}<br />
          {'  grammar_rules,'}<br />
          {'  exercises,'}<br />
          {'  skills, modules, courses CASCADE;'}
        </div>
      </details>

      <div style={{ height: 48 }} />
    </div>
  );
}

function Section({ num, title, href, color, children }: {
  num: string; title: string; href: string; color: string; children: React.ReactNode;
}) {
  return (
    <div style={{ marginBottom: 40 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
        <div style={{ width: 32, height: 32, borderRadius: '50%', background: color,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: '#fff', fontSize: 14, fontWeight: 700, flexShrink: 0 }}>{num}</div>
        <h2 style={{ margin: 0, fontSize: 20, fontWeight: 700, color: 'var(--ink)' }}>{title}</h2>
        <a href={href} style={{ marginLeft: 'auto', fontSize: 13, color, fontWeight: 600,
          textDecoration: 'none', padding: '4px 12px', border: `1.5px solid ${color}`,
          borderRadius: 'var(--r2)' }}>
          Mở trang →
        </a>
      </div>
      <div style={{ paddingLeft: 44, display: 'grid', gap: 16 }}>
        {children}
      </div>
      <div style={{ height: 1, background: 'var(--border)', marginTop: 32 }} />
    </div>
  );
}

function SubSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div style={{ display: 'grid', gap: 10 }}>
      <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--ink-2)', letterSpacing: 0.3 }}>{title}</div>
      {children}
    </div>
  );
}

function FieldTable({ rows }: { rows: [string, string, string, boolean][] }) {
  return (
    <div style={{ border: '1px solid var(--border)', borderRadius: 'var(--r2)', overflow: 'hidden', fontSize: 13 }}>
      <div style={{ display: 'grid', gridTemplateColumns: '140px 1fr 1fr 80px',
        background: 'var(--surface-muted)', padding: '8px 14px',
        fontWeight: 700, color: 'var(--ink-3)', fontSize: 11, letterSpacing: 0.5, textTransform: 'uppercase' }}>
        <span>Field</span><span>Mô tả</span><span>Ví dụ</span><span>Bắt buộc</span>
      </div>
      {rows.map(([field, desc, example, required], i) => (
        <div key={i} style={{ display: 'grid', gridTemplateColumns: '140px 1fr 1fr 80px',
          padding: '10px 14px', borderTop: '1px solid var(--border)',
          background: i % 2 === 0 ? 'transparent' : 'var(--surface)', alignItems: 'center' }}>
          <span style={{ fontWeight: 600, color: 'var(--ink)' }}>{field}</span>
          <span style={{ color: 'var(--ink-3)' }}>{desc}</span>
          <span style={{ fontFamily: 'monospace', fontSize: 12, color: 'var(--ink-2)' }}>{example}</span>
          <span>{required
            ? <span style={{ background: '#fef2f2', color: '#dc2626', borderRadius: 4, padding: '2px 8px', fontSize: 11, fontWeight: 700 }}>bắt buộc</span>
            : <span style={{ color: 'var(--ink-4)', fontSize: 12 }}>tuỳ chọn</span>
          }</span>
        </div>
      ))}
    </div>
  );
}

function Callout({ type, children }: { type: 'info' | 'warning'; children: React.ReactNode }) {
  const isWarning = type === 'warning';
  return (
    <div style={{
      padding: '10px 14px',
      borderRadius: 'var(--r2)',
      borderLeft: `3px solid ${isWarning ? '#f59e0b' : '#3b82f6'}`,
      background: isWarning ? 'rgba(245, 158, 11, 0.06)' : 'rgba(59, 130, 246, 0.06)',
      fontSize: 13,
      color: 'var(--ink-2)',
      lineHeight: 1.5,
    }}>
      {children}
    </div>
  );
}

function Code({ children }: { children: React.ReactNode }) {
  return (
    <code style={{ background: 'var(--surface)', border: '1px solid var(--border)',
      borderRadius: 4, padding: '1px 6px', fontFamily: 'monospace', fontSize: 12 }}>
      {children}
    </code>
  );
}
