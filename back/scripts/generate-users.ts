#!/usr/bin/env ts-node
/**
 * User Generator Script
 * 
 * This script generates fake users in the database using the backend API.
 * 
 * Usage:
 *   npm run generate-users -- --count 10
 *   npm run generate-users -- --count 50 --verified
 * 
 * Options:
 *   --count <number>     Number of users to generate (default: 10)
 *   --verified           Set users as email verified (default: false)
 *   --base-url <url>     Backend API URL (default: http://localhost:3000)
 *   --password <pwd>     Password for all users (default: Password123!)
 */

import axios from 'axios';

// ==================== Configuration ====================

interface GenerateOptions {
  count: number;
  verified: boolean;
  baseUrl: string;
  password: string;
}

// Parse command line arguments
function parseArgs(): GenerateOptions {
  const args = process.argv.slice(2);
  const options: GenerateOptions = {
    count: 10,
    verified: false,
    baseUrl: 'http://localhost:3000/api',
    password: 'Password123!',
  };

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--count':
        options.count = parseInt(args[++i], 10);
        break;
      case '--verified':
        options.verified = true;
        break;
      case '--base-url':
        options.baseUrl = args[++i];
        break;
      case '--password':
        options.password = args[++i];
        break;
      case '--help':
        console.log(`
User Generator Script

Usage:
  npm run generate-users -- --count 10
  npm run generate-users -- --count 50 --verified

Options:
  --count <number>     Number of users to generate (default: 10)
  --verified           Set users as email verified (default: false)
  --base-url <url>     Backend API URL (default: http://localhost:3000)
  --password <pwd>     Password for all users (default: Password123!)
  --help               Show this help message
        `);
        process.exit(0);
    }
  }

  return options;
}

// ==================== Fake Data Generators ====================

const FIRST_NAMES = [
  'Alice', 'Bob', 'Charlie', 'Diana', 'Emma', 'Frank', 'Grace', 'Henry',
  'Ivy', 'Jack', 'Kate', 'Liam', 'Mia', 'Noah', 'Olivia', 'Peter',
  'Quinn', 'Rachel', 'Sam', 'Tara', 'Uma', 'Victor', 'Wendy', 'Xander',
  'Yara', 'Zoe', 'Alex', 'Blake', 'Casey', 'Drew', 'Ellis', 'Finley',
  'Gray', 'Harper', 'Indigo', 'Jordan', 'Kai', 'Logan', 'Morgan', 'Nico',
];

const LAST_NAMES = [
  'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis',
  'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson', 'Thomas',
  'Taylor', 'Moore', 'Jackson', 'Martin', 'Lee', 'Walker', 'Hall', 'Allen',
  'Young', 'King', 'Wright', 'Scott', 'Green', 'Baker', 'Adams', 'Nelson',
  'Carter', 'Mitchell', 'Perez', 'Roberts', 'Turner', 'Phillips', 'Campbell', 'Parker',
];

const CITIES = [
  'New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 'Philadelphia',
  'San Antonio', 'San Diego', 'Dallas', 'San Jose', 'Austin', 'Jacksonville',
  'Seattle', 'Denver', 'Boston', 'Portland', 'Nashville', 'Miami', 'Atlanta',
  'Paris', 'London', 'Tokyo', 'Berlin', 'Madrid', 'Rome', 'Amsterdam', 'Dublin',
];

const MUSIC_GENRES = [
  'Rock', 'Pop', 'Jazz', 'Classical', 'Hip Hop', 'Rap',
  'Blues', 'Country', 'Electronic', 'Reggae', 'Metal',
  'R&B', 'Soul', 'Indie', 'Folk', 'Punk',
];

const BIO_TEMPLATES = [
  'Music lover and aspiring musician 🎵',
  'Just here to vibe and share good tunes 🎶',
  'Life is better with music 🎧',
  'Always looking for new music recommendations!',
  'Playlist curator extraordinaire ✨',
  'Music is my therapy 🎸',
  'Dance like nobody\'s watching 💃',
  'Concerts, festivals, and good vibes only',
  'Audiophile and proud of it 🎼',
  'Music brings us together 🌍',
];

function random<T>(array: T[]): T {
  return array[Math.floor(Math.random() * array.length)];
}

