import { playStoreUrl } from '../../lib/site';

export function PlayQr() {
  return (
    <section className="share shell" id="share" aria-labelledby="share-title">
      <div className="sharePanel">
        <div className="qrFrame">
          {/* Native img keeps QR pixels sharp for scanning and print. */}
          <img
            src="/play-store-qr.png"
            alt="رمز QR لتحميل Link من Google Play"
            width={1024}
            height={1024}
          />
        </div>
        <div className="shareCopy">
          <span className="sectionTag">للطباعة والشات</span>
          <h2 id="share-title">امسح الكود وحمّل Link</h2>
          <p>
            مناسب للموبايل، وللطباعة، وللإرسال في الشات. احفظ الصورة وابعتها
            للخدام أو علّقها في مكان الخدمة.
          </p>
          <div className="shareActions">
            <a
              className="secondaryButton"
              href={playStoreUrl}
              target="_blank"
              rel="noopener noreferrer"
            >
              فتح Google Play
            </a>
            <a className="textButton" href="/play-store-qr.png" download>
              حفظ صورة QR
            </a>
          </div>
        </div>
      </div>
    </section>
  );
}
