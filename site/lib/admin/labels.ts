export const adminColumnLabels: Record<string, string> = {
  church_id: 'الكنيسة', user_id: 'الخادم', responsible_user_id: 'مسؤول المتابعة',
  meeting_id: 'الاجتماع', class_id: 'الفصل', member_id: 'المخدوم', session_id: 'جلسة الحضور',
  created_by: 'أُنشئ بواسطة', assigned_by: 'كُلّف بواسطة', recorded_by: 'سجّل بواسطة', admin_user_id: 'المدير',
  row_id: 'السجل المتأثر', name: 'الاسم', name_ar: 'الاسم بالعربية', full_name: 'الاسم الكامل', slug: 'الرابط المختصر',
  phone: 'الهاتف', email: 'البريد الإلكتروني', address: 'العنوان', role: 'الدور', kind: 'نوع الاجتماع', weekday: 'يوم الأسبوع',
  attendance_reminder_minutes: 'دقائق التذكير', description: 'الوصف', is_active: 'الحساب نشط', display_order: 'ترتيب العرض',
  code: 'الكود', scope: 'نطاق المخدوم', sunday_school_class_id: 'فصل مدارس الأحد', birth_date: 'تاريخ الميلاد',
  whatsapp: 'واتساب', parent_name: 'اسم ولي الأمر', parent_phone: 'هاتف ولي الأمر', notes: 'ملاحظات', avatar_url: 'رابط الصورة',
  joined_on: 'تاريخ الانضمام', session_date: 'تاريخ الجلسة', week_number: 'رقم الأسبوع', title: 'عنوان الجلسة',
  status: 'الحالة', reason: 'سبب المتابعة', result: 'نتيجة المتابعة', contact_status: 'حالة التواصل', follow_up_date: 'تاريخ المتابعة',
  target_id: 'التكليف المستهدف', assignment_scope: 'نطاق التكليف', can_take_attendance: 'يسجل الحضور', can_view_reports: 'يشاهد التقارير',
  invite_token: 'رمز رابط الدعوة', declined_at: 'وقت الرفض', admin_note: 'ملاحظة المدير', is_used: 'تم استخدام الدعوة',
  category: 'التصنيف', subject: 'الموضوع', reporter_name: 'اسم المبلّغ', contact_email: 'بريد التواصل', platform: 'المنصة',
  app_version: 'إصدار التطبيق', build_number: 'رقم البناء', event_name: 'الحدث', occurred_at: 'وقت النشاط', created_at: 'تاريخ الإنشاء',
  updated_at: 'تاريخ التحديث', action: 'الإجراء', table_name: 'اسم الجدول',
};

export const adminWeekdayNames = [
  'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد',
];

export function formatAdminCell(column: string, value: unknown) {
  if (column === 'weekday') {
    const index = Number(value) - 1;
    if (Number.isInteger(index) && index >= 0 && index < adminWeekdayNames.length) return adminWeekdayNames[index];
  }
  return value === null || value === undefined || value === '' ? '—' : String(value);
}
