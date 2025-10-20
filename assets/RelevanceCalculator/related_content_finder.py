import json
import os
import networkx as nx

# ファイルパス（必要に応じて調整）
LEARNING_PATH_FILE = "learning_paths.json"
EXTRA_CONTENT_FILE = "extra_contents.json"
OUTPUT_FILE = "related_map.json"

# 関連度スコア計算ルール
def calculate_score(main, extra):
    score = 0
    if main.get("genre") == extra.get("Type"):
        score += 2
    score += len(set(main.get("keywords", [])) & set(extra.get("keywords", [])))
    if any(word in extra["title"] for word in main["title"].split()):
        score += 1
    return score

# データ読み込み
def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

# グラフ構築と関連探索
def build_related_map():
    learning_paths = load_json(LEARNING_PATH_FILE)
    extra_contents = load_json(EXTRA_CONTENT_FILE)
    related_map = {}

    G = nx.Graph()

    # ノード追加
    for lp_key, articles in learning_paths.items():
        for i, article in enumerate(articles):
            node_id = f"{lp_key}_{i}"
            G.add_node(node_id, **article, genre=path_genres.get(lp_key, ""), keywords=extract_keywords(article["main"]))
    
    for ex_key, articles in extra_contents.items():
        for i, article in enumerate(articles):
            node_id = f"{ex_key}_{i}"
            G.add_node(node_id, **article, keywords=extract_keywords(article["main"]))

    # エッジ追加
    for mp_id in [n for n in G.nodes if n.startswith("LearningPath")]:
        related = []
        for ex_id in [n for n in G.nodes if n.startswith("EX_") or n.startswith("1-")]:
            score = calculate_score(G.nodes[mp_id], G.nodes[ex_id])
            if score > 0:
                G.add_edge(mp_id, ex_id, weight=score)
                related.append((ex_id, score))
        # 上位3件を保存
        top_related = sorted(related, key=lambda x: x[1], reverse=True)[:3]
        related_map[mp_id] = [r[0] for r in top_related]

    # 結果保存
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(related_map, f, ensure_ascii=False, indent=2)
    print(f"✅ 関連マップを '{OUTPUT_FILE}' に保存したよ！")

# キーワード抽出（簡易版）
def extract_keywords(text):
    stopwords = ["こと", "する", "ある", "など", "ため", "よう", "が", "を", "に", "で", "と", "は", "も"]
    words = [w for w in text.replace("。", "").replace("、", "").split() if w not in stopwords]
    return words[:10]  # 適当に上位10語を抽出

# ジャンル定義（仮）
path_genres = {
    "LearningPath1": "テクノロジー",
    "LearningPath2": "ビジネス",
    "LearningPath3": "健康",
    "LearningPath4": "国際",
    "LearningPath5": "教育",
    "LearningPath6": "工学",
    "LearningPath7": "社会",
    "LearningPath8": "キャリア",
    "LearningPath9": "教育",
    "LearningPath10": "科学"
}

# 実行
if __name__ == "__main__":
    build_related_map()
