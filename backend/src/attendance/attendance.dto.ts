import { IsIn, IsLatitude, IsLongitude, IsOptional, Matches } from 'class-validator';

const DATE = /^\d{4}-\d{2}-\d{2}$/;

export class MarkDto {
  @IsIn(['in', 'out']) type!: 'in' | 'out';
  @IsOptional() @IsLatitude() latitude?: number;
  @IsOptional() @IsLongitude() longitude?: number;
}

export class RangeQueryDto {
  @IsOptional() @Matches(DATE) from?: string;
  @IsOptional() @Matches(DATE) to?: string;
  @IsOptional() employeeId?: string;
}
