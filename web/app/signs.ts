import type { HeartAction, HeartTotals, JourneyState } from "./journey.ts";

const HEART_ACTION_ORDER: HeartAction[] = ["release", "harmonize", "observe", "hold"];

const heartSigns: Record<HeartAction, { sign: string; transition: string; reflection: string }> = {
  hold: {
    sign: "持绳签",
    transition: "持绳",
    reflection: "你愿意把绳握在手里，也愿意留意脚下的路。",
  },
  observe: {
    sign: "观照签",
    transition: "回首",
    reflection: "你让目光慢下来，在细微处照见来路。",
  },
  harmonize: {
    sign: "同行签",
    transition: "同行",
    reflection: "你把步子放在一起，让同行成为一种安静的照应。",
  },
  release: {
    sign: "任运签",
    transition: "任运",
    reflection: "你松开用力，让风与脚步各自抵达。",
  },
};

export type DerivedSign = {
  primary: string;
  transition: string | null;
  reflection: string;
};

export function deriveSign(totals: HeartTotals): DerivedSign {
  const ordered = [...HEART_ACTION_ORDER].sort((left, right) => totals[right] - totals[left]);
  const primary = ordered[0];
  const runnerUp = ordered[1];
  const hasTransition = totals[primary] > 0 && totals[primary] - totals[runnerUp] <= 1;

  return {
    primary: heartSigns[primary].sign,
    transition: hasTransition ? `${heartSigns[primary].transition}而能${heartSigns[runnerUp].transition}` : null,
    reflection: heartSigns[primary].reflection,
  };
}

export type Sign = {
  id: string;
  archetype: string;
  title: string;
  grade: string;
  verse: string;
  explanation: string;
  sealDetail: string;
  primary: DerivedSign["primary"];
  transition: DerivedSign["transition"];
  reflection: DerivedSign["reflection"];
};

type SignVariant = Omit<Sign, keyof DerivedSign>;

const archetypes = [
  ["chase×wait", "逐风听泉"], ["chase×look_back", "回首追云"], ["chase×let_go", "解缰见路"],
  ["chase×control", "握缰问心"], ["chase×together", "并辔行山"],
  ["wait×chase", "静中有行"], ["wait×look_back", "听雨回灯"], ["wait×let_go", "松枝落雪"],
  ["wait×control", "守寸留白"], ["wait×together", "与牛同息"],
  ["look_back×chase", "旧痕新蹄"], ["look_back×wait", "回望无声"], ["look_back×let_go", "照见空山"],
  ["look_back×control", "碑前解结"], ["look_back×together", "来处同行"],
  ["let_go×chase", "放手逐光"], ["let_go×wait", "无碍听风"], ["let_go×look_back", "留白见月"],
  ["let_go×control", "绳外有岸"], ["let_go×together", "同行不系"],
] as const;

const grades = ["上签", "中上签", "无碍签"];
const openings = [
  "不必先问归处，脚下自有微光。",
  "牛影入云深，心声在水边。",
  "你留下的那一步，正好让风经过。",
];
const explanations = [
  "此签记下你在靠近与退让之间找到的分寸。",
  "此签不是答案，而是你愿意继续观看的证据。",
  "此签提醒你：同行不等于牵引，放手也不等于离开。",
];

export const SIGN_LIBRARY: SignVariant[] = archetypes.flatMap(([archetype, name]) =>
  openings.map((opening, index) => ({
    id: `${archetype}-${index + 1}`,
    archetype,
    title: `${name} · ${index + 1}`,
    grade: grades[index],
    verse: `${opening}\n${index === 0 ? "一念回身，山河便慢。" : index === 1 ? "莫催春水，牛自识津。" : "留一寸空处，月色才来。"}`,
    explanation: explanations[index],
    sealDetail: index === 0 ? "朱印落在旧痕旁" : index === 1 ? "墨线向远处舒展" : "印面留有一方空白",
  })),
);

export const SIGN_VARIANT_COUNT = SIGN_LIBRARY.length;

export function drawSign(state: JourneyState, randomValue = Math.random()): Sign {
  const derived = deriveSign(state.heartTotals);
  const index = Math.min(SIGN_LIBRARY.length - 1, Math.floor(Math.max(0, randomValue) * SIGN_LIBRARY.length));
  const variant = SIGN_LIBRARY[index];

  return {
    ...variant,
    id: `${derived.primary}-${index + 1}`,
    archetype: derived.primary,
    title: derived.primary,
    explanation: derived.reflection,
    sealDetail: derived.transition ?? variant.sealDetail,
    ...derived,
  };
}
