import type { ChoiceTag, HeartAction } from "./journey";

export type RealmChoice = {
  id: string;
  label: string;
  feedback: string;
  tags: ChoiceTag[];
  weights: Partial<Record<HeartAction, number>>;
};

export type RealmDefinition = {
  id: number;
  title: string;
  image: string;
  story: string;
  prompt: string;
  choices: RealmChoice[];
  interaction: "drag" | "observe" | "choice" | "autoplay" | "imprint";
  showProgress: boolean;
  showHint: boolean;
  /** @deprecated Kept only until the legacy realm renderer is replaced. */
  game?: "seek_cow" | "bridge" | "jump";
};

export const REALMS: RealmDefinition[] = [
  { id: 1, title: "未牧", image: "stone-untrained.jpg", story: "牛从苔痕深处挣脱。你听见蹄声，也听见自己的心先一步追了出去。", prompt: "你要怎样回应这阵奔逃？", interaction: "drag", showProgress: true, showHint: true, choices: [
    { id: "chase", label: "追上去，不让它再跑。", feedback: "你提起衣角，脚下的尘土先替你回答。", tags: ["chase"], weights: { hold: 1 } },
    { id: "wait", label: "站在原地，先听听四周。", feedback: "风停了一瞬，远处传来一声并不慌张的鼻息。", tags: ["wait"], weights: { observe: 1 } },
    { id: "call", label: "呼唤它，让它自己回来。", feedback: "你的声音落进草间，牛的影子短暂地回了头。", tags: ["look_back"], weights: { observe: 1, harmonize: 1 } },
  ] },
  { id: 2, title: "初调", image: "stone-first-taming.jpg", story: "牛回头看你，却仍把一只脚放在更深的雾里。靠近与停留，都像是在问同一个问题。", prompt: "你把哪一种声音留给它？", interaction: "observe", showProgress: true, showHint: true, choices: [
    { id: "near", label: "再靠近一点。", feedback: "你没有抓住它，但它记住了你的方向。", tags: ["chase"], weights: { hold: 1 } },
    { id: "watch", label: "不动，只观察它的呼吸。", feedback: "一呼一吸之间，缰绳不再像命令。", tags: ["wait"], weights: { observe: 1 } },
    { id: "soften", label: "把脚步放轻，让它决定距离。", feedback: "牛低下头，草尖上的露水替你松开了一结。", tags: ["let_go"], weights: { release: 1 } },
  ] },
  { id: 3, title: "受制", image: "stone-restrained.jpg", story: "绳子落在手里，牛被牵住了，心却还在山下。你终于感觉到，握紧也会让自己失去方向。", prompt: "此刻，你如何握住这根绳？", interaction: "choice", showProgress: true, showHint: true, choices: [
    { id: "tighten", label: "拉紧，不让它偏离。", feedback: "绳痕更深了，牛没有走远，你也没有更近。", tags: ["control"], weights: { hold: 2 } },
    { id: "loosen", label: "松一点，给它喘息。", feedback: "绳子在掌心回暖，沉默开始有了宽度。", tags: ["wait"], weights: { observe: 2, harmonize: 1 } },
    { id: "release", label: "解开，让它自己选择。", feedback: "牛没有立刻离开，只把头转向了你。", tags: ["let_go"], weights: { release: 2 } },
  ] },
  { id: 4, title: "回首", image: "stone-turning-back.jpg", story: "风雨从山口压下来。猛虎的影子掠过石壁，牛忽然停住，回头听你有没有跟上。", prompt: "你要看向哪里？", interaction: "choice", showProgress: true, showHint: true, choices: [
    { id: "follow", label: "追上它，挡在它身前。", feedback: "你追上了牛，却第一次看见它也在护着你。", tags: ["chase"], weights: { hold: 2, harmonize: 2 } },
    { id: "back", label: "回望来路，辨认那块旧碑。", feedback: "旧碑上的拓痕像一条回来的路，雨声也慢下来。", tags: ["look_back"], weights: { observe: 2 } },
    { id: "voice", label: "不靠近，只呼唤它的名字。", feedback: "你的声音穿过雨幕，牛的角在雾里微微一亮。", tags: ["wait"], weights: { observe: 2, harmonize: 1 } },
  ] },
  { id: 5, title: "驯伏", image: "stone-tamed.jpg", story: "两名牧人谈笑着走到桥边。绳索已经下垂，真正需要学会的是把重心交给同行者。", prompt: "上桥前，你先做什么？", interaction: "observe", showProgress: true, showHint: true, choices: [
    { id: "together", label: "和牛并肩，保持同一个步子。", feedback: "你们的脚步不再互相催促，桥身轻轻回稳。", tags: ["together"], weights: { harmonize: 3 } },
    { id: "wait", label: "让牛先走，自己听桥的回声。", feedback: "牛走出两步又停下，像是在等你加入。", tags: ["wait"], weights: { observe: 3 } },
    { id: "lead", label: "自己先走到桥中央。", feedback: "你抢到了方向，却听见身后的蹄声变得迟疑。", tags: ["control"], weights: { hold: 3 } },
  ] },
  { id: 6, title: "无碍", image: "stone-unforced.jpg", story: "桥在雾里消失。泉水替你洗去掌心的绳痕，牛低头饮水，仿佛从未被谁牵引。", prompt: "你把绳子放在哪里？", interaction: "choice", showProgress: true, showHint: true, choices: [
    { id: "hold", label: "继续握着，陪它走远。", feedback: "你还握着绳子，却不再把它当作方向。", tags: ["control"], weights: { hold: 3, harmonize: 2 } },
    { id: "hang", label: "把绳子挂到树枝上。", feedback: "风把绳子吹成一条柔软的线，牛抬头看了看。", tags: ["wait"], weights: { observe: 3, release: 2 } },
    { id: "open", label: "彻底放开。", feedback: "掌心空了，泉水却留下了一点同行的温度。", tags: ["let_go"], weights: { release: 3 } },
  ] },
  { id: 7, title: "任运", image: "stone-forgotten.jpg", story: "风把缰绳吹成一条线。牛自然站在山路上，去处不必预先命名。", prompt: "你选择哪一条路？", interaction: "choice", showProgress: true, showHint: true, choices: [
    { id: "wind", label: "沿着顺风的小路。", feedback: "你没有催促，风替你把远处的路铺开。", tags: ["let_go"], weights: { release: 4, observe: 2 } },
    { id: "hoof", label: "沿着旧蹄印回望。", feedback: "旧蹄印并非退路，它把你带到一处更开阔的地方。", tags: ["look_back"], weights: { observe: 4 } },
    { id: "none", label: "走向还没有路的方向。", feedback: "第一步落下时，路才从脚下出现。", tags: ["chase"], weights: { hold: 4 } },
  ] },
  { id: 8, title: "相忘", image: "stone-solitary.jpg", story: "少年牧人听笛，牛在身后舔蹄，白鹤落在水面。你忽然不必确认谁在跟随谁。", prompt: "这段笛声把你带向哪里？", interaction: "observe", showProgress: true, showHint: true, choices: [
    { id: "find", label: "寻找牛留下的方向。", feedback: "你追随蹄印，却没有把它变成绳索。", tags: ["chase"], weights: { hold: 4, observe: 3 } },
    { id: "listen", label: "闭上眼，把笛声听完。", feedback: "笛声停下时，牛已经在你身旁。", tags: ["wait"], weights: { observe: 4, harmonize: 3 } },
    { id: "reflection", label: "看水里的月和自己的影子。", feedback: "水面摇动，人与牛的边界也轻轻松开。", tags: ["look_back"], weights: { observe: 4, release: 3 } },
  ] },
  { id: 9, title: "独照", image: "stone-both-gone.jpg", story: "水面只剩一轮月。老牧人吹笛，牛无绳饮泉，白鹤静静听着。", prompt: "泉边的这一刻，你如何留下？", interaction: "observe", showProgress: true, showHint: true, choices: [
    { id: "approach", label: "走近一些。", feedback: "你靠近泉水，月影没有碎，只是多了一圈涟漪。", tags: ["chase"], weights: { hold: 5, harmonize: 3 } },
    { id: "stay", label: "停在原地观看。", feedback: "你与倒影相对，终于不急着给它名字。", tags: ["wait"], weights: { observe: 5 } },
    { id: "turn", label: "转身，把路让给它。", feedback: "你转身之后，身后仍有脚步与之相和。", tags: ["let_go"], weights: { release: 5 } },
  ] },
  { id: 10, title: "双忘", image: "stone-meditation.jpg", story: "牧人酣睡，牛卧在旁，猿猴轻轻拨弄衣角却不惊扰。世界第一次不需要你来维持。", prompt: "你会触碰哪一处安静？", interaction: "autoplay", showProgress: true, showHint: false, choices: [
    { id: "monkey", label: "看猿猴把果子放下。", feedback: "你看见顽皮也可以不带走什么。", tags: ["control"], weights: { observe: 5, release: 4 } },
    { id: "cow", label: "看牛的胸口起伏。", feedback: "呼吸把两个影子连在一起，又把它们各自还回去。", tags: ["look_back"], weights: { harmonize: 5, observe: 4 } },
    { id: "blank", label: "什么也不碰，只让画面继续。", feedback: "你没有做什么，故事却自己往前走了。", tags: ["let_go"], weights: { release: 5 } },
  ] },
  { id: 11, title: "禅定", image: "stone-solitary.jpg", story: "牛已经不见了。卷发修行者在龛中入定，月光落下，没有一个声音需要回答。", prompt: "在月光下停留片刻。", interaction: "autoplay", showProgress: true, showHint: false, choices: [
    { id: "moon", label: "点击月光，听它落下。", feedback: "月光没有回声，只有心里的一点尘埃慢慢沉底。", tags: ["wait"], weights: { observe: 6 } },
    { id: "still", label: "不点击，安静看着。", feedback: "静止也成为一种抵达，时间替你盖下印章。", tags: ["let_go"], weights: { release: 6 } },
  ] },
  { id: 12, title: "心月图", image: "stone-mind-moon.jpg", story: "人和牛都不见了，只剩莲台、古碑、瑞云与明月。最后要留下的，不是答案，而是你愿意记住的痕迹。", prompt: "你要把什么留在心月图上？", interaction: "imprint", showProgress: true, showHint: false, choices: [
    { id: "seal-cow", label: "留下牛的身影。", feedback: "牛不再是被寻找的对象，而是一段同行的证词。", tags: ["look_back"], weights: { observe: 7, harmonize: 6 } },
    { id: "seal-path", label: "留下脚下的路。", feedback: "路比目的地更长，走过的每一步都成为签上的墨线。", tags: ["chase"], weights: { hold: 7, harmonize: 6 } },
    { id: "seal-blank", label: "留下空白。", feedback: "空白没有拒绝故事，它只是为下一次相逢留出位置。", tags: ["let_go"], weights: { release: 7, observe: 6 } },
  ] },
];

export function getRealm(id: number): RealmDefinition {
  return REALMS.find((realm) => realm.id === id) ?? REALMS[0];
}
