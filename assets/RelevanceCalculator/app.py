from flask import Flask, request, jsonify
import csv 
import os
import pandas as pd

import related_content_finder as rcf
import user_action as ua

app = Flask(__name__)
ITEMS_CSV = "../content/items.csv"

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


@app.route("/log_event", methods=["POST"])
def log_event():
    data = request.get_json()
    user_id = data.get("user_id", 1)
    title = data.get("item_id")  # Flutterから送られるタイトル
    action = data.get("action")
    from_page = data.get("from", "")
    timestamp = data.get("timestamp")

    if not title or not action:
        return jsonify({"error": "missing fields"}), 400

    # --- タイトル → item_id 解決 ---
    try:
        items_df = pd.read_csv(ITEMS_CSV)
        title_to_id = dict(zip(items_df["title"], items_df["item_id"]))
        item_id = title_to_id.get(title)
        if item_id is None:
            print(f"⚠️ タイトル '{title}' に対応する item_id が見つかりません。")
            item_id = -1
    except Exception as e:
        print(f"❌ items.csv 読み込み失敗: {e}")
        item_id = -1

    # --- ユーザーアクションログ ---
    ua.log_user_action(user_id, item_id, action, from_page, timestamp)

    # --- 行列生成とALS学習 ---
    model, matrix = ua.train_als_model()
    recs = ua.get_als_scores(user_id, model, matrix, top_n=5)

    # NumPy型をPython標準型に変換
    recs_clean = [(int(item), float(score)) for item, score in recs]

    return jsonify({
        "status": "ok",
        "recommendations": recs_clean
    })




if __name__ == "__main__":
    print("🚀 Flask サーバーを起動します… http://127.0.0.1:5000")
    app.run(host="0.0.0.0", port=5000, debug=True)
