'use client';

import { createContext, useContext, useState, useEffect, ReactNode } from 'react';

// ── Messages ───────────────────────────────────────────────────────────────────

export interface Messages {
  nav: { exercises: string; courses: string; mockTests: string; learners: string; modules: string; skills: string; vocabulary: string; grammar: string; guide: string };
  action: { create: string; edit: string; save: string; saveChanges: string; saving: string; delete: string; cancel: string; update: string };
  status: { draft: string; published: string; archived: string };
  pick: { module: string; skill: string; course: string; exercise: string; moduleForSkills: string; allCourses: string };
  exercise: { tabPrompt: string; tabSample: string; tabMetadata: string; createTitle: string; editTitle: string; createCta: string; updateCta: string; poolCourse: string; poolExam: string; editorEyebrow: string; editorHint: string; inventoryEyebrow: string; inventoryTitle: string; inventorySubtitle: string; refresh: string; cancelEditing: string; deleteConfirm: string; noAssets: string; fieldTaskType: string; fieldTitle: string; fieldShortInstruction: string; fieldLearnerInstruction: string; fieldSampleAnswer: string; fieldStatus: string; fieldPool: string; fieldModule: string; fieldSkill: string; fieldQuestionPrompts: string; fieldScenarioPrompt: string; fieldExtraQuestionHint: string; fieldNarrativeCheckpoints: string; fieldPromptAssets: string; heroTitle: string; heroDesc: string; metricSliceLabel: string; metricSliceValue: string; metricSliceHint: string; metricStatusLabel: string; metricStatusHint: string; metricModeLabel: string; metricModeValue: string; metricModeHint: string };
  mockTest: { createTitle: string; editTitle: string; newCta: string; createCta: string; updateCta: string; maxPointsLabel: string; emptyState: string };
  module: { createTitle: string; editTitle: string; newCta: string; filterLabel: string; filterCta: string };
  skill: { createTitle: string; editTitle: string; newCta: string; filterLabel: string; emptyModule: string; emptySkills: string; kindLabel: string; titleLabel: string };
  learners: { viewAttempts: string; viewLearners: string; colTime: string; colExercise: string; colStatus: string; colCount: string; colPlatform: string; colLearner: string; colAttempts: string; colCompleted: string; colReadiness: string; colRecent: string };
  stats: { activeUsers: string; attemptsDay: string; passRate: string; aiAgreement: string };
}

