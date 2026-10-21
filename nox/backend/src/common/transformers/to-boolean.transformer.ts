import { Transform } from 'class-transformer';

/**
 * Converts query-string booleans ('true' / 'false' / '1' / '0') to real booleans.
 * Needed because `enableImplicitConversion` turns any non-empty string (including 'false') into `true`.
 * Unrecognised values are passed through unchanged so @IsBoolean() rejects them.
 */
export function ToBoolean(): PropertyDecorator {
  return Transform(({ obj, key }) => {
    const raw = obj[key];
    if (raw === undefined || raw === null || raw === '') return undefined;
    if (raw === true || raw === 'true' || raw === '1') return true;
    if (raw === false || raw === 'false' || raw === '0') return false;
    return raw;
  });
}
