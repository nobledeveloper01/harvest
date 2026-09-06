/**
 * Where a lot is, to the precision the farmer chose — and no better.
 *
 * `docs/07-BACKEND-SPEC.md`, under Security & Trust: *truncated on ingest to
 * the precision the farmer selected. The server never stores a precision the
 * farmer did not consent to.* Truncation happens **before the insert**, not on
 * the way out, because a database that holds an exact position and promises not
 * to show it is one subpoena, one bug or one careless join away from showing
 * it. What is not stored cannot leak.
 *
 * This also has to be true of the app, which never asks for GPS at all
 * (`CLAUDE.md`): the coordinate arriving here is one a farmer picked, and this
 * is the server refusing to keep more of it than they meant to give.
 */
export type Precision = 'exact' | 'village' | 'lga';

/** Degrees of latitude per grid cell, by precision. */
const grid: Record<Precision, number> = {
  // Roughly 11 m — the resolution of a pin somebody dropped, kept as given.
  exact: 0.0001,
  // ~1.1 km. A village, and not which compound in it.
  village: 0.01,
  // ~11 km. A local government area, and not which village.
  lga: 0.1,
};

export type Point = { readonly lat: number; readonly lng: number };

/**
 * Snaps a point to the centre of its cell.
 *
 * The **centre**, not the corner. Flooring to a grid moves every point
 * south-west, which over a country-sized set of listings is a systematic drift
 * of half a cell in one direction — five kilometres of it at LGA precision, all
 * the same way. Rounding to the middle of the cell keeps the error unbiased,
 * which matters because these coordinates end up in distance sorts.
 */
export function truncate(point: Point, precision: Precision): Point {
  const cell = grid[precision];
  const snap = (value: number) => Math.round(value / cell) * cell;
  // Rounded back to a sane number of decimals: `Math.round(x / 0.01) * 0.01`
  // produces 7.377000000000001, and a coordinate with binary noise on the end
  // is a coordinate that no longer looks like the promise that was made.
  const places = Math.max(0, Math.round(-Math.log10(cell)));
  const fix = (value: number) => Number(snap(value).toFixed(places));
  return { lat: fix(point.lat), lng: fix(point.lng) };
}

const earthKm = 6371;

/**
 * The box the index can use.
 *
 * A prefilter, not an answer: everything inside the circle is inside the box,
 * and the corners are then thrown away by the exact distance test. See
 * ADR-0011 for the measurement, and for why the 3% the box wastes at Nigerian
 * latitudes would be 300% in Norway.
 */
export function boundingBox(centre: Point, km: number) {
  const dLat = (km / earthKm) * (180 / Math.PI);
  // Longitude degrees shrink towards the poles. Clamped because at the pole the
  // divisor goes to zero and the box would become the whole world — which is
  // the correct answer there, and an infinity here.
  const shrink = Math.max(Math.cos((centre.lat * Math.PI) / 180), 1e-6);
  const dLng = dLat / shrink;
  return {
    minLat: centre.lat - dLat,
    maxLat: centre.lat + dLat,
    minLng: centre.lng - dLng,
    maxLng: centre.lng + dLng,
  };
}

/** Great-circle distance, in kilometres. */
export function distanceKm(a: Point, b: Point): number {
  const rad = Math.PI / 180;
  const cos =
    Math.sin(a.lat * rad) * Math.sin(b.lat * rad) +
    Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.cos((b.lng - a.lng) * rad);
  // Clamped: floating point takes the cosine of two identical points slightly
  // above 1, and `acos` of that is NaN — a distance of "not a number" between a
  // lot and itself.
  return earthKm * Math.acos(Math.min(1, Math.max(-1, cos)));
}
