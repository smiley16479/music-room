/**
 * Unified avatar utility for consistent avatar generation across the application
 * This should match the backend avatar generation logic exactly
 */

const AVATAR_COLORS = [
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

/**
 * Generates a consistent color index based on the input string
 * This ensures the same name always gets the same color
 */
function getColorIndex(name: string): number {
	if (!name) return 0;
	return name.charCodeAt(0) % AVATAR_COLORS.length;
}

/**
 * Gets the avatar color for a given name
 */
export function getAvatarColor(name: string): string {
	return AVATAR_COLORS[getColorIndex(name)];
}

/**
 * Gets the first letter of a name (for avatar display)
 */
export function getAvatarLetter(name: string): string {
	if (!name) return 'U';
	return name.charAt(0).toUpperCase();
}

/**
 * Generates a complete SVG data URL for an avatar
 */
export function generateGenericAvatar(name: string): string {
	const firstLetter = getAvatarLetter(name);
	const backgroundColor = getAvatarColor(name);
	
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
	
	return `data:image/svg+xml;base64,${btoa(svg)}`;
}

/**
 * Gets the appropriate avatar URL for a user
 * Priority: Custom avatar URL > Generated avatar
 */
export function getUserAvatarUrl(user: { avatarUrl?: string; displayName?: string; email?: string }): string {
	// Use custom avatar if available and not a generic SVG
	if (user.avatarUrl && !user.avatarUrl.startsWith('data:image/svg+xml')) {
		return user.avatarUrl;
	}
	
	// Generate consistent avatar
	const name = user.displayName || user.email || 'User';
	return generateGenericAvatar(name);
}

/**
 * Generates inline CSS style for avatar background (for use in CSS classes)
 */
export function getAvatarStyle(name: string): string {
	const backgroundColor = getAvatarColor(name);
	return `background-color: ${backgroundColor}`;
}
