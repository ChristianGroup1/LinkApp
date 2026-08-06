'use client';

export default function ConfirmDeleteButton() {
  return (
    <button
      type="submit"
      className="dangerButton"
      onClick={(event) => {
        if (!window.confirm('هل أنت متأكد؟ قد يؤدي الحذف إلى حذف بيانات مرتبطة بسبب العلاقات داخل قاعدة البيانات.')) {
          event.preventDefault();
        }
      }}
    >
      حذف السجل
    </button>
  );
}

