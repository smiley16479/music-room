import { IsArray, IsString } from 'class-validator';

export class ReorderTracksDto {
  @IsArray()
  @IsString({ each: true })
  trackIds: string[];
}
