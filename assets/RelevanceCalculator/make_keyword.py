import os
import MeCab

# ストップワード（助詞・接続詞など）
STOPWORDS = set([
    "こと", "もの", "それ", "これ", "ため", "よう", "など", "に", "の", "が", "を", "と", "は", "も", "で", "から", "まで", "より",
    "そして", "しかし", "また", "さらに", "です", "ます", "する", "ある", "いる", "なる", "できる", "思う", "考える"
])

# MeCab初期化
tagger = MeCab.Tagger("-Ochasen")
tagger.parse("")  # バグ回避

# キーワード抽出関数
def extract_keywords(text, top_n=10):
    node = tagger.parseToNode(text)
    keywords = []

    while node:
        features = node.feature.split(",")
        surface = node.surface
        pos = features[0]
        base = features[6] if len(features) > 6 else surface

        if pos == "名詞" and base not in STOPWORDS and len(base) > 1:
            keywords.append(base)
        node = node.next

    return list(dict.fromkeys(keywords))[:top_n]

# 対象フォルダ
folders = ["../content/LearningPath" + str(i) for i in range(1, 11)] + ["../content/ExtraContents"]

# ファイル処理
for folder in folders:
    for root, _, files in os.walk(folder):
        for file in files:
            if file.endswith(".txt") and file != "PathTitle.txt":
                path = os.path.join(root, file)
                with open(path, "r", encoding="utf-8") as f:
                    lines = f.readlines()

                # main: の行を探してキーワード抽出
                for line in lines:
                    if line.startswith("main:"):
                        text = line[len("main:"):].strip()
                        keywords = extract_keywords(text)
                        break
                else:
                    keywords = []

                # keyword: を追記（すでにある場合は上書き）
                new_lines = [line for line in lines if not line.startswith("keyword:")]
                new_lines.append(f"keyword: {', '.join(keywords)}\n")

                with open(path, "w", encoding="utf-8") as f:
                    f.writelines(new_lines)

print("🌊 キーワード抽出＆追記完了！")
