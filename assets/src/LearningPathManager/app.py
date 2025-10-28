import os
import sys

from flask import Flask, request, jsonify

APP_DIR = os.path.dirname(os.path.abspath(__file__))  # ../assets/src/LearningPathManager
SRC_DIR = os.path.dirname(APP_DIR)                    # ../assets/src
ASSETS_DIR = os.path.dirname(SRC_DIR)                 # ../assets
ROOT_DIR = os.path.dirname(ASSETS_DIR)                # ../MyApp

CONTENT_DIR = os.path.join(ASSETS_DIR, "content")

# src配下をPythonのモジュールパスに追加（どこから実行してもインポート可能に）
if SRC_DIR not in sys.path:
    sys.path.append(SRC_DIR)

#　関連モジュールのインポート
from RelevanceCalculator import user_action as ua
from InteresrEstimator import related_content_finder as rcf

app = Flask(__name__)

@app.route('/recommend', methods=['POST'])
def recommend():
    data = request.get_json()
    user_id = int(data.get('user_id', 0))
    keyword = data.get('keyword', '')
    print(f"📩 受信: user_id={user_id}, keyword='{keyword}'")

    # ===== 固定パラメータ =====
    w1 = 0.7      # BM25重み
    w2 = 0.3      # ALS重み
    top_n = 3     # 最終出力数
    # ==========================

    # --- BM25 スコア取得 ---
    bm25_scores = rcf.get_bm25_scores(keyword)
    # print(f"📘 BM25スコア取得完了 ({len(bm25_scores)} 件)")

    # --- BM25上位10件を表示 ---
    bm25_top = sorted(bm25_scores.items(), key=lambda x: x[1], reverse=True)[:10]
    print("🔹 BM25 上位10件:")
    for i, (item_id, score) in enumerate(bm25_top, 1):
        title = rcf.get_item_title(item_id)
        print(f"   {i:2d}. ID={item_id:>3} | BM25={score:.4f} | {title}")

    # --- ALS スコア取得 ---
    model, matrix = ua.train_als_model()
    als_scores = ua.get_als_scores(user_id, model, matrix, top_n=50)
    als_scores_dict = dict(als_scores) if als_scores else {}
    # print(f"🎯 ALSスコア取得完了 ({len(als_scores_dict)} 件)")

    # --- ALS上位10件を表示 ---
    als_top = sorted(als_scores_dict.items(), key=lambda x: x[1], reverse=True)[:10]
    print("🔸 ALS 上位10件:")
    for i, (item_id, score) in enumerate(als_top, 1):
        title = rcf.get_item_title(item_id)
        print(f"   {i:2d}. ID={item_id:>3} | ALS={score:.6f} | {title}")

    # --- スコア統合 ---
    all_items = set(bm25_scores.keys()) | set(als_scores_dict.keys())
    hybrid_scores = {}
    for item_id in all_items:
        bm25_val = bm25_scores.get(item_id, 0)
        als_val = als_scores_dict.get(item_id, 0)
        hybrid_scores[item_id] = w1 * bm25_val + w2 * als_val 

    # --- 上位 n 件を選出 ---
    top_items = sorted(hybrid_scores.items(), key=lambda x: x[1], reverse=True)[:top_n]
    print("🔝 ハイブリッド推薦結果:")
    for i, (item_id, score) in enumerate(top_items, 1):
        title = rcf.get_item_title(item_id)
        print(f"   {i:2d}. ID={item_id:>3} | Hybrid={score:.6f} | {title}")

    # --- item_id のみ返す ---
    return jsonify([str(i) for i, _ in top_items])

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
    item_id = ua.title_to_item_id(title)

    # --- ユーザーアクションログ ---
    ua.log_user_action(user_id, item_id, action, from_page, timestamp)

    return jsonify({
        "status": "ok",
    })




if __name__ == "__main__":
    print("🚀 Flask サーバーを起動します… http://127.0.0.1:5000")
    app.run(host="0.0.0.0", port=5000, debug=True)
