import os
import networkx as nx

from rank_bm25 import BM25Okapi
from janome.tokenizer import Tokenizer
import numpy as np, pandas as pd

docs = pd.read_csv("../content/items.csv")
t = Tokenizer()
tokenized = [[token.surface for token in t.tokenize(text)] for text in docs['body']]
bm25 = BM25Okapi(tokenized)

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
    print("relevance_scores:", relevance_scores[:10])  # デバッグ用に上位10件を表示
    return [path for score, path in relevance_scores[:top_n]]

def get_bm25_scores(query):
    q = [token.surface for token in t.tokenize(query)]
    scores = bm25.get_scores(q)
    # Min-Max 正規化
    norm = (scores - np.min(scores)) / (np.max(scores) - np.min(scores))
    return dict(zip(docs['item_id'], norm))

def get_item_title(item_id):
    # item_id が文字列の場合は数値変換を試みる
    try:
        key = int(item_id)
    except Exception:
        try:
            key = int(str(item_id))
        except Exception:
            key = item_id

    matched = docs[docs['item_id'] == key]
    if matched.empty:
        return None
    title = matched['title'].values[0]
    return title if title else None

if __name__ == "__main__":
    # input_keywords = ["生成", "登場", "教育", "あり方", "家庭", "教師", "生徒", "一人ひとり", "理解", "興味"]
    # folder = "../content/ExtraContents"
    # top_matches = estimate_relevance_graph(input_keywords, folder=folder)

    # for i, match in enumerate(top_matches, 1):
    #     print(f"{i}. {match}")

    query = "論理的思考の基本"
    scores = get_bm25_scores(query)
    sorted_scores = sorted(scores.items(), key=lambda x: x[1], reverse=True)[:5]
    for item_id, score in sorted_scores:
        print(f"Item ID: {item_id}, Score: {score:.4f}")
        # 該当ファイルのタイトルを表示
        title = get_item_title(item_id)
        print(f"Title: {title}")