import Image from 'next/image';
import { FaqSection } from './_components/faq-section';
import { PlayQr } from './_components/play-qr';
import { SiteHeader } from './_components/site-header';
import {
  AttendanceIcon,
  FollowUpIcon,
  MeetingsIcon,
  MembersIcon,
  OfflineIcon,
  PlayStoreIcon,
  RolesIcon,
  WindowsIcon,
} from './_components/icons';
import {
  desktopDownloadUrl,
  playStoreUrl,
  releasesUrl,
} from '../lib/site';

export const revalidate = 3600;

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
    icon: AttendanceIcon,
    title: 'تسجيل الحضور',
    description: 'سجّل الحضور والغياب بسرعة، وارجع للسجلات السابقة وقت ما تحتاج.',
  },
  {
    icon: MeetingsIcon,
    title: 'إدارة الاجتماعات',
    description: 'نظّم الاجتماعات والفصول والمواعيد والتنبيهات الأسبوعية.',
  },
  {
    icon: MembersIcon,
    title: 'إدارة الأعضاء',
    description: 'بيانات منظمة للأعضاء والخدام، ووصول سهل لكل التفاصيل.',
  },
  {
    icon: FollowUpIcon,
    title: 'متابعة الافتقاد',
    description: 'تابع الغياب، وثبّت التواصل والزيارات في مكان واحد.',
  },
  {
    icon: RolesIcon,
    title: 'صلاحيات مرنة',
    description: 'أدوار واضحة لمسؤولي الخدمة وأمناء الفصول دون تعقيد.',
  },
  {
    icon: OfflineIcon,
    title: 'يعمل دون اتصال',
    description: 'كمّل شغلك عند ضعف الإنترنت، والمزامنة تتم عند عودته.',
  },
];

const steps = [
  {
    number: '١',
    title: 'حمّل التطبيق',
    description: 'من Google Play على الموبايل، أو من حزمة Windows على الكمبيوتر.',
  },
  {
    number: '٢',
    title: 'ادعُ فريق الخدمة',
    description: 'أضف الخدام وأمناء الفصول بصلاحيات مناسبة لكل دور.',
  },
  {
    number: '٣',
    title: 'سجّل وتابع',
    description: 'حضور، غياب، افتقاد، وتقارير — كلها في منظومة واحدة.',
  },
];

const audiences = [
  {
    title: 'أمين الفصل',
    description: 'تسجيل حضور اليوم ومتابعة من تغيّب دون أوراق متناثرة.',
  },
  {
    title: 'الخادم',
    description: 'شوف مخدوميك، سجّل الافتقاد، وخلّي المتابعة واضحة.',
  },
  {
    title: 'مسؤول الخدمة',
    description: 'تقارير، صلاحيات، وصورة كاملة للخدمة من مكان واحد.',
  },
];

