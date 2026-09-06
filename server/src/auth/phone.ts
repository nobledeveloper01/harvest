/**
 * A phone number, normalised, because it is the identity.
 *
 * `accounts.phone` is unique, so **two spellings of the same number are two
 * accounts**: a farmer who signs up as `08031234567` and comes back as
 * `+2348031234567` would find their lots gone and their enquiries missing, and
 * would have no way to describe what happened. Normalisation is not tidiness
 * here, it is the difference between an identity and a string.
 *
 * Nigeria only, deliberately. `+234`, then a 10-digit national number beginning
 * with 7, 8 or 9 — which is every mobile prefix the NCC has allocated. A
 * general E.164 parser would accept numbers this product cannot send an OTP to
 * and cannot serve, and would turn a typo into a foreign number rather than
 * into an error.
 */
export type Phone = string;

const digitsOnly = /[^\d]/g;

export function normalise(input: string): Phone | null {
  const digits = input.replace(digitsOnly, '');

  // `08031234567` → national with the trunk zero.
  // `8031234567`  → national without it.
  // `2348031234567` → already international.
  let national: string;
  if (digits.length === 13 && digits.startsWith('234')) national = digits.slice(3);
  else if (digits.length === 11 && digits.startsWith('0')) national = digits.slice(1);
  else if (digits.length === 10) national = digits;
  else return null;

  if (!/^[789]\d{9}$/.test(national)) return null;
  return `+234${national}`;
}
