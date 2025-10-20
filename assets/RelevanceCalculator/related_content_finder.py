import os
import networkx as nx

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

if __name__ == "__main__":
    input_keywords = ["生成", "登場", "教育", "あり方", "家庭", "教師", "生徒", "一人ひとり", "理解", "興味"]
    folder = "../content/ExtraContents"
    top_matches = estimate_relevance_graph(input_keywords, folder=folder)

    for i, match in enumerate(top_matches, 1):
        print(f"{i}. {match}")