const VI: Messages = {
  nav: {
    exercises: 'Bài tập', courses: 'Khóa học', mockTests: 'Mock Test',
    learners: 'Học viên', modules: 'Module', skills: 'Kỹ năng',
    vocabulary: 'Từ vựng', grammar: 'Ngữ pháp', guide: 'Hướng dẫn',
  },
  action: {
    create: 'Tạo', edit: 'Chỉnh sửa', save: 'Lưu', saveChanges: 'Lưu thay đổi',
    saving: 'Đang lưu…', delete: 'Xóa', cancel: 'Hủy', update: 'Cập nhật',
  },
  status: { draft: 'Bản nháp', published: 'Đã xuất bản', archived: 'Đã lưu trữ' },
  pick: {
    module: '— Chọn module —', skill: '— Chọn kỹ năng —',
    course: '— Chọn khóa học —', exercise: '— Chọn bài tập —',
    moduleForSkills: '— Chọn module để xem kỹ năng —', allCourses: 'Tất cả khóa học',
  },
  exercise: {
    tabPrompt: 'Đề bài', tabSample: 'Bài mẫu', tabMetadata: 'Siêu dữ liệu',
    createTitle: 'Tạo bài tập', editTitle: 'Chỉnh sửa bài tập',
    createCta: 'Tạo bài tập', updateCta: 'Cập nhật bài tập',
    poolCourse: 'Bài luyện khóa học (course)', poolExam: 'Bài thi mock exam (exam)',
    editorEyebrow: 'Trình soạn thảo',
    editorHint: 'Giữ prompt ngắn, rõ ràng để học viên dễ hiểu và bình tĩnh trong lúc nói.',
    inventoryEyebrow: 'Kho bài tập',
    inventoryTitle: 'Danh sách bài tập',
    inventorySubtitle: 'Lấy từ /v1/admin/exercises.',
    refresh: 'Tải lại',
    cancelEditing: 'Hủy chỉnh sửa',
    deleteConfirm: 'Xóa bài tập này? Không thể hoàn tác.',
    noAssets: 'Chưa có asset nào cho bài tập này.',
    fieldTaskType: 'Loại bài',
    fieldTitle: 'Tiêu đề',
    fieldShortInstruction: 'Hướng dẫn ngắn',
    fieldLearnerInstruction: 'Hướng dẫn học viên',
    fieldSampleAnswer: 'Câu trả lời mẫu (tiếng Czech)',
    fieldStatus: 'Trạng thái',
    fieldPool: 'Pool',
    fieldModule: 'Module',
    fieldSkill: 'Kỹ năng',
    fieldQuestionPrompts: 'Câu hỏi (mỗi câu 1 dòng)',
    fieldScenarioPrompt: 'Tình huống hội thoại',
    fieldExtraQuestionHint: 'Câu hỏi bổ sung (tùy chọn)',
    fieldNarrativeCheckpoints: 'Các mốc câu chuyện (mỗi mốc 1 dòng)',
    fieldPromptAssets: 'Ảnh / tài nguyên',
    heroTitle: 'Quản lý nội dung bài nói A2',
    heroDesc: 'Tạo, chỉnh sửa và xóa bài tập cho 4 loại Úloha. Learner app chỉ hiển thị bài có status = published.',
    metricSliceLabel: 'Phần hiện tại',
    metricSliceValue: 'Bộ nói V1 đầy đủ',
    metricSliceHint: 'Tạo, sửa, xóa bài tập',
    metricStatusLabel: 'Số bài tập',
    metricStatusHint: 'bài trong danh sách',
    metricModeLabel: 'Chế độ',
    metricModeValue: 'Theo loại bài',
    metricModeHint: 'Không có schema builder chung',
  },
  mockTest: {
    createTitle: 'Đề thi mới', editTitle: 'Chỉnh sửa đề thi',
    newCta: '+ Thêm đề thi mới', createCta: 'Tạo', updateCta: 'Lưu thay đổi',
    maxPointsLabel: 'Điểm tối đa', emptyState: 'Chưa có đề thi nào.',
  },
  module: {
    createTitle: 'Module mới', editTitle: 'Chỉnh sửa module',
    newCta: '+ Thêm module mới', filterLabel: 'Lọc theo khóa học:', filterCta: 'Lọc',
  },
  skill: {
    createTitle: 'Kỹ năng mới', editTitle: 'Chỉnh sửa kỹ năng',
    newCta: '+ Thêm kỹ năng mới', filterLabel: 'Lọc theo module:',
    emptyModule: 'Chọn module ở trên để quản lý kỹ năng.',
    emptySkills: 'Chưa có kỹ năng nào cho module này.',
    kindLabel: 'Loại kỹ năng *', titleLabel: 'Tên kỹ năng',
  },
  learners: {
    viewAttempts: 'Lượt nộp', viewLearners: 'Học viên',
    colTime: 'Thời gian', colExercise: 'Bài tập', colStatus: 'Trạng thái',
    colCount: 'Lần', colPlatform: 'Nền tảng', colLearner: 'Học viên',
    colAttempts: 'Lượt', colCompleted: 'Hoàn thành',
    colReadiness: 'Phân bố readiness', colRecent: 'Gần nhất',
  },
  stats: {
    activeUsers: 'Học viên active (7d)', attemptsDay: 'Bài hoàn thành/ngày',
    passRate: 'Pass rate Mock A2', aiAgreement: 'AI / reviewer đồng ý',
  },
};

