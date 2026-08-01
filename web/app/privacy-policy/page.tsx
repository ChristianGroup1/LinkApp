import type { Metadata } from 'next';
import React from 'react';

export const metadata: Metadata = {
  title: 'Privacy Policy | Honara7ty',
  description: 'Privacy Policy for the Honara7ty mobile application provided by fady khayrat.',
};

export default function PrivacyPolicyPage() {
  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <div style={styles.badge}>Official Document</div>
        <h1 style={styles.title}>Privacy Policy</h1>
        <p style={styles.subtitle}>
          <strong>Effective date:</strong> April 24, 2026
        </p>
      </div>

      <div style={styles.card}>
        <p style={styles.intro}>
          This Privacy Policy applies to the <strong>Honara7ty</strong> mobile application (&quot;Application&quot;), 
          provided by <strong>fady khayrat</strong> (&quot;Service Provider&quot;) as a free service. 
          The Application is provided for use as is.
        </p>

        <hr style={styles.divider} />

        <section style={styles.section}>
          <h2 style={styles.sectionTitle}>1. Information We Collect</h2>
          <p style={styles.paragraph}>
            When you use the Application, we may collect and process the following categories of information:
          </p>
          <ul style={styles.list}>
            <li><strong>Account information:</strong> such as your name, email address, and profile details</li>
            <li><strong>Authentication data:</strong> used to sign you in securely</li>
            <li><strong>Devotional data:</strong> such as reminder settings, reading plans, reading activity, devotional tracking data, prayer notes, and reflections</li>
            <li><strong>Device and app information:</strong> such as device type, operating system, app version, country/region, and general diagnostic information</li>
            <li><strong>Usage information:</strong> such as screens viewed, features used, interactions within the app, and time spent using the Application</li>
            <li><strong>Crash, error, and performance data:</strong> to help diagnose issues and improve reliability</li>
          </ul>
          <div style={styles.highlightBox}>
            <strong>Note:</strong> The Application does not collect precise location information from your mobile device for its core functionality.
          </div>
        </section>

        <hr style={styles.divider} />

        <section style={styles.section}>
          <h2 style={styles.sectionTitle}>2. How We Use Information</h2>
          <p style={styles.paragraph}>We use information collected through the Application to:</p>
          <ul style={styles.list}>
            <li>Create and manage your account</li>
            <li>Authenticate you securely</li>
            <li>Save your devotional preferences, reminders, and reading plans</li>
            <li>Store prayer notes, reflections, and devotional activity</li>
            <li>Send reminders and notifications when enabled by you</li>
            <li>Monitor app performance, diagnose crashes and errors, and improve reliability</li>
            <li>Understand how users interact with the Application and improve the user experience</li>
            <li>Maintain security and prevent abuse</li>
          </ul>
        </section>

        <hr style={styles.divider} />

        <section style={styles.section}>
          <h2 style={styles.sectionTitle}>3. Analytics, Diagnostics, and Session Replay</h2>
          <p style={styles.paragraph}>
            The Application uses analytics, diagnostics, and session replay tools to understand app reliability and user experience. These tools may collect information such as:
          </p>
          <ul style={styles.list}>
            <li>App usage and interaction data</li>
            <li>Screen navigation and feature usage</li>
            <li>Device and app diagnostics</li>
            <li>Crash logs, error details, and performance data</li>
            <li>Session-related data to help replay and understand app behavior</li>
          </ul>
          <p style={styles.paragraph}>
            The Application currently uses services such as <strong>Sentry</strong> and <strong>Microsoft Clarity</strong> for error monitoring, diagnostics, analytics, and session replay. These services may receive device, usage, and diagnostic data in order to provide their services.
          </p>
          <div style={styles.warningBox}>
            <strong>Privacy Safeguard:</strong> Where supported by these services, sensitive content is intended to be masked or sanitized. However, no system can guarantee perfect masking in every situation, so users should avoid entering unnecessary highly sensitive personal information into free-text fields.
          </div>
        </section>

        <hr style={styles.divider} />

        <section style={styles.section}>
          <h2 style={styles.sectionTitle}>4. Third-Party Services</h2>
          <p style={styles.paragraph}>
            The Application may use third-party services, including:
          </p>
          <div style={styles.grid}>
            <div style={styles.gridItem}>Google Play Services</div>
            <div style={styles.gridItem}>Supabase</div>
            <div style={styles.gridItem}>Google Sign-In</div>
            <div style={styles.gridItem}>Sentry</div>
            <div style={styles.gridItem}>Microsoft Clarity</div>
          </div>
          <p style={styles.paragraphSmall}>
            These third parties may process information in accordance with their own privacy policies.
          </p>
        </section>

        <hr style={styles.divider} />

        <section style={styles.section}>
          <h2 style={styles.sectionTitle}>5. Notifications</h2>
          <p style={styles.paragraph}>
            If you enable notifications, the Application may use your notification preferences and reminder settings to send devotional reminders and other relevant app notifications.
          </p>
        </section>

        <hr style={styles.divider} />

        <section style={styles.section}>
          <h2 style={styles.sectionTitle}>6. Data Retention</h2>
          <p style={styles.paragraph}>
            The Service Provider retains user-provided account and app data for as long as needed to provide the Application and for a reasonable period afterward, unless a longer retention period is required by law or needed for legitimate operational purposes.
          </p>
          <p style={styles.paragraph}>
            Analytics, diagnostics, and session replay data may be retained by third-party providers according to their own retention policies.
          </p>
          <div style={styles.contactBox}>
            To request deletion of your account or personal data, contact:{' '}
            <a href="mailto:fadykhayrat@gmail.com" style={styles.link}>
              fadykhayrat@gmail.com
            </a>
          </div>
        </section>

        <hr style={styles.divider} />

        <section style={styles.section}>
          <h2 style={styles.sectionTitle}>7. Data Security</h2>
          <p style={styles.paragraph}>
            The Service Provider uses reasonable administrative, technical, and organizational safeguards to protect information processed through the Application. Data transmitted through third-party services is expected to be encrypted in transit where supported by those providers.
          </p>
        </section>

        <hr style={styles.divider} />

        <section style={styles.section}>
          <h2 style={styles.sectionTitle}>8. Children&apos;s Privacy</h2>
          <p style={styles.paragraph}>
            The Application is not intended for children under 13, and the Service Provider does not knowingly collect personal information from children under 13. If you believe a child under 13 has provided personal information, contact{' '}
            <a href="mailto:fadykhayrat@gmail.com" style={styles.link}>
              fadykhayrat@gmail.com
            </a>{' '}
            so appropriate action can be taken.
          </p>
        </section>

        <hr style={styles.divider} />

        <section style={styles.section}>
          <h2 style={styles.sectionTitle}>9. Your Choices</h2>
          <p style={styles.paragraph}>
            You may choose whether to enable notifications in your device settings and within the Application where applicable. You may also stop all collection of information by uninstalling the Application.
          </p>
        </section>

        <hr style={styles.divider} />

        <section style={styles.section}>
          <h2 style={styles.sectionTitle}>10. Changes to This Privacy Policy</h2>
          <p style={styles.paragraph}>
            This Privacy Policy may be updated from time to time. The Service Provider will update the effective date above when changes are made. Continued use of the Application after changes become effective means you accept the updated Privacy Policy.
          </p>
        </section>

        <hr style={styles.divider} />

        <section style={styles.section}>
          <h2 style={styles.sectionTitle}>11. Contact</h2>
          <p style={styles.paragraph}>
            If you have questions about this Privacy Policy or data practices related to the Application, contact:
          </p>
          <p style={styles.contactEmail}>
            <a href="mailto:fadykhayrat@gmail.com" style={styles.linkBold}>
              fadykhayrat@gmail.com
            </a>
          </p>
        </section>
      </div>

      <footer style={styles.footer}>
        &copy; {new Date().getFullYear()} Honara7ty by fady khayrat. All rights reserved.
      </footer>
    </div>
  );
}

