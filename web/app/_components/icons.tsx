type IconProps = {
  className?: string;
};

export function PlayStoreIcon({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" aria-hidden="true">
      <path
        fill="currentColor"
        d="M3.6 2.3c-.4.2-.6.7-.6 1.2v16.9c0 .6.2 1 .6 1.3l10.2-9.7L3.6 2.3Zm12.2 7.2-2.2 2.1 2.2 2.1 4.6-2.6c.8-.5.8-1.6 0-2.1l-4.6 2.5ZM4.8 21.5 13.2 13l2.4 2.3-10.8 6.2Zm10.8-12.1L13.2 11 4.8 2.5l10.8 6.9Z"
      />
    </svg>
  );
}

export function WindowsIcon({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" aria-hidden="true">
      <path
        fill="currentColor"
        d="M3 5.1 11.2 4v7.4H3V5.1Zm8.2 8.4V19.9L3 18.8v-5.3h8.2ZM12.4 4 21 2.8v8.6h-8.6V4Zm8.6 9.4V21l-8.6-1.2v-6.4H21Z"
      />
    </svg>
  );
}

export function AttendanceIcon({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M8 3v3M16 3v3M5 8h14M6.5 5.5h11A1.5 1.5 0 0 1 19 7v12a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 5 19V7a1.5 1.5 0 0 1 1.5-1.5Z"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
      />
      <path
        d="m9 14 2.1 2.1L16 11.2"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

export function MeetingsIcon({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle cx="12" cy="12" r="8.2" stroke="currentColor" strokeWidth="1.8" />
      <path
        d="M12 8v4.3l2.8 1.7"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

export function MembersIcon({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle cx="9" cy="8.2" r="2.4" stroke="currentColor" strokeWidth="1.8" />
      <circle cx="16.2" cy="9" r="2" stroke="currentColor" strokeWidth="1.8" />
      <path
        d="M4.8 18.2c.5-2.8 2.5-4.3 4.4-4.3s3.9 1.5 4.4 4.3"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
      />
      <path
        d="M13.6 13.9c1.4-.3 3.4.5 4.4 3.3"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
      />
    </svg>
  );
}

export function FollowUpIcon({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M12.8 18.7 8 20.2l1.5-4.8 8.5-8.5a2.1 2.1 0 0 1 3 3l-8.2 8.8Z"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinejoin="round"
      />
      <path
        d="M14.6 7.4 16.7 9.5"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
      />
    </svg>
  );
}

export function RolesIcon({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M12 3.8 19 7v5.1c0 4.2-2.9 6.8-7 8.1-4.1-1.3-7-3.9-7-8.1V7l7-3.2Z"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinejoin="round"
      />
      <path
        d="m9.3 12.1 1.9 1.9 3.6-3.8"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

export function OfflineIcon({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M7 15.2a5.4 5.4 0 0 1 10 0M4.4 12.4a8.6 8.6 0 0 1 15.2 0"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
      />
      <circle cx="12" cy="18.2" r="1.3" fill="currentColor" />
    </svg>
  );
}
