import Image from 'next/image';

export const revalidate = 3600;

const playStoreUrl =
  'https://play.google.com/store/apps/details?id=com.linkapp.church';
const desktopDownloadUrl =
  'https://github.com/ChristianGroup1/LinkApp/releases/download/desktop-latest/LinkApp-Windows-x64.zip';
const releasesUrl = 'https://github.com/ChristianGroup1/LinkApp/releases';

async function desktopReleaseAvailable() {
  try {
    const response = await fetch(
      'https://api.github.com/repos/ChristianGroup1/LinkApp/releases/tags/desktop-latest',
      {
        headers: { Accept: 'application/vnd.github+json' },
        next: { revalidate: 3600 },
      },
    );
    if (!response.ok) return false;
    const release = (await response.json()) as {
      assets?: Array<{ name?: string }>;
    };
    return Boolean(
      release.assets?.some(
        (asset) => asset.name === 'LinkApp-Windows-x64.zip',
      ),
    );
  } catch {
    return false;
  }
}

const features = [
  {
    icon: '✓',
    title: 'تسجيل الحضور',
    description: 'تسجيل سريع للحضور والغياب مع مراجعة السجلات السابقة.',
  },
  {
    icon: '◷',
    title: 'إدارة الاجتماعات',
    description: 'تنظيم الاجتماعات والفصول والمواعيد والتنبيهات الأسبوعية.',
  },
  {
    icon: '♙',
    title: 'إدارة الأعضاء',
    description: 'بيانات منظمة للأعضاء والخدام وسهولة الوصول لكل التفاصيل.',
  },
  {
    icon: '♡',
    title: 'متابعة الافتقاد',
    description: 'متابعة الغياب وتوثيق التواصل والزيارات في مكان واحد.',
  },
  {
    icon: '⌁',
    title: 'صلاحيات مرنة',
    description: 'أدوار وصلاحيات مناسبة لمسؤولي الخدمة وأمناء الفصول.',
  },
  {
    icon: '↻',
    title: 'يعمل دون اتصال',
    description: 'استمر في العمل عند ضعف الإنترنت مع المزامنة عند عودته.',
  },
];