export default async function HomePage() {
  const hasDesktopRelease = await desktopReleaseAvailable();
  const windowsHref = hasDesktopRelease ? desktopDownloadUrl : releasesUrl;
  const windowsLabel = hasDesktopRelease
    ? 'تحميل Link لنظام Windows'
    : 'متابعة إصدار Windows القادم';

  return (
    <>
      <a className="skipLink" href="#content">
        تخطي إلى المحتوى
      </a>
      <SiteHeader />
      <main id="content">
        <section className="hero shell" aria-labelledby="hero-title">
          <div className="heroCopy">
            <p className="eyebrow">
              <span /> منظومة واحدة لخدمة أكثر تنظيمًا
            </p>
            <h1 id="hero-title">
              ركّز في <em>الخدمة</em>
              <br />
              واترك التنظيم لـ Link
            </h1>
            <p>
              تطبيق عربي للكنائس والخدمات: اجتماعات، حضور، أعضاء، وافتقاد —
              بواجهة بسيطة تعمل على الموبايل والكمبيوتر حتى مع ضعف الإنترنت.
            </p>

            <div className="downloadActions" id="download">
              <a
                className="downloadButton primary"
                href={playStoreUrl}
                target="_blank"
                rel="noopener noreferrer"
              >
                <PlayStoreIcon className="storeIcon" />
                <span>
                  <small>حمّل التطبيق من</small>
                  Google Play
                </span>
              </a>
              <a
                className={`downloadButton desktop${hasDesktopRelease ? '' : ' pending'}`}
                href={windowsHref}
                target="_blank"
                rel="noopener noreferrer"
                aria-label={windowsLabel}
              >
                <WindowsIcon className="windowsIcon" />
                <span>
                  <small>{hasDesktopRelease ? 'تحميل مباشر' : 'قريبًا'}</small>
                  Link for Windows
                </span>
              </a>
            </div>
            <ul className="platformNote">
              <li>Android</li>
              <li>
                <span dir="ltr">Windows 10 / 11</span>
              </li>
              <li>مزامنة آمنة</li>
            </ul>
          </div>

          <div className="heroVisual">
            <div className="glow glowOne" />
            <div className="glow glowTwo" />
            <div className="phoneFrame" aria-hidden="true">
              <div className="phoneNotch" />
              <div className="appCard">
                <div className="appCardTop">
                  <div>
                    <small>مساء الخير</small>
                    <strong>لوحة متابعة الخدمة</strong>
                  </div>
                  <Image src="/link-logo.png" alt="" width={40} height={40} />
                </div>
                <div className="statGrid">
                  <div>
                    <span className="dot indigo" />
                    <strong>١٢٨</strong>
                    <small>عضوًا</small>
                  </div>
                  <div>
                    <span className="dot teal" />
                    <strong>٨٧٪</strong>
                    <small>نسبة الحضور</small>
                  </div>
                  <div>
                    <span className="dot gold" />
                    <strong>٦</strong>
                    <small>اجتماعات</small>
                  </div>
                </div>
                <div className="attendanceCard">
                  <div className="attendanceTitle">
                    <span>الحضور هذا الأسبوع</span>
                    <strong>٨٧٪</strong>
                  </div>
                  <div className="progress">
                    <span />
                  </div>
                  <div className="miniBars">
                    {[42, 68, 54, 82, 73, 91, 78].map((height) => (
                      <i key={height} style={{ height: `${height}%` }} />
                    ))}
                  </div>
                </div>
                <div className="nextMeeting">
                  <span className="calendarIcon">١٠</span>
                  <div>
                    <small>الاجتماع القادم</small>
                    <strong>اجتماع الشباب — الجمعة ٧:٠٠م</strong>
                  </div>
                </div>
              </div>
            </div>
            <div className="floatingBadge badgeMembers">
              <span>+١٢</span> عضو جديد
            </div>
            <div className="floatingBadge badgeSync">
              <span>✓</span> تمت المزامنة
            </div>
          </div>
        </section>

        <section className="trustStrip">
          <div className="shell trustContent">
            <strong>كل أدوات الخدمة في مكان واحد</strong>
            <span>حضور</span>
            <i />
            <span>اجتماعات</span>
            <i />
            <span>أعضاء</span>
            <i />
            <span>افتقاد</span>
            <i />
            <span>تقارير</span>
          </div>
        </section>

        <section className="steps shell" id="how" aria-labelledby="how-title">
          <div className="sectionHeading">
            <span>ثلاث خطوات للبداية</span>
            <h2 id="how-title">ابدأ اليوم من غير تعقيد</h2>
            <p>من التحميل إلى المتابعة اليومية — المسار واضح لكل خادم في الفريق.</p>
          </div>
          <ol className="stepGrid">
            {steps.map((step) => (
              <li className="stepCard" key={step.title}>
                <span className="stepNumber">{step.number}</span>
                <h3>{step.title}</h3>
                <p>{step.description}</p>
              </li>
            ))}
          </ol>
        </section>

        <section className="features shell" id="features" aria-labelledby="features-title">
          <div className="sectionHeading">
            <span>مصمم للخدمة اليومية</span>
            <h2 id="features-title">كل ما تحتاجه لإدارة خدمتك بوضوح</h2>
            <p>
              أدوات عملية، عربي واضح، وبياناتك متاحة على الموبايل والكمبيوتر.
            </p>
          </div>
          <div className="featureGrid">
            {features.map((feature, index) => {
              const Icon = feature.icon;
              return (
                <article className="featureCard" key={feature.title}>
                  <div className={`featureIcon color${(index % 3) + 1}`}>
                    <Icon />
                  </div>
                  <h3>{feature.title}</h3>
                  <p>{feature.description}</p>
                </article>
              );
            })}
          </div>
        </section>

        <section className="audience shell" aria-labelledby="audience-title">
          <div className="sectionHeading">
            <span>لمن صُمّم Link؟</span>
            <h2 id="audience-title">كل دور في الخدمة له مكانه</h2>
          </div>
          <div className="audienceGrid">
            {audiences.map((item) => (
              <article className="audienceCard" key={item.title}>
                <h3>{item.title}</h3>
                <p>{item.description}</p>
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
                className={`secondaryButton${hasDesktopRelease ? '' : ' pending'}`}
                href={windowsHref}
                target="_blank"
                rel="noopener noreferrer"
              >
                {hasDesktopRelease
                  ? 'تنزيل نسخة Windows'
                  : 'نسخة Windows تُجهّز للنشر'}
              </a>
            </div>
            <div className="desktopMockup" aria-hidden="true">
              <div className="windowBar">
                <i />
                <i />
                <i />
                <span>Link</span>
              </div>
              <div className="windowBody">
                <aside>
                  <Image src="/link-logo.png" alt="" width={42} height={42} />
                  <b />
                  <b />
                  <b />
                  <b />
                </aside>
                <div className="windowContent">
                  <span />
                  <div>
                    <i />
                    <i />
                    <i />
                  </div>
                  <strong />
                  <strong />
                </div>
              </div>
            </div>
          </div>
        </section>

        <FaqSection />
        <PlayQr />

        <section className="cta">
          <div className="shell ctaInner">
            <Image src="/link-logo.png" alt="" width={80} height={80} />
            <div>
              <h2>ابدأ تنظيم خدمتك اليوم</h2>
              <p>حمّل Link وسجّل دخولك — أدوات الخدمة كلها بين يديك.</p>
            </div>
            <a href={playStoreUrl} target="_blank" rel="noopener noreferrer">
              تحميل من Google Play
            </a>
          </div>
        </section>
      </main>

      <footer className="footer shell">
        <div className="brand footerBrand">
          <Image src="/link-logo.png" alt="" width={40} height={40} />
          <span>
            <strong>Link</strong>
            <small>متصلين بمحبة، ننمو معًا</small>
          </span>
        </div>
        <p>© 2026 Link. جميع الحقوق محفوظة.</p>
        <a href="/support">الدعم</a>
        <a href="/privacy-policy">سياسة الخصوصية</a>
      </footer>
    </>
  );
}
