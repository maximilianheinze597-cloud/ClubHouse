export type Rarity='Bronze'|'Silber'|'Gold'|'Ultimate'|'Legendär';
export type Card={id:string;definitionId?:string;name:string;position:string;rating:number;rarity:Rarity;pace:number;shooting:number;passing:number;dribbling:number;defense:number;physical:number;edition:string;owned:number};
export const rarities:Rarity[]=['Bronze','Silber','Gold','Ultimate','Legendär'];
export const initialCards:Card[]=[];
export const totalSquadRating=(cards:Card[])=>cards.length?Math.round(cards.reduce((s,c)=>s+c.rating,0)/cards.length):0;
export function pickRarity(n:number,w:Record<Rarity,number>):Rarity{if(Math.abs(Object.values(w).reduce((a,b)=>a+b,0)-100)>.0001)throw new Error('Wahrscheinlichkeiten müssen 100 % ergeben.');if(n<0||n>=1)throw new Error('Zufallswert außerhalb [0,1).');const target=n*100;let c=0;for(const r of rarities){c+=w[r];if(target<c)return r;}return 'Legendär';}