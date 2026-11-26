import Foundation

public enum DeviceText: String, CaseIterable, Sendable {
    case status, food, training, quest, clean, power, medical, call, clock, sound, age, weight, hunger, strength, effort, dp, winRate
    case meat, protein, start, hits, success, fail, victory, defeat, lights, cold, backup, yes, no, on, off, egg, days, confirm, cancel
    case devices, digidex, history, settings, classic, enhanced, sandbox, mode, unknown, locked, firstObtained, obtainedCount, all, attribute, stage, device, collection
    case sleep, sick, injured, dead, frozen, live, touch, volume, contrast, brightness, shell, language, notifications, reset, returnFormal, timeAdvance, animation, animationFallback, pending, ready, trainingCount, battleCount, wins, losses, species, careMistakes, evolutionTime
    public func text(_ language: AppLanguage) -> String {
        let i = [AppLanguage.simplified,.traditional,.english,.japanese].firstIndex(of: language) ?? 0
        return Self.words[self]?[i] ?? rawValue
    }
    public static let words: [Self:[String]] = [
        .status:["状态","狀態","STATUS","ステータス"],.food:["喂食","餵食","FOOD","しょくじ"],.training:["训练","訓練","TRAIN","トレーニング"],
        .quest:["闯关","闖關","QUEST","クエスト"],.clean:["清洁","清潔","CLEAN","トイレ"],.power:["电源","電源","POWER","でんげん"],
        .medical:["医疗","醫療","MEDICAL","ちりょう"],.call:["呼叫","呼叫","CALL","よびだし"],.clock:["时钟","時鐘","CLOCK","とけい"],.sound:["音效","音效","SOUND","サウンド"],
        .age:["年龄","年齡","AGE","ねんれい"],.weight:["体重","體重","WEIGHT","たいじゅう"],.hunger:["饱食","飽食","HUNGER","おなか"],
        .strength:["力量","力量","STRENGTH","きんりょく"],.effort:["努力","努力","EFFORT","どりょく"],.dp:["体力 DP","體力 DP","DP","たいりょく"],.winRate:["战斗胜率","戰鬥勝率","WIN RATE","しょうりつ"],
        .meat:["肉","肉","MEAT","エサ"],.protein:["蛋白质","蛋白質","PROTEIN","プロテイン"],.start:["开始","開始","START","スタート"],.hits:["命中","命中","HITS","ヒット"],
        .success:["成功","成功","SUCCESS","せいこう"],.fail:["失败","失敗","FAIL","しっぱい"],.victory:["胜利","勝利","VICTORY","しょうり"],.defeat:["败北","敗北","DEFEAT","はいぼく"],
        .lights:["灯光","燈光","LIGHTS","ライト"],.cold:["冷冻","冷凍","COLD","コールド"],.backup:["备份交换","備份交換","BACKUP","バックアップ"],
        .yes:["是","是","YES","はい"],.no:["否","否","NO","いいえ"],.on:["开","開","ON","オン"],.off:["关","關","OFF","オフ"],.egg:["数码蛋","數碼蛋","DIGITAMA","デジタマ"],.days:["天","天","DAYS","さい"],
        .confirm:["确认","確認","CONFIRM","けってい"],.cancel:["返回","返回","BACK","もどる"],.devices:["设备收藏","設備收藏","DEVICES","デバイス"],.digidex:["图鉴","圖鑑","DIGIDEX","ずかん"],.history:["养成历史","養成歷史","HISTORY","きろく"],.settings:["设置","設定","SETTINGS","せってい"],
        .classic:["经典模式","經典模式","CLASSIC","クラシック"],.enhanced:["增强模式","增強模式","ENHANCED","エンハンス"],.sandbox:["沙盒测试","沙盒測試","SANDBOX","サンドボックス"],.mode:["游戏模式","遊戲模式","MODE","モード"],
        .unknown:["未发现","未發現","UNKNOWN","みはっけん"],.locked:["未解锁","未解鎖","LOCKED","ロック"],.firstObtained:["首次获得","首次獲得","FIRST OBTAINED","はじめて"],.obtainedCount:["获得次数","獲得次數","OBTAINED","かいすう"],.all:["全部","全部","ALL","すべて"],
        .attribute:["属性","屬性","ATTRIBUTE","ぞくせい"],.stage:["成长阶段","成長階段","STAGE","せいちょう"],.device:["设备","設備","DEVICE","デバイス"],.collection:["收藏","收藏","COLLECTION","コレクション"],
        .sleep:["睡眠","睡眠","SLEEP","すいみん"],.sick:["生病","生病","SICK","びょうき"],.injured:["受伤","受傷","INJURED","けが"],.dead:["回归数据","回歸資料","MEMORY","しぼう"],.frozen:["已冷冻","已冷凍","FROZEN","コールド"],.live:["成长中","成長中","LIVE","せいちょう"],
        .touch:["触屏模式","觸控模式","TOUCH MODE","タッチ操作"],.volume:["音量","音量","VOLUME","おんりょう"],.contrast:["LCD对比度","LCD對比度","CONTRAST","コントラスト"],.brightness:["LCD亮度","LCD亮度","BRIGHTNESS","あかるさ"],.shell:["外壳颜色","外殼顏色","SHELL","ほんたいカラー"],.language:["语言","語言","LANGUAGE","げんご"],
        .notifications:["本地提醒","本機提醒","REMINDERS","つうち"],.reset:["重置设备","重設設備","RESET DEVICE","リセット"],.returnFormal:["返回正式养成","返回正式養成","RETURN TO FORMAL","通常育成にもどる"],.timeAdvance:["推进测试时间","推進測試時間","ADVANCE TIME","テスト時間を進める"],.animation:["动作预览","動作預覽","ANIMATION","アニメーション"],
        .animationFallback:["已有姿势回退","現有姿勢替代","POSE FALLBACK","代替ポーズ"],.pending:["待核验","待核驗","PENDING DATA","データ未確認"],.ready:["可游玩","可遊玩","PLAYABLE","プレイ可能"],.trainingCount:["训练次数","訓練次數","TRAINING COUNT","トレーニング数"],.battleCount:["战斗次数","戰鬥次數","BATTLES","バトル数"],.wins:["胜利次数","勝利次數","WINS","しょうり数"],.losses:["失败次数","失敗次數","LOSSES","はいぼく数"],.species:["角色编号","角色編號","SPECIES ID","ID"],.careMistakes:["照顾失误","照顧失誤","CARE MISTAKES","おせわミス"],.evolutionTime:["阶段成长时间","階段成長時間","STAGE TIME","せいちょう時間"]
    ]
}
public extension Species {
    func localizedName(_ language: AppLanguage) -> String {
        switch language { case .simplified: return nameSC; case .traditional: return nameTC; case .english: return name; case .japanese: return nameJP }
    }
}
