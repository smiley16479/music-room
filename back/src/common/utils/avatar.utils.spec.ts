import { generateGenericAvatar, getRandomAvatarColor, getFacebookProfilePictureUrl } from './avatar.utils';

describe('Avatar Utils', () => {
  describe('getRandomAvatarColor', () => {
    it('should return a valid hex color', () => {
      const color = getRandomAvatarColor();
      expect(color).toMatch(/^#[0-9A-F]{6}$/i);
    });

    it('should return different colors on multiple calls', () => {
      const colors = new Set();
      for (let i = 0; i < 50; i++) {
        colors.add(getRandomAvatarColor());
      }
      // Should have more than 1 unique color in 50 calls
      expect(colors.size).toBeGreaterThan(1);
    });
  });

  describe('generateGenericAvatar', () => {
    it('should generate a valid SVG data URL', () => {
      const avatar = generateGenericAvatar('John Doe');
      expect(avatar).toMatch(/^data:image\/svg\+xml;base64,/);
    });

    it('should use the first letter of the name', () => {
      const avatar = generateGenericAvatar('Alice');
      const decodedSvg = Buffer.from(avatar.split(',')[1], 'base64').toString();
      expect(decodedSvg).toContain('>A<');
    });

    it('should handle empty name gracefully', () => {
      const avatar = generateGenericAvatar('');
      const decodedSvg = Buffer.from(avatar.split(',')[1], 'base64').toString();
      expect(decodedSvg).toContain('>U<');
    });

    it('should handle single character names', () => {
      const avatar = generateGenericAvatar('X');
      const decodedSvg = Buffer.from(avatar.split(',')[1], 'base64').toString();
      expect(decodedSvg).toContain('>X<');
    });
  });

  describe('getFacebookProfilePictureUrl', () => {
    it('should generate correct Facebook profile picture URL', () => {
      const url = getFacebookProfilePictureUrl('123456789');
      expect(url).toBe('https://graph.facebook.com/123456789/picture?type=large');
    });
  });
});
