/**
 * Utility functions for avatar generation and management
 */

/**
 * Generates a random background color from a predefined palette
 */
export function getRandomAvatarColor(): string {
  const colors = [
    '#FF6B6B', // Red
    '#4ECDC4', // Teal
    '#45B7D1', // Blue
    '#96CEB4', // Green
    '#FFEAA7', // Yellow
    '#DDA0DD', // Plum
    '#98D8C8', // Mint
    '#F7DC6F', // Light Yellow
    '#BB8FCE', // Light Purple
    '#85C1E9', // Light Blue
    '#F8C471', // Orange
    '#82E0AA', // Light Green
    '#F1948A', // Light Red
    '#D7BDE2', // Lavender
    '#A9DFBF', // Pale Green
  ];
  
  return colors[Math.floor(Math.random() * colors.length)];
}

/**
 * Generates a generic avatar URL with the first letter of the name and random background
 * This creates a data URL for an SVG image
 */
export function generateGenericAvatar(name: string): string {
  const firstLetter = (name || 'U').charAt(0).toUpperCase();
  const backgroundColor = getRandomAvatarColor();
  
  // Create SVG markup
  const svg = `
    <svg width="100" height="100" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
      <circle cx="50" cy="50" r="50" fill="${backgroundColor}"/>
      <text 
        x="50" 
        y="50" 
        text-anchor="middle" 
        dominant-baseline="central" 
        font-family="Arial, sans-serif" 
        font-size="40" 
        font-weight="bold" 
        fill="white"
      >${firstLetter}</text>
    </svg>
  `.replace(/\s+/g, ' ').trim();
  
  // Convert to base64 data URL
  const base64 = Buffer.from(svg).toString('base64');
  return `data:image/svg+xml;base64,${base64}`;
}

/**
 * Gets the appropriate avatar URL based on user data
 * Priority: Facebook profile picture > Google profile picture > Generic avatar
 */
export function getAvatarUrl(userData: {
  displayName?: string;
  facebookId?: string;
  googleId?: string;
  facebookProfilePicture?: string;
  googleProfilePicture?: string;
}): string {
  const { displayName, facebookProfilePicture, googleProfilePicture } = userData;
  
  // Use Facebook profile picture if available
  if (facebookProfilePicture) {
    return facebookProfilePicture;
  }
  
  // Use Google profile picture if available
  if (googleProfilePicture) {
    return googleProfilePicture;
  }
  
  // Generate generic avatar
  return generateGenericAvatar(displayName || 'User');
}

/**
 * Extracts Facebook profile picture URL from Facebook user data
 */
export function getFacebookProfilePictureUrl(facebookId: string): string {
  return `https://graph.facebook.com/${facebookId}/picture?type=large`;
}