const styles: { [key: string]: React.CSSProperties } = {
  container: {
    maxWidth: '900px',
    margin: '0 auto',
    padding: '40px 20px',
    fontFamily:
      "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif",
    color: '#0f172a',
    backgroundColor: '#f8fafc',
    minHeight: '100vh',
    direction: 'ltr',
    textAlign: 'left',
  },
  header: {
    textAlign: 'center',
    marginBottom: '32px',
  },
  badge: {
    display: 'inline-block',
    padding: '6px 16px',
    borderRadius: '9999px',
    backgroundColor: '#e0e7ff',
    color: '#4338ca',
    fontSize: '13px',
    fontWeight: '700',
    letterSpacing: '0.5px',
    textTransform: 'uppercase',
    marginBottom: '12px',
  },
  title: {
    fontSize: '36px',
    fontWeight: '800',
    color: '#1e1b4b',
    margin: '0 0 8px 0',
    letterSpacing: '-0.5px',
  },
  subtitle: {
    fontSize: '15px',
    color: '#64748b',
    margin: 0,
  },
  card: {
    backgroundColor: '#ffffff',
    borderRadius: '24px',
    padding: '40px',
    boxShadow:
      '0 20px 25px -5px rgba(0, 0, 0, 0.05), 0 8px 10px -6px rgba(0, 0, 0, 0.01)',
    border: '1px solid #e2e8f0',
  },
  intro: {
    fontSize: '17px',
    lineHeight: '1.7',
    color: '#334155',
    margin: 0,
  },
  divider: {
    border: 'none',
    borderTop: '1px solid #f1f5f9',
    margin: '32px 0',
  },
  section: {
    marginBottom: '16px',
  },
  sectionTitle: {
    fontSize: '22px',
    fontWeight: '700',
    color: '#1e293b',
    margin: '0 0 16px 0',
  },
  paragraph: {
    fontSize: '15px',
    lineHeight: '1.7',
    color: '#475569',
    margin: '0 0 12px 0',
  },
  paragraphSmall: {
    fontSize: '14px',
    lineHeight: '1.6',
    color: '#64748b',
    marginTop: '12px',
  },
  list: {
    paddingLeft: '24px',
    margin: '0 0 16px 0',
    color: '#334155',
    fontSize: '15px',
    lineHeight: '1.8',
  },
  highlightBox: {
    backgroundColor: '#f0fdf4',
    borderLeft: '4px solid #22c55e',
    padding: '14px 18px',
    borderRadius: '8px',
    color: '#15803d',
    fontSize: '14px',
    marginTop: '16px',
  },
  warningBox: {
    backgroundColor: '#fffbeb',
    borderLeft: '4px solid #f59e0b',
    padding: '14px 18px',
    borderRadius: '8px',
    color: '#b45309',
    fontSize: '14px',
    marginTop: '16px',
  },
  contactBox: {
    backgroundColor: '#f1f5f9',
    padding: '14px 18px',
    borderRadius: '10px',
    color: '#334155',
    fontSize: '14px',
    fontWeight: '600',
    marginTop: '16px',
  },
  grid: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: '10px',
    marginTop: '12px',
  },
  gridItem: {
    backgroundColor: '#f8fafc',
    border: '1px solid #cbd5e1',
    padding: '8px 16px',
    borderRadius: '10px',
    fontSize: '14px',
    fontWeight: '600',
    color: '#334155',
  },
  link: {
    color: '#4f46e5',
    textDecoration: 'underline',
  },
  linkBold: {
    color: '#4f46e5',
    textDecoration: 'none',
    fontWeight: '700',
    fontSize: '17px',
  },
  contactEmail: {
    marginTop: '8px',
    fontSize: '17px',
  },
  footer: {
    textAlign: 'center',
    marginTop: '40px',
    color: '#94a3b8',
    fontSize: '13px',
  },
};
