# User Generator Scripts

This directory contains scripts to generate fake users for testing purposes.

## Available Scripts

### 1. TypeScript Version (`generate-users.ts`)

A full-featured TypeScript script that uses the backend API to create users.

**Usage:**

```bash
# From the back directory
npm run generate-users -- --count 10
npm run generate-users -- --count 50
npm run generate-users -- --help
```

**Options:**
- `--count <number>` - Number of users to generate (default: 10)
- `--verified` - Set users as email verified (default: false)
- `--base-url <url>` - Backend API URL (default: http://localhost:3000/api)
- `--password <pwd>` - Password for all users (default: Password123!)
- `--help` - Show help message

**Examples:**

```bash
# Generate 20 users
npm run generate-users -- --count 20

# Generate 10 users with custom password
npm run generate-users -- --count 10 --password MySecret123

# Generate users for different backend
npm run generate-users -- --count 15 --base-url http://localhost:4000/api
```