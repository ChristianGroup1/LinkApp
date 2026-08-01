import type { Metadata } from 'next';
import React from 'react';

export const metadata: Metadata = {
  title: 'Privacy Policy | LinkApp — Church Management',
  description: 'Privacy Policy for the LinkApp mobile application provided by fady khayrat.',
};

export default function PrivacyPolicyPage() {
  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <div style={styles.badge}>Official Document</div>
        <h1 style={styles.title}>Privacy Policy</h1>
        <p style={styles.subtitle}>
          <strong>Effective date:</strong> August 2, 2026
        </p>
      </div>

      <div style={styles.card}>
        <p style={styles.intro}>
          This Privacy Policy applies to the <strong>LinkApp</strong> mobile application (&quot;Application&quot;), 
          provided by <strong>fady khayrat</strong> (&quot;Service Provider&quot;) as a free service. 
          LinkApp is a comprehensive church management, attendance tracking, and Sunday School service management system. 
          The Application is provided for use as is.
        </p>

        <hr style={styles.divider} />

        <section style={styles.section}>
          <h2 style={styles.sectionTitle}>1. Information We Collect</h2>
          <p style={styles.paragraph}>
            When you use the Application to manage church services, attendance, or servant duties, we may collect and process the following categories of information:
          </p>
          <ul style={styles.list}>
            <li><strong>Account &amp; Profile Information:</strong> your full name, email address, assigned church ID, and service role (such as Church Admin or Attendance Officer).</li>
            <li><strong>Authentication Data:</strong> credentials and security tokens used to sign you into your church workspace securely via Supabase Auth.</li>
            <li><strong>Church &amp; Service Data:</strong> attendance records, member directories, Sunday School class assignments, meeting schedules, and visitation logs.</li>
            <li><strong>Invitation Data:</strong> deep-link tokens and invitation records used to invite servants or members to join your church organization.</li>
            <li><strong>Device &amp; App Information:</strong> device type, operating system version, app version, and general diagnostic logs to ensure reliable synchronization.</li>
            <li><strong>Local Notification Preferences:</strong> reminder settings and scheduled meeting alert preferences for taking attendance.</li>
          </ul>
          <div style={styles.highlightBox}>
            <strong>Location Notice:</strong> LinkApp does not collect precise GPS or real-time location data from your mobile device.
          </div>
        </section>

        <hr style={styles.divider} />

        <section style={styles.section}>
          <h2 style={styles.sectionTitle}>2. How We Use Information</h2>
          <p style={styles.paragraph}>We use the information collected through LinkApp to:</p>
          <ul style={styles.list}>
            <li>Create and manage user accounts and church organizational structures</li>
            <li>Authenticate servants and church administrators securely</li>
            <li>Record, manage, and calculate weekly attendance statistics for Sunday School classes and meetings</li>
            <li>Deliver scheduled local meeting notifications and attendance reminders on your mobile device</li>
            <li>Enable offline data synchronization so attendance can be recorded even without internet connectivity</li>
            <li>Manage servant permissions, member directories, and invitation links</li>
            <li>Monitor app performance, diagnose system errors, and maintain data security</li>
          </ul>
        </section>

        <hr style={styles.divider} />

        <section style={styles.section}>
          <h2 style={styles.sectionTitle}>3. Third-Party Services</h2>
          <p style={styles.paragraph}>
            The Application uses trusted third-party infrastructure and services to operate securely:
          </p>
          <div style={styles.grid}>
            <div style={styles.gridItem}>Google Play Services</div>
            <div style={styles.gridItem}>Supabase (Database &amp; Authentication)</div>
            <div style={styles.gridItem}>Flutter Local Notifications</div>
          </div>
          <p style={styles.paragraphSmall}>
            These third-party service providers process data in accordance with their strict privacy and security standards.
          </p>
        </section>

        <hr style={styles.divider} />

        <section style={styles.section}>
          <h2 style={styles.sectionTitle}>4. Notifications &amp; Reminders</h2>
          <p style={styles.paragraph}>
            If enabled by you, LinkApp uses local device notification services to deliver recurring weekly reminders for upcoming meeting times, ensuring attendance taking is never missed. You can manage or disable notification permissions at any time through your device settings.
          </p>
        </section>

        <hr style={styles.divider} />

        <section style={styles.section}>
          <h2 style={styles.sectionTitle}>5. Data Security</h2>
          <p style={styles.paragraph}>
            We take data security very seriously. All communication between LinkApp and server infrastructure is encrypted in transit using industry-standard TLS/SSL encryption. Access to church data is strictly controlled via role-based access policies (Row Level Security).
          </p>
        </section>

        <hr style={styles.divider} />

        <section style={styles.section}>
          <h2 style={styles.sectionTitle}>6. Data Retention &amp; Account Deletion</h2>
          <p style={styles.paragraph}>
            We retain church, attendance, and account data for as long as necessary to provide the service to your church organization. Church administrators or servants may request deletion of their account or church records at any time.
          </p>
          <div style={styles.contactBox}>
            To request account deletion or data removal, please contact us at:{' '}
            <a href="mailto:fadykhayrat@gmail.com" style={styles.link}>
              fadykhayrat@gmail.com
            </a>
          </div>
        </section>

        <hr style={styles.divider} />

        <section style={styles.section}>
          <h2 style={styles.sectionTitle}>7. Children&apos;s Privacy</h2>
          <p style={styles.paragraph}>
            LinkApp is designed for church servants and administrators. Member attendance records entered by servants (including Sunday School children) are stored strictly for church administrative purposes and are not shared with third-party marketers or advertisers.
          </p>
        </section>

        <hr style={styles.divider} />

        <section style={styles.section}>
          <h2 style={styles.sectionTitle}>8. Changes to This Privacy Policy</h2>
          <p style={styles.paragraph}>
            This Privacy Policy may be updated periodically. The effective date above will reflect the latest revision. Continued use of LinkApp indicates your acceptance of the updated policy.
          </p>
        </section>

        <hr style={styles.divider} />

        <section style={styles.section}>
          <h2 style={styles.sectionTitle}>9. Contact Us</h2>
          <p style={styles.paragraph}>
            If you have any questions or concerns regarding this Privacy Policy or data privacy in LinkApp, please contact:
          </p>
          <p style={styles.contactEmail}>
            <a href="mailto:fadykhayrat@gmail.com" style={styles.linkBold}>
              fadykhayrat@gmail.com
            </a>
          </p>
        </section>
      </div>

      <footer style={styles.footer}>
        &copy; {new Date().getFullYear()} LinkApp by fady khayrat. All rights reserved.
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
