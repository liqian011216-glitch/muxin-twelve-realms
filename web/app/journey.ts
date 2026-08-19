export const TAGS = ["chase", "wait", "look_back", "let_go", "control", "together"] as const;
export type ChoiceTag = (typeof TAGS)[number];
export type FinalSeal = "cow" | "path" | "blank";
export const HEART_ACTIONS = ["hold", "observe", "harmonize", "release"] as const;
export type HeartAction = (typeof HEART_ACTIONS)[number];
export type HeartTotals = Record<HeartAction, number>;

const heartActionByChoiceTag: Record<ChoiceTag, HeartAction> = {
  chase: "hold",
  wait: "observe",
  look_back: "observe",
  let_go: "release",
  control: "hold",
  together: "harmonize",
};

export function recordHeartAction(
  totals: HeartTotals,
  action: HeartAction,
  weight?: number,
): HeartTotals;
export function recordHeartAction(
  state: JourneyState,
  action: HeartAction,
  weight?: number,
): JourneyState;
export function recordHeartAction(
  target: HeartTotals | JourneyState,
  action: HeartAction,
  weight = 1,
): HeartTotals | JourneyState {
  if ("heartTotals" in target) {
    return { ...target, heartTotals: recordHeartAction(target.heartTotals, action, weight) };
  }
  return { ...target, [action]: target[action] + weight };
}

export type GameResult = {
  game: "stone_rubbing" | "seek_cow" | "bridge" | "jump";
  actions: string[];
  result: ChoiceTag;
};

export type JourneyState = {
  heartTotals: HeartTotals;
  counts: Record<ChoiceTag, number>;
  choices: string[];
  gameResults: GameResult[];
  lastTag: ChoiceTag | null;
  finalSeal: FinalSeal | null;
  sign: unknown | null;
};

export function createJourneyState(): JourneyState {
  return {
    heartTotals: { hold: 0, observe: 0, harmonize: 0, release: 0 },
    counts: Object.fromEntries(TAGS.map((tag) => [tag, 0])) as Record<ChoiceTag, number>,
    choices: [],
    gameResults: [],
    lastTag: null,
    finalSeal: null,
    sign: null,
  };
}

export function recordChoice(state: JourneyState, tag: ChoiceTag, choice: string): JourneyState {
  const heartJourney = recordHeartAction(state, heartActionByChoiceTag[tag]);
  return {
    ...heartJourney,
    counts: { ...state.counts, [tag]: state.counts[tag] + 1 },
    choices: [...state.choices, choice],
    lastTag: tag,
  };
}

export function recordGameResult(state: JourneyState, result: GameResult): JourneyState {
  const heartJourney = recordHeartAction(state, heartActionByChoiceTag[result.result]);
  return {
    ...heartJourney,
    counts: { ...state.counts, [result.result]: state.counts[result.result] + 1 },
    gameResults: [...state.gameResults, result],
    lastTag: result.result,
  };
}

const sealTieBreak: Record<FinalSeal, ChoiceTag> = {
  cow: "chase",
  path: "look_back",
  blank: "let_go",
};

export function getSignArchetype(state: JourneyState): string {
  const sorted = [...TAGS].sort((a, b) => state.counts[b] - state.counts[a]);
  const first = sorted[0];
  const tied = sorted.filter((tag) => state.counts[tag] === state.counts[first]);
  const tiePreferred = state.finalSeal ? sealTieBreak[state.finalSeal] : state.lastTag;
  const primary = tied.includes(tiePreferred as ChoiceTag) ? tiePreferred : first;
  const secondary = sorted.find((tag) => tag !== primary && state.counts[tag] > 0) ?? "wait";
  return `${primary}×${secondary}`;
}

export function setFinalSeal(state: JourneyState, finalSeal: FinalSeal): JourneyState {
  return { ...state, finalSeal };
}
