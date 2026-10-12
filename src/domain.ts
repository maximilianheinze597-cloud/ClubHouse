export type Rarity='Bronze'|'Silber'|'Gold'|'Ultimate'|'Legendär';
export type Card={id:string;definitionId?:string;name:string;position:string;rating:number;rarity:Rarity;pace:number;shooting:number;passing:number;dribbling:number;defense:number;physical:number;edition:string;owned:number};
export const rarities:Rarity[]=['Bronze','Silber','Gold','Ultimate','Legendär'];
export const initialCards:Card[]=[
{id:'c1',name:'Mika Sommer',position:'ST',rating:58,rarity:'Bronze',pace:62,shooting:59,passing:51,dribbling:60,defense:28,physical:55,edition:'SVHS · Saison 26/27',owned:1},
{id:'c2',name:'Toni Feld',position:'IV',rating:70,rarity:'Silber',pace:65,shooting:42,passing:60,dribbling:55,defense:73,physical:75,edition:'SVHS · Saison 26/27',owned:1},
{id:'c3',name:'Kai Grün',position:'ZM',rating:80,rarity:'Gold',pace:78,shooting:76,passing:82,dribbling:80,defense:64,physical:72,edition:'SVHS · Saison 26/27',owned:1},
{id:'c4',name:'Nico Licht',position:'TW',rating:88,rarity:'Ultimate',pace:65,shooting:20,passing:70,dribbling:42,defense:30,physical:82,edition:'SVHS · Special Edition',owned:1},
{id:'c5',name:'Robin Stern',position:'LF',rating:96,rarity:'Legendär',pace:95,shooting:94,passing:88,dribbling:96,defense:45,physical:86,edition:'SVHS · Legend Edition',owned:1}];
export const totalSquadRating=(cards:Card[])=>cards.length?Math.round(cards.reduce((s,c)=>s+c.rating,0)/cards.length):0;
export function pickRarity(n:number,w:Record<Rarity,number>):Rarity{if(Math.abs(Object.values(w).reduce((a,b)=>a+b,0)-100)>.0001)throw new Error('Wahrscheinlichkeiten müssen 100 % ergeben.');if(n<0||n>=1)throw new Error('Zufallswert außerhalb [0,1).');const target=n*100;let c=0;for(const r of rarities){c+=w[r];if(target<c)return r;}return 'Legendär';}