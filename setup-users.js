// MGTS Request Hub — one-time user setup script
// Run: node setup-users.js
// Creates 3 test auth users + their roles in Supabase

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL  = 'https://dezhhevqmskbtxmunuem.supabase.co';
const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRlemhoZXZxbXNrYnR4bXVudWVtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODExODk2MDIsImV4cCI6MjA5Njc2NTYwMn0.rCDo4GiV83SxDGngnhIqCjOpLftDg8_NmiWmfpX0rwQ';

const USERS = [
  { email: 'andrew.baines@mgts.co.uk', name: 'Andrew Baines',  role: 'finance'    },
  { email: 'authoriser@mgts.co.uk',    name: 'Test Authoriser', role: 'authoriser' },
  { email: 'requestor@mgts.co.uk',     name: 'Test Requestor',  role: 'requestor'  },
];

const PASSWORD = 'Mgts2025!';

const db = createClient(SUPABASE_URL, SUPABASE_ANON);

async function run() {
  console.log('MGTS User Setup\n');

  for (const u of USERS) {
    process.stdout.write(`Creating ${u.name} (${u.role})... `);

    // 1. Sign up the auth user
    const { data: signUpData, error: signUpErr } = await db.auth.signUp({
      email: u.email, password: PASSWORD,
      options: { data: { name: u.name } }
    });

    if (signUpErr && !signUpErr.message.includes('already registered')) {
      console.log(`SIGN-UP ERROR: ${signUpErr.message}`);
      continue;
    }
    if (signUpErr?.message.includes('already registered')) {
      console.log('already exists — skipping signUp');
    } else {
      console.log('auth user created');
    }

    // 2. Sign in to get a valid session
    const { data: session, error: signInErr } = await db.auth.signInWithPassword({
      email: u.email, password: PASSWORD
    });

    if (signInErr) {
      console.log(`  -> Sign-in failed: ${signInErr.message} (email confirmation may be required)`);
      console.log(`  -> Confirm the email in Supabase Auth > Users, then re-run this script.\n`);
      continue;
    }

    // 3. Insert role (finance user inserts own role first via bootstrap policy)
    const userDb = createClient(SUPABASE_URL, SUPABASE_ANON, {
      global: { headers: { Authorization: `Bearer ${session.session.access_token}` } }
    });

    const { error: roleErr } = await userDb
      .from('user_roles')
      .upsert({ email: u.email, name: u.name, role: u.role }, { onConflict: 'email' });

    if (roleErr) {
      console.log(`  -> Role insert failed: ${roleErr.message}`);
      console.log(`  -> Run create-users.sql in Supabase SQL Editor instead.\n`);
    } else {
      console.log(`  -> Role '${u.role}' inserted OK`);
    }
  }

  console.log('\nDone. Verifying...');
  const { data: roles } = await db.from('user_roles').select('email, name, role');
  if (roles?.length) {
    roles.forEach(r => console.log(`  ${r.role.padEnd(12)} ${r.name} (${r.email})`));
  } else {
    console.log('  No roles found — run create-users.sql in Supabase SQL Editor.');
  }
}

run().catch(console.error);
