export type Rarity='Bronze'|'Silber'|'Gold'|'Ultimate'|'Legendär';
export type Card={id:string;name:string;position:string;rating:number;rarity:Rarity;pace:number;shooting:number;passing:number;dribbling:number;defense:number;physical:number;edition:string;owned:number};
export const rarities:Rarity[]=['Bronze','Silber','Gold','Ultimate','Legendär'];
export const initialCards:Card[]=[
{id:'c1',name:'Johannes Hüller',position:'ST',rating:78,rarity:'Gold',pace:79,shooting:81,passing:72,dribbling:77,defense:34,physical:76,edition:'SVHS · Saison 26/27',owned:1},
{id:'c2',name:'Maximilian Heinze',position:'TW',rating:74,rarity:'Silber',pace:61,shooting:24,passing:60,dribbling:44,defense:30,physical:67,edition:'SVHS · Saison 26/27',owned:1},
{id:'c3',name:'Leo Wachowski',position:'IV',rating:71,rarity:'Silber',pace:74,shooting:45,passing:61,dribbling:54,defense:76,physical:82,edition:'SVHS · Saison 26/27',owned:1},
{id:'c4',name:'Julian Keich',position:'ZM',rating:67,rarity:'Silber',pace:65,shooting:62,passing:69,dribbling:66,defense:53,physical:61,edition:'SVHS · Saison 26/27',owned:1},
{id:'c5',name:'Silas Pomeranz',position:'RV',rating:59,rarity:'Bronze',pace:64,shooting:42,passing:55,dribbling:53,defense:60,physical:58,edition:'SVHS · Saison 26/27',owned:1}];
export const totalSquadRating=(cards:Card[])=>cards.length?Math.round(cards.reduce((s,c)=>s+c.rating,0)/cards.length):0;
export function pickRarity(n:number,w:Record<Rarity,number>):Rarity{if(Math.abs(Object.values(w).reduce((a,b)=>a+b,0)-100)>.0001)throw new Error('Wahrscheinlichkeiten müssen 100 % ergeben.');if(n<0||n>=1)throw new Error('Zufallswert außerhalb [0,1).');const target=n*100;let c=0;for(const r of rarities){c+=w[r];if(target<c)return r;}return 'Legendär';}