import { describe, expect, it } from 'vitest';
import { initialCards, pickRarity, totalSquadRating, type Rarity } from '../src/domain';
const weights: Record<Rarity, number> = { Bronze: 55, Silber: 30, Gold: 12, Ultimate: 2.8, Legendär: 0.2 };
describe('CLUBHOUSE game domain', () => {
 it('calculates squad rating from cards', () => { expect(totalSquadRating(initialCards.slice(0, 5))).toBe(78); });
 it('rejects invalid probability totals', () => { expect(() => pickRarity(0.5, { ...weights, Bronze: 54 })).toThrow(/100 %/); });
 it('rejects random values outside [0,1)', () => { expect(() => pickRarity(1, weights)).toThrow(/außerhalb/); expect(() => pickRarity(-0.1, weights)).toThrow(); });
 it('selects rarity at boundaries', () => { expect(pickRarity(0, weights)).toBe('Bronze'); expect(pickRarity(0.55, weights)).toBe('Silber'); expect(pickRarity(0.85, weights)).toBe('Gold'); expect(pickRarity(0.999, weights)).toBe('Legendär'); });
});
