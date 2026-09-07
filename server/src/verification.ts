/**
 * Where an identity check happens, which is not here.
 *
 * `docs/07-BACKEND-SPEC.md` puts ID and liveness with a third-party provider and
 * says why in three words: *not something to build.* This port is the seam.
 */
export type IdentityCheck = {
  /** Starts a check and returns the provider's reference and where to send the user. */
  start(accountId: string, kind: 'identity' | 'business'): Promise<{
    reference: string;
    url: string;
  }>;
};

/**
 * The stand-in, and it announces itself.
 *
 * The tempting version passes everybody so the tier can be demonstrated. That
 * one is indistinguishable from a working KYC integration to everybody who is
 * not reading this file — including whoever decides the feature is ready — and
 * *verified* is the tier that lets a stranger ask a farmer where their crop is.
 * So it starts a check that nothing will ever settle, and says so in the URL it
 * hands back.
 */
export function noIdentityCheck(): IdentityCheck {
  return {
    async start(accountId) {
      return {
        reference: `unwired-${accountId}`,
        url: 'about:blank#no-identity-provider-is-configured',
      };
    },
  };
}
