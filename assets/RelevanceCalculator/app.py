from flask import Flask, request, jsonify
import os

import related_content_finder as rcf

app = Flask(__name__)

@app.route('/recommend', methods=['POST'])
def recommend():
    data = request.get_json()
    keyword = data.get('keyword', '')
    print("📩 受け取ったキーワード:", keyword)

    # keywordを使って関連度探索
    # recommendations = rcf.estimate_relevance_graph(keyword)
    scores = rcf.get_bm25_scores(keyword)
    sorted_scores = sorted(scores.items(), key=lambda x: x[1], reverse=True)

    # --- 重複タイトルを除外しながら上位3件抽出 ---
    seen_titles = set()
    recommendations = []
    print("🔍 スコア上位候補:", sorted_scores[:10])  # デバッグ用に上位10件を表示
    for item_id, _score in sorted_scores:

        title = rcf.get_item_title(item_id)
        if title and title != keyword and title not in seen_titles:
            seen_titles.add(title)
            recommendations.append(str(item_id))
        if len(recommendations) >= 3:
            break

    print("🔍 推薦結果:", recommendations)

    # クライアント向けにパスを変換して返す
    # converted = [_convert_path_for_client(p) for p in recommendations]
    # print("🔁 変換後パス (クライアント向け):", converted)

    return jsonify(recommendations)

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
