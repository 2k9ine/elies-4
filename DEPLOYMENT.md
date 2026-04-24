# Deployment Guide — Eli's Learning Music School App

## Prerequisites

- GitHub account
- Netlify account
- Supabase account
- Anthropic API key (for report generation)

---

## Step 1: Supabase Setup

### 1.1 Create a Supabase Project

1. Go to [supabase.com](https://supabase.com) and create a new project
2. Note your **Project URL** and **anon/public key** from Settings → API
3. Choose a secure password for your admin account

### 1.2 Run the Database Schema

1. In Supabase Dashboard, go to **SQL Editor**
2. Copy and paste the contents of `music-school-schema.sql`
3. Click **Run** to execute

This creates:
- `profiles` - User auth profiles
- `students` - Student records
- `books` - Book inventory
- `book_issuances` - Book checkout tracking
- `observations` - Teacher observation notes
- `reports` - Generated progress reports
- `attendance` - Attendance records
- `music_pieces` - Student piece progress

### 1.3 Enable Row Level Security

RLS is enabled by the schema. For initial testing, the policies allow all operations for authenticated users.

### 1.4 Create Your Admin Account

1. In Supabase Dashboard → **Authentication** → **Users**
2. Click **Add user** → **Create new user**
3. Enter your email and a secure password
4. Set `full_name` to your name

---

## Step 2: Deploy to Netlify

### 2.1 Create a GitHub Repository

1. Go to [github.com](https://github.com) and sign in
2. Click the **+** icon (top right) → **New repository**
3. Fill in:
   - **Repository name:** `elis-learning` (or your choice)
   - **Description:** `Music school management app`
   - **Visibility:** Private (recommended)
   - **Do NOT** initialize with README (we already have files)
4. Click **Create repository**

### 2.2 Prepare Your Local Files

Ensure your project folder contains:
```
/
├── index.html          (main application)
├── config.js           (credentials - must be gitignored)
├── netlify.toml        (Netlify configuration)
├── .gitignore          (ignore config.js and .env)
└── netlify/
    └── functions/
        └── generate-report.js
```

### 2.3 Add .gitignore

Create a file called `.gitignore` in your project root:
```
config.js
config.local.js
.env
node_modules/
```

### 2.4 Push to GitHub

Open terminal in your project folder and run:

```bash
# Initialize git (if not already)
git init

# Add all files
git add .

# Commit
git commit -m "Initial commit - music school management app"

# Connect to GitHub (replace with your actual repo URL)
git remote add origin https://github.com/YOUR_USERNAME/elis-learning.git

# Push
git branch -M main
git push -u origin main
```

You'll be asked for your GitHub credentials. Use a [Personal Access Token](https://github.com/settings/tokens) instead of your password.

### 2.5 Connect Netlify to GitHub

1. Log in to [Netlify](https://netlify.com)
2. Click **Add new site** → **Import an existing project**
3. Under **GitHub**, click **Install GitHub App** (first time only)
4. Grant Netlify access to your repositories
5. Find and select your `elis-learning` repository
6. **Deploy settings** (critical!):
   - **Build command:** (leave empty — vanilla JS needs no build)
   - **Publish directory:** `.` (just a period, meaning current root)
7. Click **Deploy site**
8. Wait 30-60 seconds — Netlify will pull and deploy automatically

### 2.6 Verify the Deploy

1. After deploy completes, Netlify shows your site URL (e.g., `random-name-123.netlify.app`)
2. Click the link to verify it loads
3. Any future pushes to `main` branch will auto-deploy

---

## Step 3: Configure Environment Variables

### 3.1 In Netlify Dashboard

1. Go to **Site settings** → **Environment variables**
2. Add each variable:

| Key | Value | Notes |
|-----|-------|-------|
| `SUPABASE_URL` | `https://xxxx.supabase.co` | From Supabase → Settings → API |
| `SUPABASE_ANON_KEY` | `eyJ...` | From Supabase → Settings → API |
| `OPENROUTER_API_KEY` | `sk-or-v1...` | From OpenRouter dashboard (free tier available) |

> **Note:** OpenRouter offers free credits and has models like Llama 3.1 8B that are free. Sign up at [openrouter.ai](https://openrouter.ai) to get your API key.

### 3.2 Update config.js

After deployment, Netlify will inject these env vars. But for local testing, create a local config:

**config.local.js** (never commit this):
```javascript
window.APP_CONFIG = {
  SUPABASE_URL: 'https://xxxx.supabase.co',
  SUPABASE_ANON_KEY: 'eyJ...',
  GENERATE_REPORT_FUNCTION: '/.netlify/functions/generate-report',
};
```

---

## Step 4: Verify Deployment

### 5.1 Test Authentication

1. Visit your Netlify URL
2. Try to log in with your Supabase credentials
3. If you see errors, check browser console and Netlify function logs

### 5.2 Test Supabase Connection

1. After login, go to **Students** tab
2. Try adding a student
3. Refresh the page — data should persist

### 5.3 Test Report Generation

1. Go to **Reports** tab
2. Select a student
3. Choose a tone
4. Click **Generate Report**
5. Should see AI-generated content

---

## Troubleshooting

### "Failed to fetch" errors
- Check if Supabase URL and anon key are correct in config.js
- Verify RLS policies allow your operations

### "Cannot read property 'createClient' of undefined"
- Make sure Supabase JS CDN is loading: `https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2`

### Serverless function errors
- Check Netlify Dashboard → Functions → function logs
- Verify OPENROUTER_API_KEY is set in environment variables
- Check OpenRouter API status and quota

### CORS errors
- Netlify functions handle CORS automatically
- Ensure you're calling the correct function endpoint

---

## File Structure Reference

```
project-root/
├── index.html          # Main application (HTML/CSS/JS)
├── config.js           # Supabase credentials (gitignored)
├── config.local.js     # Local testing config (gitignored)
├── netlify.toml        # Netlify configuration
├── netlify/
│   └── functions/
│       └── generate-report.js   # OpenRouter API call (no npm install needed)
├── music-school-schema.sql  # Database schema
└── DEPLOYMENT.md          # This file
```

---

## Security Notes

- **Never commit config.js** — it contains your Supabase credentials
- **Never expose OPENROUTER_API_KEY** — it must only exist in Netlify environment variables and the serverless function
- **Enable RLS** — all tables have Row Level Security enabled
- **Use HTTPS** — Netlify provides HTTPS automatically
