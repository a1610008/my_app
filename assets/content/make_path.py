import os

# ラーニングパスのデータ（例：10パス × 各3記事）
learning_paths = {
    "LearningPath1": [
        {"title": "生成AIが教育を変える", "main": "AI家庭教師の登場で、学びが個人に合わせて進化。教育の形が大きく変わりつつある。"},
        {"title": "AIと人間の役割分担", "main": "AIが得意な分析や処理、人間が得意な創造や共感。それぞれの強みを活かす時代へ。"},
        {"title": "AI倫理と社会的影響", "main": "AI導入で起こるプライバシーや偏見の問題。倫理的な視点がますます重要に。"}
    ],
    "LearningPath2": [
        {"title": "論理的思考の基本", "main": "課題発見から解決までの流れを学ぶ。"},
        {"title": "マーケティング入門", "main": "4P分析で商品戦略を考える。"},
        {"title": "経営戦略の立て方", "main": "競争優位性をどう築くか。"}
    ],
    "LearningPath3": [
        {"title": "ガムで集中力UP？", "main": "ロッテの研究から見る脳の活性化。"},
        {"title": "脳の準備運動とは", "main": "学習前に脳を整える方法。"},
        {"title": "集中力を持続させる技術", "main": "環境と習慣の工夫で集中力をキープ。"}
    ],
    "LearningPath4": [
        {"title": "グローバル環境での働き方", "main": "異文化理解と対応力が求められる。"},
        {"title": "海外企業の事例研究", "main": "インドのAI教育企業SigIQの挑戦。"},
        {"title": "国際的な交渉術", "main": "文化差を乗り越える交渉力が鍵。"}
    ],
    "LearningPath5": [
        {"title": "大人の学び直しとは", "main": "9割が挫折する理由と対策。"},
        {"title": "継続できる学習法", "main": "モチベーション維持のコツ。"},
        {"title": "学び直しの成功事例", "main": "キャリアアップにつながった人々。"}
    ],
    "LearningPath6": [
        {"title": "クラウド活用の最前線", "main": "自動車業界の取り組みが進化中。"},
        {"title": "SDVとは何か", "main": "Software Defined Vehicleの可能性。"},
        {"title": "生成AIと製造業", "main": "効率化と革新の両立を目指す。"}
    ],
    "LearningPath7": [
        {"title": "10分ニュースの活用法", "main": "教育現場での実践例を紹介。"},
        {"title": "ニュース共有の効果", "main": "クラスの活性化と個人の成長。"},
        {"title": "子どもとニュースの距離", "main": "怖い・堅いという印象を変えるには。"}
    ],
    "LearningPath8": [
        {"title": "学位不要の高収入職", "main": "必要なのは「たったひとつのスキル」。"},
        {"title": "スキル重視の採用", "main": "米国企業の新しい流れ。"},
        {"title": "高収入スキルの習得法", "main": "90日間で身につける方法。"}
    ],
    "LearningPath9": [
        {"title": "AI家庭教師の可能性", "main": "インド企業SigIQの挑戦。"},
        {"title": "教育の民主化とは", "main": "誰もが学べる社会へ。"},
        {"title": "個別最適化学習の実現", "main": "AIが導く学びの進化。"}
    ],
    "LearningPath10": [
        {"title": "集中力とガムの関係", "main": "噛むことで脳が活性化。"},
        {"title": "科学的に見る勉強法", "main": "脳の働きに基づいた学習。"},
        {"title": "日常に潜む科学", "main": "身近な行動の裏にある理論。"}
    ]
}
extra_contents = {
    "1-1": [
        {"title": "AIの歴史", "main": "1950年代から始まったAIの進化。チューリングの理論が基礎に。", "Type": "技術"},
        {"title": "オンライン学習の台頭", "main": "MOOCや動画教材の普及で、学びの場が教室から世界へ広がった。", "Type": "教育"},
        {"title": "AIによる職業変化", "main": "AIの進化で消える仕事と生まれる仕事。未来の働き方を考える。", "Type": "社会"}
    ],
    "1-2": [
        {"title": "チューリングの功績", "main": "AIの父と呼ばれるチューリング。機械が思考できるかを問うた。", "Type": "技術"},
        {"title": "ハイコンテクスト vs ローコンテクスト", "main": "コミュニケーションの違いがAIとの関係にも影響する。", "Type": "文化"},
        {"title": "自動運転の未来", "main": "AIが運転を担う時代。人間の判断とのバランスが課題。", "Type": "工学"}
    ],
    "1-3": [
        {"title": "フェイクニュースの見分け方", "main": "AIが生成する情報の信頼性をどう見極めるかが重要。", "Type": "教育"},
        {"title": "教育格差の是正", "main": "AIによる教育の民主化が、格差を埋める可能性を持つ。", "Type": "社会"},
        {"title": "SNSと意見表明", "main": "AIが関与するSNSでの発言が社会に与える影響を考える。", "Type": "社会"}
    ],
    "2-1": [
        {"title": "ロジカルシンキングのフレーム", "main": "MECEやピラミッド構造で思考を整理する技術。", "Type": "ビジネス"},
        {"title": "課題発見の手法", "main": "現状分析から本質的な問題を見つける方法。", "Type": "教育"},
        {"title": "論理と感情のバランス", "main": "論理だけでは伝わらない。感情との融合が鍵。", "Type": "心理"}
    ],
    "2-2": [
        {"title": "4P分析の実例", "main": "実際の企業の商品戦略を4Pで読み解く。", "Type": "マーケティング"},
        {"title": "消費者行動の心理", "main": "人はなぜ買うのか？購買の裏にある心理を探る。", "Type": "心理"},
        {"title": "ブランド戦略の基本", "main": "ブランド価値を高めるための考え方。", "Type": "ビジネス"}
    ],
    "2-3": [
        {"title": "競争優位性の理論", "main": "ポーターの戦略論から学ぶ差別化の方法。", "Type": "経営"},
        {"title": "企業事例で学ぶ戦略", "main": "AppleやNetflixの成功戦略を分析。", "Type": "企業"},
        {"title": "失敗から学ぶ戦略", "main": "KodakやWeWorkの事例から戦略の落とし穴を知る。", "Type": "経営"}
    ],
    "3-1": [
        {"title": "噛むことと脳の関係", "main": "咀嚼が脳の血流を促進し、集中力を高める。", "Type": "健康"},
        {"title": "ガムの種類と効果", "main": "ミント系とフルーツ系で脳への刺激が異なる。", "Type": "科学"},
        {"title": "集中力と味覚の関係", "main": "味覚刺激が脳の覚醒に影響する可能性。", "Type": "心理"}
    ],
    "3-2": [
        {"title": "脳のウォームアップ法", "main": "軽い運動や深呼吸で脳を起こす方法。", "Type": "健康"},
        {"title": "朝のルーティンと集中力", "main": "朝の習慣が脳の働きに与える影響。", "Type": "生活"},
        {"title": "脳波と学習効率", "main": "α波が出ているときが学習に最適。", "Type": "科学"}
    ],
    "3-3": [
        {"title": "ポモドーロ・テクニック", "main": "25分集中＋5分休憩で効率アップ。", "Type": "教育"},
        {"title": "理想の学習環境", "main": "照明や音が集中力に与える影響。", "Type": "生活"},
        {"title": "習慣化のメカニズム", "main": "脳が「慣れる」ことで集中力が安定する。", "Type": "心理"}
    ],
    "4-1": [
        {"title": "異文化理解の基本", "main": "文化の違いを知ることで誤解を防ぐ。", "Type": "文化"},
        {"title": "グローバルマナー", "main": "国によって異なるビジネスマナーを学ぶ。", "Type": "ビジネス"},
        {"title": "言語と文化の関係", "main": "言語が思考や価値観に与える影響。", "Type": "言語"}
    ],
    "4-2": [
        {"title": "インドの教育事情", "main": "急成長するEdTech市場の背景。", "Type": "教育"},
        {"title": "SigIQの戦略", "main": "AIを活用した個別学習の仕組み。", "Type": "技術"},
        {"title": "アジアの教育格差", "main": "地域による教育機会の違いを探る。", "Type": "社会"}
    ],
    "4-3": [
        {"title": "交渉術の心理学", "main": "相手の立場を理解することで交渉がうまくいく。", "Type": "心理"},
        {"title": "国際交渉の事例", "main": "FTAや国際会議での交渉の実例。", "Type": "政治"},
        {"title": "文化差と説得力", "main": "説得のスタイルは文化によって異なる。", "Type": "文化"}
    ],
    "5-1": [
        {"title": "学び直しの動機", "main": "キャリアや自己成長を求めて学び直す人が増加。", "Type": "キャリア"},
        {"title": "学習の壁と対策", "main": "時間・集中力・環境の課題を乗り越える方法。", "Type": "教育"},
        {"title": "社会人学習の支援制度", "main": "企業や自治体による学び直し支援。", "Type": "社会"}
    ],
    "5-2": [
        {"title": "モチベーション維持法", "main": "目標設定と報酬でやる気を持続。", "Type": "心理"},
        {"title": "学習習慣の作り方", "main": "毎日のルーティンで学びを定着させる。", "Type": "教育"},
        {"title": "時間管理術", "main": "スケジュールと優先順位で効率化。", "Type": "生活"}
    ],
    "5-3": [
        {"title": "成功事例インタビュー", "main": "学び直しで転職や昇進を果たした人々。", "Type": "キャリア"},
                {"title": "スキル習得のプロセス", "main": "段階的に学ぶことでスキルが定着する。", "Type": "教育"},
        {"title": "キャリアチェンジの準備", "main": "学び直しを活かした転職活動のポイント。", "Type": "キャリア"}
    ],
    "6-1": [
        {"title": "クラウドの基本構造", "main": "IaaS・PaaS・SaaSの違いを理解しよう。", "Type": "技術"},
        {"title": "自動車業界のDX", "main": "クラウドで進化する製造とサービス。", "Type": "産業"},
        {"title": "セキュリティの課題", "main": "クラウド導入における情報保護の重要性。", "Type": "技術"}
    ],
    "6-2": [
        {"title": "SDVの仕組み", "main": "ソフトウェアで制御される車の構造とは。", "Type": "工学"},
        {"title": "EVとの違い", "main": "電気自動車とSDVの技術的な違い。", "Type": "技術"},
        {"title": "未来の車社会", "main": "SDVがもたらす交通の変化。", "Type": "社会"}
    ],
    "6-3": [
        {"title": "AIによる品質管理", "main": "製造現場でのAI活用事例。", "Type": "産業"},
        {"title": "生産性向上の工夫", "main": "AIとIoTで工場の効率を最大化。", "Type": "技術"},
        {"title": "人とAIの協働", "main": "人間とAIが共に働く未来の工場。", "Type": "社会"}
    ],
    "7-1": [
        {"title": "ニュース教材の作り方", "main": "10分で読める要約記事の活用法。", "Type": "教育"},
        {"title": "探究型学習との相性", "main": "ニュースを使った深掘り学習の実践。", "Type": "教育"},
        {"title": "時事問題の扱い方", "main": "子どもにどう伝えるかの工夫。", "Type": "教育"}
    ],
    "7-2": [
        {"title": "ディスカッションの効果", "main": "ニュースを共有することで思考が広がる。", "Type": "教育"},
        {"title": "意見交換のルール", "main": "安心して話せる場づくりのポイント。", "Type": "心理"},
        {"title": "ニュースと価値観", "main": "異なる視点を知ることで多様性を学ぶ。", "Type": "社会"}
    ],
    "7-3": [
        {"title": "子ども向けニュースサイト", "main": "わかりやすくて安全な情報源を紹介。", "Type": "教育"},
        {"title": "メディアリテラシー入門", "main": "情報の信頼性を見極める力を育てる。", "Type": "教育"},
        {"title": "ニュースと感情", "main": "怖い・悲しいニュースとの向き合い方。", "Type": "心理"}
    ],
    "8-1": [
        {"title": "高収入スキル一覧", "main": "データ分析・プログラミングなど注目スキル。", "Type": "キャリア"},
        {"title": "スキルと年収の関係", "main": "習得したスキルが収入にどう影響するか。", "Type": "経済"},
        {"title": "独学のすすめ", "main": "学位がなくてもスキルで勝負できる時代。", "Type": "教育"}
    ],
    "8-2": [
        {"title": "スキルベース採用とは", "main": "学歴よりも実力重視の採用が広がる。", "Type": "仕事"},
        {"title": "ポートフォリオの作り方", "main": "成果を見せるための資料作成術。", "Type": "キャリア"},
        {"title": "LinkedIn活用術", "main": "スキルをアピールするSNS活用法。", "Type": "ビジネス"}
    ],
    "8-3": [
        {"title": "90日学習計画", "main": "短期集中でスキルを身につける方法。", "Type": "教育"},
        {"title": "反復練習の効果", "main": "繰り返し学ぶことで記憶が定着する。", "Type": "心理"},
        {"title": "学習ツール紹介", "main": "おすすめのアプリや教材を紹介。", "Type": "技術"}
    ],
    "9-1": [
        {"title": "AI家庭教師の仕組み", "main": "学習履歴に基づいて問題を出す技術。", "Type": "技術"},
        {"title": "EdTechの進化", "main": "教育とテクノロジーの融合が進む。", "Type": "教育"},
        {"title": "個別学習の未来", "main": "一人ひとりに合わせた学びが可能に。", "Type": "教育"}
    ],
    "9-2": [
        {"title": "教育の民主化とは", "main": "誰もが学べる環境を整える取り組み。", "Type": "社会"},
        {"title": "教育格差の課題", "main": "地域や経済状況による学習機会の違い。", "Type": "社会"},
        {"title": "無料学習ツール紹介", "main": "誰でも使える学習支援サービス。", "Type": "教育"}
    ],
    "9-3": [
        {"title": "AIによる学習分析", "main": "学習データから最適な指導を導く。", "Type": "技術"},
        {"title": "ゾーン理論とは", "main": "学習者の成長を促す理論的枠組み。", "Type": "教育"},
        {"title": "構成主義の学び", "main": "知識を構築するプロセスを重視する教育法。", "Type": "教育"}
    ],
    "10-1": [
        {"title": "咀嚼と脳の関係", "main": "噛むことで脳の血流が増し、集中力が向上。", "Type": "健康"},
        {"title": "味覚と脳の刺激", "main": "味の刺激が脳の覚醒に影響する。", "Type": "科学"},
        {"title": "ガムの種類と効果", "main": "フレーバーによって集中力に差が出る。", "Type": "心理"}
    ],
    "10-2": [
        {"title": "脳科学的学習法", "main": "脳の働きに合わせた学習スタイル。", "Type": "科学"},
        {"title": "記憶のメカニズム", "main": "短期記憶と長期記憶の違いを理解する。", "Type": "医学"},
        {"title": "集中力と運動", "main": "軽い運動が脳の活性化に効果的。", "Type": "健康"}
    ],
    "10-3": [
        {"title": "生活に潜む科学", "main": "日常の行動に科学的根拠があることを知る。", "Type": "科学"},
        {"title": "習慣と脳の関係", "main": "繰り返しの行動が脳に与える影響。", "Type": "心理"},
        {"title": "睡眠と学習効果", "main": "よく眠ることで記憶力が向上する。", "Type": "健康"}
    ]
}


