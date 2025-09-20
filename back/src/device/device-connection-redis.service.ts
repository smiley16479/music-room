import Redis from 'ioredis';

// Service Redis minimal pour le mapping user <-> device
export class DeviceConnectionRedisService {
  private redis: Redis;

  constructor() {
    console.log('REDIS_URL:', process.env.REDIS_URL);
    this.redis = process.env.REDIS_URL
      ? new Redis(process.env.REDIS_URL)
      : new Redis();
  }

  async addUserToDevice(deviceId: string, userId: string) {
    await this.redis.sadd(`device:${deviceId}:users`, userId);
    await this.redis.sadd(`user:${userId}:devices`, deviceId);
  }

  async removeUserFromDevice(deviceId: string, userId: string) {
    await this.redis.srem(`device:${deviceId}:users`, userId);
    await this.redis.srem(`user:${userId}:devices`, deviceId);
  }

  async getUsersForDevice(deviceId: string): Promise<string[]> {
    return await this.redis.smembers(`device:${deviceId}:users`);
  }

  async getDevicesForUser(userId: string): Promise<string[]> {
    return await this.redis.smembers(`user:${userId}:devices`);
  }

  async clearDevice(deviceId: string) {
    await this.redis.del(`device:${deviceId}:users`);
  }

  async clearUser(userId: string) {
    await this.redis.del(`user:${userId}:devices`);
  }
}