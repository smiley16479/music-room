import { Catch, ArgumentsHost } from '@nestjs/common';
import { BaseWsExceptionFilter, WsException } from '@nestjs/websockets';
import { Socket } from 'socket.io';

@Catch(WsException)
export class WebsocketExceptionFilter extends BaseWsExceptionFilter {
  catch(exception: WsException, host: ArgumentsHost) {
    const client = host.switchToWs().getClient<Socket>();
    const data = host.switchToWs().getData();
    const error = exception.getError();
    
    const details = error instanceof Object ? { ...error } : { message: error };
    
    client.emit('error', {
      id: client.id,
      rid: data.rid,
      ...details,
    });
  }
}