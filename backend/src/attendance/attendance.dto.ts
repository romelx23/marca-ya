import { ArrayMinSize, IsArray, IsIn, IsLatitude, IsLongitude, IsOptional, IsString, Matches } from 'class-validator';

const DATE = /^\d{4}-\d{2}-\d{2}$/;

export class MarkDto {
  @IsIn(['in', 'out']) type!: 'in' | 'out';
  @IsOptional() @IsLatitude() latitude?: number;
  @IsOptional() @IsLongitude() longitude?: number;
  /** Embedding facial calculado en el teléfono (método face). */
  @IsOptional() @IsArray() @ArrayMinSize(1) embedding?: number[];
  /** PIN de respaldo (método pin). */
  @IsOptional() @IsString() @Matches(/^\d{4,6}$/) pin?: string;
}

export class RangeQueryDto {
  @IsOptional() @Matches(DATE) from?: string;
  @IsOptional() @Matches(DATE) to?: string;
  @IsOptional() employeeId?: string;
}