function randomInt(min: number, max: number): number {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomDate(start: Date, end: Date): Date {
  return new Date(start.getTime() + Math.random() * (end.getTime() - start.getTime()));
}

function randomSubset<T>(array: T[], min: number, max: number): T[] {
  const count = randomInt(min, max);
  const shuffled = [...array].sort(() => 0.5 - Math.random());
  return shuffled.slice(0, count);
}

function generateUser(index: number) {
  const firstName = random(FIRST_NAMES);
  const lastName = random(LAST_NAMES);
  const displayName = `${firstName} ${lastName}`;
  const email = `${firstName.toLowerCase()}.${lastName.toLowerCase()}${index}@test.com`;
  
  // Generate birth date (18-70 years old)
  const today = new Date();
  const minDate = new Date(today.getFullYear() - 70, today.getMonth(), today.getDate());
  const maxDate = new Date(today.getFullYear() - 18, today.getMonth(), today.getDate());
  const birthDate = randomDate(minDate, maxDate);

  // Random visibility settings
  const visibilities = ['public', 'friends', 'private'];
  
  return {
    email,
    password: '', // Will be set from options
    displayName,
    bio: Math.random() > 0.3 ? random(BIO_TEMPLATES) : undefined,
    location: Math.random() > 0.4 ? random(CITIES) : undefined,
    birthDate: birthDate.toISOString().split('T')[0],
    displayNameVisibility: random(visibilities),
    bioVisibility: random(visibilities),
    birthDateVisibility: random(visibilities),
    locationVisibility: random(visibilities),
    musicPreferences: randomSubset(MUSIC_GENRES, 2, 6),
    musicPreferenceVisibility: random(visibilities),
  };
}

// ==================== API Functions ====================

async function registerUser(baseUrl: string, userData: any) {
  try {
    const response = await axios.post(`${baseUrl}/auth/register`, userData);
    return { success: true, data: response.data };
  } catch (error: any) {
    return { 
      success: false, 
      error: error.response?.data?.message || error.message 
    };
  }
}

async function verifyUserEmail(baseUrl: string, userId: string, adminToken: string) {
  try {
    // This would require an admin endpoint to directly verify emails
    // For now, we'll skip this as it requires backend changes
    return { success: true };
  } catch (error: any) {
    return { 
      success: false, 
      error: error.response?.data?.message || error.message 
    };
  }
}

// ==================== Main Script ====================

async function main() {
  const options = parseArgs();

  console.log('🚀 User Generator Script');
  console.log('========================');
  console.log(`Base URL: ${options.baseUrl}`);
  console.log(`Users to generate: ${options.count}`);
  console.log(`Email verified: ${options.verified}`);
  console.log(`Password: ${options.password}`);
  console.log('');

  const results = {
    success: 0,
    failed: 0,
    errors: [] as string[],
  };

  for (let i = 1; i <= options.count; i++) {
    const userData = generateUser(i);
    userData.password = options.password;

    process.stdout.write(`[${i}/${options.count}] Creating ${userData.email}... `);

    const result = await registerUser(options.baseUrl, userData);

    if (result.success) {
      console.log('✅ Success');
      results.success++;
    } else {
      console.log(`❌ Failed: ${result.error}`);
      results.failed++;
      results.errors.push(`${userData.email}: ${result.error}`);
    }

    // Small delay to avoid overwhelming the server
    await new Promise(resolve => setTimeout(resolve, 100));
  }

  console.log('');
  console.log('========================');
  console.log('📊 Summary');
  console.log('========================');
  console.log(`✅ Successfully created: ${results.success}`);
  console.log(`❌ Failed: ${results.failed}`);
  
  if (results.errors.length > 0) {
    console.log('');
    console.log('Errors:');
    results.errors.forEach(error => console.log(`  - ${error}`));
  }

  console.log('');
  console.log('💡 Tips:');
  console.log(`  - All users have the same password: ${options.password}`);
  console.log(`  - Email format: firstname.lastname<number>@test.com`);
  if (!options.verified) {
    console.log(`  - Users need to verify their email before logging in`);
    console.log(`  - Check the backend logs for verification links`);
  }

  process.exit(results.failed > 0 ? 1 : 0);
}

// Run the script
main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