const EN: Messages = {
  nav: {
    exercises: 'Exercises', courses: 'Courses', mockTests: 'Mock Tests',
    learners: 'Learners', modules: 'Modules', skills: 'Skills',
    vocabulary: 'Vocabulary', grammar: 'Grammar', guide: 'Guide',
  },
  action: {
    create: 'Create', edit: 'Edit', save: 'Save', saveChanges: 'Save changes',
    saving: 'Saving…', delete: 'Delete', cancel: 'Cancel', update: 'Update',
  },
  status: { draft: 'Draft', published: 'Published', archived: 'Archived' },
  pick: {
    module: '— Pick module —', skill: '— Pick skill —',
    course: '— Pick course —', exercise: '— Pick exercise —',
    moduleForSkills: '— Pick a module to see its skills —', allCourses: 'All courses',
  },
  exercise: {
    tabPrompt: 'Prompt', tabSample: 'Sample', tabMetadata: 'Metadata',
    createTitle: 'Create exercise', editTitle: 'Edit exercise',
    createCta: 'Create exercise', updateCta: 'Update exercise',
    poolCourse: 'Course exercise (course)', poolExam: 'Mock exam exercise (exam)',
    editorEyebrow: 'Content editor',
    editorHint: 'Keep prompts short, specific, and easy to scan so learners can stay calm inside the speaking flow.',
    inventoryEyebrow: 'Current inventory',
    inventoryTitle: 'Exercises',
    inventorySubtitle: 'Pulled from /v1/admin/exercises.',
    refresh: 'Refresh',
    cancelEditing: 'Cancel editing',
    deleteConfirm: 'Delete this exercise? This cannot be undone.',
    noAssets: 'No prompt assets yet for this exercise.',
    fieldTaskType: 'Task type',
    fieldTitle: 'Title',
    fieldShortInstruction: 'Short instruction',
    fieldLearnerInstruction: 'Learner instruction',
    fieldSampleAnswer: 'Sample answer (Czech)',
    fieldStatus: 'Status',
    fieldPool: 'Pool',
    fieldModule: 'Module',
    fieldSkill: 'Skill',
    fieldQuestionPrompts: 'Question prompts (one per line)',
    fieldScenarioPrompt: 'Scenario prompt',
    fieldExtraQuestionHint: 'Extra question hint (optional)',
    fieldNarrativeCheckpoints: 'Narrative checkpoints (one per line)',
    fieldPromptAssets: 'Prompt assets',
    heroTitle: 'Content ops for oral tasks',
    heroDesc: 'Create, edit, and delete exercises for all four Úloha types. Only published exercises appear in the learner app.',
    metricSliceLabel: 'Current slice',
    metricSliceValue: 'Full V1 oral set',
    metricSliceHint: 'Create, edit, and delete exercises',
    metricStatusLabel: 'Content status',
    metricStatusHint: 'exercises in admin list',
    metricModeLabel: 'Working mode',
    metricModeValue: 'Task-specific',
    metricModeHint: 'No generic schema builder',
  },
  mockTest: {
    createTitle: 'New mock test', editTitle: 'Edit mock test',
    newCta: '+ New mock test', createCta: 'Create', updateCta: 'Save changes',
    maxPointsLabel: 'Max points', emptyState: 'No mock tests yet.',
  },
  module: {
    createTitle: 'New module', editTitle: 'Edit module',
    newCta: '+ New module', filterLabel: 'Filter by course:', filterCta: 'Filter',
  },
  skill: {
    createTitle: 'New skill', editTitle: 'Edit skill',
    newCta: '+ New skill', filterLabel: 'Filter by module:',
    emptyModule: 'Select a module above to manage its skills.',
    emptySkills: 'No skills for this module yet.',
    kindLabel: 'Skill kind *', titleLabel: 'Title',
  },
  learners: {
    viewAttempts: 'Submissions', viewLearners: 'Learners',
    colTime: 'Time', colExercise: 'Exercise', colStatus: 'Status',
    colCount: 'Count', colPlatform: 'Platform', colLearner: 'Learner',
    colAttempts: 'Attempts', colCompleted: 'Completed',
    colReadiness: 'Readiness dist.', colRecent: 'Recent',
  },
  stats: {
    activeUsers: 'Active learners (7d)', attemptsDay: 'Attempts/day',
    passRate: 'Mock A2 pass rate', aiAgreement: 'AI / reviewer agreement',
  },
};
export type Locale = 'vi' | 'en';

// ── Context ────────────────────────────────────────────────────────────────────

type LocaleCtx = { locale: Locale; toggle: () => void };
const Ctx = createContext<LocaleCtx>({ locale: 'vi', toggle: () => {} });
const MsgCtx = createContext<Messages>(VI as Messages);

const STORAGE_KEY = 'cms-locale';

export function LocaleProvider({ children }: { children: ReactNode }) {
  const [locale, setLocale] = useState<Locale>('vi');

  useEffect(() => {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored === 'en' || stored === 'vi') setLocale(stored);
  }, []);

  function toggle() {
    const next: Locale = locale === 'vi' ? 'en' : 'vi';
    localStorage.setItem(STORAGE_KEY, next);
    setLocale(next);
  }

  return (
    <Ctx.Provider value={{ locale, toggle }}>
      <MsgCtx.Provider value={locale === 'vi' ? VI : EN}>
        {children}
      </MsgCtx.Provider>
    </Ctx.Provider>
  );
}

export function useS(): Messages { return useContext(MsgCtx); }
export function useLocale(): LocaleCtx { return useContext(Ctx); }

// ── Locale switcher UI ─────────────────────────────────────────────────────────

export function LocaleSwitcher() {
  const { locale, toggle } = useLocale();
  return (
    <button
      onClick={toggle}
      title={locale === 'vi' ? 'Switch to English' : 'Chuyển sang Tiếng Việt'}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        width: '100%',
        padding: '8px 12px',
        borderRadius: 'var(--r2)',
        border: 'none',
        background: 'rgba(255,255,255,0.06)',
        color: 'rgba(255,255,255,0.7)',
        fontSize: 13,
        fontWeight: 500,
        cursor: 'pointer',
        textAlign: 'left',
      }}
    >
      <span style={{ fontSize: 15 }}>{locale === 'vi' ? '🇻🇳' : '🇬🇧'}</span>
      <span style={{ flex: 1 }}>{locale === 'vi' ? 'Tiếng Việt' : 'English'}</span>
      <span style={{ fontSize: 11, opacity: 0.5 }}>↔</span>
    </button>
  );
}
