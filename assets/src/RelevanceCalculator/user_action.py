
import csv
import os

import numpy as np
import pandas as pd

from scipy.sparse import csr_matrix
from implicit.als import AlternatingLeastSquares
# ================================
# 🔧 設定
# ================================
APP_DIR = os.path.dirname(os.path.abspath(__file__))  # ../assets/src/LearningPathManager
SRC_DIR = os.path.dirname(APP_DIR)                    # ../assets/src
ASSETS_DIR = os.path.dirname(SRC_DIR)                 # ../assets
ROOT_DIR = os.path.dirname(ASSETS_DIR)                # ../MyApp

CONTENT_DIR = os.path.join(ASSETS_DIR, "content")
LOG_DIR = os.path.join(ASSETS_DIR, "logs")

LOG_FILE = os.path.join(LOG_DIR, "user_events.csv")
ITEMS_CSV = os.path.join(CONTENT_DIR, "items.csv")

# ================================
# ⚙️ action → action_id マップ
# ================================
ACTION_MAP = {
    "click": 1,
    "bookmark": 2,
    "navigate": 3
}

ACTIONS_WEIGHT = {
    "click": 1.0,
    "navigate": 2.0,
    "bookmark": 3.0
}
# ================================
# 🗂️ items.csv のロード関数
# ================================
def load_items_map():
    """items.csv から {title: item_id} の辞書を作成"""
    mapping = {}
    if not os.path.exists(ITEMS_CSV):
        print(f"⚠️ {ITEMS_CSV} が存在しません。title→id変換ができません。")
        return mapping

    with open(ITEMS_CSV, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            print("row:", row)  # デバッグ用に行データを表示
            title = row.get("title")
            item_id = row.get("item_id")
            print("Loaded item:", title, item_id)  # デバッグ用に読み込んだアイテムを表示
            if title and item_id:
                mapping[title.strip()] = item_id.strip()
    return mapping

# ================================
# 📝 ユーザーアクションログ記録関数
# ================================
def log_user_action(user_id, item_id, action, from_page="", timestamp=""):
    """ユーザーアクションをCSVに記録する"""

    # ログフォルダを作成
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)

    # CSVファイルが存在しなければ、ヘッダーを書き込む
    write_header = not os.path.exists(LOG_FILE)

    # action → action_id 変換
    action_id = ACTION_MAP.get(action.lower(), 0)

    # CSV追記
    with open(LOG_FILE, "a", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        if write_header:
            writer.writerow(["timestamp", "user_id", "item_id", "action", "action_id", "from"])
        writer.writerow([timestamp, user_id, item_id, action, action_id, from_page])

    print(f"📝 user_events に記録: user_id={user_id}, item_id={item_id}, action={action}")

# ============================================================
# ALSモデルの訓練関数
# ============================================================
def train_als_model(csv_path=LOG_FILE, factors=20, regularization=0.1, iterations=20):
    if not os.path.exists(csv_path):
        print(f"❌ {csv_path} が見つかりません。学習をスキップします。")
        return None, None

    df = pd.read_csv(csv_path)

    # 不要行を削除
    df = df.dropna(subset=["user_id", "item_id", "action"])
    df = df[df["action"].isin(["click", "bookmark", "navigate"])]

    # 重みを設定
    weight_map = {"click": 1.0, "bookmark": 3.0, "navigate": 2.0}
    df["weight"] = df["action"].map(weight_map)

    # ユーザー数・アイテム数の上限を固定
    num_users = int(df["user_id"].max()) + 1
    num_items = int(df["item_id"].max()) + 1

    # print(f"🧠 ALSモデル訓練中... 行列 shape=({num_users}, {num_items})")

    # 🔧 全てのitem_idを含む疎行列を生成
    matrix = csr_matrix(
        (df["weight"], (df["user_id"], df["item_id"])),
        shape=(num_users, num_items)
    )

    # ALSモデルを構築
    model = AlternatingLeastSquares(
        factors=factors,
        regularization=regularization,
        iterations=iterations
    )

    # 🚨 ここが重要：全アイテム列を含む転置行列を渡す
    model.fit(matrix)

    # print(f"✅ ALSモデル訓練完了: users={num_users}, items={num_items}")
    # print(f"   model.item_factors.shape={model.item_factors.shape}")

    return model, matrix

# ============================================================
# タイトル → item_id 変換関数
# ============================================================
def title_to_item_id(title):
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
    return item_id

# ============================================================
# ALSモデルからスコアを取得する関数
# ============================================================
def get_als_scores(user_id, model, matrix, top_n=5):
    if model is None or matrix is None:
        print("⚠️ ALSモデルまたは行列が未定義のためスコア計算をスキップします。")
        return []

    num_items_matrix = matrix.shape[1]
    num_items_model = model.item_factors.shape[0]

    # ✅ サイズ整合性チェック
    if num_items_matrix != num_items_model:
        print(f"❌ モデルと行列の列数不一致: model={num_items_model}, matrix={num_items_matrix}")
        print("🧩 再訓練が必要です。スコアを返さず終了します。")
        return []

    # ✅ user_idが範囲内かチェック
    if user_id >= matrix.shape[0]:
        print(f"⚠️ user_id {user_id} は範囲外です（最大 {matrix.shape[0]-1}）")
        return []

    # ✅ ALS推薦実行
    try:
        recs, scores = model.recommend(user_id, matrix[user_id], N=top_n)
        scores = np.array(scores, dtype=float)

        # --- 🔧 Min-Max正規化 ---
        if len(scores) > 0:
            min_score = np.min(scores)
            max_score = np.max(scores)
            if max_score > min_score:
                scores = (scores - min_score) / (max_score - min_score)
            else:
                scores = np.zeros_like(scores)

        # print(f"🎯 ALS推薦結果: {list(zip(recs, scores))}")
        return list(zip(recs, scores))
    except Exception as e:
        print(f"❌ ALS推薦中にエラー発生: {e}")
        print(f"🧩 model.item_factors.shape={model.item_factors.shape}, matrix.shape={matrix.shape}")
        return []