export default async function HomePage() {
  const hasDesktopRelease = await desktopReleaseAvailable();

  return (
    <main>
      <nav className="nav shell" aria-label="التنقل الرئيسي">
        <a className="brand" href="#top" aria-label="Link — الرئيسية">
          <Image src="/link-logo.png" alt="شعار Link" width={48} height={48} />
          <span>
            <strong>Link</strong>
            <small>إدارة الخدمة ببساطة</small>
          </span>
        </a>
        <div className="navLinks">
          <a href="#features">المميزات</a>
          <a href="#download">تحميل التطبيق</a>
        </div>
      </nav>

      <section className="hero shell" id="top">
        <div className="heroCopy">
          <div className="eyebrow"><span /> منظومة واحدة لخدمة أكثر تنظيمًا</div>
          <h1>
            ركّز في <em>الخدمة</em>
            <br />واترك التنظيم لـ Link
          </h1>
          <p>
            تطبيق عربي متكامل لإدارة الاجتماعات والحضور والأعضاء والافتقاد،
            مصمم للكنائس والخدمات التي تريد رؤية أوضح ومتابعة أسهل.
          </p>

          <div className="downloadActions" id="download">
            <a
              className="downloadButton primary"
              href={playStoreUrl}
              target="_blank"
              rel="noreferrer"
            >
              <span className="storeIcon">▶</span>
              <span><small>حمّل التطبيق من</small>Google Play</span>
            </a>
            <a
              className={`downloadButton desktop ${hasDesktopRelease ? '' : 'pending'}`}
              href={hasDesktopRelease ? desktopDownloadUrl : releasesUrl}
              target="_blank"
              rel="noreferrer"
              aria-label={
                hasDesktopRelease
                  ? 'تحميل Link لنظام Windows'
                  : 'متابعة إصدار Windows القادم'
              }
            >
              <span className="windowsIcon">⊞</span>
              <span>
                <small>{hasDesktopRelease ? 'تحميل مباشر' : 'قريبًا'}</small>
                Link for Windows
              </span>
            </a>
          </div>
          <div className="platformNote">
            <span>✓ Android</span>
            <span>✓ Windows 10/11</span>
            <span>✓ مزامنة آمنة</span>
          </div>
        </div>

        <div
          className="heroVisual"
          role="img"
          aria-label="نظرة توضيحية على لوحة تحكم Link"
        >
          <div className="glow glowOne" />
          <div className="glow glowTwo" />
          <div className="appCard">
            <div className="appCardTop">
              <div>
                <small>مساء الخير 👋</small>
                <strong>لوحة متابعة الخدمة</strong>
              </div>
              <Image src="/link-logo.png" alt="" width={54} height={54} />
            </div>
            <div className="statGrid">
              <div><span className="dot indigo" /><strong>١٢٨</strong><small>عضوًا</small></div>
              <div><span className="dot teal" /><strong>٨٧٪</strong><small>نسبة الحضور</small></div>
              <div><span className="dot gold" /><strong>٦</strong><small>اجتماعات</small></div>
            </div>
            <div className="attendanceCard">
              <div className="attendanceTitle">
                <span>الحضور هذا الأسبوع</span><strong>٨٧٪</strong>
              </div>
              <div className="progress"><span /></div>
              <div className="miniBars">
                {[42, 68, 54, 82, 73, 91, 78].map((height, index) => (
                  <i key={index} style={{ height: `${height}%` }} />
                ))}
              </div>
            </div>
            <div className="nextMeeting">
              <span className="calendarIcon">١٠</span>
              <div><small>الاجتماع القادم</small><strong>اجتماع الشباب — الجمعة ٧:٠٠م</strong></div>
              <b>‹</b>
            </div>
          </div>
          <div className="floatingBadge badgeMembers"><span>+١٢</span> عضو جديد</div>
          <div className="floatingBadge badgeSync"><span>✓</span> تمت المزامنة</div>
        </div>
      </section>

      <section className="trustStrip">
        <div className="shell trustContent">
          <strong>كل أدوات الخدمة في مكان واحد</strong>
          <span>حضور</span><i />
          <span>اجتماعات</span><i />
          <span>أعضاء</span><i />
          <span>افتقاد</span><i />
          <span>تقارير</span>
        </div>
      </section>

      <section className="features shell" id="features">
        <div className="sectionHeading">
          <span>مصمم للخدمة اليومية</span>
          <h2>كل ما تحتاجه لإدارة خدمتك بوضوح</h2>
          <p>أدوات عملية، واجهة عربية بسيطة، ومعلوماتك متاحة على الموبايل والكمبيوتر.</p>
        </div>
        <div className="featureGrid">
          {features.map((feature, index) => (
            <article className="featureCard" key={feature.title}>
              <div className={`featureIcon color${(index % 3) + 1}`}>{feature.icon}</div>
              <h3>{feature.title}</h3>
              <p>{feature.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="desktopSection shell">
        <div className="desktopPanel">
          <div className="desktopCopy">
            <span className="sectionTag">Link على الكمبيوتر</span>
            <h2>نفس بيانات خدمتك، على شاشة أكبر</h2>
            <p>
              نسخة Windows تمنحك مساحة أوسع للمراجعة والإدارة، مع نفس الحساب
              والمزامنة الموجودة على تطبيق Android.
            </p>
            <ul>
              <li>تسجيل الدخول بنفس حساب Link</li>
              <li>مزامنة مباشرة وآمنة للبيانات</li>
              <li>حزمة ZIP سهلة التشغيل على Windows 10 و11</li>
            </ul>
            <a
              className={`secondaryButton ${hasDesktopRelease ? '' : 'pending'}`}
              href={hasDesktopRelease ? desktopDownloadUrl : releasesUrl}
              target="_blank"
              rel="noreferrer"
            >
              {hasDesktopRelease ? 'تنزيل نسخة Windows ↓' : 'نسخة Windows تُجهّز للنشر'}
            </a>
          </div>
          <div className="desktopMockup" aria-hidden="true">
            <div className="windowBar"><i /><i /><i /><span>Link</span></div>
            <div className="windowBody">
              <aside><Image src="/link-logo.png" alt="" width={58} height={58} /><b /><b /><b /><b /></aside>
              <div className="windowContent"><span /><div><i /><i /><i /></div><strong /><strong /><strong /></div>
            </div>
          </div>
        </div>
      </section>

      <section className="cta">
        <div className="shell ctaInner">
          <Image src="/link-logo.png" alt="شعار Link" width={96} height={96} />
          <div><h2>ابدأ تنظيم خدمتك اليوم</h2><p>حمّل Link وسجّل دخولك، وكل أدوات الخدمة ستكون بين يديك.</p></div>
          <a href={playStoreUrl} target="_blank" rel="noreferrer">تحميل من Google Play</a>
        </div>
      </section>

      <footer className="footer shell">
        <div className="brand footerBrand">
          <Image src="/link-logo.png" alt="" width={40} height={40} />
          <span><strong>Link</strong><small>متصلين بمحبة، ننمو معًا</small></span>
        </div>
        <p>© 2026 Link. جميع الحقوق محفوظة.</p>
        <a href="/support">الدعم</a>
        <a href="/privacy-policy">سياسة الخصوصية</a>
      </footer>
    </main>
  );
}
