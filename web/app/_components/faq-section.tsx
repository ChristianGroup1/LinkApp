const faqs = [
  {
    question: 'إزاي أبدأ؟',
    answer:
      'حمّل Link من Google Play، سجّل حسابك، وأنشئ خدمتك. بعد كده تضيف الاجتماعات والأعضاء وتبدأ تسجيل الحضور من أول يوم.',
  },
  {
    question: 'إزاي أدعو الخدام؟',
    answer:
      'من التطبيق: الخدام والصلاحيات. اكتب إيميل الخادم، حدّد دوره، وابعت الدعوة. الخادم يفتح الرابط ويقبل أو يرفض. تقدر كمان تبعت الرابط على واتساب.',
  },
  {
    question: 'الصلاحيات بتشتغل إزاي؟',
    answer:
      'كل خادم ياخد صلاحيات تناسب شغله، زي تسجيل الحضور أو التقارير. أمين الفصل والخدام ومسؤول الخدمة كل واحد يشوف اللي يخصّه، من غير اختلاط في الأدوار.',
  },
];

export function FaqSection() {
  return (
    <section className="faq shell" id="faq" aria-labelledby="faq-title">
      <div className="sectionHeading">
        <span>أسئلة قصيرة</span>
        <h2 id="faq-title">أسئلة بتتكرر في أول أسبوع</h2>
        <p>ثلاث إجابات واضحة للبداية، الدعوات، والصلاحيات.</p>
      </div>
      <div className="faqList">
        {faqs.map((item, index) => (
          <details className="faqItem" key={item.question} open={index === 0}>
            <summary>{item.question}</summary>
            <p>{item.answer}</p>
          </details>
        ))}
      </div>
    </section>
  );
}
