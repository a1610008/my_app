import os

def write_folder_structure(output_file="folder_structure.txt"):
    root_dir = os.getcwd()
    with open(output_file, "w", encoding="utf-8") as f:
        for dirpath, dirnames, filenames in os.walk(root_dir):
            # 階層の深さに応じてインデント
            depth = dirpath.replace(root_dir, "").count(os.sep)
            indent = "    " * depth
            f.write(f"{indent}{os.path.basename(dirpath)}/\n")
            for filename in filenames:
                f.write(f"{indent}    {filename}\n")
    print(f"📁 フォルダ構成を '{output_file}' に出力したよ！")

# 実行
if __name__ == "__main__":
    write_folder_structure()