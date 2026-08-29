export type AdminTableConfig = {
  table: string;
  label: string;
  description: string;
  visibleColumns: string[];
  searchableColumns: string[];
  editableColumns: string[];
  insertTemplate: Record<string, unknown>;
  orderBy: string;
  canInsert?: boolean;
  canDelete?: boolean;
};

export const adminTables = {
  churches: {
    table: 'churches', label: 'الكنائس', description: 'الجهات المسجلة في المنظومة.',
    visibleColumns: ['name_ar', 'slug', 'phone', 'created_at'],
    searchableColumns: ['name_ar', 'name', 'slug', 'phone'],
    editableColumns: ['name', 'name_ar', 'slug', 'phone', 'address'],
    insertTemplate: { name: '', name_ar: '', slug: '', phone: null, address: null },
    orderBy: 'created_at',
  },
  profiles: {
    table: 'profiles', label: 'المستخدمون', description: 'ملفات المستخدمين والأدوار وحالة الحساب.',
    visibleColumns: ['full_name', 'email', 'role', 'is_active', 'church_id'],
    searchableColumns: ['full_name', 'email', 'phone'],
    editableColumns: ['church_id', 'full_name', 'role', 'email', 'phone', 'is_active'],
    insertTemplate: {}, orderBy: 'created_at', canInsert: false, canDelete: false,
  },
  meetings: {
    table: 'meetings', label: 'الاجتماعات', description: 'الاجتماعات ومواعيد تذكير الحضور.',
    visibleColumns: ['name_ar', 'kind', 'weekday', 'is_active', 'church_id'],
    searchableColumns: ['name_ar', 'name', 'description'],
    editableColumns: ['church_id', 'name', 'name_ar', 'kind', 'weekday', 'attendance_reminder_minutes', 'description', 'is_active', 'created_by'],
    insertTemplate: { church_id: '', name: '', name_ar: '', kind: 'normal', weekday: 7, is_active: true },
    orderBy: 'created_at',
  },
  sunday_school_classes: {
    table: 'sunday_school_classes', label: 'الفصول', description: 'فصول مدارس الأحد وترتيبها.',
    visibleColumns: ['name_ar', 'meeting_id', 'display_order', 'is_active', 'church_id'],
    searchableColumns: ['name_ar', 'name'],
    editableColumns: ['church_id', 'meeting_id', 'name', 'name_ar', 'display_order', 'is_active'],
    insertTemplate: { church_id: '', meeting_id: '', name: '', name_ar: '', display_order: 0, is_active: true },
    orderBy: 'created_at',
  },
  members: {
    table: 'members', label: 'المخدومون', description: 'بيانات الأعضاء والمخدومين وحالة نشاطهم.',
    visibleColumns: ['full_name', 'code', 'scope', 'phone', 'is_active', 'church_id'],
    searchableColumns: ['full_name', 'code', 'phone', 'whatsapp', 'parent_name'],
    editableColumns: ['church_id', 'full_name', 'code', 'scope', 'sunday_school_class_id', 'meeting_id', 'birth_date', 'phone', 'whatsapp', 'parent_name', 'parent_phone', 'notes', 'avatar_url', 'is_active', 'joined_on'],
    insertTemplate: { church_id: '', full_name: '', scope: 'meeting', meeting_id: '', sunday_school_class_id: null, is_active: true },
    orderBy: 'created_at',
  },
  class_assignments: {
    table: 'class_assignments', label: 'تكليفات الفصول', description: 'ربط الخدام بالفصول وصلاحياتهم.',
    visibleColumns: ['user_id', 'class_id', 'can_take_attendance', 'can_view_reports', 'church_id'],
    searchableColumns: [],
    editableColumns: ['church_id', 'class_id', 'user_id', 'can_take_attendance', 'can_view_reports', 'assigned_by'],
    insertTemplate: { church_id: '', class_id: '', user_id: '', can_take_attendance: true, can_view_reports: true },
    orderBy: 'created_at',
  },
  meeting_assignments: {
    table: 'meeting_assignments', label: 'تكليفات الاجتماعات', description: 'ربط الخدام بالاجتماعات وصلاحياتهم.',
    visibleColumns: ['user_id', 'meeting_id', 'can_take_attendance', 'can_view_reports', 'church_id'],
    searchableColumns: [],
    editableColumns: ['church_id', 'meeting_id', 'user_id', 'can_take_attendance', 'can_view_reports', 'assigned_by'],
    insertTemplate: { church_id: '', meeting_id: '', user_id: '', can_take_attendance: true, can_view_reports: true },
    orderBy: 'created_at',
  },
  attendance_sessions: {
    table: 'attendance_sessions', label: 'جلسات الحضور', description: 'شيتات الحضور المنشأة لكل اجتماع وتاريخ.',
    visibleColumns: ['session_date', 'title', 'meeting_id', 'class_id', 'church_id'],
    searchableColumns: ['title'],
    editableColumns: ['church_id', 'meeting_id', 'class_id', 'session_date', 'week_number', 'title', 'created_by'],
    insertTemplate: { church_id: '', meeting_id: '', class_id: null, session_date: '', week_number: 1, title: null },
    orderBy: 'session_date',
  },
  attendance_records: {
    table: 'attendance_records', label: 'سجلات الحضور', description: 'حالة كل عضو داخل جلسة الحضور.',
    visibleColumns: ['status', 'member_id', 'session_id', 'recorded_at', 'church_id'],
    searchableColumns: ['notes'],
    editableColumns: ['church_id', 'session_id', 'member_id', 'status', 'notes', 'recorded_by', 'recorded_at'],
    insertTemplate: { church_id: '', session_id: '', member_id: '', status: 'absent', notes: null },
    orderBy: 'recorded_at',
  },
  follow_ups: {
    table: 'follow_ups', label: 'الافتقاد', description: 'متابعات الغياب والتواصل والنتيجة.',
    visibleColumns: ['contact_status', 'follow_up_date', 'member_id', 'responsible_user_id', 'church_id'],
    searchableColumns: ['reason', 'result'],
    editableColumns: ['church_id', 'member_id', 'session_id', 'reason', 'contact_status', 'result', 'responsible_user_id', 'follow_up_date', 'created_by'],
    insertTemplate: { church_id: '', member_id: '', session_id: null, reason: '', contact_status: 'pending', follow_up_date: '' },
    orderBy: 'created_at',
  },
  invitations: {
    table: 'invitations', label: 'الدعوات', description: 'الدعوات المرسلة وحالتها وصلاحياتها.',
    visibleColumns: ['full_name', 'email', 'role', 'is_used', 'declined_at', 'church_id'],
    searchableColumns: ['full_name', 'email', 'phone', 'code'],
    editableColumns: ['church_id', 'full_name', 'email', 'phone', 'role', 'target_id', 'assignment_scope', 'can_take_attendance', 'can_view_reports', 'code', 'invite_token', 'is_used', 'declined_at'],
    insertTemplate: { church_id: '', full_name: '', email: '', role: 'attendance_officer', code: '', invite_token: '', is_used: false },
    orderBy: 'created_at',
  },
  support_tickets: {
    table: 'support_tickets', label: 'بلاغات المشاكل', description: 'البلاغات المرسلة من داخل التطبيق ومتابعة حالتها.',
    visibleColumns: ['status', 'category', 'subject', 'description', 'reporter_name', 'contact_email', 'platform', 'app_version', 'build_number', 'created_at'],
    searchableColumns: ['subject', 'description', 'reporter_name', 'contact_email'],
    editableColumns: ['status', 'admin_note'],
    insertTemplate: {}, orderBy: 'created_at', canInsert: false, canDelete: false,
  },
  app_usage_events: {
    table: 'app_usage_events', label: 'نشاط التطبيق', description: 'أحداث فتح التطبيق وتسجيل الدخول حسب المنصة والإصدار.',
    visibleColumns: ['event_name', 'platform', 'app_version', 'user_id', 'church_id', 'occurred_at'],
    searchableColumns: ['event_name', 'platform', 'app_version'],
    editableColumns: [], insertTemplate: {}, orderBy: 'occurred_at', canInsert: false, canDelete: false,
  },
  admin_audit_logs: {
    table: 'admin_audit_logs', label: 'سجل الإدارة', description: 'كل تعديل أو حذف تم من لوحة الإدارة.',
    visibleColumns: ['action', 'table_name', 'row_id', 'admin_user_id', 'created_at'],
    searchableColumns: ['action', 'table_name', 'row_id'],
    editableColumns: [], insertTemplate: {}, orderBy: 'created_at', canInsert: false, canDelete: false,
  },
} satisfies Record<string, AdminTableConfig>;

export type AdminTableKey = keyof typeof adminTables;

export function isAdminTable(value: string): value is AdminTableKey {
  return Object.hasOwn(adminTables, value);
}
