from flask import Flask, request, jsonify
import os
import networkx as nx
# import related_content_finder as rcf

app = Flask(__name__)

@app.route('/recommend', methods=['POST'])
def recommend():
    data = request.get_json()
    keyword = data.get('keyword', '')
    print("📩 受け取ったキーワード:", keyword)

    # keywordを使って関連度探索
    recommendations = estimate_relevance_graph(keyword)
    print("🔍 推薦結果:", recommendations)

    # クライアント向けにパスを変換して返す
    converted = [_convert_path_for_client(p) for p in recommendations]
    print("🔁 変換後パス (クライアント向け):", converted)

    return jsonify(converted)

def build_keyword_graph(folder="../content/ExtraContents"):
    G = nx.Graph()

    for root, _, files in os.walk(folder):
        for file in files:
            if file.endswith(".txt"):
                path = os.path.join(root, file)
                with open(path, "r", encoding="utf-8") as f:
                    lines = f.readlines()

                for line in lines:
                    if line.startswith("keyword:"):
                        keywords = line[len("keyword:"):].strip().split(", ")
                        for kw in keywords:
                            G.add_node(kw)
                        for i in range(len(keywords)):
                            for j in range(i + 1, len(keywords)):
                                G.add_edge(keywords[i], keywords[j], weight=1.0)
                        break
    return G

def estimate_relevance_graph(input_keywords, folder="../content/ExtraContents", top_n=3):
    G = build_keyword_graph(folder)
    relevance_scores = []

    for root, _, files in os.walk(folder):
        for file in files:
            if file.endswith(".txt"):
                path = os.path.join(root, file)
                with open(path, "r", encoding="utf-8") as f:
                    lines = f.readlines()

                for line in lines:
                    if line.startswith("keyword:"):
                        file_keywords = line[len("keyword:"):].strip().split(", ")
                        union = set(input_keywords) | set(file_keywords)
                        intersection = set(input_keywords) & set(file_keywords)

                        # 類似度スコア（Jaccard係数）
                        score = len(intersection) / len(union) if union else 0

                        # グラフ上の接続も加味（近接ノード数）
                        graph_score = sum(1 for kw in input_keywords for fk in file_keywords if G.has_edge(kw, fk))
                        total_score = score + 0.1 * graph_score  # 重み調整

                        relevance_scores.append((total_score, path))
                        break

    relevance_scores.sort(reverse=True)
    return [path for score, path in relevance_scores[:top_n]]

def _convert_path_for_client(path):
    # バックスラッシュをスラッシュに統一
    p = path.replace("\\", "/")
    # ../content/... -> assets/content/...
    p = p.replace("../content/", "assets/content/")
    # ../assets/... -> assets/...
    p = p.replace("../assets/", "assets/")
    # ./ を削除
    if p.startswith("./"):
        p = p[2:]
    # 先頭に余分な ../ が残っていたら取り除く
    while p.startswith("../"):
        p = p[3:]
    return p


if __name__ == "__main__":
    print("🚀 Flask サーバーを起動します… http://127.0.0.1:5000")
    app.run(host="0.0.0.0", port=5000, debug=True)
