import { execFileSync } from 'node:child_process';

const patch = execFileSync(
  'git',
  ['log', '--all', '--format=', '--patch', '--no-ext-diff'],
  { encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 }
);

const detectors = [
  ['Supabase secret key', /sb_secret_[A-Za-z0-9_-]{20,}/g],
  ['Razorpay live/test key', /rzp_(?:live|test)_[A-Za-z0-9]{12,}/g],
  ['Razorpay secret assignment', /RAZORPAY_KEY_SECRET\s*[:=]\s*["'][^"']{12,}["']/gi],
  ['Supabase service-role assignment', /SUPABASE_SERVICE_ROLE_KEY\s*[:=]\s*["'][^"']{12,}["']/gi],
  ['AWS access key', /AKIA[0-9A-Z]{16}/g],
  ['Google API key', /AIza[0-9A-Za-z_-]{35}/g],
  ['GitHub personal access token', /(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})/g],
  ['Slack token', /xox[baprs]-[A-Za-z0-9-]{20,}/g],
  ['Private key PEM header', /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/g]
];

const findings = new Set();
const chunks = patch.split(/^diff --git /m);

for (const chunk of chunks) {
  const firstLine = chunk.split('\n', 1)[0];
  const pathMatch = firstLine.match(/^a\/(.+?) b\/(.+)$/);
  if (!pathMatch) continue;

  const filePath = pathMatch[2];
  if (filePath === 'scripts/scan-secret-history.mjs') continue;

  for (const [label, pattern] of detectors) {
    pattern.lastIndex = 0;
    if (pattern.test(chunk)) findings.add(filePath + ' — ' + label);
  }

  const jwtPattern = /eyJ[A-Za-z0-9_-]{20,}\.([A-Za-z0-9_-]{20,})\.[A-Za-z0-9_-]{10,}/g;
  for (const match of chunk.matchAll(jwtPattern)) {
    try {
      const payload = JSON.parse(Buffer.from(match[1], 'base64url').toString('utf8'));
      if (payload.role === 'service_role') {
        findings.add(filePath + ' — JWT with service_role claim');
      }
    } catch {
      // Non-JSON JWT-like strings are ignored by this targeted detector.
    }
  }
}

if (findings.size) {
  console.error('Potential historical credential exposure detected:');
  for (const finding of findings) console.error(' - ' + finding);
  process.exitCode = 1;
} else {
  console.log('Secret-history scan passed: no configured credential patterns found in reachable Git history.');
}