def make_LearningPaths():
    # ファイル生成処理
    for folder, articles in learning_paths.items():
        os.makedirs(folder, exist_ok=True)
        for idx, article in enumerate(articles, start=1):
            filename = f"{folder}/Path{folder[-1]}-{idx}.txt"
            with open(filename, "w", encoding="utf-8") as f:
                f.write(f"title: {article['title']}\n")
                f.write(f"main: {article['main']}\n")

    print("すべてのテキストファイルを生成しました！💧")

def make_ExtraContents():
    # ExtraContents フォルダに保存
    os.makedirs("ExtraContents", exist_ok=True)

    for key, extras in extra_contents.items():
        for idx, extra in enumerate(extras, start=1):
            filename = f"ExtraContents/Extra{key}-{idx}.txt"
            with open(filename, "w", encoding="utf-8") as f:
                f.write(f"title: {extra['title']}\n")
                f.write(f"main: {extra['main']}\n")
                f.write(f"Type: {extra['Type']}\n")

    print("寄り道コンテンツを ExtraContents フォルダに保存したよ！🫧")

def make_folderPaths():
    import os

# 対象のルートフォルダ（カレントディレクトリ）
root_dirs = [f"LearningPath{i}" for i in range(1, 11)] + ["ExtraContents"]

# 出力ファイル名
output_file = "folder_structure.txt"

