import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator';

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredPermissions = this.reflector.getAllAndOverride<string[]>(
      PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (!requiredPermissions) {
      return true;
    }

    const request = context.switchToHttp().getRequest();
    const user = request.user;

    if (!user) {
      throw new ForbiddenException('User not authenticated');
    }

    // For now, we'll implement basic permission checking
    // In a real application, you might want to implement role-based permissions
    const hasPermission = requiredPermissions.every(permission =>
      this.userHasPermission(user, permission, request),
    );

    if (!hasPermission) {
      throw new ForbiddenException('Insufficient permissions');
    }

    return true;
  }

  private userHasPermission(user: any, permission: string, request: any): boolean {
    // Basic permission logic - customize based on your needs
    const resourceId = request.params.id;
    
    switch (permission) {
      case 'users:update':
      case 'users:delete':
        return user.id === resourceId;
        
      case 'events:update':
      case 'events:delete':
        // Check if user is the creator of the event
        return this.isResourceOwner(user.id, 'event', resourceId);
        
      case 'playlists:update':
      case 'playlists:delete':
        // Check if user is the creator or collaborator
        return this.isResourceOwnerOrCollaborator(user.id, 'playlist', resourceId);
        
      case 'devices:control':
      case 'devices:delegate':
        // Check if user owns the device or has been delegated control
        return this.hasDeviceAccess(user.id, resourceId);
        
      default:
        return true; // Default allow for basic permissions
    }
  }

  // These methods would be implemented with proper database queries
  private isResourceOwner(userId: string, resourceType: string, resourceId: string): boolean {
    // TODO: Implement database check
    return true;
  }

  private isResourceOwnerOrCollaborator(userId: string, resourceType: string, resourceId: string): boolean {
    // TODO: Implement database check
    return true;
  }

  private hasDeviceAccess(userId: string, deviceId: string): boolean {
    // TODO: Implement database check
    return true;
  }
}