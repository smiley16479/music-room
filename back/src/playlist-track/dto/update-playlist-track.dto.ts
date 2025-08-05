import { PartialType } from '@nestjs/mapped-types';
import { CreatePlaylistTrackDto } from './create-playlist-track.dto';

export class UpdatePlaylistTrackDto extends PartialType(CreatePlaylistTrackDto) {}