with open(output_file, "w", encoding="utf-8") as f:
    for root in root_dirs:
        if os.path.exists(root):
            f.write(f"{root}/\n")
            for file in sorted(os.listdir(root)):
                f.write(f"  └── {file}\n")
        else:
            f.write(f"{root}/ (フォルダが存在しません)\n")

print("フォルダ構成を folder_structure.txt に保存したよ！📁🫧")

def make_path_titletxt():
    import os

    # 各ラーニングパスのタイトル（フォルダ名と対応）
    path_titles = {
        "LearningPath1": "生成AIの未来を探る",
        "LearningPath2": "ビジネススキルを磨く",
        "LearningPath3": "脳と集中力の科学",
        "LearningPath4": "グローバルビジネスの基礎",
        "LearningPath5": "学び直しのススメ",
        "LearningPath6": "テクノロジーと社会",
        "LearningPath7": "ニュースで学ぶ社会",
        "LearningPath8": "スキルで年収アップ",
        "LearningPath9": "教育の未来",
        "LearningPath10": "科学と日常"
    }

    # 各フォルダに PathTitle.txt を作成
    for folder, title in path_titles.items():
        os.makedirs(folder, exist_ok=True)
        filepath = os.path.join(folder, "PathTitle.txt")
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(f"title: {title}\n")

    print("各フォルダに PathTitle.txt を作成したよ！📘✨")


if __name__ == "__main__":
    make_LearningPaths()
    make_ExtraContents()
    make_folderPaths()
    make_path_titletxt()